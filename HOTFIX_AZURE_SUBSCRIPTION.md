# HOTFIX: Azure Subscription Read-Only Error

## 🚨 Problem Description

**Error encountered during**: `make enable-quarantine`

**Error message**:

```
Error: listing keys for Authorization Rule
ReadOnlyDisabledSubscription: The subscription '029b3537-0f24-400b-b624-6058a145efe1'
is disabled and therefore marked as read only. You cannot perform any write actions
on this subscription until it is re-enabled.
```

## 🔍 Root Cause Analysis

### Test Results (2026-01-22 11:26)

| Test               | Command                                               | Result                              |
| ------------------ | ----------------------------------------------------- | ----------------------------------- |
| Subscription State | `az account show`                                     | ✅ **Enabled**                      |
| List Subscriptions | `az account list`                                     | ✅ **Enabled**                      |
| Read EventHub Keys | `az eventhubs namespace authorization-rule keys list` | ❌ **ReadOnlyDisabledSubscription** |

### Conclusion

The subscription **appears** as "Enabled" in basic checks, but **fails** when trying to access Event Hub authorization rule keys. This indicates:

1. **Billing/Payment Issue**: There's likely an outstanding payment or billing problem
2. **Partial Suspension**: The subscription is in a "soft disabled" state where reads work but certain operations (like listing security keys) are blocked
3. **Policy Restriction**: A spending limit or policy is preventing write/sensitive operations

This is **NOT a Terraform or code issue** - it's an Azure billing/subscription policy problem that requires action via the Azure Portal.

**This is NOT a code issue** - it's an Azure subscription configuration problem.

The Azure subscription `029b3537-0f24-400b-b624-6058a145efe1` has been:

- Marked as **disabled**
- Set to **read-only mode**

This typically happens when:

1. **Billing issues**: Payment method expired or failed
2. **Spending limit reached**: Azure Free Trial or spending cap hit
3. **Subscription suspended**: By administrator or Azure policy
4. **Expired subscription**: Trial period ended

## ✅ Resolution Steps

### Step 1: Check Subscription Status

```bash
az account show --subscription 029b3537-0f24-400b-b624-6058a145efe1
```

Look for the `state` field - it should show `Disabled` or `Warned`.

### Step 2: Check Billing Status

Visit the Azure Portal:

1. Go to: https://portal.azure.com/#blade/Microsoft_Azure_Billing/SubscriptionsBlade
2. Select subscription `029b3537-0f24-400b-b624-6058a145efe1`
3. Check **Payment method** and **Billing status**

### Step 3: Re-enable Subscription

#### Option A: If Billing Issue

1. Update payment method in Azure Portal
2. Clear any outstanding invoices
3. Wait 10-15 minutes for subscription to reactivate

#### Option B: If Spending Limit Reached

```bash
# Remove spending limit (careful!)
az consumption budget delete --budget-name <budget-name> --resource-group rg-e6-dbreau
```

Or increase spending limit in Azure Portal:

- Portal → Cost Management → Budgets → Modify limit

#### Option C: If Trial Expired

- Upgrade to Pay-As-You-Go subscription
- Or create a new subscription

### Step 4: Verify Reactivation

```bash
# Check subscription state
az account show --query state -o tsv

# Should return: "Enabled"
```

### Step 5: Retry Terraform Deployment

Once subscription is re-enabled:

```bash
make enable-quarantine
```

## 🛠️ Temporary Workaround

If you cannot re-enable the subscription immediately, you can:

1. **Use a different subscription**:

   ```bash
   az account set --subscription <other-subscription-id>
   cd terraform
   terraform plan  # Verify it uses the new subscription
   ```

2. **Skip quarantine deployment** for now:
   - Continue with other features that don't require new resources
   - Enable quarantine later when subscription is active

## 📋 Prevention

To avoid this in the future:

1. **Set up billing alerts**:

   ```bash
   az consumption budget create \
     --budget-name "Monthly-Alert" \
     --amount 100 \
     --time-grain Monthly \
     --resource-group rg-e6-dbreau
   ```

2. **Monitor subscription health**:
   - Add subscription status check to CI/CD pipeline
   - Set up email notifications for billing issues

3. **Use Azure Cost Management**:
   - Enable daily cost alerts
   - Set spending quotas per resource group

## 🔗 Useful Links

- [Azure Subscription States](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/subscription-states)
- [Reactivate Disabled Subscription](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/subscription-disabled)
- [Azure Spending Limits](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/spending-limit)

---

**Branch**: `HTFX/azure-subscription-readonly`  
**Date**: 2026-01-22  
**Status**: ⚠️ **ACTION REQUIRED** - Azure subscription must be re-enabled before continuing
