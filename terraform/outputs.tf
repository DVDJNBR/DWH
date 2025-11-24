output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "unique_name" {
  description = "Unique name suffix used for resources"
  value       = local.unique_name
}

output "eventhub_namespace" {
  description = "Event Hub namespace name"
  value       = module.event_hubs.namespace_name
}

output "sql_server_fqdn" {
  description = "SQL Server fully qualified domain name"
  value       = module.sql_database.server_fqdn
}

output "sql_database_name" {
  description = "SQL Database name"
  value       = module.sql_database.database_name
}

output "stream_analytics_job_name" {
  description = "Stream Analytics job name"
  value       = module.stream_analytics.job_name
}

output "container_group_name" {
  description = "Container group name"
  value       = module.container_producers.container_group_name
}
