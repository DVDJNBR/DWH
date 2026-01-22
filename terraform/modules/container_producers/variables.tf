variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "container_image" {
  type = string
}

variable "connection_string" {
  type = string
}

variable "containers_group_name" {
  type    = string
  default = "aeh-producers"
}

variable "container_name" {
  type    = string
  default = "event-producers"
}

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = number
  default = 1.0
}

variable "dockerhub_username" {
  type = string
}

variable "dockerhub_token" {
  type = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "sql_server_fqdn" {
  description = "SQL Server FQDN for marketplace producer"
  type        = string
}

variable "sql_database_name" {
  description = "SQL Database name for marketplace producer"
  type        = string
}

variable "sql_admin_login" {
  description = "SQL admin login for marketplace producer"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password for marketplace producer"
  type        = string
  sensitive   = true
}
