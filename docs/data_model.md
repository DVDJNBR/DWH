# Data Warehouse Data Model

This document describes the data model of the ShopNow Data Warehouse.

## Modeling Approach

The data warehouse uses a **Star Schema** model. This approach was chosen to optimize for analytic queries, providing a clear and simple structure with a central fact table surrounded by descriptive dimension tables. This design simplifies join logic and improves query performance for the types of analytical questions this data warehouse is designed to answer.

## Schema Details

The core schema is defined in `terraform/dwh_schema.sql`.

### Dimensions

*   **`dim_customer`** (SCD Type 1): Stores information about customers.
*   **`dim_product`** (SCD Type 2 - **Implemented**): Stores information about products, with historical tracking of changes. See [SCD Type 2 Implementation](#scd-type-2-implementation) below for details.
*   **`dim_vendor`** (SCD Type 2 - **Implemented**): Stores information about vendors, with historical tracking of changes. See [SCD Type 2 Implementation](#scd-type-2-implementation) below for details.

### Facts

*   **`fact_order`**: Stores order information, linking to the dimension tables.
*   **`fact_clickstream`**: Stores clickstream data.
*   **`fact_vendor_performance`** (Planned): Will store vendor performance metrics.
*   **`fact_stock`** (Planned): Will store stock level information.

## SCD Type 2 Implementation

### Overview

The `dim_vendor` dimension uses **Slowly Changing Dimension Type 2 (SCD Type 2)** to maintain a complete history of vendor changes over time. This allows the data warehouse to answer questions like "What was this vendor's commission rate in Q3 2025?" or "When did this vendor change from pending to active status?"

### Implementation Architecture

The SCD Type 2 implementation uses a **staging table + stored procedure + trigger** pattern:

1. **Stream Analytics** writes raw vendor events to `stg_vendor` (staging table)
2. **Database trigger** (`tr_vendor_staging_process`) automatically fires on new inserts
3. **Stored procedure** (`sp_merge_vendor_scd2`) processes the staging data and applies SCD Type 2 logic
4. **Final data** lands in `dim_vendor` with proper historization

### Schema Structure

**Staging Table: `stg_vendor`**
```sql
CREATE TABLE stg_vendor (
    staging_id INT IDENTITY(1,1) PRIMARY KEY,
    vendor_id NVARCHAR(50) NOT NULL,
    vendor_name NVARCHAR(255) NOT NULL,
    vendor_status NVARCHAR(50) NOT NULL,
    vendor_category NVARCHAR(100),
    vendor_email NVARCHAR(255),
    commission_rate DECIMAL(5,2),
    event_timestamp DATETIME2 NOT NULL,
    processed BIT NOT NULL DEFAULT 0
);
```

**Dimension Table: `dim_vendor`**
```sql
CREATE TABLE dim_vendor (
    vendor_key INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate key
    vendor_id NVARCHAR(50) NOT NULL,            -- Business key
    vendor_name NVARCHAR(255) NOT NULL,
    vendor_status NVARCHAR(50) NOT NULL,
    vendor_category NVARCHAR(100),
    vendor_email NVARCHAR(255),
    commission_rate DECIMAL(5,2),

    -- SCD Type 2 fields
    valid_from DATETIME2 NOT NULL,   -- When this version became active
    valid_to DATETIME2 NULL,         -- When this version expired (NULL = current)
    is_current BIT NOT NULL DEFAULT 1 -- 1 = current version, 0 = historical
);
```

### SCD Type 2 Logic

The `sp_merge_vendor_scd2` stored procedure implements the following logic:

**For a NEW vendor** (vendor_id not in dim_vendor):
- Insert a new record with `is_current = 1`, `valid_to = NULL`

**For an EXISTING vendor** (vendor_id exists with `is_current = 1`):
- Compare all tracked fields (name, status, category, email, commission_rate)
- If **no changes detected**: Mark staging record as processed, no dim_vendor changes
- If **changes detected** (SCD Type 2 triggered):
  1. **Close the old record**: Set `valid_to = event_timestamp`, `is_current = 0`
  2. **Insert new record**: Same `vendor_id`, updated fields, `is_current = 1`, `valid_from = event_timestamp`, `valid_to = NULL`

### Data Flow

```
Vendor Event (JSON)
    ↓
Event Hub (vendors)
    ↓
Stream Analytics
    ↓
stg_vendor (staging)
    ↓
tr_vendor_staging_process (trigger)
    ↓
sp_merge_vendor_scd2 (stored procedure)
    ↓
dim_vendor (historized dimension)
```

### Stream Analytics Query

The Stream Analytics job `asa-shopnow-marketplace` routes vendor events to the staging table:

```sql
SELECT
    vendor_id,
    vendor_name,
    vendor_status,
    vendor_category,
    vendor_email,
    commission_rate,
    DATEADD(second, timestamp, '1970-01-01') AS event_timestamp
INTO
    [OutputStgVendor]
FROM
    [InputVendors]
```

### Example: Vendor History

**Initial Insert** (2026-01-15 10:00:00):
| vendor_key | vendor_id | vendor_name | commission_rate | valid_from | valid_to | is_current |
|------------|-----------|-------------|-----------------|------------|----------|------------|
| 101        | V001      | TechStore   | 15.00           | 2026-01-15 10:00:00 | NULL | 1 |

**Update Event** (2026-01-20 14:30:00) - Commission rate increased to 20%:
| vendor_key | vendor_id | vendor_name | commission_rate | valid_from | valid_to | is_current |
|------------|-----------|-------------|-----------------|------------|----------|------------|
| 101        | V001      | TechStore   | 15.00           | 2026-01-15 10:00:00 | **2026-01-20 14:30:00** | **0** |
| 102        | V001      | TechStore   | **20.00**       | **2026-01-20 14:30:00** | NULL | **1** |

### Testing

The SCD Type 2 implementations can be tested with:

```bash
# Test SCD Type 2 for vendors
make test-scd2-vendor
```

These tests:
1. Insert a new entity and verify it appears with `is_current = 1`
2. Update the entity with changed fields
3. Verify the old record is closed (`is_current = 0`, `valid_to` populated)
4. Verify the new record is active (`is_current = 1`, `valid_to = NULL`)

### Migration Files

- **`scripts/migrations/001_add_marketplace_tables.sql`**: Creates initial `dim_vendor` table with SCD Type 2 structure
- **`scripts/migrations/002_implement_scd2_vendor.sql`**: Implements staging table, stored procedure, and trigger
- **`scripts/migrations/003_implement_scd2_product.sql`**: Implements staging table, stored procedure, and trigger for products

### Performance Considerations

- **Index on `is_current`**: Fast filtering for current vendor versions
- **Index on `vendor_id`**: Fast lookups for specific vendors across all versions
- **Trigger-based processing**: Real-time SCD Type 2 processing with minimal latency
- **Staging table**: Decouples Stream Analytics from complex MERGE logic

## Marketplace Enhancements

The transition to a marketplace model introduces schema changes, primarily managed through migrations. The initial marketplace schema changes are located in `scripts/migrations/001_add_marketplace_tables.sql`.
