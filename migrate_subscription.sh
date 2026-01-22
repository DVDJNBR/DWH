#!/bin/bash
# Migration script to switch Azure subscriptions
# Cleans old Terraform state and reinitializes with new subscription

set -e

echo "🔄 Azure Subscription Migration Script"
echo "======================================="
echo ""

# Step 1: Show current Azure subscription
echo "📊 Current Azure Subscription:"
az account show --query "{Name:name, ID:id, State:state}" -o table
echo ""

read -p "Is this the subscription you want to use? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "❌ Aborting. Please run 'az login' and select the correct subscription first."
    exit 1
fi

CURRENT_SUB_ID=$(az account show --query id -o tsv)
echo ""
echo "✅ Using subscription: $CURRENT_SUB_ID"
echo ""

# Step 2: Backup current state
echo "💾 Step 1: Backing up current Terraform state..."
if [ -f terraform/terraform.tfstate ]; then
    BACKUP_FILE="terraform/terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
    cp terraform/terraform.tfstate "$BACKUP_FILE"
    echo "✅ State backed up to: $BACKUP_FILE"
else
    echo "⚠️  No existing state file found (this is OK for fresh setups)"
fi
echo ""

# Step 3: Clean old state (if resources are on disabled subscription)
echo "🧹 Step 2: Cleaning old state from disabled subscription..."
read -p "Do you want to remove the old Terraform state? This will force re-import or recreation. (y/n): " clean_state

if [ "$clean_state" = "y" ]; then
    rm -f terraform/terraform.tfstate
    rm -f terraform/terraform.tfstate.backup
    rm -f terraform/.terraform.lock.hcl
    rm -rf terraform/.terraform
    echo "✅ Old state cleaned"
else
    echo "⚠️  Keeping old state (you may encounter errors if resources are on a disabled subscription)"
fi
echo ""

# Step 4: Remove subscription_id from terraform.tfvars if it exists
echo "🔧 Step 3: Updating terraform.tfvars..."
if [ -f terraform/terraform.tfvars ]; then
    # Remove subscription_id line from terraform.tfvars
    sed -i '/^subscription_id/d' terraform/terraform.tfvars
    echo "✅ Removed hardcoded subscription_id from terraform.tfvars"
    echo "   (Will now use active subscription: $CURRENT_SUB_ID)"
else
    echo "⚠️  No terraform.tfvars found"
fi
echo ""

# Step 5: Reinitialize Terraform
echo "🔄 Step 4: Reinitializing Terraform..."
cd terraform
terraform init -upgrade
echo "✅ Terraform reinitialized"
echo ""

# Step 6: Verify
echo "📋 Step 5: Verification..."
terraform plan -out=migration.tfplan
echo ""
echo "✅ Migration complete!"
echo ""
echo "Next steps:"
echo "1. Review the plan above"
echo "2. If it looks good, run: cd terraform && terraform apply migration.tfplan"
echo "3. Or run: make deploy"
echo ""
echo "🎉 Your project is now using subscription: $CURRENT_SUB_ID"
