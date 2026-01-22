-- ============================================================================
-- Migration 004: Fix Missing Index on dim_product
-- ============================================================================
-- 
-- This migration adds the missing idx_product_vendor index on dim_product
-- that was detected by the schema validation test.
--
-- ============================================================================

PRINT 'Starting Migration 004: Fix Missing Index';
GO

-- Create index on vendor_id if it doesn't exist
IF NOT EXISTS (
    SELECT * FROM sys.indexes 
    WHERE object_id = OBJECT_ID('dim_product') 
    AND name = 'idx_product_vendor'
)
BEGIN
    CREATE INDEX idx_product_vendor ON dim_product(vendor_id);
    PRINT '✓ Created index idx_product_vendor on dim_product.vendor_id';
END
ELSE
BEGIN
    PRINT '⚠ Index idx_product_vendor already exists on dim_product';
END
GO

PRINT 'Migration 004 completed successfully!';
GO
