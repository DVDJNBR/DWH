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
