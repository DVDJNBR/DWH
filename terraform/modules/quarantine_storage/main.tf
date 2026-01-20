# Quarantine Storage Module
# Provides Azure Blob Storage for data quality quarantine zone

resource "azurerm_storage_account" "quarantine" {
  name                     = "stquarantine${var.unique_suffix}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = var.tags
}

resource "azurerm_storage_container" "quarantine_orders" {
  name                  = "quarantine-orders"
  storage_account_name  = azurerm_storage_account.quarantine.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "quarantine_clickstream" {
  name                  = "quarantine-clickstream"
  storage_account_name  = azurerm_storage_account.quarantine.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "quarantine_vendors" {
  name                  = "quarantine-vendors"
  storage_account_name  = azurerm_storage_account.quarantine.name
  container_access_type = "private"
}
