variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "unique_name" {
  description = "Unique name suffix for resources"
  type        = string
}

variable "sql_admin_login" {
  type = string
}

variable "sql_admin_password" {
  type = string
}

variable "schema_file_path" {
  type        = string
  description = "Path to the SQL schema file"
  default     = "dwh_schema.sql"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
