output "storage_account_name" {
  description = "Name of the quarantine storage account"
  value       = azurerm_storage_account.quarantine.name
}

output "storage_account_id" {
  description = "ID of the quarantine storage account"
  value       = azurerm_storage_account.quarantine.id
}

output "primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.quarantine.primary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "Primary connection string for the storage account"
  value       = azurerm_storage_account.quarantine.primary_connection_string
  sensitive   = true
}

output "container_orders_name" {
  description = "Name of the quarantine orders container"
  value       = azurerm_storage_container.quarantine_orders.name
}

output "container_clickstream_name" {
  description = "Name of the quarantine clickstream container"
  value       = azurerm_storage_container.quarantine_clickstream.name
}

output "container_vendors_name" {
  description = "Name of the quarantine vendors container"
  value       = azurerm_storage_container.quarantine_vendors.name
}

output "storage_account_endpoint" {
  description = "Primary blob endpoint for the storage account"
  value       = azurerm_storage_account.quarantine.primary_blob_endpoint
}
