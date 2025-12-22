-- ============================================================================
-- Migration 001: Add Marketplace Support
-- ============================================================================
-- 
-- This migration adds support for multi-vendor marketplace:
-- - dim_vendor: Vendor dimension with SCD Type 2
-- - fact_vendor_performance: Vendor KPIs and metrics
-- - fact_stock: Stock levels per vendor
-- - Modify dim_product: Add vendor_id link
-- - Row-Level Security: Vendor data isolation
--
-- Execution: Run on existing database to add marketplace features
-- Rollback: See 001_rollback_marketplace_tables.sql
--
-- ============================================================================

PRINT 'Starting Migration 001: Add Marketplace Support';
GO

-- ============================================================================
-- 1. Create dim_vendor (SCD Type 2)
-- ============================================================================

PRINT 'Creating dim_vendor table...';
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dim_vendor')
BEGIN
    CREATE TABLE dim_vendor (
        vendor_key INT IDENTITY(1,1) PRIMARY KEY,
        vendor_id NVARCHAR(50) NOT NULL,
        vendor_name NVARCHAR(255) NOT NULL,
        vendor_status NVARCHAR(50) NOT NULL DEFAULT 'active',
        vendor_category NVARCHAR(100),
        vendor_email NVARCHAR(255),
        vendor_phone NVARCHAR(50),
        commission_rate DECIMAL(5,2) DEFAULT 0.00,
        
        -- SCD Type 2 fields
        valid_from DATETIME2 NOT NULL DEFAULT GETDATE(),
        valid_to DATETIME2 NULL,
        is_current BIT NOT NULL DEFAULT 1,
        
        -- Audit fields
        created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
        updated_at DATETIME2 NOT NULL DEFAULT GETDATE()
    );

    CREATE INDEX idx_vendor_id ON dim_vendor(vendor_id);
    CREATE INDEX idx_vendor_is_current ON dim_vendor(is_current);
    CREATE INDEX idx_vendor_status ON dim_vendor(vendor_status);
    
    PRINT '✓ dim_vendor table created';
END
ELSE
BEGIN
    PRINT '⚠ dim_vendor table already exists, skipping';
END
GO

-- ============================================================================
-- 2. Sample vendors can be created using Faker
-- ============================================================================

-- Sample vendors can be created using: make seed-vendors
-- This will generate realistic vendor data using Faker
PRINT '💡 To create sample vendors: make seed-vendors';
GO

-- ============================================================================
-- 3. Modify dim_product to add vendor_id
-- ============================================================================

PRINT 'Modifying dim_product table...';
GO

-- Add vendor_id column if it doesn't exist
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('dim_product') 
    AND name = 'vendor_id'
)
BEGIN
    ALTER TABLE dim_product
    ADD vendor_id NVARCHAR(50) NULL;
    
    PRINT '✓ Added vendor_id column to dim_product';
END
ELSE
BEGIN
    PRINT '⚠ vendor_id column already exists in dim_product';
END
GO

-- Update existing products to link to default vendor
PRINT 'Linking existing products to default vendor...';
GO

UPDATE dim_product
SET vendor_id = 'SHOPNOW'
WHERE vendor_id IS NULL;

PRINT '✓ Existing products linked to SHOPNOW vendor';
GO

-- Make vendor_id NOT NULL after migration
IF EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('dim_product') 
    AND name = 'vendor_id'
    AND is_nullable = 1
)
BEGIN
    ALTER TABLE dim_product
    ALTER COLUMN vendor_id NVARCHAR(50) NOT NULL;
    
    PRINT '✓ vendor_id column set to NOT NULL';
END
GO

-- Add data quality fields
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('dim_product') 
    AND name = 'data_quality_score'
)
BEGIN
    ALTER TABLE dim_product
    ADD data_quality_score INT NULL,
        last_validated_at DATETIME2 NULL;
    
    PRINT '✓ Added data quality fields to dim_product';
END
GO

-- Create index on vendor_id
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE object_id = OBJECT_ID('dim_product') 
    AND name = 'idx_product_vendor'
)
BEGIN
    CREATE INDEX idx_product_vendor ON dim_product(vendor_id);
    PRINT '✓ Created index on dim_product.vendor_id';
END
GO

-- ============================================================================
-- 4. Add vendor_id to fact_order
-- ============================================================================

PRINT 'Modifying fact_order table...';
GO

-- Add vendor_id column with DEFAULT if it doesn't exist
IF NOT EXISTS (
    SELECT * FROM sys.columns
    WHERE object_id = OBJECT_ID('fact_order')
    AND name = 'vendor_id'
)
BEGIN
    ALTER TABLE fact_order
    ADD vendor_id NVARCHAR(50) NOT NULL DEFAULT 'SHOPNOW';

    PRINT '✓ Added vendor_id column to fact_order with DEFAULT SHOPNOW';
END
ELSE
BEGIN
    PRINT '⚠ vendor_id column already exists in fact_order';
END
GO

-- Create index on vendor_id
IF NOT EXISTS (
    SELECT * FROM sys.indexes
    WHERE object_id = OBJECT_ID('fact_order')
    AND name = 'idx_order_vendor'
)
BEGIN
    CREATE INDEX idx_order_vendor ON fact_order(vendor_id);
    PRINT '✓ Created index on fact_order.vendor_id';
END
GO

-- ============================================================================
-- 5. Create fact_vendor_performance
-- ============================================================================

PRINT 'Creating fact_vendor_performance table...';
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_vendor_performance')
BEGIN
    CREATE TABLE fact_vendor_performance (
        performance_id INT IDENTITY(1,1) PRIMARY KEY,
        vendor_key INT NOT NULL,
        date_key INT NOT NULL,
        
        -- Sales metrics
        total_orders INT DEFAULT 0,
        total_revenue DECIMAL(18,2) DEFAULT 0.00,
        total_commission DECIMAL(18,2) DEFAULT 0.00,
        avg_order_value DECIMAL(18,2) DEFAULT 0.00,
        
        -- Quality metrics
        data_quality_issues INT DEFAULT 0,
        rejected_products INT DEFAULT 0,
        
        -- Performance metrics
        avg_delivery_time_days INT NULL,
        customer_satisfaction_score DECIMAL(3,2) NULL,
        
        -- Audit
        created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
        
        FOREIGN KEY (vendor_key) REFERENCES dim_vendor(vendor_key)
    );

    CREATE INDEX idx_vendor_performance_vendor_date ON fact_vendor_performance(vendor_key, date_key);
    CREATE INDEX idx_vendor_performance_date ON fact_vendor_performance(date_key);
    
    PRINT '✓ fact_vendor_performance table created';
END
ELSE
BEGIN
    PRINT '⚠ fact_vendor_performance table already exists, skipping';
END
GO

-- ============================================================================
-- 5. Create fact_stock
-- ============================================================================

PRINT 'Creating fact_stock table...';
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'fact_stock')
BEGIN
    CREATE TABLE fact_stock (
        stock_id INT IDENTITY(1,1) PRIMARY KEY,
        vendor_key INT NOT NULL,
        product_id NVARCHAR(50) NOT NULL,
        stock_level INT NOT NULL DEFAULT 0,
        warehouse_location NVARCHAR(100) NULL,
        alert_threshold INT DEFAULT 10,
        stock_status NVARCHAR(50) NOT NULL DEFAULT 'unknown',
        snapshot_date DATETIME2 NOT NULL DEFAULT GETDATE(),
        
        FOREIGN KEY (vendor_key) REFERENCES dim_vendor(vendor_key)
    );

    CREATE INDEX idx_stock_vendor_product ON fact_stock(vendor_key, product_id);
    CREATE INDEX idx_stock_date ON fact_stock(snapshot_date);
    CREATE INDEX idx_stock_status ON fact_stock(stock_status);
    
    PRINT '✓ fact_stock table created';
END
ELSE
BEGIN
    PRINT '⚠ fact_stock table already exists, skipping';
END
GO

-- ============================================================================
-- 6. Create Row-Level Security (RLS)
-- ============================================================================

PRINT 'Setting up Row-Level Security...';
GO

-- Create Security schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Security')
BEGIN
    EXEC('CREATE SCHEMA Security');
    PRINT '✓ Security schema created';
END
GO

-- Create security predicate function
IF NOT EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_VendorAccessPredicate')
BEGIN
    EXEC('
    CREATE FUNCTION Security.fn_VendorAccessPredicate(@VendorId NVARCHAR(50))
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN SELECT 1 AS fn_VendorAccessPredicate_result
    WHERE 
        @VendorId = CAST(SESSION_CONTEXT(N''VendorId'') AS NVARCHAR(50))
        OR IS_MEMBER(''db_owner'') = 1
        OR IS_MEMBER(''DataAnalyst'') = 1
        OR CAST(SESSION_CONTEXT(N''VendorId'') AS NVARCHAR(50)) IS NULL;
    ');
    
    PRINT '✓ Security predicate function created';
END
ELSE
BEGIN
    PRINT '⚠ Security predicate function already exists';
END
GO

-- Create security policy
IF NOT EXISTS (SELECT * FROM sys.security_policies WHERE name = 'VendorAccessPolicy')
BEGIN
    CREATE SECURITY POLICY Security.VendorAccessPolicy
    ADD FILTER PREDICATE Security.fn_VendorAccessPredicate(vendor_id)
    ON dbo.dim_product,
    ADD FILTER PREDICATE Security.fn_VendorAccessPredicate(vendor_id)
    ON dbo.dim_vendor
    WITH (STATE = OFF);  -- Start disabled, enable manually when ready
    
    PRINT '✓ Security policy created (disabled by default)';
    PRINT '⚠ To enable RLS: ALTER SECURITY POLICY Security.VendorAccessPolicy WITH (STATE = ON);';
END
ELSE
BEGIN
    PRINT '⚠ Security policy already exists';
END
GO

-- ============================================================================
-- 7. Create sample vendors for testing
-- ============================================================================

PRINT 'Creating vendors...';
GO

-- Vendor 0: SHOPNOW (la boutique principale)
IF NOT EXISTS (SELECT * FROM dim_vendor WHERE vendor_id = 'SHOPNOW')
BEGIN
    INSERT INTO dim_vendor (vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, valid_from, is_current)
    VALUES ('SHOPNOW', 'ShopNow Official Store', 'active', 'general', 'contact@shopnow.com', 0.00, GETDATE(), 1);
    PRINT '✓ Created vendor SHOPNOW (Official Store)';
END
GO

-- Vendor 1: Electronics specialist
IF NOT EXISTS (SELECT * FROM dim_vendor WHERE vendor_id = 'V001')
BEGIN
    INSERT INTO dim_vendor (vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, valid_from, is_current)
    VALUES ('V001', 'TechStore Pro', 'active', 'electronics', 'contact@techstore.com', 15.00, GETDATE(), 1);
    PRINT '✓ Created vendor V001 (TechStore Pro)';
END
GO

-- Vendor 2: Fashion specialist
IF NOT EXISTS (SELECT * FROM dim_vendor WHERE vendor_id = 'V002')
BEGIN
    INSERT INTO dim_vendor (vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, valid_from, is_current)
    VALUES ('V002', 'Fashion Hub', 'active', 'fashion', 'contact@fashionhub.com', 20.00, GETDATE(), 1);
    PRINT '✓ Created vendor V002 (Fashion Hub)';
END
GO

-- Vendor 3: Home & Garden
IF NOT EXISTS (SELECT * FROM dim_vendor WHERE vendor_id = 'V003')
BEGIN
    INSERT INTO dim_vendor (vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, valid_from, is_current)
    VALUES ('V003', 'Home & Garden Plus', 'active', 'home', 'contact@homegardenplus.com', 12.00, GETDATE(), 1);
    PRINT '✓ Created vendor V003 (Home & Garden Plus)';
END
GO

-- ============================================================================
-- 8. Verification
-- ============================================================================

PRINT '';
PRINT '============================================================================';
PRINT 'Migration 001 completed successfully!';
PRINT '============================================================================';
PRINT '';
PRINT 'Summary:';
PRINT '--------';

DECLARE @vendor_count INT, @product_count INT;

SELECT @vendor_count = COUNT(*) FROM dim_vendor;
SELECT @product_count = COUNT(*) FROM dim_product WHERE vendor_id IS NOT NULL;

PRINT '✓ Vendors created: ' + CAST(@vendor_count AS NVARCHAR(10));
PRINT '✓ Products linked to vendors: ' + CAST(@product_count AS NVARCHAR(10));
PRINT '✓ New tables: dim_vendor, fact_vendor_performance, fact_stock';
PRINT '✓ Row-Level Security configured (disabled by default)';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Review the changes';
PRINT '2. Test vendor data isolation';
PRINT '3. Enable RLS when ready: ALTER SECURITY POLICY Security.VendorAccessPolicy WITH (STATE = ON);';
PRINT '';
PRINT '============================================================================';
GO
