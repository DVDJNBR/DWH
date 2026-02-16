# GDPR Compliance & Data Management

This document serves as the **Register of Processing Activities** (Article 30 GDPR) for the ShopNow Data Warehouse project.

## 1. Controller Information

| Role               | Details                                     |
| :----------------- | :------------------------------------------ |
| **Controller**     | ShopNow Inc.                                |
| **Representative** | CTO / VP Engineering                        |
| **DPO**            | dpo@shopnow.com                             |
| **Purpose**        | Analytics, Reporting, and Vendor Management |

## 2. Register of Processing Activities

The following table details the processing of Personally Identifiable Information (PII), aligned with CNIL recommendations.

| Activity               | Categories of Data Subject | Categories of Data                                                | Purpose                                               | Recipients                      | Transfers outside EU     | Retention             |
| :--------------------- | :------------------------- | :---------------------------------------------------------------- | :---------------------------------------------------- | :------------------------------ | :----------------------- | :-------------------- |
| **Customer Analytics** | Customers                  | ID, Name, Email, Address, Phone, Order History, Browsing Behavior | Segmentation, Marketing Analysis, Service Improvement | Analytics Team, Marketing Dept. | None (Azure West Europe) | 5 years active        |
| **Vendor Management**  | Vendors                    | Contact Name, Professional Email, Performance Metrics             | Contract Performance, Payment, Quality Monitoring     | Operations Team, Accounting     | None (Azure West Europe) | 5 years post-contract |

> **Note**: `fact_order` and `fact_clickstream` are pseudo-anonymized but linked to the above categories.

## 3. Data Security (Technical & Organizational Measures)

| Measure            | Implementation                                                                      |
| :----------------- | :---------------------------------------------------------------------------------- |
| **Access Control** | **Row-Level Security (RLS)** restricts vendor access to their own data only.        |
| **Encryption**     | **TLS 1.2** in transit. **TDE** (Transparent Data Encryption) at rest in Azure SQL. |
| **Network**        | Azure SQL Firewall restricted to known IPs. Private Endpoints (planned).            |
| **Backup**         | Automated daily backups with Point-in-Time Restore (7 days retention).              |

## 4. Data Subject Rights Procedures

The following SQL procedures are defined to technical respond to subject requests.

### 4.1 Right of Access (Article 15)

_Retrieve all data associated with a specific user._

```sql
-- Retrieve Customer Profile
SELECT * FROM dim_customer WHERE email = 'user@example.com';

-- Retrieve Order History
SELECT o.*
FROM fact_order o
JOIN dim_customer c ON o.customer_id = c.customer_id
WHERE c.email = 'user@example.com';

-- Retrieve Clickstream History
SELECT cl.*
FROM fact_clickstream cl
JOIN dim_customer c ON cl.user_id = c.customer_id
WHERE c.email = 'user@example.com';
```

### 4.2 Right to Rectification (Article 16)

_Correct inaccurate personal data._

**For Customers (SCD Type 1 - Overwrite):**

```sql
UPDATE dim_customer
SET address = 'New Address', phone = 'New Phone'
WHERE email = 'user@example.com';
```

**For Vendors (SCD Type 2 - Historize):**
_Use the stored procedure `sp_merge_vendor_scd2` which automatically handles historization._

```sql
-- Insert new state in staging; the ETL process will close the old record and create a new one.
INSERT INTO stg_vendor (vendor_id, vendor_name, vendor_email, ...)
VALUES ('V123', 'Vendor Name', 'new.email@vendor.com', ...);
```

### 4.3 Right to Erasure / "Right to be Forgotten" (Article 17)

_Anonymize personal data instead of deleting rows, to preserve analytical consistency._

```sql
-- Anonymize Customer
UPDATE dim_customer
SET
    name = 'ANONYMIZED',
    email = 'anonymized_' + CAST(customer_id AS VARCHAR) + '@deleted.com',
    address = 'ANONYMIZED',
    phone = '0000000000'
WHERE email = 'user@example.com';
```

> **Impact**: Historical orders will technically remain linked to this ID, but the ID will no longer lead to a real person.

## 5. Incident Response

In case of a data breach:

1.  **Detect**: Monitor Azure Security Center alerts.
2.  **Assess**: Determine scope (tables affected, number of rows).
3.  **Notify**: Inform the DPO within 72 hours.
