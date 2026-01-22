# ============================================================================
# Data Sources - Auto-detect Active Azure Subscription
# ============================================================================

# Get current Azure client configuration (active subscription from az login)
data "azurerm_client_config" "current" {}

# Locals to determine which subscription profile to use
locals {
  # Active subscription ID from az login
  active_subscription_id = data.azurerm_client_config.current.subscription_id
  
  # Subscription profiles mapping
  subscription_profiles = {
    # HDF Roubaix subscription
    "029b3537-0f24-400b-b624-6058a145efe1" = {
      name        = "HDF_ROUBAIX"
      username    = "dbreau"
      environment = "dev"
    }
    
    # Personal Azure subscription
    "1418505f-9957-467a-a0ba-ee7ac1036b73" = {
      name        = "PERSONAL_AZURE"
      username    = "dbreau"
      environment = "dev"
    }
    
    # Azure for Students subscription
    "090e5792-c538-4d9b-bcd8-c62d22a28b15" = {
      name        = "AZURE_STUDENTS"
      username    = "dbreau"
      environment = "dev"
    }
  }
  
  # Auto-select profile based on active subscription
  active_profile = lookup(
    local.subscription_profiles,
    local.active_subscription_id,
    {
      name        = "UNKNOWN"
      username    = var.username
      environment = var.environment
    }
  )
  
  # Display active subscription info
  subscription_info = "Using subscription: ${local.active_profile.name} (${local.active_subscription_id})"
}

# Output for debugging
output "active_subscription" {
  value = {
    id          = local.active_subscription_id
    profile     = local.active_profile.name
    username    = local.active_profile.username
    environment = local.active_profile.environment
  }
  description = "Active Azure subscription and profile information"
}
