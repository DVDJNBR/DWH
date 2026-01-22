# Stream Analytics - Base (original)
resource "azurerm_stream_analytics_job" "asa_job" {
  count                                    = var.enable_marketplace ? 0 : 1
  name                                     = "asa-shopnow"
  resource_group_name                      = var.resource_group_name
  location                                 = var.location
  compatibility_level                      = "1.2"
  data_locale                              = "en-US"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  streaming_units                          = 1
  tags                                     = var.tags

  transformation_query = var.enable_quarantine ? local.query_base_with_quarantine : local.query_base
}

# Stream Analytics - Marketplace (nouveau stream qui remplace le base)
resource "azurerm_stream_analytics_job" "asa_job_marketplace" {
  count                                    = var.enable_marketplace ? 1 : 0
  name                                     = "asa-shopnow-marketplace"
  resource_group_name                      = var.resource_group_name
  location                                 = var.location
  compatibility_level                      = "1.2"
  data_locale                              = "en-US"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = var.enable_quarantine ? "Stop" : "Drop"
  streaming_units                          = 1
  tags                                     = var.tags

  transformation_query = var.enable_quarantine ? local.query_with_vendors_with_quarantine : local.query_with_vendors
}

locals {
  # Référence dynamique au job actif (base ou marketplace)
  active_job_name = var.enable_marketplace ? azurerm_stream_analytics_job.asa_job_marketplace[0].name : azurerm_stream_analytics_job.asa_job[0].name
  active_job_id   = var.enable_marketplace ? azurerm_stream_analytics_job.asa_job_marketplace[0].id : azurerm_stream_analytics_job.asa_job[0].id

  query_base_with_quarantine = <<QUERY
    WITH
    ValidOrders AS (
        SELECT
            *
        FROM
            [InputOrders] o
        WHERE
            o.order_id IS NOT NULL
            AND o.customer.id IS NOT NULL
            AND GetArrayLength(o.items) > 0
            AND NOT EXISTS (
                SELECT 1
                FROM GetArrayElements(o.items) AS i
                WHERE i.ArrayValue.product_id IS NULL OR i.ArrayValue.quantity <= 0
            )
    ),
    QuarantinedOrders AS (
        SELECT
            *,
            'Invalid order data' as reason
        FROM
            [InputOrders] o
        WHERE
            o.order_id IS NULL
            OR o.customer.id IS NULL
            OR GetArrayLength(o.items) <= 0
            OR EXISTS (
                SELECT 1
                FROM GetArrayElements(o.items) AS i
                WHERE i.ArrayValue.product_id IS NULL OR i.ArrayValue.quantity <= 0
            )
    ),
    ValidClickstream AS (
        SELECT *
        FROM [InputClickstream]
        WHERE event_id IS NOT NULL AND session_id IS NOT NULL AND user_id IS NOT NULL
    ),
    QuarantinedClickstream AS (
        SELECT *, 'Invalid clickstream data' as reason
        FROM [InputClickstream]
        WHERE event_id IS NULL OR session_id IS NULL OR user_id IS NULL
    )

    -- Quarantine Outputs
    SELECT * INTO [QuarantineOrders] FROM QuarantinedOrders
    SELECT * INTO [QuarantineClickstream] FROM QuarantinedClickstream

    -- Valid Data Outputs
    SELECT o.order_id, i.ArrayValue.product_id, o.customer.id AS customer_id, i.ArrayValue.quantity, i.ArrayValue.unit_price, o.status, DATEADD(second, o.timestamp, '1970-01-01') AS order_timestamp, 'SHOPNOW' AS vendor_id
    INTO [OutputFactOrder]
    FROM ValidOrders o CROSS APPLY GetArrayElements(o.items) AS i

    SELECT i.ArrayValue.product_id, i.ArrayValue.name, i.ArrayValue.category, COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id, DATEADD(second, o.timestamp, '1970-01-01') AS event_timestamp
    INTO [OutputStgProduct]
    FROM ValidOrders o CROSS APPLY GetArrayElements(o.items) AS i

    SELECT customer.id AS customer_id, customer.name, customer.email, customer.address, customer.city, customer.country
    INTO [OutputDimCustomer]
    FROM ValidOrders

    SELECT event_id, session_id, user_id, url, event_type, DATEADD(second, timestamp, '1970-01-01') AS event_timestamp
    INTO [OutputFactClickstream]
    FROM ValidClickstream
QUERY

  query_with_vendors_with_quarantine = <<QUERY
    WITH
    ValidOrders AS (
        SELECT *
        FROM [InputOrders] o
        WHERE
            o.order_id IS NOT NULL AND o.customer.id IS NOT NULL AND GetArrayLength(o.items) > 0
    ),
    QuarantinedOrders AS (
        SELECT *, 'Invalid order data' as reason
        FROM [InputOrders] o
        WHERE
            o.order_id IS NULL OR o.customer.id IS NULL OR GetArrayLength(o.items) <= 0
    ),
    ValidClickstream AS (
        SELECT * FROM [InputClickstream]
        WHERE event_id IS NOT NULL AND session_id IS NOT NULL AND user_id IS NOT NULL
    ),
    QuarantinedClickstream AS (
        SELECT *, 'Invalid clickstream data' as reason
        FROM [InputClickstream]
        WHERE event_id IS NULL OR session_id IS NULL OR user_id IS NULL
    ),
    ValidVendors AS (
        SELECT * FROM [InputVendors]
        WHERE vendor_id IS NOT NULL AND vendor_name IS NOT NULL
    ),
    QuarantinedVendors AS (
        SELECT *, 'Invalid vendor data' as reason
        FROM [InputVendors]
        WHERE vendor_id IS NULL OR vendor_name IS NULL
    )

    -- Quarantine Outputs
    SELECT * INTO [QuarantineOrders] FROM QuarantinedOrders
    SELECT * INTO [QuarantineClickstream] FROM QuarantinedClickstream
    SELECT * INTO [QuarantineVendors] FROM QuarantinedVendors

    -- Valid Data Outputs
    SELECT o.order_id, i.ArrayValue.product_id, o.customer.id AS customer_id, i.ArrayValue.quantity, i.ArrayValue.unit_price, o.status, DATEADD(second, o.timestamp, '1970-01-01') AS order_timestamp, COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id
    INTO [OutputFactOrder]
    FROM ValidOrders o CROSS APPLY GetArrayElements(o.items) AS i

    SELECT i.ArrayValue.product_id, i.ArrayValue.name, i.ArrayValue.category, COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id, DATEADD(second, o.timestamp, '1970-01-01') AS event_timestamp
    INTO [OutputStgProduct]
    FROM ValidOrders o CROSS APPLY GetArrayElements(o.items) AS i

    SELECT customer.id AS customer_id, customer.name, customer.email, customer.address, customer.city, customer.country
    INTO [OutputDimCustomer]
    FROM ValidOrders

    SELECT event_id, session_id, user_id, url, event_type, DATEADD(second, timestamp, '1970-01-01') AS event_timestamp
    INTO [OutputFactClickstream]
    FROM ValidClickstream

    SELECT vendor_id, vendor_name, vendor_status, vendor_category, vendor_email, commission_rate, DATEADD(second, timestamp, '1970-01-01') AS event_timestamp
    INTO [OutputStgVendor]
    FROM ValidVendors
QUERY

  query_base = <<QUERY

    /* 1. Orders -> fact_order */

    SELECT
        o.order_id,
        i.ArrayValue.product_id,
        o.customer.id AS customer_id,
        i.ArrayValue.quantity,
        i.ArrayValue.unit_price,
        o.status,
        DATEADD(second, o.timestamp, '1970-01-01') AS order_timestamp,
        'SHOPNOW' AS vendor_id
    INTO
        [OutputFactOrder]
    FROM
        [InputOrders] o
    CROSS APPLY GetArrayElements(o.items) AS i


    /* 2. Orders -> dim_product (with vendor_id fallback) */

    SELECT
        i.ArrayValue.product_id,
        i.ArrayValue.name,
        i.ArrayValue.category,
        COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id,
        DATEADD(second, o.timestamp, '1970-01-01') AS event_timestamp
    INTO
        [OutputStgProduct]
    FROM
        [InputOrders] o
    CROSS APPLY GetArrayElements(o.items) AS i


    /* 3. Orders (Customer info) -> dim_customer */

    SELECT
        customer.id AS customer_id,
        customer.name,
        customer.email,
        customer.address,
        customer.city,
        customer.country
    INTO
        [OutputDimCustomer]
    FROM
        [InputOrders]

    /* 4. Clickstream -> fact_clickstream */
    SELECT
        event_id,
        session_id,
        user_id,
        url,
        event_type,
        DATEADD(second, timestamp, '1970-01-01') AS event_timestamp
    INTO
        [OutputFactClickstream]
    FROM
        [InputClickstream]
QUERY

  query_with_vendors = <<QUERY

    /* 1. Orders -> fact_order (with vendor_id) */

    SELECT
        o.order_id,
        i.ArrayValue.product_id,
        o.customer.id AS customer_id,
        i.ArrayValue.quantity,
        i.ArrayValue.unit_price,
        o.status,
        DATEADD(second, o.timestamp, '1970-01-01') AS order_timestamp,
        COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id
    INTO
        [OutputFactOrder]
    FROM
        [InputOrders] o
    CROSS APPLY GetArrayElements(o.items) AS i


    /* 2. Orders -> dim_product (with vendor_id fallback) */

    SELECT
        i.ArrayValue.product_id,
        i.ArrayValue.name,
        i.ArrayValue.category,
        COALESCE(i.ArrayValue.vendor_id, 'SHOPNOW') AS vendor_id,
        DATEADD(second, o.timestamp, '1970-01-01') AS event_timestamp
    INTO
        [OutputStgProduct]
    FROM
        [InputOrders] o
    CROSS APPLY GetArrayElements(o.items) AS i


    /* 3. Orders (Customer info) -> dim_customer */

    SELECT
        customer.id AS customer_id,
        customer.name,
        customer.email,
        customer.address,
        customer.city,
        customer.country
    INTO
        [OutputDimCustomer]
    FROM
        [InputOrders]

    /* 4. Clickstream -> fact_clickstream */
    SELECT
        event_id,
        session_id,
        user_id,
        url,
        event_type,
        DATEADD(second, timestamp, '1970-01-01') AS event_timestamp
    INTO
        [OutputFactClickstream]
    FROM
        [InputClickstream]

    /* 5. Vendors -> stg_vendor (Staging for SCD Type 2 processing) */
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
QUERY
}

# --- INPUTS ---

resource "azurerm_stream_analytics_stream_input_eventhub" "input_orders" {
  name                         = "InputOrders"
  stream_analytics_job_name    = local.active_job_name
  resource_group_name          = var.resource_group_name
  eventhub_consumer_group_name = "$Default"
  eventhub_name                = "orders"
  servicebus_namespace         = var.eventhub_namespace_name
  shared_access_policy_key     = var.eventhub_listen_key
  shared_access_policy_name    = "listen-policy"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}


resource "azurerm_stream_analytics_stream_input_eventhub" "input_clickstream" {
  name                         = "InputClickstream"
  stream_analytics_job_name    = local.active_job_name
  resource_group_name          = var.resource_group_name
  eventhub_consumer_group_name = "$Default"
  eventhub_name                = "clickstream"
  servicebus_namespace         = var.eventhub_namespace_name
  shared_access_policy_key     = var.eventhub_listen_key
  shared_access_policy_name    = "listen-policy"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_stream_input_eventhub" "input_vendors" {
  count                        = var.enable_marketplace ? 1 : 0
  name                         = "InputVendors"
  stream_analytics_job_name    = local.active_job_name
  resource_group_name          = var.resource_group_name
  eventhub_consumer_group_name = "$Default"
  eventhub_name                = "vendors"
  servicebus_namespace         = var.eventhub_namespace_name
  shared_access_policy_key     = var.eventhub_listen_key
  shared_access_policy_name    = "listen-policy"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

# --- OUTPUTS ---

resource "azurerm_stream_analytics_output_mssql" "output_fact_order" {
  name                      = "OutputFactOrder"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "fact_order"
}

resource "azurerm_stream_analytics_output_mssql" "output_dim_customer" {
  name                      = "OutputDimCustomer"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "dim_customer"
}


resource "azurerm_stream_analytics_output_mssql" "output_stg_product" {
  name                      = "OutputStgProduct"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "stg_product"
}

resource "azurerm_stream_analytics_output_mssql" "output_fact_clickstream" {
  name                      = "OutputFactClickstream"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "fact_clickstream"
}

resource "azurerm_stream_analytics_output_mssql" "output_stg_vendor" {
  count                     = var.enable_marketplace ? 1 : 0
  name                      = "OutputStgVendor"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  server                    = var.sql_server_fqdn
  user                      = var.sql_admin_login
  password                  = var.sql_admin_password
  database                  = var.sql_database_name
  table                     = "stg_vendor"
}

# --- QUARANTINE OUTPUTS ---

resource "azurerm_stream_analytics_output_blob" "quarantine_orders" {
  count = var.enable_quarantine ? 1 : 0

  name                      = "QuarantineOrders"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  storage_account_name      = var.quarantine_storage_account_name
  storage_account_key       = var.quarantine_storage_account_key
  storage_container_name    = var.quarantine_container_orders
  path_pattern              = "{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"

  serialization {
    type     = "Json"
    format   = "LineSeparated"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_output_blob" "quarantine_clickstream" {
  count = var.enable_quarantine ? 1 : 0

  name                      = "QuarantineClickstream"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  storage_account_name      = var.quarantine_storage_account_name
  storage_account_key       = var.quarantine_storage_account_key
  storage_container_name    = var.quarantine_container_clickstream
  path_pattern              = "{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"

  serialization {
    type     = "Json"
    format   = "LineSeparated"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_output_blob" "quarantine_vendors" {
  count = var.enable_quarantine ? 1 : 0

  name                      = "QuarantineVendors"
  stream_analytics_job_name = local.active_job_name
  resource_group_name       = var.resource_group_name
  storage_account_name      = var.quarantine_storage_account_name
  storage_account_key       = var.quarantine_storage_account_key
  storage_container_name    = var.quarantine_container_vendors
  path_pattern              = "{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"

  serialization {
    type     = "Json"
    format   = "LineSeparated"
    encoding = "UTF8"
  }
}

# Terraform crée et configure le job Stream Analytics, mais Azure ne démarre
# jamais automatiquement un job ASA après son déploiement. Sans un démarrage
# explicite, le job reste à l'état "Stopped" et ne consomme aucun événement.
resource "null_resource" "start_job" {
  triggers = {
    job_id = local.active_job_id
  }

  depends_on = [
    azurerm_stream_analytics_job.asa_job,
    azurerm_stream_analytics_job.asa_job_marketplace,
    azurerm_stream_analytics_stream_input_eventhub.input_orders,
    azurerm_stream_analytics_stream_input_eventhub.input_clickstream,
    azurerm_stream_analytics_output_mssql.output_fact_order,
    azurerm_stream_analytics_output_mssql.output_dim_customer,
    azurerm_stream_analytics_output_mssql.output_stg_product,
    azurerm_stream_analytics_output_mssql.output_fact_clickstream,
    azurerm_stream_analytics_output_blob.quarantine_orders,
    azurerm_stream_analytics_output_blob.quarantine_clickstream,
    azurerm_stream_analytics_output_blob.quarantine_vendors
  ]

  provisioner "local-exec" {
    command = "az stream-analytics job start --resource-group ${var.resource_group_name} --name ${local.active_job_name} --output-start-mode JobStartTime"
  }
}


# ============================================================================
# Alert Rule for Stream Analytics Job Failures
# ============================================================================

resource "azurerm_monitor_metric_alert" "asa_job_failed" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "alert-asa-job-failed"
  resource_group_name = var.resource_group_name
  scopes              = [local.active_job_id]
  description         = "Alert when Stream Analytics job fails or has significant runtime errors"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.StreamAnalytics/streamingjobs"
    metric_name      = "Errors"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags
}

resource "azurerm_monitor_activity_log_alert" "asa_job_health" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "alert-asa-job-health"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = [var.resource_group_id]
  description         = "Alert on unexpected Stream Analytics job health issues (Unavailable/Degraded)"

  criteria {
    resource_id = local.active_job_id
    category    = "ResourceHealth"
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags
}
