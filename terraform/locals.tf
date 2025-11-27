# Nommage dynamique pour éviter les problèmes de soft delete Azure
resource "random_pet" "suffix" {
  length    = 2
  separator = "-"
}

locals {
  # Format: username-word-word (ex: dbreau-happy-panda)
  unique_name = "${var.username}-${random_pet.suffix.id}"
  
  # Tags communs pour toutes les ressources
  common_tags = {
    Project     = "DWH-Azure"
    Environment = var.environment == "prod" ? "Production" : "Development"
    ManagedBy   = "Terraform"
    Owner       = var.username
  }
  
  # ============================================================================
  # Environment-specific configurations
  # ============================================================================
  
  # SQL Database SKU based on environment
  sql_sku = var.environment == "prod" ? "S3" : "S0"
  
  # Backup retention based on environment
  backup_retention_days = var.environment == "prod" ? 7 : 1
  
  # Geo-replication based on environment
  geo_backup_enabled = var.environment == "prod" ? true : false
  
  # Long-term retention based on environment and backup feature
  enable_long_term_retention = var.environment == "prod" && var.enable_backup
  
  # ============================================================================
  # Marketplace feature configuration
  # ============================================================================
  
  # Event Hubs list - add vendors when marketplace is enabled
  eventhubs = var.enable_marketplace ? ["orders", "clickstream", "vendors"] : ["orders", "clickstream"]
}
