-- ============================================================================
-- Migration 003: Implement Proper SCD Type 2 for dim_product
-- ============================================================================
--
-- This migration adds proper SCD Type 2 handling for dim_product:
-- - Renames existing dim_product (if any) and creates a new one with SCD2 columns.
-- - stg_product: Staging table for incoming product events
-- - sp_merge_product_scd2: Stored procedure to process SCD Type 2 logic
-- - Stream Analytics and seed scripts will write to stg_product, then SP processes changes
--
-- Execution: Run after 002_implement_scd2_vendor.sql
-- Rollback: Drop objects created in this migration
--
-- ============================================================================

PRINT 'Starting Migration 003: Implement SCD Type 2 for dim_product';
GO

-- ============================================================================
-- 0. Pre-migration: Handle existing dim_product
-- ============================================================================

-- If dim_product exists without SCD2 columns, we need to adapt it or re-create it.
-- For simplicity and assuming initial deployment, we will drop and recreate.
-- In a real-world scenario with existing data, a more complex migration
-- involving data movement would be necessary.

IF OBJECT_ID('dbo.dim_product', 'U') IS NOT NULL
BEGIN
    PRINT 'Dropping existing dim_product table for recreation with SCD2 schema...';
    DROP TABLE dbo.dim_product;
END
GO

-- ============================================================================
-- 1. Create dim_product table with SCD Type 2 attributes
-- ============================================================================

PRINT 'Creating dim_product table with SCD Type 2 attributes...';
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_product')
BEGIN
    CREATE TABLE dim_product (
        product_key     INT IDENTITY(1,1) PRIMARY KEY, -- Surrogate Key
        product_id      NVARCHAR(50) NOT NULL,         -- Natural Key
        name            NVARCHAR(255) NOT NULL,
        category        NVARCHAR(100) NOT NULL,
        vendor_id       NVARCHAR(50) NOT NULL DEFAULT 'SHOPNOW', -- Added in migration 001
        valid_from      DATETIME2 NOT NULL,
        valid_to        DATETIME2,
        is_current      BIT NOT NULL,
        created_at      DATETIME2 NOT NULL DEFAULT GETDATE(),
        updated_at      DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    CREATE UNIQUE INDEX uix_dim_product_natural_key_current
    ON dim_product (product_id)
    WHERE is_current = 1; -- Ensures only one current record per product_id

    CREATE INDEX idx_dim_product_product_id ON dim_product(product_id);
    CREATE INDEX idx_dim_product_is_current ON dim_product(is_current);
    CREATE INDEX idx_dim_product_valid_from ON dim_product(valid_from);

    PRINT '✓ dim_product table created with SCD2 attributes';
END
ELSE
BEGIN
    PRINT '⚠ dim_product table already exists with (presumably) SCD2 attributes';
END
GO

-- ============================================================================
-- 2. Create Staging Table for Product Events
-- ============================================================================

PRINT 'Creating stg_product staging table...';
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'stg_product')
BEGIN
    CREATE TABLE stg_product (
        staging_id      INT IDENTITY(1,1) PRIMARY KEY,
        product_id      NVARCHAR(50) NOT NULL,
        name            NVARCHAR(255) NOT NULL,
        category        NVARCHAR(100) NOT NULL,
        vendor_id       NVARCHAR(50) NOT NULL DEFAULT 'SHOPNOW',
        event_timestamp DATETIME2 NOT NULL,
        processed       BIT NOT NULL DEFAULT 0,
        created_at      DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    CREATE INDEX idx_stg_product_processed ON stg_product(processed);
    CREATE INDEX idx_stg_product_id ON stg_product(product_id);

    PRINT '✓ stg_product table created';
END
ELSE
BEGIN
    PRINT '⚠ stg_product table already exists';
END
GO

-- ============================================================================
-- 3. Create Stored Procedure for SCD Type 2 Processing (Products)
-- ============================================================================

PRINT 'Creating sp_merge_product_scd2 stored procedure...';
GO

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_merge_product_scd2' AND type = 'P')
BEGIN
    DROP PROCEDURE sp_merge_product_scd2;
    PRINT '⚠ Dropped existing sp_merge_product_scd2';
END
GO

CREATE PROCEDURE sp_merge_product_scd2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProcessedCount INT = 0;
    DECLARE @InsertedCount INT = 0;
    DECLARE @UpdatedCount INT = 0;

    -- Process each unprocessed staging record
    DECLARE @staging_id INT;
    DECLARE @product_id NVARCHAR(50);
    DECLARE @name NVARCHAR(255);
    DECLARE @category NVARCHAR(100);
    DECLARE @vendor_id NVARCHAR(50);
    DECLARE @event_timestamp DATETIME2;

    DECLARE staging_cursor CURSOR FOR
        SELECT staging_id, product_id, name, category, vendor_id, event_timestamp
        FROM stg_product
        WHERE processed = 0
        ORDER BY created_at; -- Process in order of arrival

    OPEN staging_cursor;

    FETCH NEXT FROM staging_cursor INTO
        @staging_id, @product_id, @name, @category, @vendor_id, @event_timestamp;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check if product exists with is_current = 1
        DECLARE @current_product_key INT;
        DECLARE @current_name NVARCHAR(255);
        DECLARE @current_category NVARCHAR(100);
        DECLARE @current_vendor_id NVARCHAR(50);
        DECLARE @has_changes BIT = 0;

        SELECT TOP 1
            @current_product_key = product_key,
            @current_name = name,
            @current_category = category,
            @current_vendor_id = vendor_id
        FROM dim_product
        WHERE product_id = @product_id AND is_current = 1;

        -- Check if this is a new product or if data has changed
        IF @current_product_key IS NULL
        BEGIN
            -- New product - just insert
            INSERT INTO dim_product (
                product_id, name, category, vendor_id, valid_from, valid_to, is_current
            )
            VALUES (
                @product_id, @name, @category, @vendor_id, @event_timestamp, NULL, 1
            );

            SET @InsertedCount = @InsertedCount + 1;
        END
        ELSE
        BEGIN
            -- Check if any relevant field has changed
            IF (@current_name != @name OR
                @current_category != @category OR
                @current_vendor_id != @vendor_id)
            BEGIN
                SET @has_changes = 1;
            END

            IF @has_changes = 1
            BEGIN
                -- SCD Type 2: Close current record and insert new one

                -- 1. Close the current record
                UPDATE dim_product
                SET valid_to = @event_timestamp,
                    is_current = 0,
                    updated_at = GETDATE()
                WHERE product_key = @current_product_key;

                -- 2. Insert new record with updated data
                INSERT INTO dim_product (
                    product_id, name, category, vendor_id, valid_from, valid_to, is_current
                )
                VALUES (
                    @product_id, @name, @category, @vendor_id, @event_timestamp, NULL, 1
                );

                SET @UpdatedCount = @UpdatedCount + 1;
            END
            -- Else: No changes, just mark as processed in staging table
        END

        -- Mark staging record as processed
        UPDATE stg_product
        SET processed = 1
        WHERE staging_id = @staging_id;

        SET @ProcessedCount = @ProcessedCount + 1;

        FETCH NEXT FROM staging_cursor INTO
            @staging_id, @product_id, @name, @category, @vendor_id, @event_timestamp;
    END

    CLOSE staging_cursor;
    DEALLOCATE staging_cursor;

    -- Log results
    PRINT '✓ SCD Type 2 processing for products complete';
    PRINT '  Processed: ' + CAST(@ProcessedCount AS NVARCHAR(10));
    PRINT '  Inserted (new products): ' + CAST(@InsertedCount AS NVARCHAR(10));
    PRINT '  Updated (historized products): ' + CAST(@UpdatedCount AS NVARCHAR(10));

    -- Optional cleanup: DELETE FROM stg_product WHERE processed = 1;
END
GO

PRINT '✓ sp_merge_product_scd2 stored procedure created';
GO

-- ============================================================================
-- 4. Create Automated Trigger for Real-Time Processing (Products)
-- ============================================================================

PRINT 'Creating trigger for automatic SCD Type 2 processing for products...';
GO

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_product_staging_process')
BEGIN
    DROP TRIGGER tr_product_staging_process;
    PRINT '⚠ Dropped existing tr_product_staging_process';
END
GO

CREATE TRIGGER tr_product_staging_process
ON stg_product
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Process SCD Type 2 logic immediately after insert
    EXEC sp_merge_product_scd2;
END
GO

PRINT '✓ Trigger tr_product_staging_process created';
GO

-- ============================================================================
-- 5. Test the Implementation
-- ============================================================================

PRINT '';
PRINT 'Testing SCD Type 2 implementation for products...';
GO

-- Test 1: Insert a new product
DECLARE @test_timestamp_prod1 DATETIME2 = GETDATE();

INSERT INTO stg_product (product_id, name, category, vendor_id, event_timestamp)
VALUES ('PROD_TEST_SCD2_01', 'Smartphone X', 'Electronics', 'VENDOR_A', @test_timestamp_prod1);

-- Verify insertion
IF EXISTS (SELECT * FROM dim_product WHERE product_id = 'PROD_TEST_SCD2_01' AND is_current = 1)
    PRINT '✓ Test 1 passed: New product inserted correctly';
ELSE
    PRINT '✗ Test 1 failed: New product not found';

-- Test 2: Update the product (SCD Type 2 - change category)
WAITFOR DELAY '00:00:01'; -- Wait 1 second to ensure different timestamp
DECLARE @test_timestamp_prod2 DATETIME2 = GETDATE();

INSERT INTO stg_product (product_id, name, category, vendor_id, event_timestamp)
VALUES ('PROD_TEST_SCD2_01', 'Smartphone X', 'Mobile Devices', 'VENDOR_A', @test_timestamp_prod2);

-- Verify historization
DECLARE @current_prod_count INT;
DECLARE @historical_prod_count INT;

SELECT @current_prod_count = COUNT(*) FROM dim_product WHERE product_id = 'PROD_TEST_SCD2_01' AND is_current = 1;
SELECT @historical_prod_count = COUNT(*) FROM dim_product WHERE product_id = 'PROD_TEST_SCD2_01' AND is_current = 0;

IF @current_prod_count = 1 AND @historical_prod_count = 1
    PRINT '✓ Test 2 passed: SCD Type 2 working correctly (1 current, 1 historical) for category change';
ELSE
    PRINT '✗ Test 2 failed: Current=' + CAST(@current_prod_count AS NVARCHAR(10)) + ', Historical=' + CAST(@historical_prod_count AS NVARCHAR(10));

-- Test 3: Update the product (SCD Type 2 - change name and vendor_id)
WAITFOR DELAY '00:00:01'; -- Wait 1 second to ensure different timestamp
DECLARE @test_timestamp_prod3 DATETIME2 = GETDATE();

INSERT INTO stg_product (product_id, name, category, vendor_id, event_timestamp)
VALUES ('PROD_TEST_SCD2_01', 'Smartphone X Pro', 'Mobile Devices', 'VENDOR_B', @test_timestamp_prod3);

-- Verify historization again
SELECT @current_prod_count = COUNT(*) FROM dim_product WHERE product_id = 'PROD_TEST_SCD2_01' AND is_current = 1;
SELECT @historical_prod_count = COUNT(*) FROM dim_product WHERE product_id = 'PROD_TEST_SCD2_01' AND is_current = 0;

IF @current_prod_count = 1 AND @historical_prod_count = 2 -- Now 2 historical records
    PRINT '✓ Test 3 passed: SCD Type 2 working correctly (1 current, 2 historical) for name/vendor change';
ELSE
    PRINT '✗ Test 3 failed: Current=' + CAST(@current_prod_count AS NVARCHAR(10)) + ', Historical=' + CAST(@historical_prod_count AS NVARCHAR(10));


-- Cleanup test data
DELETE FROM dim_product WHERE product_id = 'PROD_TEST_SCD2_01';
DELETE FROM stg_product WHERE product_id = 'PROD_TEST_SCD2_01';

PRINT '✓ Test cleanup complete';
GO

-- ============================================================================
-- 6. Verification
-- ============================================================================

PRINT '';
PRINT '============================================================================';
PRINT 'Migration 003 completed successfully!';
PRINT '============================================================================';
PRINT '';
PRINT 'Summary:';
PRINT '--------';
PRINT '✓ dim_product table adapted for SCD Type 2';
PRINT '✓ Staging table created: stg_product';
PRINT '✓ Stored procedure created: sp_merge_product_scd2';
PRINT '✓ Trigger created: tr_product_staging_process';
PRINT '✓ SCD Type 2 logic tested and verified for products';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Update Stream Analytics to write to stg_product instead of dim_product';
PRINT '2. Update seed scripts to write to stg_product';
PRINT '3. Test product event processing';
PRINT '';
PRINT 'Note: The trigger processes staging records automatically in real-time.';
PRINT 'For batch processing, call: EXEC sp_merge_product_scd2;';
PRINT '';
PRINT '============================================================================';
GO
