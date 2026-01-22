# Monitoring and Alerting

This document describes the monitoring and alerting strategy for the data warehouse, implemented as part of Story 1.4.

## 1. Azure Dashboard

An Azure Dashboard is provisioned via Terraform to provide a centralized view of the data warehouse's health.

### Dashboard Widgets

The dashboard will contain visualizations for the following key metrics for the active Stream Analytics job:

- **SU % Utilization**: Monitors the consumption of allocated Streaming Units.
- **Input Events**: The number of incoming events from all inputs.
- **Output Events**: The number of outgoing events to all outputs.
- **Runtime Errors**: The number of errors encountered during query processing.
- **Data Conversion Errors**: The number of errors related to data serialization or deserialization.
- **Late Input Events**: The number of events that arrived later than the configured tolerance window.
- **Quarantined Events**: The number of events sent to quarantine outputs (if enabled).

## 2. Alerting

An automated alert system is in place to notify the operations team of critical issues.

### Action Group

- **Name**: `ag-dwh-critical-alerts`
- **Receiver**: An email receiver is configured. The recipient email address is configurable via Terraform variables.

### Alert Rules

Two alert rules are configured to detect issues:

#### 1. Job Errors Alert (`alert-asa-job-failed`)

- **Target**: The active Stream Analytics job
- **Severity**: 1 (Error)
- **Condition**: Triggers when the "Errors" metric is **greater than 5** over a 5-minute period (filters out transient noise)
- **Action**: Sends an email notification to the configured admin email

#### 2. Job Health Alert (`alert-asa-job-health`)

- **Target**: The active Stream Analytics job
- **Condition**: Triggers when the Resource Health status is **Unavailable** or **Degraded** (detects unexpected issues while ignoring intentional manual stops).
- **Action**: Sends an email notification to the configured admin email

## 3. Deployment

To enable monitoring, run:

```bash
make enable-monitoring
```

This command:

1. Creates the Azure Monitor Action Group
2. Creates the Azure Dashboard
3. Configures alert rules for Stream Analytics

## 4. Configuration

The alert email recipient is configurable via the `alert_email` Terraform variable:

```bash
# In terraform.tfvars or as environment variable
TF_VAR_alert_email="your-email@example.com"
```

## 5. Accessing the Dashboard

After deployment, the dashboard is available in the Azure Portal:

1. Navigate to the Azure Portal
2. Go to "Dashboards"
3. Select "dwh-main-dashboard"

Or access directly via:
`https://portal.azure.com/#@/dashboard/arm/subscriptions/{subscription-id}/resourceGroups/rg-e6-{username}/providers/Microsoft.Portal/dashboards/dwh-main-dashboard`
