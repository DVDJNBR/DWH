resource "azurerm_monitor_action_group" "main" {
  name                = var.action_group_name
  resource_group_name = var.resource_group_name
  short_name          = "dwh-ag"

  email_receiver {
    name          = "send-to-admin"
    email_address = var.email_receiver
  }

  tags = var.tags
}
