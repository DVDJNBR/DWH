variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "eventhub_namespace_name" {
  type = string
}

variable "eventhub_listen_key" {
  type = string
}

variable "sql_server_fqdn" {
  type = string
}

variable "sql_database_name" {
  type = string
}

variable "sql_admin_login" {
  type = string
}

variable "sql_admin_password" {
  type = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_marketplace" {
  description = "Enable marketplace features (vendors streaming)"
  type        = bool
  default     = false
}

variable "enable_quarantine" {
  description = "Enable data quarantine for invalid events"
  type        = bool
  default     = false
}

variable "quarantine_storage_account_name" {
  description = "The name of the storage account to use for quarantine"
  type        = string
  default     = ""
}

variable "quarantine_storage_account_key" {
  description = "The access key for the quarantine storage account"
  type        = string
  default     = ""
  sensitive   = true
}

variable "quarantine_container_orders" {
  description = "The name of the container for quarantined orders"
  type        = string
  default     = ""
}

variable "quarantine_container_clickstream" {
  description = "The name of the container for quarantined clickstream events"
  type        = string
  default     = ""
}

variable "quarantine_container_vendors" {
  description = "The name of the container for quarantined vendors"
  type        = string
  default     = ""
}
