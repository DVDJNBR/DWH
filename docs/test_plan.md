# Data Warehouse Test Plan

This document outlines the testing strategy and procedures for the ShopNow Data Warehouse.

## Testing Strategy

The testing strategy is centered around a series of `make` commands that execute Python scripts to validate different aspects of the data warehouse. This ensures that the core components are functioning as expected after any changes.

## Test Procedures

### Base Schema Verification

*   **Command**: `make test-base`
*   **Purpose**: To validate the base schema of the data warehouse after initial deployment. This test ensures that all expected tables and columns exist as defined in `terraform/dwh_schema.sql`.

### Marketplace Schema Verification

*   **Command**: `make test-schema`
*   **Purpose**: To validate the schema after the marketplace migrations have been applied. This test ensures that the new tables and columns required for the marketplace functionality are correctly added.

### Backup and Recovery Verification

*   **Command**: `make test-backup`
*   **Purpose**: To perform a quick verification of the backup configuration.
*   **Command**: `make test-backup-full`
*   **Purpose**: To perform a full point-in-time restore of the database to validate the disaster recovery plan. This is a slow test and should be run when significant changes to the backup policy are made.

### Vendor Stream Verification

*   **Command**: `make test-vendors-stream`
*   **Purpose**: To validate the end-to-end flow of vendor data, especially the SCD Type 2 implementation.

## Comprehensive Test Procedure

1.  After a fresh deployment (`make deploy`), run `make test-base` to ensure the base schema is correct.
2.  After applying schema migrations (`make update-schema`), run `make test-schema` to ensure the marketplace schema is correct.
3.  After configuring backups (`make recovery-setup`), run `make test-backup` or `make test-backup-full` to validate the recovery process.
4.  After enabling the vendor stream (`make stream-new-vendors`), run `make test-vendors-stream` to validate the SCD Type 2 logic.
5.  After any change, a full regression test should include running all applicable test commands to ensure no existing functionality is broken.
