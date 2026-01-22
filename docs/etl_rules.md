# ETL Data Quality and Business Rules

This document outlines the business rules and data quality checks enforced by the Stream Analytics jobs. Events that fail these checks are routed to the quarantine storage for further analysis.

## General Rules
- All incoming records must be valid JSON. The Stream Analytics job will automatically route malformed JSON to the quarantine.

## Stream: `orders`
**Input**: `InputOrders` (Event Hub)
**Valid Output**: `OutputFactOrder`, `OutputDimProduct`, `OutputDimCustomer` (SQL Database)
**Quarantine Output**: `QuarantineOrders` (Blob Storage)

### Validation Checks
An order record is sent to quarantine if any of the following conditions are met:
- `order_id` is `NULL`.
- `customer.id` is `NULL`.
- The `items` array is `NULL` or empty.
- Any item in the `items` array is missing `product_id`.
- Any item in the `items` array has a `quantity` less than or equal to 0.

## Stream: `clickstream`
**Input**: `InputClickstream` (Event Hub)
**Valid Output**: `OutputFactClickstream` (SQL Database)
**Quarantine Output**: `QuarantineClickstream` (Blob Storage)

### Validation Checks
A clickstream event is sent to quarantine if any of the following conditions are met:
- `event_id` is `NULL`.
- `session_id` is `NULL`.
- `user_id` is `NULL`.

## Stream: `vendors`
**Input**: `InputVendors` (Event Hub)
**Valid Output**: `OutputStgVendor` (SQL Database)
**Quarantine Output**: `QuarantineVendors` (Blob Storage)

*This stream is only active if the `enable_marketplace` flag is true.*

### Validation Checks
A vendor event is sent to quarantine if any of the following conditions are met:
- `vendor_id` is `NULL`.
- `vendor_name` is `NULL`.
