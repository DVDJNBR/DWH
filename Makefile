.PHONY: help init plan apply deploy deploy-backup deploy-monitoring deploy-full destroy clean status

# Variables
TERRAFORM_DIR := terraform
RESOURCE_GROUP := rg-e6-dbreau
STREAM_JOB := asa-shopnow
ENV ?= dev

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Affiche cette aide
	@echo "$(GREEN)Commandes disponibles:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo "\n$(GREEN)Environnements:$(NC)"
	@echo "  ENV=dev (défaut)  : Configuration minimale pour tests"
	@echo "  ENV=prod          : Configuration complète pour production"

init: ## Initialise Terraform
	@echo "$(GREEN)🔧 Initialisation de Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init

plan: ## Affiche le plan de déploiement
	@echo "$(GREEN)📋 Génération du plan (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform plan -var="environment=$(ENV)"

apply: ## Déploie l'infrastructure (avec confirmation)
	@echo "$(GREEN)🚀 Déploiement de l'infrastructure (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -var="environment=$(ENV)"

deploy: ## Déploie l'architecture de base (sans confirmation)
	@echo "$(GREEN)🚀 Déploiement architecture de base (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve -var="environment=$(ENV)"

deploy-backup: ## Déploie avec backup et disaster recovery
	@echo "$(GREEN)🛡️  Déploiement avec BACKUP (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-var="environment=$(ENV)" \
		-var="enable_backup=true"

deploy-monitoring: ## Déploie avec backup + monitoring
	@echo "$(GREEN)📊 Déploiement avec BACKUP + MONITORING (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-var="environment=$(ENV)" \
		-var="enable_backup=true" \
		-var="enable_monitoring=true"

deploy-full: ## Déploie avec toutes les améliorations
	@echo "$(GREEN)🚀 Déploiement COMPLET (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-var="environment=$(ENV)" \
		-var="enable_backup=true" \
		-var="enable_monitoring=true" \
		-var="enable_security=true"

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
d: deploy ## Alias pour deploy
s: status ## Alias pour status
