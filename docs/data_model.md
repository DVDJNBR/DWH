# Data Warehouse Data Model

This document describes the data model of the ShopNow Data Warehouse.

## Modeling Approach

The data warehouse uses a **Star Schema** model. This approach was chosen to optimize for analytic queries, providing a clear and simple structure with a central fact table surrounded by descriptive dimension tables. This design simplifies join logic and improves query performance for the types of analytical questions this data warehouse is designed to answer.

## Schema Details

The core schema is defined in `terraform/dwh_schema.sql`.

### Dimensions

*   **`dim_customer`** (SCD Type 1): Stores information about customers.
*   **`dim_product`** (SCD Type 1): Stores information about products.
*   **`dim_vendor`** (SCD Type 2 - In Progress): Stores information about vendors, with historical tracking of changes.

### Facts

*   **`fact_order`**: Stores order information, linking to the dimension tables.
*   **`fact_clickstream`**: Stores clickstream data.
*   **`fact_vendor_performance`** (Planned): Will store vendor performance metrics.
*   **`fact_stock`** (Planned): Will store stock level information.

## Marketplace Enhancements

The transition to a marketplace model introduces schema changes, primarily managed through migrations. The initial marketplace schema changes are located in `scripts/migrations/001_add_marketplace_tables.sql`.
