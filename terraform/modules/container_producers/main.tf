
resource "azurerm_container_group" "producers" {
  name                = var.containers_group_name
  location            = var.location
  resource_group_name = var.resource_group_name

  os_type         = "Linux"
  restart_policy  = "Always"
  ip_address_type = "None"
  tags            = var.tags

  container {
    name   = var.container_name
    image  = var.container_image
    cpu    = var.cpu
    memory = var.memory


    environment_variables = {
      EVENTHUB_CONNECTION_STR      = var.connection_string
      ORDERS_INTERVAL              = 60
      PRODUCTS_INTERVAL            = 120
      CLICKSTREAM_INTERVAL         = 2
      MARKETPLACE_ORDERS_INTERVAL  = 90
      SQL_SERVER_FQDN              = var.sql_server_fqdn
      SQL_DATABASE_NAME            = var.sql_database_name
      SQL_ADMIN_LOGIN              = var.sql_admin_login
      SQL_ADMIN_PASSWORD           = var.sql_admin_password
    }

  }

  image_registry_credential {
    server   = "index.docker.io"
    username = var.dockerhub_username
    password = var.dockerhub_token
  }
}
