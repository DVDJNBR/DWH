.PHONY: help init plan apply deploy destroy clean status logs start stop validate fmt check

# Variables
TERRAFORM_DIR := terraform
RESOURCE_GROUP := rg-e6-dbreau
STREAM_JOB := asa-shopnow
ENV ?= dev

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
CYAN := \033[0;36m
NC := \033[0m

##@ Help

help: ## Display this help
	@echo "$(GREEN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║           ShopNow Data Warehouse - Make Commands              ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; category=""} /^##@/ { category=substr($$0, 5); printf "\n$(CYAN)%s:$(NC)\n", category; next } /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-22s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check: ## Check prerequisites (Azure CLI, Terraform, Docker)
	@echo "$(GREEN)🔍 Checking prerequisites...$(NC)"
	@command -v az >/dev/null 2>&1 && echo "✅ Azure CLI installed" || echo "❌ Azure CLI missing"
	@command -v terraform >/dev/null 2>&1 && echo "✅ Terraform installed" || echo "❌ Terraform missing"
	@command -v docker >/dev/null 2>&1 && echo "✅ Docker installed" || echo "❌ Docker missing"
	@az account show >/dev/null 2>&1 && echo "✅ Connected to Azure" || echo "❌ Not connected to Azure (run: az login)"

status: ## Show Azure resources status
	@echo "$(GREEN)📊 Resources status...$(NC)"
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

##@ Deployment Workflow

deploy: ## [1] Deploy base infrastructure (ENV=dev by default)
	@echo "$(GREEN)🚀 Deploying base infrastructure (ENV=$(ENV))...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve -var="environment=$(ENV)"

seed: ## [2] Generate historical data (ENV=dev: 7 days, ENV=prod: 30 days)
	@echo "$(GREEN)📊 Generating historical data (ENV=$(ENV))...$(NC)"
	@echo "$(YELLOW)⚠️  Make sure infrastructure is deployed and .env configured$(NC)"
	@SERVER=$$(cd $(TERRAFORM_DIR) && terraform output -raw sql_server_fqdn 2>/dev/null) && \
	DATABASE=$$(cd $(TERRAFORM_DIR) && terraform output -raw sql_database_name 2>/dev/null) && \
	SQL_SERVER_FQDN=$$SERVER SQL_DATABASE_NAME=$$DATABASE \
	uv run --directory scripts seed_historical_data.py $(if $(filter prod,$(ENV)),,--days 7 --orders-per-day 20 --clicks-per-day 200)

recovery-setup: ## [3] Backup & disaster recovery (ENV=dev: 1 day, ENV=prod: 7 days + geo)
	@echo "$(GREEN)🛡️  Configuring backup and disaster recovery (ENV=$(ENV))...$(NC)"
	@echo "$(YELLOW)⚠️  This modifies the existing database without recreating it$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-target=module.sql_database \
		-var="environment=$(ENV)" \
		-var="enable_backup=true"

update-schema: ## [4] Apply schema migrations (marketplace + SCD Type 2)
	@echo "$(GREEN)🔄 Applying schema migrations...$(NC)"
	@echo "$(YELLOW)⚠️  This modifies the existing database schema$(NC)"
	@echo "$(CYAN)📦 Migration 001: Marketplace tables...$(NC)"
	@uv run --directory scripts python migrations/apply_migration.py 001
	@echo "$(CYAN)📦 Migration 002: SCD Type 2 implementation...$(NC)"
	@uv run --directory scripts python migrations/apply_migration.py 002
	@echo "$(CYAN)📦 Migration 003: SCD Type 2 for products...$(NC)"
	@uv run --directory scripts python migrations/apply_migration.py 003

update-stream: ## [5] Replace base stream with marketplace stream
	@echo "$(GREEN)🌊 Replacing Stream Analytics with marketplace version...$(NC)"
	@echo "$(YELLOW)⚠️  This destroys 'asa-shopnow' and creates 'asa-shopnow-marketplace'$(NC)"
	@echo "$(YELLOW)⏸️  Stopping existing Stream Analytics job...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting 10 seconds...$(NC)"
	@sleep 10
	@echo "$(GREEN)🔧 Applying Terraform with enable_marketplace=true...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve -var="enable_marketplace=true"
	@echo "$(GREEN)✅ Stream Analytics marketplace deployed!$(NC)"

seed-vendors: ## [7] Generate realistic vendors with Faker
	@echo "$(GREEN)🏪 Generating vendors with Faker...$(NC)"
	@uv run --directory scripts python seed_vendors.py --count 10

stream-new-vendors: ## [8] Enable vendor events streaming (requires ENV)
	@echo "$(GREEN)🌊 Enabling vendor streaming (ENV=$(ENV))...$(NC)"
	@echo "$(YELLOW)⚠️  This adds vendor Event Hub and activates marketplace producer$(NC)"
	@echo "$(YELLOW)⏸️  Stopping Stream Analytics job...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting 10 seconds...$(NC)"
	@sleep 10
	@echo "$(GREEN)🔧 Applying Terraform changes...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-target=module.event_hubs \
		-target=module.container_producers \
		-var="environment=$(ENV)" \
		-var="enable_marketplace=true"
	@echo "$(GREEN)✅ Marketplace streaming enabled!$(NC)"

enable-quarantine: ## [6] Enable data quality quarantine zone
	@echo "$(GREEN)🗑️  Enabling data quality quarantine...$(NC)"
	@echo "$(YELLOW)⚠️  This creates Azure Blob Storage for invalid events$(NC)"
	@echo "$(YELLOW)⏸️  Stopping Stream Analytics job...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting 10 seconds...$(NC)"
	@sleep 10
	@echo "$(GREEN)🔧 Applying Terraform changes...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-var="enable_marketplace=true" \
		-var="enable_quarantine=true"
	@echo "$(GREEN)▶️  Restarting Stream Analytics job...$(NC)"
	@az stream-analytics job start --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace --output-start-mode JobStartTime
	@echo "$(GREEN)✅ Quarantine enabled and stream restarted!$(NC)"
	@echo "$(CYAN)💡 Test with: make test-quarantine$(NC)"

enable-monitoring: ## [9] Enable monitoring dashboard and alerts
	@echo "$(GREEN)📊 Enabling monitoring and alerting...$(NC)"
	@echo "$(YELLOW)⚠️  This creates Azure Dashboard + Action Group + Alert Rules$(NC)"
	@echo "$(YELLOW)⏸️  Stopping Stream Analytics job...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting 10 seconds...$(NC)"
	@sleep 10
	@echo "$(GREEN)🔧 Applying Terraform changes...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve \
		-var="enable_marketplace=true" \
		-var="enable_quarantine=true" \
		-var="enable_monitoring=true"
	@echo "$(GREEN)▶️  Restarting Stream Analytics job...$(NC)"
	@az stream-analytics job start --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace --output-start-mode JobStartTime
	@echo "$(GREEN)✅ Monitoring enabled and stream restarted!$(NC)"
	@echo "$(CYAN)📊 Dashboard: https://portal.azure.com/#@/dashboard/arm/subscriptions/.../resourceGroups/$(RESOURCE_GROUP)/providers/Microsoft.Portal/dashboards/dwh-main-dashboard$(NC)"

##@ Testing

test-base: ## Test base schema (after deploy)
	@echo "$(GREEN)🧪 Testing base schema...$(NC)"
	@uv run --directory scripts python tests/test_base_schema.py

test-schema: ## Test marketplace schema (after update-schema)
	@echo "$(GREEN)🧪 Testing marketplace schema...$(NC)"
	@uv run --directory scripts python tests/test_marketplace_schema.py

test-backup: ## Test backup configuration (quick)
	@echo "$(GREEN)🧪 Testing backup configuration...$(NC)"
	@uv run --directory scripts python tests/test_backup_quick.py

test-backup-full: ## Test Point-in-Time Restore (slow, full restore)
	@echo "$(GREEN)🧪 Testing full backup and restore...$(NC)"
	@echo "$(YELLOW)⚠️  This will take 5-10 minutes (full database restore)$(NC)"
	@uv run --directory scripts python tests/test_backup_full.py

test-vendors-stream: ## Test vendor events streaming
	@echo "$(GREEN)🧪 Testing vendor streaming...$(NC)"
	@uv run --directory scripts python tests/test_vendors_stream.py

test-scd2-vendor: ## Test SCD Type 2 implementation for vendors
	@echo "$(GREEN)🧪 Testing SCD Type 2 for vendors...$(NC)"
	@uv run --directory scripts python tests/test_scd2_vendor.py

test-quarantine: ## Test data quality quarantine (invalid events)
	@echo "$(GREEN)🧪 Testing quarantine...$(NC)"
	@uv run --directory scripts python tests/test_quarantine.py

test-scd2-product: ## Test SCD Type 2 implementation for products
	@echo "$(GREEN)🧪 Testing SCD Type 2 for products...$(NC)"
	@uv run --directory scripts python tests/test_scd2_product.py

##@ Terraform (Advanced)

init: ## Initialize Terraform
	@echo "$(GREEN)🔧 Initializing Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init

validate: ## Validate Terraform configuration
	@echo "$(GREEN)✅ Validating configuration...$(NC)"
	cd $(TERRAFORM_DIR) && terraform validate

fmt: ## Format Terraform files
	@echo "$(GREEN)📝 Formatting files...$(NC)"
	cd $(TERRAFORM_DIR) && terraform fmt -recursive

plan: ## Show deployment plan
	@echo "$(GREEN)📋 Generating plan...$(NC)"
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Deploy infrastructure (with confirmation)
	@echo "$(GREEN)🚀 Deploying infrastructure...$(NC)"
	cd $(TERRAFORM_DIR) && terraform apply

output: ## Show Terraform outputs
	@echo "$(GREEN)📤 Terraform outputs...$(NC)"
	cd $(TERRAFORM_DIR) && terraform output

refresh: ## Refresh Terraform state
	@echo "$(GREEN)🔄 Refreshing state...$(NC)"
	cd $(TERRAFORM_DIR) && terraform refresh

show: ## Show detailed Terraform state
	@echo "$(GREEN)📋 Terraform state...$(NC)"
	cd $(TERRAFORM_DIR) && terraform show

graph: ## Generate dependency graph (requires graphviz)
	@echo "$(GREEN)📊 Generating graph...$(NC)"
	cd $(TERRAFORM_DIR) && terraform graph | dot -Tpng > terraform-graph.png
	@echo "$(GREEN)✅ Graph generated: $(TERRAFORM_DIR)/terraform-graph.png$(NC)"

clean: ## Clean Terraform temporary files
	@echo "$(GREEN)🧹 Cleaning...$(NC)"
	rm -rf $(TERRAFORM_DIR)/.terraform
	rm -f $(TERRAFORM_DIR)/.terraform.lock.hcl
	rm -f $(TERRAFORM_DIR)/terraform.tfstate*

##@ Stream Analytics

stream-start: ## Start Stream Analytics job (asa-shopnow-marketplace)
	@echo "$(GREEN)▶️  Starting Stream Analytics job...$(NC)"
	az stream-analytics job start --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace --output-start-mode JobStartTime

stream-stop: ## Stop Stream Analytics job (asa-shopnow-marketplace)
	@echo "$(YELLOW)⏸️  Stopping Stream Analytics job...$(NC)"
	az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name asa-shopnow-marketplace

stream-logs: ## Show Stream Analytics activity logs
	@echo "$(GREEN)📜 Stream Analytics logs...$(NC)"
	az monitor activity-log list --resource-group $(RESOURCE_GROUP) --max-events 20 --query "[].{Time:eventTimestamp, Level:level, Operation:operationName.localizedValue, Status:status.localizedValue}" -o table

##@ Destruction

destroy: ## Destroy infrastructure (with confirmation)
	@echo "$(RED)💥 Destroying infrastructure...$(NC)"
	@echo "$(YELLOW)⚠️  Stopping Stream Analytics job first...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting 10 seconds...$(NC)"
	@sleep 10
	cd $(TERRAFORM_DIR) && terraform destroy

destroy-force: ## Destroy infrastructure (without confirmation)
	@echo "$(RED)💥 Automatic destruction...$(NC)"
	@echo "$(YELLOW)⚠️  Stopping Stream Analytics job first...$(NC)"
	-az stream-analytics job stop --resource-group $(RESOURCE_GROUP) --name $(STREAM_JOB) 2>/dev/null || true
	@echo "$(YELLOW)⏳ Waiting 10 seconds...$(NC)"
	@sleep 10
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

##@ Shortcuts

i: init ## Alias for init
p: plan ## Alias for plan
a: apply ## Alias for apply
d: deploy ## Alias for deploy
s: status ## Alias for status
