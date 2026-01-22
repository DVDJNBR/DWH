#!/bin/bash
# Hotfix script to resolve Azure subscription read-only error
# This script refreshes Terraform state and retries the operation

set -e  # Exit on error

echo "🔧 Azure Subscription Hotfix Script"
echo "===================================="
echo ""

# Step 1: Verify Azure subscription is enabled
echo "📊 Step 1: Checking Azure subscription status..."
SUBSCRIPTION_STATE=$(az account show --query state -o tsv)

if [ "$SUBSCRIPTION_STATE" != "Enabled" ]; then
    echo "❌ ERROR: Subscription is not enabled (State: $SUBSCRIPTION_STATE)"
    echo ""
    echo "Please re-enable your Azure subscription:"
    echo "1. Visit: https://portal.azure.com/#blade/Microsoft_Azure_Billing/SubscriptionsBlade"
    echo "2. Check payment method and billing status"
    echo "3. Re-run this script after fixing the issue"
    echo ""
    exit 1
fi

echo "✅ Subscription is Enabled"
echo ""

# Step 2: Refresh Terraform state
echo "🔄 Step 2: Refreshing Terraform state..."
cd terraform
terraform refresh -var="enable_marketplace=true" -var="enable_quarantine=true"
echo "✅ Terraform state refreshed"
echo ""

# Step 3: Retry the quarantine deployment
echo "🚀 Step 3: Retrying quarantine deployment..."
cd ..
make enable-quarantine

echo ""
echo "✅ Hotfix completed successfully!"
