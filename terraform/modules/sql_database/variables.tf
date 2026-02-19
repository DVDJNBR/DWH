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

# ============================================================================
# Backup and Environment Configuration
# ============================================================================

variable "sql_sku" {
  description = "SQL Database SKU (S0 for dev, S3 for prod)"
  type        = string
  default     = "S0"
}

variable "enable_backup" {
  description = "Enable backup features"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 1
}

variable "geo_backup_enabled" {
  description = "Enable geo-replication"
  type        = bool
  default     = false
}

variable "enable_long_term_retention" {
  description = "Enable long-term retention policy"
  type        = bool
  default     = false
}

# ============================================================================
# Security Configuration
# ============================================================================

variable "enable_security" {
  description = "Enable security features (Auditing, Data Masking)"
  type        = bool
  default     = false
}

variable "storage_account_endpoint" {
  description = "Storage account endpoint for SQL Auditing"
  type        = string
  default     = ""
}

variable "storage_account_key" {
  description = "Storage account key for SQL Auditing"
  type        = string
  default     = ""
  sensitive   = true
}
