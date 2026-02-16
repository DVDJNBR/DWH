# 🏪 ShopNow Data Warehouse

[![Release](https://img.shields.io/github/v/release/DVDJNBR/DWH)](https://github.com/DVDJNBR/DWH/releases)
[![Azure](https://img.shields.io/badge/Azure-Cloud-blue)](https://azure.microsoft.com)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Real-time Data Warehouse for e-commerce analytics with multi-vendor marketplace support, deployed on Azure with Terraform.

---

## 🚀 Quick Start

**Prerequisites:** [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli), [Terraform](https://www.terraform.io/downloads) >= 1.0, [Python](https://www.python.org/) >= 3.10 with [uv](https://github.com/astral-sh/uv)

**Setup:**

```bash
git clone https://github.com/DVDJNBR/DWH.git && cd DWH
cp .env.example .env  # Edit with your Azure credentials
az login && az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

**Environment:** Use `ENV=dev` (default, 7-day data, 1-day backup) or `ENV=prod` (30-day data, 7-day backup + geo-replication) on deployment commands.

---

## 🛠️ Deployment Workflow

**Deploy base infrastructure**
Event Hubs, Stream Analytics, SQL Database, event producers

```bash
make deploy
```

<sub>Note: adding `ENV=prod` deploys S3 database instead of S0</sub>

**Generate historical data**
Populate warehouse with realistic orders and clickstream events

```bash
make seed
```

<sub>Note: adding `ENV=prod` generates 30 days of data instead of 7</sub>

- `make test-base` to test base schema

**Configure backup & disaster recovery**
Point-in-Time Restore with automated backups

```bash
make recovery-setup
```

<sub>Note: adding `ENV=prod` enables 7-day retention + geo-replication instead of 1 day</sub>

- `make test-backup` to test Point-in-Time Restore

**Add marketplace schema**
Adds `dim_vendor`, modifies `fact_order` and `dim_product` with `vendor_id`

```bash
make update-schema
```

- `make test-schema` to test marketplace schema

**Replace Stream Analytics**
Destroys `asa-shopnow`, creates `asa-shopnow-marketplace` with multi-vendor support

```bash
make update-stream
```

- `make test-marketplace-stream` to test marketplace stream configuration

**Enable data quality quarantine**
Creates Azure Blob Storage for invalid events

```bash
make enable-quarantine
```

- `make test-quarantine` to test invalid events routing

**Generate realistic vendors**
Creates 10 vendors with Faker (14 total with migration defaults)

```bash
make seed-vendors
```

**Enable marketplace streaming**
Adds vendors Event Hub and activates marketplace producer

```bash
make stream-new-vendors
```

- `make test-vendors-stream` to test vendor event processing
- `make test-marketplace-stream` to test Stream Analytics marketplace configuration

**Enable monitoring**
Dashboard and automated alerts

```bash
make enable-monitoring
```

- `make stream-start` / `make stream-stop` to control Stream Analytics job
- `make test-monitoring` to verify configuration

**Other useful commands:**

```bash
make help     # Show all available commands
make status   # Check Azure resources status
make destroy  # Destroy all infrastructure
```

---

## 📋 Project Context

This project is part of a **professional certification program** (E6 - Améliorer, monitorer et maintenir un Data Warehouse). The objective is to **improve, monitor, and maintain** an existing Data Warehouse in a changing business context.

### Fictional Case Study: ShopNow Marketplace

**ShopNow** is a fast-growing e-commerce platform transitioning from a centralized seller model to a **multi-vendor Marketplace**. This strategic shift introduces new challenges:

- **Vendor tracking**: Monitor third-party vendors over time
- **Data quality**: Handle heterogeneous data from multiple sources
- **External integrations**: Integrate vendor APIs (stock, products)
- **Security**: Ensure vendors only access their own data

**Starting point:**

- Basic Data Warehouse with star schema (`dim_customer` (SCD Type 1), `dim_product` (SCD Type 2), `fact_order`, `fact_clickstream`)
- Real-time ingestion via Azure Event Hubs
- No backup, monitoring, or security features

**Mission:** Evolve the infrastructure to support the Marketplace model with production-grade features.

---

## 📦 Phase 1: Base Infrastructure

Deploy the initial Data Warehouse with real-time data pipeline.

```bash
make deploy  # ENV=dev by default
```

**What gets deployed:**

```
Event Producers (Docker)
    ↓
Azure Event Hubs (orders, clickstream)
    ↓
Azure Stream Analytics
    ↓
Azure SQL Database (Data Warehouse)
```

**Components:**

- **Event Hubs**: Ingests real-time events (orders, clickstream)
- **Stream Analytics**: Transforms and routes data to the warehouse
- **SQL Database**: Stores data in star schema (dimensions + facts)
- **Container Instances**: Generates realistic event data for testing

**Data Model:**

- `dim_customer`: Customer information
- `dim_product`: Product catalog
- `fact_order`: Orders and transactions
- `fact_clickstream`: User navigation events

**Check deployment:**

```bash
make status
```

---

## 🛡️ Phase 2: Backup & Disaster Recovery

Add production-grade backup and disaster recovery capabilities.

```bash
make recovery-setup  # ENV=dev by default
```

**What gets added:**

**Short-term backup:**

- Automated daily backups
- Point-in-Time Restore: restore to any moment in the retention period
- Retention: 1 day (dev) / 7 days (prod)

**Long-term backup (ENV=prod only):**

- Weekly retention: 4 weeks
- Monthly retention: 12 months
- Yearly retention: 5 years
- Geo-replication: backup copy in secondary Azure region

**Test the backup:**

```bash
make test-backup
```

This command will:

1. Count current data
2. Delete some records (simulation)
3. Restore database to a previous point in time
4. Verify data recovery
5. Generate a detailed report

**Manual restore example:**

```bash
az sql db restore \
  --resource-group rg-e6-dbreau \
  --server sql-dbreau-xxx \
  --name dwh-shopnow \
  --dest-name dwh-shopnow-restored \
  --time "2025-11-26T10:00:00Z"
```

---

## 📦 Phase 3: Marketplace Schema Migration

Extend the Data Warehouse to support multi-vendor marketplace.

```bash
make update-schema
```

**What gets added:**

**New dimension: `dim_vendor`**

- Vendor information with SCD Type 2 (historical tracking)
- Fields: vendor_id, name, status, category, commission_rate
- Tracks vendor evolution over time (valid_from, valid_to, is_current)
- **SHOPNOW vendor** created automatically (the main store)

**New facts:**

- `fact_vendor_performance`: KPIs per vendor (orders, revenue, quality metrics)
- `fact_stock`: Stock levels per vendor and product

**Schema modifications:**

- `dim_product` extended with `vendor_id` (links products to vendors) and now supports **SCD Type 2** for historization.
- `fact_order` extended with `vendor_id NOT NULL DEFAULT 'SHOPNOW'`
- Existing products and orders automatically linked to SHOPNOW vendor
- Indexes created on vendor_id for performance

**Security:**

- Row-Level Security (RLS) configured for vendor data isolation
- Vendors can only access their own data
- Disabled by default (enable manually when ready)

**Test the schema:**

```bash
make test-schema
```

This validates:

- All tables exist and are accessible
- Indexes are created for performance
- Data integrity (foreign keys, relationships)
- RLS configuration is correct

---

## 🌊 Phase 4: Stream Analytics Marketplace Upgrade

Replace the base Stream Analytics job with the marketplace version that supports multi-vendor tracking.

```bash
make update-stream
```

**Test the stream:**

```bash
make test-marketplace-stream
```

**What happens:**

**Infrastructure change:**

- **Destroys**: `asa-shopnow` (base stream)
- **Creates**: `asa-shopnow-marketplace` (new marketplace stream)

**Why replace instead of update?**

- Simulates a real production migration where the marketplace wasn't planned initially
- The base stream inserts `vendor_id = 'SHOPNOW'` (hardcoded)
- The marketplace stream uses `COALESCE(vendor_id, 'SHOPNOW')` to support both:
  - ShopNow orders → `vendor_id = 'SHOPNOW'`
  - Marketplace orders → `vendor_id` from event data

**Query differences:**

_Base stream (before):_

```sql
SELECT
    order_id, product_id, customer_id, quantity, unit_price,
    'SHOPNOW' AS vendor_id  -- Hardcoded
INTO [OutputFactOrder]
FROM [InputOrders]
```

_Marketplace stream (after):_

```sql
SELECT
    order_id, product_id, customer_id, quantity, unit_price,
    COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id  -- Dynamic
INTO [OutputFactOrder]
FROM [InputOrders]
```

**New capabilities:**

- Processes orders from multiple vendors
- Automatically assigns SHOPNOW to events without vendor_id
- Prepares infrastructure for marketplace producer

---

## 🏪 Phase 5: Vendor Data Generation

Generate realistic vendor data for testing.

```bash
make seed-vendors
```

**What gets created:**

**Sample vendors (10 by default):**

- Realistic company names (using Faker)
- Valid email addresses
- Random categories (electronics, fashion, home, sports, books, toys, food)
- Commission rates between 10-25%
- Mix of active (80%) and pending (20%) statuses

**Total vendors after this step:**

- 1 × SHOPNOW (official store)
- 3 × Test vendors (V001, V002, V003 - created by migration)
- 10 × Generated vendors
- **Total: 14 vendors**

**Custom generation:**

```bash
# Generate 50 vendors instead of 10
uv run --directory scripts python seed_vendors.py --count 50
```

---

## 🚀 Phase 6: Marketplace Event Streaming

Enable real-time marketplace order generation with multi-vendor support.

```bash
make stream-new-vendors  # ENV=dev by default
```

**What gets added:**

**New Event Hub: `vendors`**

- Dedicated stream for vendor events (creation, updates, status changes)
- Integrated with existing Event Hub namespace

**Stream Analytics updates:**

- New input: `InputVendors`
- New output: `OutputDimVendor`
- Query extended to process vendor events in real-time

**Marketplace Producer:**

- Single unified producer handles all vendors (including SHOPNOW)
- Reads active vendors from `dim_vendor` (SQL query)
- Generates orders with random `vendor_id` from all active vendors
- **Auto-refresh**: Re-reads vendor list every 5 minutes
- Interval: 90 seconds per order

**Event flow:**

```
Marketplace Producer
    ├─> Event Hub (orders) → Stream Analytics → fact_order (vendor_id = SHOPNOW, V001, V002, etc.)
    └─> Event Hub (vendors) → Stream Analytics → stg_vendor → dim_vendor (SCD Type 2)
```

**Marketplace order format:**

```json
{
  "order_id": "uuid",
  "customer": {...},
  "items": [
    {
      "product_id": "uuid",
      "name": "Product Name",
      "vendor_id": "V001",
      "quantity": 2,
      "unit_price": 99.99
    }
  ],
  "source": "marketplace"
}
```

**Test the streaming:**

```bash
make test-vendors-stream
```

This will:

1. Verify vendors Event Hub exists
2. Send a test vendor event
3. Wait for Stream Analytics to process it
4. Verify the vendor appears in `dim_vendor`
5. Validate all fields are correct
6. Display last 10 orders with vendor/customer/product joins

**Sample output:**

```
─────────────────────────────────────────────────────────────
  Order #1: abc123-def456
  📅 Date: 2026-01-21 10:15:30
  👤 Customer: John Smith (Paris)
  📦 Product: Wireless Headphones [Electronics]
  🏪 Vendor: TechStore Pro [electronics]
  💰 2 x $149.99 = $299.98
  📈 Commission: 15.0% = $45.00
─────────────────────────────────────────────────────────────
```

---

## 📦 Phase 7: Product Historization (SCD Type 2)

This step enhances the `dim_product` dimension to track its full history, enabling more powerful temporal analysis. This is an example of iterative improvement on the data warehouse after the initial marketplace launch.

The necessary database changes for this are included in the main `update-schema` command.

```bash
make update-schema
```

**What gets added:**

- **`dim_product` becomes SCD Type 2**: The table is modified to include `valid_from`, `valid_to`, and `is_current` columns to track changes.
- **Staging & Processing**: A new `stg_product` table and a stored procedure (`sp_merge_product_scd2`) are created to automatically process incoming data and apply the SCD2 logic.

**Test the implementation:**

```bash
make test-scd2-product
```

---

## ✅ Phase 8: Data Quality (Quarantine)

Add data validation and quarantine zone for invalid events.

```bash
make enable-quarantine
```

**What gets added:**

**Quarantine Storage:**

- Azure Blob Storage container for quarantined data
- Separate containers for orders, clickstream, and vendors

**Stream Analytics validation:**

- Real-time validation of incoming events
- Invalid data routed to quarantine instead of dropping
- Validation rules: null checks, required fields, data types

**Quarantine outputs:**

- `QuarantineOrders`: Invalid order events
- `QuarantineClickstream`: Invalid clickstream events
- `QuarantineVendors`: Invalid vendor events

**Test the quarantine:**

```bash
make test-quarantine
```

This will:

1. Send invalid events (null order_id, null session_id)
2. Wait for Stream Analytics to process
3. Verify events arrive in quarantine blob storage
4. Confirm they're NOT in the SQL database

---

## ✅ Phase 9: Monitoring & Alerting

Add observability dashboard and automated alerting.

```bash
make enable-monitoring
```

**What gets added:**

**Azure Dashboard:**

- Real-time monitoring of Stream Analytics job
- Metrics: SU utilization, input/output events, errors, watermark delay
- Direct links to Event Hubs and SQL Database

**Action Group:**

- Email notifications for critical alerts
- Configurable alert email in `terraform.tfvars`

**Alert Rules:**

- `alert-asa-job-failed`: Triggers when Stream Analytics has errors (Severity 1)
- `alert-asa-job-stopped`: Triggers when job stops running (Severity 0 - Critical)

**Dashboard URL:**

```
https://portal.azure.com/#@/dashboard/arm/.../dwh-main-dashboard
```

---

## 📊 Data Management

### Generate Historical Data

```bash
# Generate 30 days of data
make seed

# Generate 7 days of data (faster)
make seed-quick
```

### Connect to Database

```bash
# Get connection info
terraform -chdir=terraform output sql_server_fqdn
terraform -chdir=terraform output sql_database_name
```

**Example query:**

```sql
-- Top 10 best-selling products
SELECT
    p.name,
    COUNT(o.order_id) as total_orders,
    SUM(o.quantity * o.unit_price) as revenue
FROM fact_order o
JOIN dim_product p ON o.product_id = p.product_id
GROUP BY p.name
ORDER BY revenue DESC;
```

---

## 📁 Project Structure

```
.
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                  # Main configuration
│   ├── variables.tf             # Variables
│   ├── locals.tf                # Environment-based logic
│   ├── dwh_schema.sql           # SQL schema
│   └── modules/
│       ├── event_hubs/          # Event Hub namespace and hubs
│       ├── sql_database/        # SQL Server and database
│       ├── stream_analytics/    # ASA job, inputs, outputs, alerts
│       ├── container_producers/ # Container Instance for producers
│       ├── action_group/        # Alert notification group
│       └── dashboard/           # Azure monitoring dashboard
├── data-generator/              # Event data generator
│   ├── producers.py             # Base producer (legacy)
│   ├── producers_marketplace.py # Marketplace producer (active)
│   ├── supervisord.conf         # Process manager config
│   └── Dockerfile
├── scripts/                     # Utility scripts
│   ├── seed_historical_data.py
│   ├── seed_vendors.py
│   ├── migrations/              # SQL migrations
│   │   ├── 001_add_marketplace_tables.sql
│   │   └── 002_implement_scd2_vendor.sql
│   └── tests/                   # Test scripts
│       ├── test_base_schema.py
│       ├── test_marketplace_schema.py
│       ├── test_backup_quick.py
│       ├── test_vendors_stream.py
│       └── test_quarantine.py
├── docs/                        # Documentation
│   ├── monitoring.md            # Monitoring & alerts guide
│   └── stories/                 # Development stories
├── Makefile                     # Simplified commands
└── README.md
```

---

## 🔒 Security

- Secrets stored in `.env` (not committed)
- Encrypted connections (TLS/SSL)
- SQL firewall dynamically configured with your public IP
- Managed Identity for containers

> **Note:** The firewall rule `AllowLocalIP` is automatically updated with your current public IPv4 address during deployment.

---

## 📈 Monitoring

### View Logs

```bash
# Container logs
az container logs \
  --resource-group rg-e6-dbreau \
  --name aeh-producers

# Stream Analytics logs
az monitor activity-log list \
  --resource-group rg-e6-dbreau
```

### Key Metrics

- **Event Hubs**: Incoming/outgoing messages, errors
- **Stream Analytics**: Processed events, latency, errors

### Current Test Coverage

- **Base Verification**: `make test-base` (Schema validation)
- **Backup Verification**: `make test-backup` (DR validation - C16/C14)
- **Marketplace Verification**: `make test-schema` (Validation of new model - C13/C17)
- **Marketplace Stream Verification**: `make test-marketplace-stream` (Stream Analytics configuration validation)
- **Vendor SCD2 Verification**: `make test-scd2-vendor` (SCD Type 2 validation for vendors)
- **Product SCD2 Verification**: `make test-scd2-product` (SCD Type 2 validation for products)
- **Monitoring Verification**: `make test-monitoring` (Validates Action Groups, Alerts, Dashboard)

## 👤 Author

**David Breau**

- GitHub: [@DVDJNBR](https://github.com/DVDJNBR)
- Email: d4v1dbr34u@gmail.com

---
