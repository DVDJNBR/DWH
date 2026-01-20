# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "main" {
  name     = "rg-e6-${var.username}"
  location = var.location
  tags     = local.common_tags
}

# ============================================================================
# Event Hubs Module
# ============================================================================

module "event_hubs" {
  source = "./modules/event_hubs"

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  eventhub_namespace_name = "eh-${local.unique_name}"
  eventhubs               = local.eventhubs
  tags                    = local.common_tags
}

# ============================================================================
# SQL Database Module
# ============================================================================

module "sql_database" {
  source = "./modules/sql_database"

  depends_on = [module.event_hubs]

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  unique_name         = local.unique_name
  sql_admin_login     = var.sql_admin_login
  sql_admin_password  = var.sql_admin_password
  schema_file_path    = "${path.root}/dwh_schema.sql"
  tags                = local.common_tags
  
  # Backup configuration
  sql_sku                     = local.sql_sku
  enable_backup               = var.enable_backup
  backup_retention_days       = local.backup_retention_days
  geo_backup_enabled          = local.geo_backup_enabled
  enable_long_term_retention  = local.enable_long_term_retention
}

# ============================================================================
# Quarantine Storage Module
# ============================================================================

module "quarantine_storage" {
  count  = var.enable_quarantine ? 1 : 0
  source = "./modules/quarantine_storage"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  unique_suffix       = replace(local.unique_name, "-", "")
  tags                = local.common_tags
}

# ============================================================================
# Stream Analytics Module
# ============================================================================

module "stream_analytics" {
  source = "./modules/stream_analytics"

  depends_on = [module.event_hubs, module.sql_database, module.quarantine_storage]

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  eventhub_namespace_name = module.event_hubs.namespace_name
  eventhub_listen_key     = module.event_hubs.listen_connection_string
  sql_server_fqdn         = module.sql_database.server_fqdn
  sql_database_name       = module.sql_database.database_name
  sql_admin_login         = var.sql_admin_login
  sql_admin_password      = var.sql_admin_password
  enable_marketplace      = var.enable_marketplace
  tags                    = local.common_tags

  # Quarantine configuration
  enable_quarantine                 = var.enable_quarantine
  quarantine_storage_account_name   = var.enable_quarantine ? module.quarantine_storage[0].storage_account_name : ""
  quarantine_storage_account_key    = var.enable_quarantine ? module.quarantine_storage[0].primary_access_key : ""
  quarantine_container_orders       = var.enable_quarantine ? module.quarantine_storage[0].container_orders_name : ""
  quarantine_container_clickstream  = var.enable_quarantine ? module.quarantine_storage[0].container_clickstream_name : ""
  quarantine_container_vendors      = var.enable_quarantine ? module.quarantine_storage[0].container_vendors_name : ""
  action_group_id                   = var.enable_monitoring ? module.action_group[0].id : ""
  enable_monitoring                 = var.enable_monitoring
}

# ============================================================================
# Monitoring
# ============================================================================

module "action_group" {
  count = var.enable_monitoring ? 1 : 0

  source              = "./modules/action_group"
  resource_group_name = azurerm_resource_group.main.name
  action_group_name   = "ag-dwh-critical-alerts"
  email_receiver      = var.alert_email
  tags                = local.common_tags
}

module "dashboard" {
  count = var.enable_monitoring ? 1 : 0

  source                  = "./modules/dashboard"
  dashboard_name          = "dwh-main-dashboard"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  stream_analytics_job_id = module.stream_analytics.job_id
  tags                    = local.common_tags

  depends_on = [module.stream_analytics]
}

# ============================================================================
# Container Producers Module
# ============================================================================

module "container_producers" {
  source = "./modules/container_producers"

  depends_on = [module.event_hubs, module.stream_analytics]

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  container_image       = var.container_producers_image
  connection_string     = module.event_hubs.send_connection_string
  dockerhub_username    = var.dockerhub_username
  dockerhub_token       = var.dockerhub_token
  sql_server_fqdn       = module.sql_database.server_fqdn
  sql_database_name     = module.sql_database.database_name
  sql_admin_login       = var.sql_admin_login
  sql_admin_password    = var.sql_admin_password
  tags                  = local.common_tags
}
