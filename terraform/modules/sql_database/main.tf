data "http" "myip" {
  url = "https://ifconfig.me/ip"
}

resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-${var.unique_name}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  tags                         = var.tags
}

resource "azurerm_mssql_database" "dwh" {
  name           = "dwh-shopnow"
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = var.sql_sku
  zone_redundant = false
  
  # ============================================================================
  # BACKUP CONFIGURATION (activated with enable_backup variable)
  # ============================================================================
  
  # Short-term backup (Point-in-time restore)
  dynamic "short_term_retention_policy" {
    for_each = var.enable_backup ? [1] : []
    content {
      retention_days           = var.backup_retention_days
      backup_interval_in_hours = 24
    }
  }
  
  # Long-term backup (Archival)
  dynamic "long_term_retention_policy" {
    for_each = var.enable_long_term_retention ? [1] : []
    content {
      weekly_retention  = "P4W"   # 4 weeks
      monthly_retention = "P12M"  # 12 months
      yearly_retention  = "P5Y"   # 5 years
      week_of_year      = 1
    }
  }
  
  # Geo-replication for disaster recovery
  geo_backup_enabled = var.geo_backup_enabled
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_local_ip" {
  name             = "AllowLocalIP"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = chomp(data.http.myip.response_body)
  end_ip_address   = chomp(data.http.myip.response_body)
}

// ============================================================================
// Azure Container Instance pour l'initialisation du schéma de la base de données
// ============================================================================
// 
// Azure SQL Database ne permet PAS d'injecter un schéma SQL directement lors
// de sa création via Terraform. Cette ressource crée un conteneur temporaire
// dans Azure qui exécute le script SQL d'initialisation.
//
// FONCTIONNEMENT :
// ----------------
// 1. Terraform crée le SQL Server et la base de données
// 2. Terraform crée cette Container Instance dans Azure
// 3. Le conteneur démarre et exécute les commandes suivantes :
//    a) Charge le contenu de dwh_schema.sql dans /tmp/schema.sql
//    b) Utilise sqlcmd pour se connecter à la base de données
//    c) Exécute le script SQL pour créer les tables
// 4. Le conteneur se termine automatiquement (restart_policy = "Never")
// 5. Azure garde le conteneur en état "Terminated" pour consultation des logs
//
// ============================================================================

resource "azurerm_container_group" "db_setup" {
  # Attend que la base de données et la règle firewall soient créées
  depends_on = [azurerm_mssql_database.dwh, azurerm_mssql_firewall_rule.allow_azure_services]

  name                = "db-setup-${var.unique_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  restart_policy      = "Never" # Le conteneur s'exécute une seule fois puis s'arrête

  container {
    name   = "sqlcmd"
    image  = "mcr.microsoft.com/mssql-tools" # Image officielle Microsoft avec sqlcmd
    cpu    = "0.5"                           # 0.5 CPU core (suffisant pour un script SQL)
    memory = "1.0"                           # 1 GB de RAM

    # Azure Container Instance nécessite au moins un port exposé (même si non utilisé)
    ports {
      port     = 80
      protocol = "TCP"
    }

    # Commandes exécutées dans le conteneur
    commands = [
      "/bin/bash",
      "-c",
      <<-EOT
        # Écrit le contenu du fichier SQL dans le conteneur
        echo '${file(var.schema_file_path)}' > /tmp/schema.sql
        
        # Exécute le script SQL sur la base de données Azure SQL
        /opt/mssql-tools/bin/sqlcmd \
          -S ${azurerm_mssql_server.sql_server.fully_qualified_domain_name} \
          -U ${var.sql_admin_login} \
          -P '${var.sql_admin_password}' \
          -d ${azurerm_mssql_database.dwh.name} \
          -i /tmp/schema.sql
      EOT
    ]
  }
}


# ============================================================================
# SECURITY & GDPR (activated with enable_security variable)
# ============================================================================

# Dynamic Data Masking - Email
resource "azurerm_mssql_database_extended_auditing_policy" "example" {
  database_id            = azurerm_mssql_database.dwh.id
  storage_endpoint       = var.storage_account_endpoint
  storage_account_access_key = var.storage_account_key
  storage_account_access_key_is_secondary = false
  retention_in_days      = 6
  log_monitoring_enabled = false
  count                  = var.enable_security ? 1 : 0
}

# Note: Terraform azurerm provider v3+ handles data masking via direct T-SQL or specifics
# For simplicity and robustness in this demo, we will use a null_resource to apply masking via SQLCMD 
# if the native resource is tricky or deprecated. 
# ACTUALLY, azurerm_mssql_database_data_masking_policy is available but often deprecated/complex. 
# Best approach for this demo: PROPOSE MANUAL CLICK or SQL SCRIPT. 
# But wait, I can add a dedicated SQL script runner for security!

resource "null_resource" "apply_masking" {
  count = var.enable_security ? 1 : 0
  triggers = {
    security_enabled = var.enable_security
  }

  provisioner "local-exec" {
    command = <<EOT
      sqlcmd -S ${azurerm_mssql_server.sql_server.fully_qualified_domain_name} \
             -U ${var.sql_admin_login} \
             -P '${var.sql_admin_password}' \
             -d ${azurerm_mssql_database.dwh.name} \
             -Q "ALTER TABLE dim_customer ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()'); ALTER TABLE dim_customer ALTER COLUMN address ADD MASKED WITH (FUNCTION = 'default()');"
    EOT
  }
}
