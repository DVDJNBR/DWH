.PHONY: help init plan apply deploy destroy clean status logs start stop validate fmt check

# Variables
TERRAFORM_DIR := terraform
RESOURCE_GROUP := rg-e6-dbreau
STREAM_JOB := asa-shopnow

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Affiche cette aide
	@echo "$(GREEN)Commandes disponibles:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

init: ## Initialise Terraform
	@echo "$(GREEN)🔧 Initialisation de Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init

validate: ## Valide la configuration Terraform
	@echo "$(GREEN)✅ Validation de la configuration...$(NC)"
	cd $(TERRAFORM_DIR) && terraform validate

fmt: ## Formate les fichiers Terraform
	@echo "$(GREEN)📝 Formatage des fichiers...$(NC)"
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

plan: ## Affiche le plan de déploiement
	@echo "$(GREEN)📋 Génération du plan...$(NC)"
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Déploie l'infrastructure (avec confirmation)
	@echo "$(GREEN)🚀 Déploiement de l'infrastructure...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply

deploy: ## Déploie l'infrastructure de base (sans confirmation)
	@echo "$(GREEN)🚀 Déploiement de l'infrastructure de base...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve

apply-backup: ## Ajoute le backup à l'infrastructure existante (incremental)
	@echo "$(GREEN)🛡️  Ajout du BACKUP à l'infrastructure existante (ENV=$(ENV))...$(NC)"
	@echo "$(YELLOW)⚠️  Ceci modifie la base de données existante sans la recréer$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-target=module.sql_database \
		-var="environment=$(ENV)" \
		-var="enable_backup=true"

destroy: ## Détruit l'infrastructure (avec confirmation)
	@echo "$(RED)💥 Destruction de l'infrastructure...$(NC)"
	@echo "$(YELLOW)⚠️  Arrêt du Stream Analytics job d'abord...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) 2>/dev/null || true
	@echo "$(YELLOW)⏳ Attente de 10 secondes...$(NC)"
	@sleep 10
	cd $(TERRAFORM_DIR) && terraform destroy

destroy-force: ## Détruit l'infrastructure (sans confirmation)
	@echo "$(RED)💥 Destruction automatique...$(NC)"
	@echo "$(YELLOW)⚠️  Arrêt du Stream Analytics job d'abord...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) 2>/dev/null || true
	@echo "$(YELLOW)⏳ Attente de 10 secondes...$(NC)"
	@sleep 10
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

clean: ## Nettoie les fichiers temporaires Terraform
	@echo "$(GREEN)🧹 Nettoyage...$(NC)"
	rm -rf $(TERRAFORM_DIR)/.terraform
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	rm -f $(TERRAFORM_DIR)/terraform.tfstate*

status: ## Affiche l'état des ressources Azure
	@echo "$(GREEN)📊 État des ressources...$(NC)"
	@echo "\n$(YELLOW)Resource Group:$(NC)"
	-az group show --name $(RESOURCE_GROUP) --query "{Name:name, Location:location, State:properties.provisioningState}" -o table 2>/dev/null || echo "❌ Resource group not found"
	@echo "\n$(YELLOW)Stream Analytics Job:$(NC)"
	-az stream-analytics job show --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) --query "{Name:name, State:jobState, StreamingUnits:transformation.streamingUnits}" -o table 2>/dev/null || echo "❌ Stream Analytics job not found"
	@echo "\n$(YELLOW)Event Hubs:$(NC)"
	-az eventhubs namespace list --resource-group $(RESOURCE_GROUP) --query "[].{Name:name, Location:location, Sku:sku.name}" -o table 2>/dev/null || echo "❌ No Event Hubs found"
	@echo "\n$(YELLOW)SQL Database:$(NC)"
	-az sql db list --resource-group $(RESOURCE_GROUP) --query "[].{Name:name, Server:managedBy, Status:status}" -o table 2>/dev/null || echo "❌ No SQL Database found"
	@echo "\n$(YELLOW)Container Instances:$(NC)"
	-az container list --resource-group $(RESOURCE_GROUP) --query "[].{Name:name, State:containers[0].instanceView.currentState.state, Restarts:containers[0].instanceView.restartCount}" -o table 2>/dev/null || echo "❌ No containers found"

logs: ## Affiche les logs du Stream Analytics job
	@echo "$(GREEN)📜 Logs Stream Analytics...$(NC)"
	az monitor activity-log list --resource-group $(RESOURCE_GROUP) --max-events 20 --query "[].{Time:eventTimestamp, Level:level, Operation:operationName.localizedValue, Status:status.localizedValue}" -o table

start: ## Démarre le Stream Analytics job
	@echo "$(GREEN)▶️  Démarrage du Stream Analytics job...$(NC)"
	az stream-analytics job start --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) --output-start-mode JobStartTime

stop: ## Arrête le Stream Analytics job
	@echo "$(YELLOW)⏸️  Arrêt du Stream Analytics job...$(NC)"
	az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB)

check: ## Vérifie les prérequis (Azure CLI, Terraform, Docker)
	@echo "$(GREEN)🔍 Vérification des prérequis...$(NC)"
	@command -v az >/dev/null 2>&1 && echo "✅ Azure CLI installé" || echo "❌ Azure CLI manquant"
	@command -v terraform >/dev/null 2>&1 && echo "✅ Terraform installé" || echo "❌ Terraform manquant"
	@command -v docker >/dev/null 2>&1 && echo "✅ Docker installé" || echo "❌ Docker manquant"
	@az account show >/dev/null 2>&1 && echo "✅ Connecté à Azure" || echo "❌ Non connecté à Azure (run: az login)"

output: ## Affiche les outputs Terraform
	@echo "$(GREEN)📤 Outputs Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform output

refresh: ## Rafraîchit l'état Terraform
	@echo "$(GREEN)🔄 Rafraîchissement de l'état...$(NC)"
	cd $(TERRAFORM_DIR) && terraform refresh

show: ## Affiche l'état Terraform détaillé
	@echo "$(GREEN)📋 État Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform show

graph: ## Génère un graphe de dépendances (nécessite graphviz)
	@echo "$(GREEN)📊 Génération du graphe...$(NC)"
	cd $(TERRAFORM_DIR) && terraform graph | dot -Tpng > terraform-graph.png
	@echo "$(GREEN)✅ Graphe généré: $(TERRAFORM_DIR)/terraform-graph.png$(NC)"

seed: ## Génère des données historiques dans le DWH
	@echo "$(GREEN)📊 Génération de données historiques...$(NC)"
	@echo "$(YELLOW)⚠️  Assurez-vous que l'infrastructure est déployée et .env configuré$(NC)"
	@SERVER=$$(cd $(TERRAFORM_DIR) && terraform output -raw sql_server_fqdn 2>/dev/null) && \
	DATABASE=$$(cd $(TERRAFORM_DIR) && terraform output -raw sql_database_name 2>/dev/null) && \
	SQL_SERVER_FQDN=$$SERVER SQL_DATABASE_NAME=$$DATABASE \
	uv run --directory scripts seed_historical_data.py

seed-quick: ## Génère 7 jours de données (rapide)
	@echo "$(GREEN)📊 Génération rapide (7 jours)...$(NC)"
	@SERVER=$$(cd $(TERRAFORM_DIR) && terraform output -raw sql_server_fqdn 2>/dev/null) && \
	DATABASE=$$(cd $(TERRAFORM_DIR) && terraform output -raw sql_database_name 2>/dev/null) && \
	SQL_SERVER_FQDN=$$SERVER SQL_DATABASE_NAME=$$DATABASE \
	uv run --directory scripts seed_historical_data.py --days 7 --orders-per-day 20 --clicks-per-day 200

# Raccourcis
i: init ## Alias pour init
p: plan ## Alias pour plan
a: apply ## Alias pour apply
d: deploy ## Alias pour deploy
s: status ## Alias pour status

update-schema: ## Applique les migrations de schéma (marketplace)
	@echo "$(GREEN)🔄 Application des migrations de schéma...$(NC)"
	@echo "$(YELLOW)⚠️  Ceci modifie le schéma de la base de données existante$(NC)"
	@uv run --directory scripts python migrations/apply_migration.py 001

test-base: ## Teste le schéma de base (après deploy)
	@echo "$(GREEN)🧪 Test du schéma de base...$(NC)"
	@uv run --directory scripts python tests/test_base_schema.py

test-schema: ## Teste le nouveau schéma marketplace (après update-schema)
	@echo "$(GREEN)🧪 Test du schéma marketplace...$(NC)"
	@uv run --directory scripts python tests/test_marketplace_schema.py

test-backup: ## Teste le Point-in-Time Restore
	@echo "$(GREEN)🧪 Test de backup et restauration...$(NC)"
	@uv run --directory scripts python tests/test_backup_restore.py
