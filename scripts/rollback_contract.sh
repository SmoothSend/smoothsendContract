#!/bin/bash

# SmoothSend Contract Rollback Script
# Emergency rollback plan in case upgrade fails or causes issues

set -e

echo "🚨 SmoothSend Contract Emergency Rollback"
echo "======================================="

# Configuration
PROFILE="smoothsend"
CONTRACT_ADDRESS="0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b"

echo "⚠️  WARNING: This is an EMERGENCY ROLLBACK procedure"
echo "   Profile: $PROFILE"
echo "   Contract Address: $CONTRACT_ADDRESS"
echo ""

echo "📋 Rollback Options:"
echo "   1. Pause contract (if pause functionality is available)"
echo "   2. Deploy original v1 contract to new address"
echo "   3. Contact Aptos support for more advanced rollback"
echo ""

read -p "❓ Which rollback option do you want? (1/2/3): " option

case $option in
    1)
        echo "🛑 Option 1: Pausing contract..."
        echo "   - Attempting to pause the upgraded contract..."
        
        aptos move run \
            --function-id ${CONTRACT_ADDRESS}::smoothsend::pause_contract \
            --profile $PROFILE \
            --assume-yes
        
        if [ $? -eq 0 ]; then
            echo "   ✅ Contract paused successfully"
            echo "   📝 All transfers are now blocked until unpaused"
        else
            echo "   ❌ Failed to pause contract"
            echo "   💡 Try option 2 (redeploy) instead"
        fi
        ;;
        
    2)
        echo "🔄 Option 2: Redeploying original v1 contract..."
        echo "   - This will deploy v1 to a NEW address"
        echo "   - You'll need to update your backend configuration"
        echo ""
        
        # Restore original contract
        cp sources/smoothsend.move sources/smoothsend_backup.move
        
        # Update Move.toml back to v1
        sed -i 's/version = "2.0.0"/version = "1.0.0"/' Move.toml
        
        echo "   - Compiling original v1 contract..."
        aptos move compile --profile $PROFILE
        
        echo "   - Publishing v1 contract to new address..."
        aptos move publish --profile $PROFILE --assume-yes
        
        if [ $? -eq 0 ]; then
            echo "   ✅ V1 contract redeployed successfully"
            echo "   🔧 Update your backend to use the new contract address"
            echo "   📝 Check deployment output above for the new address"
        else
            echo "   ❌ Failed to redeploy v1 contract"
        fi
        ;;
        
    3)
        echo "📞 Option 3: Contact Aptos Support"
        echo "   - For advanced rollback scenarios, contact Aptos support"
        echo "   - Provide them with:"
        echo "     • Contract address: $CONTRACT_ADDRESS"
        echo "     • Upgrade transaction hash"
        echo "     • Backup files from the upgrade"
        echo ""
        echo "   📧 Aptos Support: https://discord.gg/aptoslabs"
        ;;
        
    *)
        echo "❌ Invalid option selected"
        exit 1
        ;;
esac

echo ""
echo "🔧 Post-Rollback Actions:"
echo "   1. Update your backend configuration if needed"
echo "   2. Test all functionality"
echo "   3. Notify users if there was any downtime"
echo "   4. Plan for a better upgrade strategy"
echo ""
echo "✅ Rollback procedure completed."
