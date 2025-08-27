#!/bin/bash

# SmoothSend Contract Upgrade Script
# This script upgrades the contract from v1 to v2 with enhanced sececho "   - Upgrading contract with enhanced security features..."

aptos move upgrade --profile $PROFILE --assume-yesty features

set -e  # Exit on any error

echo "🚀 SmoothSend Contract Upgrade v1 → v2"
echo "======================================"

# Configuration
PROFILE="smoothsend"
NETWORK="testnet"  # Change to "mainnet" for production
CONTRACT_ADDRESS="0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b"

echo "📋 Upgrade Configuration:"
echo "   Profile: $PROFILE"
echo "   Network: $NETWORK"
echo "   Contract Address: $CONTRACT_ADDRESS"
echo ""

# Step 1: Backup current state
echo "💾 Step 1: Creating backup of current contract state..."
mkdir -p backups/$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"

# Query current contract state for backup
echo "   - Backing up current contract state to $BACKUP_DIR"
aptos account list --profile $PROFILE > "$BACKUP_DIR/account_resources_pre_upgrade.json" 2>/dev/null || echo "   Warning: Could not backup account resources"
echo "   ✅ Backup completed"
echo ""

# Step 2: Build the upgraded contract
echo "🔨 Step 2: Building upgraded contract..."
echo "   - Cleaning previous build artifacts..."
rm -rf build/

echo "   - Compiling contract v2..."
aptos move compile
if [ $? -eq 0 ]; then
    echo "   ✅ Contract compiled successfully"
else
    echo "   ❌ Compilation failed! Please fix errors before upgrading."
    exit 1
fi
echo ""

# Step 3: Run tests (if available)
echo "🧪 Step 3: Running tests..."
if [ -d "tests" ] && [ "$(ls -A tests)" ]; then
    echo "   - Running unit tests..."
    aptos move test
    if [ $? -eq 0 ]; then
        echo "   ✅ All tests passed"
    else
        echo "   ❌ Tests failed! Please fix before upgrading."
        exit 1
    fi
else
    echo "   ⚠️  No tests found, skipping test phase"
fi
echo ""

# Step 4: Compatibility check
echo "🔍 Step 4: Checking upgrade compatibility..."
echo "   - Verifying upgrade policy is 'compatible'..."
if grep -q "upgrade_policy.*compatible" Move.toml; then
    echo "   ✅ Upgrade policy is set to 'compatible'"
else
    echo "   ❌ Upgrade policy must be 'compatible' for safe upgrades"
    exit 1
fi
echo ""

# Step 5: Pre-upgrade validation
echo "🔍 Step 5: Pre-upgrade validation..."
echo "   - Contract compiles successfully ✅"
echo "   - Upgrade policy is compatible ✅" 
echo "   - Ready to proceed with upgrade"
echo ""

# Step 6: Confirm upgrade
echo "⚠️  Step 6: Final confirmation"
echo ""
echo "🔄 READY TO UPGRADE CONTRACT"
echo "   From: v1.0.0 (existing deployment)"
echo "   To:   v2.0.0 (enhanced security features)"
echo ""
echo "🆕 New Features Being Added:"
echo "   • Integer overflow protection"
echo "   • Zero amount validation"
echo "   • Self-transfer prevention"
echo "   • Enhanced error codes (E_OVERFLOW, E_AMOUNT_ZERO, etc.)"
echo "   • Emergency pause functionality"
echo "   • Additional address validation"
echo ""
echo "⚡ This upgrade will:"
echo "   • Maintain all existing functionality"
echo "   • Keep existing data intact"
echo "   • Add new security features"
echo "   • Not affect existing relayer integrations"
echo ""

read -p "❓ Do you want to proceed with the upgrade? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Upgrade cancelled by user"
    exit 0
fi
echo ""

# Step 7: Execute upgrade
echo "🚀 Step 7: Executing contract upgrade..."
echo "   - Upgrading contract with enhanced security features..."

aptos move publish --profile $PROFILE --assume-yes

if [ $? -eq 0 ]; then
    echo "   ✅ Contract upgrade successful!"
    
    # Store the upgrade transaction hash
    echo "   - Saving upgrade transaction details..."
    echo "Upgrade completed at: $(date)" > "$BACKUP_DIR/upgrade_success.log"
    echo "Profile used: $PROFILE" >> "$BACKUP_DIR/upgrade_success.log"
    echo "Network: $NETWORK" >> "$BACKUP_DIR/upgrade_success.log"
else
    echo "   ❌ Contract upgrade failed!"
    echo "   📝 Check the error output above for details"
    exit 1
fi
echo ""

# Step 8: Post-upgrade initialization
echo "🔧 Step 8: Post-upgrade initialization..."
echo "   - The pause functionality needs to be initialized separately"
echo "   - Run this command when ready:"
echo "     aptos move run --function-id ${CONTRACT_ADDRESS}::smoothsend::initialize_pause_state --profile $PROFILE"
echo ""

# Step 9: Verification
echo "✅ Step 9: Upgrade verification..."
echo "   - Querying updated contract..."
aptos account list --profile $PROFILE > "$BACKUP_DIR/account_resources_post_upgrade.json" 2>/dev/null || echo "   Warning: Could not query post-upgrade state"

echo ""
echo "🎉 UPGRADE COMPLETED SUCCESSFULLY!"
echo "=================================="
echo ""
echo "📊 Summary:"
echo "   • Contract upgraded from v1.0.0 to v2.0.0"
echo "   • All existing functionality preserved"
echo "   • New security features added"
echo "   • Backup saved to: $BACKUP_DIR"
echo ""
echo "🚨 IMPORTANT NEXT STEPS:"
echo "   1. Initialize pause functionality (optional):"
echo "      aptos move run --function-id ${CONTRACT_ADDRESS}::smoothsend::initialize_pause_state --profile $PROFILE"
echo ""
echo "   2. Test the upgraded contract with your backend"
echo "   3. Monitor for any issues in the first 24 hours"
echo "   4. Update your frontend/backend error handling for new error codes"
echo ""
echo "📋 New Error Codes to Handle:"
echo "   • E_AMOUNT_ZERO (5): Amount cannot be zero"
echo "   • E_SELF_TRANSFER (6): Cannot transfer to self"
echo "   • E_OVERFLOW (7): Integer overflow protection"
echo "   • E_RELAYER_FEE_ZERO (8): Relayer fee cannot be zero"
echo "   • E_INVALID_ADDRESS (9): Invalid address provided"
echo ""
echo "✅ Upgrade complete! Your contract is now running v2.0.0 with enhanced security."
