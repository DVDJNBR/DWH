<!-- Powered by BMAD™ Core -->

# ShopNow Data Warehouse - Brownfield Architecture Document

## Introduction

This document captures the CURRENT STATE of the ShopNow Data Warehouse project. This project is a buildable and reproducible environment designed to validate Data Engineer certification skills (Block B3). It is currently transitioning from a centralized retail model to a multi-vendor Marketplace model.

### Document Scope

Comprehensive documentation of the entire system, with a focus on areas relevant to the **B3 Datawarehouse certification block** (C13-C17).

### Change Log

| Date       | Version | Description                 | Author      |
| ---------- | ------- | --------------------------- | ----------- |
| 2026-01-19 | 1.0     | Initial brownfield analysis | BMad Master |

## Quick Reference - Key Files and Entry Points

### Critical Files for Understanding the System

- **Infrastructure (IaC)**: `terraform/main.tf` and `terraform/modules/`
- **Database Schema**: `terraform/dwh_schema.sql` (Base) and `scripts/migrations/` (Marketplace)
- **ETL Logic**: `terraform/modules/stream_analytics/main.tf` (Azure Stream Analytics queries)
- **Data Generation**: `data-generator/producers.py` (Core) and `scripts/seed_historical_data.py`
- **Automation/Workflow**: `Makefile` (Contains the stage-by-base deployment roadmap)
- **Certification Bridge**: `RESOURCES/B3_Datawarehouse_Competences.md` (Skills to validate)

## High Level Architecture

### Technical Summary

The ShopNow DWH is a real-time data platform on Azure. It ingests simulated e-commerce events (Orders, Clicks), transforms them on the fly, and persists them into a Star Schema in Azure SQL Database.

### Actual Tech Stack

| Category       | Technology             | Version | Notes                          |
| -------------- | ---------------------- | ------- | ------------------------------ |
| Infrastructure | Terraform              | >= 1.0  | Modular infrastructure         |
| Ingestion      | Azure Event Hubs       | Basic   | Real-time event buffering      |
| ETL / Stream   | Azure Stream Analytics | 1.2     | SQL-like stream processing     |
| Database       | Azure SQL DB           | S0      | Star Schema (Dimensions/Facts) |
| Data Source    | Python / Docker        | 3.12    | Synthetic event producers      |
| Automation     | Make                   | -       | Orchestrates deployment stages |

## Repository Structure Reality Check

- **Type**: Monorepo
- **Notable**: The project uses a "Step-by-Step" educational approach (`STEPS/` directory), which reflects in the `Makefile` stages.

```text
DWH/
├── terraform/           # Core IaC (Event Hubs, SQL, Stream Analytics, ACI)
├── scripts/             # Python scripts for seeding, migrations, and testing
├── data-generator/      # Python source for the event producers (Dockerized)
├── STEPS/               # Educational roadmap and detailed sub-documentation
├── TEACHING_DWH_terraform/ # Legacy/Reference resources and Case Study
├── RESOURCES/           # Certification-specific references (B3 Skills)
└── Makefile             # Entry point for infrastructure management
```

## Source Tree and Module Organization

### Project Structure (Actual)

- `terraform/modules/sql_database`: Manages the DWH storage, firewall, and initial schema.
- `terraform/modules/stream_analytics`: Contains the transformation logic (C15).
- `terraform/modules/event_hubs`: Manages ingestion endpoints.
- `terraform/modules/container_producers`: Deploys the ACI instances that feed the system.

## Data Models and APIs

### Current Star Schema

- **Dimensions**: `dim_customer` (SCD Type 1), `dim_product` (SCD Type 1), `dim_vendor` (SCD Type 2 - In Progress).
- **Facts**: `fact_order`, `fact_clickstream`, `fact_vendor_performance` (Planned), `fact_stock` (Planned).

### Schema Location

- Base: `terraform/dwh_schema.sql`
- Marketplace: `terraform/modules/sql_database/marketplace_schema.sql` (or via scripts/migrations)

## Technical Debt and Known Issues

### Critical Technical Debt

1. **SCD Type 2 Implementation**: Currently handled via manual migrations and Stream Analytics updates. Needs a more robust automation for C17.
2. **Data Quality (Quarantine)**: Requirement C15 (guaranteeing quality) is partially handled. A "quarantine" zone is planned but not fully implemented.
3. **Row-Level Security (RLS)**: Essential for requirement C16 (access control). Currently being integrated for multi-vendor isolation.

### Workarounds and Gotchas

- **Stream Analytics Restarts**: Updating the marketplace stream (`make update-stream`) destroys and recreates the job, causing temporary data gaps.
- **Soft Delete**: Azure resources (Key Vault, SQL servers) may stay in "soft-deleted" state, preventing immediate redeployment with the same name. `random_pet` in Terraform mitigates this.

## Integration Points and External Dependencies

- **Azure Event Hubs**: Primary ingestion point.
- **Python Producers**: Simulate real-world traffic.
- **External APIs (Planned)**: Integration with vendor stock systems (Phase 5).

## Development and Deployment

### Local Development Setup

1. `az login`
2. `make init`
3. `make deploy`
4. `make seed`

### Build and Deployment Process

- Use `Makefile` stages. Each stage corresponds to a step in the certification roadmap.

## Testing Reality

### Current Test Coverage

- **Base Verification**: `make test-base` (Schema validation)
- **Backup Verification**: `make test-backup` (DR validation - C16/C14)
- **Marketplace Verification**: `make test-schema` (Validation of new model - C13/C17)

## Impact Analysis (B3 Certification Focus)

Based on `RESOURCES/B3_Datawarehouse_Competences.md`, the following areas are critical:

- **C13 (Modelling)**: `terraform/dwh_schema.sql` + Marketplace migration.
- **C14 (Environment)**: `terraform/` modules + `terraform.tfvars` configuration.
- **C15 (ETL/Quality)**: `terraform/modules/stream_analytics/main.tf` logic.
- **C16 (Management/RGPD)**: `Makefile recovery-setup`, Azure Monitor logs, RLS implementation.
- **C17 (Historization/SCD)**: `dim_vendor` implementation using SCD Type 2 logic.

---

_Documented by BMad Master for ShopNow Marketplace transition._
