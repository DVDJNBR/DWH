variable "subscription_id" {
  description = "Azure subscription ID (optional - uses active az CLI subscription if not provided)"
  type        = string
  default     = null  # Uses active subscription from az CLI
}

variable "username" {
  description = "Username for resource naming (lowercase, no spaces)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.username))
    error_message = "Username must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "francecentral"
}

variable "eventhubs" {
  description = "List of Event Hub names to create"
  type        = list(string)
  default     = ["orders", "clickstream"]
}

variable "sql_admin_login" {
  description = "SQL Server administrator login"
  type        = string
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.sql_admin_password) >= 8
    error_message = "Password must be at least 8 characters long."
  }
}

variable "dockerhub_username" {
  description = "Docker Hub username"
  type        = string
}

variable "dockerhub_token" {
  description = "Docker Hub access token"
  type        = string
  sensitive   = true
}

variable "container_producers_image" {
  description = "Docker image for event producers"
  type        = string
  default     = "davidbreau/data-generator:latest"
}

# ============================================================================
# Environment and Features Configuration
# ============================================================================

variable "environment" {
  description = "Environment (dev or prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "enable_backup" {
  description = "Enable backup and disaster recovery features"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting features"
  type        = bool
  default     = false
}

variable "enable_security" {
  description = "Enable advanced security features (RLS)"
  type        = bool
  default     = false
}

variable "enable_marketplace" {
  description = "Enable marketplace features (vendors streaming)"
  type        = bool
  default     = false
}

variable "enable_quarantine" {
  description = "Enable data quality quarantine zone (Blob Storage)"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for critical alerts."
  type        = string
  default     = "dbreau.ext@simplonformations.co"
}
