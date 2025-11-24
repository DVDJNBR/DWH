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
  eventhubs               = var.eventhubs
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
}

# ============================================================================
# Stream Analytics Module
# ============================================================================

module "stream_analytics" {
  source = "./modules/stream_analytics"

  depends_on = [module.event_hubs, module.sql_database]

  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  eventhub_namespace_name = module.event_hubs.namespace_name
  eventhub_listen_key     = module.event_hubs.listen_connection_string
  sql_server_fqdn         = module.sql_database.server_fqdn
  sql_database_name       = module.sql_database.database_name
  sql_admin_login         = var.sql_admin_login
  sql_admin_password      = var.sql_admin_password
  tags                    = local.common_tags
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
  tags                  = local.common_tags
}
