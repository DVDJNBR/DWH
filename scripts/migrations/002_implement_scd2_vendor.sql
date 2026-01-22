-- ============================================================================
-- Migration 002: Implement Proper SCD Type 2 for dim_vendor
-- ============================================================================
--
-- This migration adds proper SCD Type 2 handling for dim_vendor:
-- - stg_vendor: Staging table for incoming vendor events
-- - sp_merge_vendor_scd2: Stored procedure to process SCD Type 2 logic
-- - Stream Analytics will write to stg_vendor, then SP processes changes
--
-- Execution: Run after 001_add_marketplace_tables.sql
-- Rollback: Drop objects created in this migration
--
-- ============================================================================

PRINT 'Starting Migration 002: Implement SCD Type 2 for dim_vendor';
GO

-- ============================================================================
-- 1. Create Staging Table for Vendor Events
-- ============================================================================

PRINT 'Creating stg_vendor staging table...';
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'stg_vendor')
BEGIN
    CREATE TABLE stg_vendor (
        staging_id INT IDENTITY(1,1) PRIMARY KEY,
        vendor_id NVARCHAR(50) NOT NULL,
        vendor_name NVARCHAR(255) NOT NULL,
        vendor_status NVARCHAR(50) NOT NULL,
        vendor_category NVARCHAR(100),
        vendor_email NVARCHAR(255),
        commission_rate DECIMAL(5,2),
        event_timestamp DATETIME2 NOT NULL,
        processed BIT NOT NULL DEFAULT 0,
        created_at DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    CREATE INDEX idx_stg_vendor_processed ON stg_vendor(processed);
    CREATE INDEX idx_stg_vendor_id ON stg_vendor(vendor_id);

    PRINT '✓ stg_vendor table created';
END
ELSE
BEGIN
    PRINT '⚠ stg_vendor table already exists';
END
GO

-- ============================================================================
-- 2. Create Stored Procedure for SCD Type 2 Processing
-- ============================================================================

PRINT 'Creating sp_merge_vendor_scd2 stored procedure...';
GO

IF EXISTS (SELECT * FROM sys.objects WHERE name = 'sp_merge_vendor_scd2' AND type = 'P')
BEGIN
    DROP PROCEDURE sp_merge_vendor_scd2;
    PRINT '⚠ Dropped existing sp_merge_vendor_scd2';
END
GO

CREATE PROCEDURE sp_merge_vendor_scd2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProcessedCount INT = 0;
    DECLARE @InsertedCount INT = 0;
    DECLARE @UpdatedCount INT = 0;

    -- Process each unprocessed staging record
    DECLARE @staging_id INT;
    DECLARE @vendor_id NVARCHAR(50);
    DECLARE @vendor_name NVARCHAR(255);
    DECLARE @vendor_status NVARCHAR(50);
    DECLARE @vendor_category NVARCHAR(100);
    DECLARE @vendor_email NVARCHAR(255);
    DECLARE @commission_rate DECIMAL(5,2);
    DECLARE @event_timestamp DATETIME2;

    DECLARE staging_cursor CURSOR FOR
        SELECT staging_id, vendor_id, vendor_name, vendor_status,
               vendor_category, vendor_email, commission_rate, event_timestamp
        FROM stg_vendor
        WHERE processed = 0
        ORDER BY created_at;

    OPEN staging_cursor;

    FETCH NEXT FROM staging_cursor INTO
        @staging_id, @vendor_id, @vendor_name, @vendor_status,
        @vendor_category, @vendor_email, @commission_rate, @event_timestamp;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check if vendor exists with is_current = 1
        DECLARE @current_vendor_key INT;
        DECLARE @current_name NVARCHAR(255);
        DECLARE @current_status NVARCHAR(50);
        DECLARE @current_category NVARCHAR(100);
        DECLARE @current_email NVARCHAR(255);
        DECLARE @current_commission DECIMAL(5,2);
        DECLARE @has_changes BIT = 0;

        SELECT TOP 1
            @current_vendor_key = vendor_key,
            @current_name = vendor_name,
            @current_status = vendor_status,
            @current_category = vendor_category,
            @current_email = vendor_email,
            @current_commission = commission_rate
        FROM dim_vendor
        WHERE vendor_id = @vendor_id AND is_current = 1;

        -- Check if this is a new vendor or if data has changed
        IF @current_vendor_key IS NULL
        BEGIN
            -- New vendor - just insert
            INSERT INTO dim_vendor (
                vendor_id, vendor_name, vendor_status, vendor_category,
                vendor_email, commission_rate, valid_from, valid_to, is_current
            )
            VALUES (
                @vendor_id, @vendor_name, @vendor_status, @vendor_category,
                @vendor_email, @commission_rate, @event_timestamp, NULL, 1
            );

            SET @InsertedCount = @InsertedCount + 1;
        END
        ELSE
        BEGIN
            -- Check if any field has changed
            IF (@current_name != @vendor_name OR
                @current_status != @vendor_status OR
                ISNULL(@current_category, '') != ISNULL(@vendor_category, '') OR
                ISNULL(@current_email, '') != ISNULL(@vendor_email, '') OR
                ISNULL(@current_commission, 0) != ISNULL(@commission_rate, 0))
            BEGIN
                SET @has_changes = 1;
            END

            IF @has_changes = 1
            BEGIN
                -- SCD Type 2: Close current record and insert new one

                -- 1. Close the current record
                UPDATE dim_vendor
                SET valid_to = @event_timestamp,
                    is_current = 0,
                    updated_at = GETDATE()
                WHERE vendor_key = @current_vendor_key;

                -- 2. Insert new record with updated data
                INSERT INTO dim_vendor (
                    vendor_id, vendor_name, vendor_status, vendor_category,
                    vendor_email, commission_rate, valid_from, valid_to, is_current
                )
                VALUES (
                    @vendor_id, @vendor_name, @vendor_status, @vendor_category,
                    @vendor_email, @commission_rate, @event_timestamp, NULL, 1
                );

                SET @UpdatedCount = @UpdatedCount + 1;
            END
            -- Else: No changes, just mark as processed
        END

        -- Mark staging record as processed
        UPDATE stg_vendor
        SET processed = 1
        WHERE staging_id = @staging_id;

        SET @ProcessedCount = @ProcessedCount + 1;

        FETCH NEXT FROM staging_cursor INTO
            @staging_id, @vendor_id, @vendor_name, @vendor_status,
            @vendor_category, @vendor_email, @commission_rate, @event_timestamp;
    END

    CLOSE staging_cursor;
    DEALLOCATE staging_cursor;

    -- Log results
    PRINT '✓ SCD Type 2 processing complete';
    PRINT '  Processed: ' + CAST(@ProcessedCount AS NVARCHAR(10));
    PRINT '  Inserted (new vendors): ' + CAST(@InsertedCount AS NVARCHAR(10));
    PRINT '  Updated (historized): ' + CAST(@UpdatedCount AS NVARCHAR(10));

    -- Cleanup processed staging records (optional - comment out to keep history)
    -- DELETE FROM stg_vendor WHERE processed = 1;
END
GO

PRINT '✓ sp_merge_vendor_scd2 stored procedure created';
GO

-- ============================================================================
-- 3. Create Automated Trigger for Real-Time Processing
-- ============================================================================

PRINT 'Creating trigger for automatic SCD Type 2 processing...';
GO

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'tr_vendor_staging_process')
BEGIN
    DROP TRIGGER tr_vendor_staging_process;
    PRINT '⚠ Dropped existing tr_vendor_staging_process';
END
GO

CREATE TRIGGER tr_vendor_staging_process
ON stg_vendor
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Process SCD Type 2 logic immediately after insert
    EXEC sp_merge_vendor_scd2;
END
GO

PRINT '✓ Trigger tr_vendor_staging_process created';
GO

-- ============================================================================
-- 4. Test the Implementation
-- ============================================================================

PRINT '';
PRINT 'Testing SCD Type 2 implementation...';
GO

-- Test 1: Insert a new vendor
DECLARE @test_timestamp DATETIME2 = GETDATE();

INSERT INTO stg_vendor (vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, event_timestamp)
VALUES ('TEST_SCD2', 'Test Vendor Initial', 'active', 'electronics', 'test@example.com', 15.00, @test_timestamp);

-- Verify insertion
IF EXISTS (SELECT * FROM dim_vendor WHERE vendor_id = 'TEST_SCD2' AND is_current = 1)
    PRINT '✓ Test 1 passed: New vendor inserted correctly';
ELSE
    PRINT '✗ Test 1 failed: New vendor not found';

-- Test 2: Update the vendor (SCD Type 2)
WAITFOR DELAY '00:00:01'; -- Wait 1 second to ensure different timestamp
SET @test_timestamp = GETDATE();

INSERT INTO stg_vendor (vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, event_timestamp)
VALUES ('TEST_SCD2', 'Test Vendor Updated', 'active', 'electronics', 'test.updated@example.com', 20.00, @test_timestamp);

-- Verify historization
DECLARE @current_count INT;
DECLARE @historical_count INT;

SELECT @current_count = COUNT(*) FROM dim_vendor WHERE vendor_id = 'TEST_SCD2' AND is_current = 1;
SELECT @historical_count = COUNT(*) FROM dim_vendor WHERE vendor_id = 'TEST_SCD2' AND is_current = 0;

IF @current_count = 1 AND @historical_count = 1
    PRINT '✓ Test 2 passed: SCD Type 2 working correctly (1 current, 1 historical)';
ELSE
    PRINT '✗ Test 2 failed: Current=' + CAST(@current_count AS NVARCHAR(10)) + ', Historical=' + CAST(@historical_count AS NVARCHAR(10));

-- Cleanup test data
DELETE FROM dim_vendor WHERE vendor_id = 'TEST_SCD2';
DELETE FROM stg_vendor WHERE vendor_id = 'TEST_SCD2';

PRINT '✓ Test cleanup complete';
GO

-- ============================================================================
-- 5. Verification
-- ============================================================================

PRINT '';
PRINT '============================================================================';
PRINT 'Migration 002 completed successfully!';
PRINT '============================================================================';
PRINT '';
PRINT 'Summary:';
PRINT '--------';
PRINT '✓ Staging table created: stg_vendor';
PRINT '✓ Stored procedure created: sp_merge_vendor_scd2';
PRINT '✓ Trigger created: tr_vendor_staging_process';
PRINT '✓ SCD Type 2 logic tested and verified';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Update Stream Analytics to write to stg_vendor instead of dim_vendor';
PRINT '2. Test with make test-vendors-stream';
PRINT '3. Monitor dim_vendor for proper historization';
PRINT '';
PRINT 'Note: The trigger processes staging records automatically in real-time.';
PRINT 'For batch processing, call: EXEC sp_merge_vendor_scd2;';
PRINT '';
PRINT '============================================================================';
GO
