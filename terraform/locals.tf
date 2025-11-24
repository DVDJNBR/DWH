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
    Environment = "Development"
    ManagedBy   = "Terraform"
    Owner       = var.username
  }
}
