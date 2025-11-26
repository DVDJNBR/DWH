# 🏪 ShopNow Data Warehouse

[![Release](https://img.shields.io/github/v/release/DVDJNBR/DWH)](https://github.com/DVDJNBR/DWH/releases)
[![Azure](https://img.shields.io/badge/Azure-Cloud-blue)](https://azure.microsoft.com)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Real-time Data Warehouse for e-commerce analytics, deployed on Azure with Terraform.

## 📋 Context

This project is part of a **professional certification program** (E6 - Améliorer, monitorer et maintenir un Data Warehouse). The objective is to **improve, monitor, and maintain** an existing Data Warehouse in a changing business context.

### Fictional Case Study: ShopNow Marketplace

**ShopNow** is a fast-growing e-commerce platform transitioning from a centralized seller model to a **multi-vendor Marketplace**. This strategic shift introduces new challenges:

- **Vendor tracking**: Monitor third-party vendors over time
- **Data quality**: Handle heterogeneous data from multiple sources
- **External integrations**: Integrate vendor APIs (stock, products)
- **Security**: Ensure vendors only access their own data

**Starting point:**
- Basic Data Warehouse with star schema (`dim_customer`, `dim_product`, `fact_order`, `fact_clickstream`)
- Real-time ingestion via Azure Event Hubs
- No backup, monitoring, or security features

**Mission:** Evolve the infrastructure to support the Marketplace model with production-grade features.

---

## 🚀 Getting Started

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Docker Hub](https://hub.docker.com/) account
- [Python](https://www.python.org/) >= 3.10 with [uv](https://github.com/astral-sh/uv)

### Initial Setup

```bash
# Clone repository
git clone https://github.com/DVDJNBR/DWH.git
cd DWH

# Configure environment
cp .env.example .env
# Edit .env with your Azure credentials

# Login to Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

---

## 📦 Phase 1: Base Infrastructure

Deploy the initial Data Warehouse with real-time data pipeline.

```bash
make deploy ENV=dev
```

**Environment configuration:**
- `ENV=dev` (default): Minimal resources to reduce costs (S0 database, 1-day retention)
- `ENV=prod`: Production-grade resources (S3 database, 7-day retention, geo-backup)

💡 Use `dev` for testing and learning, `prod` for realistic production scenarios.

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
make deploy-backup ENV=prod
```

**What gets added:**

**Short-term backup:**
- Automated daily backups
- 7 days retention (prod) / 1 day (dev)
- Point-in-Time Restore: restore to any moment in the retention period

**Long-term backup (prod only):**
- Weekly retention: 4 weeks
- Monthly retention: 12 months
- Yearly retention: 5 years

**Geo-replication (prod only):**
- Backup copy in secondary Azure region
- Protection against regional failures

**Recovery objectives:**
- **RTO** (Recovery Time Objective): 4 hours
- **RPO** (Recovery Point Objective): 1 hour

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

## 🔜 Phase 3: Monitoring & Alerting (Planned)

Add observability and automated alerting.

```bash
make deploy-monitoring  # Coming soon
```

**Planned features:**
- Log Analytics Workspace for centralized logging
- Application Insights for performance monitoring
- Automated alerts (errors, latency, resource usage)
- Monitoring dashboard
- Key metrics tracking (throughput, errors, DTU usage)

---

## 🔜 Phase 4: Marketplace Evolution (Planned)

Adapt the Data Warehouse for multi-vendor support.

**Planned features:**
- New dimension: `dim_vendor` with SCD Type 2
- New facts: `fact_vendor_performance`, `fact_stock`
- Data quality zone: quarantine for problematic data
- Row-Level Security (RLS): vendor data isolation
- External integrations: vendor APIs for stock and products

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

## 🛠️ Available Commands

```bash
make help              # Show all available commands
make init              # Initialize Terraform
make plan              # Show deployment plan (add ENV=prod for production)
make deploy            # Deploy base infrastructure (add ENV=prod for production)
make deploy-backup     # Deploy with backup & DR (add ENV=prod for production)
make status            # Check resources status
make seed              # Generate historical data (30 days)
make seed-quick        # Generate historical data (7 days)
make test-backup       # Test Point-in-Time Restore
make destroy           # Destroy infrastructure
```

**Environment examples:**
```bash
make deploy ENV=dev              # Development (default, minimal costs)
make deploy-backup ENV=prod      # Production (full features)
```

---

## 📁 Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Main configuration
│   ├── variables.tf       # Variables
│   ├── locals.tf          # Environment-based logic
│   ├── dwh_schema.sql     # SQL schema
│   └── modules/           # Terraform modules
│       ├── event_hubs/
│       ├── sql_database/
│       ├── stream_analytics/
│       └── container_producers/
├── data-generator/        # Event data generator
│   ├── producers.py
│   └── Dockerfile
├── scripts/               # Utility scripts
│   ├── seed_historical_data.py
│   └── test_backup_restore.py
├── Makefile              # Simplified commands
└── README.md
```

---

## 🔒 Security

- Secrets stored in `.env` (not committed)
- Encrypted connections (TLS/SSL)
- SQL firewall configured
- Managed Identity for containers

⚠️ **Note**: Current firewall allows all IPs (0.0.0.0/0) for development. Restrict in production.

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
- **SQL Database**: DTU usage, connections, size

---

## 👤 Author

**David Breau**
- GitHub: [@DVDJNBR](https://github.com/DVDJNBR)
- Email: d4v1dbr34u@gmail.com

---

⭐ If this project helped you, feel free to give it a star!
