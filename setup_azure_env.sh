#!/bin/bash
# Auto-configure Azure subscription from active az login session
# This script sets ARM_SUBSCRIPTION_ID environment variable for Terraform

set -e

echo "🔍 Detecting active Azure subscription..."
ACTIVE_SUB_ID=$(az account show --query id -o tsv 2>/dev/null)

if [ -z "$ACTIVE_SUB_ID" ]; then
    echo "❌ No active Azure subscription found."
    echo "Run 'az login' first to authenticate."
    exit 1
fi

ACTIVE_SUB_NAME=$(az account show --query name -o tsv 2>/dev/null)

echo "✅ Active subscription detected:"
echo "   Name: $ACTIVE_SUB_NAME"
echo "   ID:   $ACTIVE_SUB_ID"
echo ""

# Export environment variable for Terraform
export ARM_SUBSCRIPTION_ID="$ACTIVE_SUB_ID"

# Subscription profiles for reference
case "$ACTIVE_SUB_ID" in
    "029b3537-0f24-400b-b624-6058a145efe1")
        echo "📋 Profile: HDF ROUBAIX (may be disabled)"
        ;;
    "1418505f-9957-467a-a0ba-ee7ac1036b73")
        echo "📋 Profile: PERSONAL AZURE"
        ;;
    "090e5792-c538-4d9b-bcd8-c62d22a28b15")
        echo "📋 Profile: AZURE FOR STUDENTS"
        ;;
    *)
        echo "📋 Profile: UNKNOWN (will use default settings)"
        ;;
esac

echo ""
echo "🚀 Ready to run Terraform commands!"
echo ""
echo "Environment variable set:"
echo "export ARM_SUBSCRIPTION_ID=\"$ACTIVE_SUB_ID\""
echo ""
echo "Run your Terraform commands now (from this same shell session):"
echo "  cd terraform"
echo "  terraform plan"
echo "  terraform apply"
