# SmoothSend Contract Upgrade Guide v1 → v2

## 🚀 Overview

This guide covers the upgrade of SmoothSend contract from v1.0.0 to v2.0.0 with enhanced security features. The upgrade maintains full backward compatibility while adding critical security improvements.

## 🆕 What's New in v2.0.0

### Enhanced Security Features
- **Integer Overflow Protection**: Prevents arithmetic overflow in fee calculations
- **Zero Amount Validation**: Blocks transfers with zero amounts or relayer fees
- **Self-Transfer Prevention**: Prevents users from transferring to themselves
- **Address Validation**: Validates addresses are not zero/null
- **Emergency Pause System**: Admin can pause/unpause contract in emergencies

### New Error Codes
- `E_AMOUNT_ZERO (5)`: Transfer amount cannot be zero
- `E_SELF_TRANSFER (6)`: Cannot transfer to the same address
- `E_OVERFLOW (7)`: Integer overflow protection triggered
- `E_RELAYER_FEE_ZERO (8)`: Relayer fee cannot be zero
- `E_INVALID_ADDRESS (9)`: Invalid address provided

### Backward Compatibility
✅ All existing functions work exactly the same
✅ Existing relayer integrations continue working
✅ No data migration required
✅ Same contract address maintained

## 📋 Pre-Upgrade Checklist

- [ ] Contract has `upgrade_policy = "compatible"` in Move.toml
- [ ] All tests pass
- [ ] Backup of current contract state created
- [ ] Upgrade tested on testnet first
- [ ] Rollback plan prepared
- [ ] Team notified of upgrade window

## 🛠️ Upgrade Process

### Step 1: Preparation
```bash
# Ensure you're in the contract directory
cd /home/ved-mohan/Desktop/smoothsendcontract

# Verify current setup
aptos config show-profiles | grep smoothsend
```

### Step 2: Run the Upgrade Script
```bash
# Execute the automated upgrade script
./scripts/upgrade_contract.sh
```

The script will:
1. Create backup of current state
2. Compile the new contract
3. Run compatibility checks
4. Perform dry run simulation
5. Execute the upgrade
6. Verify the upgrade

### Step 3: Post-Upgrade Initialization
```bash
# Initialize the new pause functionality (optional)
aptos move run --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::initialize_pause_state --profile smoothsend
```

### Step 4: Validate Upgrade
```bash
# Run post-upgrade tests
./scripts/test_upgrade.sh
```

## 🔧 Manual Upgrade Commands

If you prefer manual control:

```bash
# 1. Compile the contract
aptos move compile --profile smoothsend

# 2. Test the upgrade (dry run)
aptos move upgrade --profile smoothsend --assume-yes --simulate

# 3. Execute the upgrade
aptos move upgrade --profile smoothsend --assume-yes
```

## 🚨 Emergency Procedures

### If Upgrade Fails
```bash
# Run the rollback script
./scripts/rollback_contract.sh
```

### If Contract Needs Emergency Pause
```bash
# Pause all transfers
aptos move run --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::pause_contract --profile smoothsend

# Unpause when ready
aptos move run --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::unpause_contract --profile smoothsend
```

## 🧪 Testing Procedures

### Pre-Upgrade Testing
1. Test on testnet first
2. Verify all existing functionality
3. Test with small amounts
4. Confirm relayer integration works

### Post-Upgrade Testing
1. Run `./scripts/test_upgrade.sh`
2. Test actual transfers with your backend
3. Verify new error conditions work
4. Test pause/unpause functionality

### Backend Integration Testing
Update your backend error handling to support new error codes:

```javascript
// New error codes to handle
const ERROR_CODES = {
  E_NOT_ADMIN: 1,
  E_COIN_NOT_SUPPORTED: 2,
  E_RELAYER_NOT_WHITELISTED: 3,
  E_INSUFFICIENT_BALANCE: 4,
  E_AMOUNT_ZERO: 5,           // NEW
  E_SELF_TRANSFER: 6,         // NEW
  E_OVERFLOW: 7,              // NEW
  E_RELAYER_FEE_ZERO: 8,      // NEW
  E_INVALID_ADDRESS: 9        // NEW
};
```

## 📊 Configuration

### Current Setup
- **Profile**: `smoothsend`
- **Network**: `testnet`
- **Contract Address**: `0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b`
- **Admin Address**: `6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b`

### Move.toml Configuration
```toml
[package]
name = "smoothsend"
version = "2.0.0"
upgrade_policy = "compatible"

[addresses]
smoothsend = "0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b"
```

## 🔍 Verification Commands

```bash
# Check contract version
aptos move view --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::is_paused --profile smoothsend

# Check if relayer is whitelisted
aptos move view --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::is_relayer_whitelisted --args address:RELAYER_ADDRESS --profile smoothsend

# Check if coin is supported
aptos move view --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::is_coin_supported --type-args COIN_TYPE --profile smoothsend
```

## 📞 Support

### If You Need Help
1. Check the error logs in the upgrade output
2. Run the test script to identify issues
3. Use the rollback script if needed
4. Join Aptos Discord for technical support

### Contact Information
- **Aptos Discord**: https://discord.gg/aptoslabs
- **Aptos Documentation**: https://aptos.dev/

## ✅ Success Checklist

After upgrade completion:
- [ ] Upgrade script completed successfully
- [ ] Test script shows all green checks
- [ ] Backend integration tested
- [ ] Small test transfers completed
- [ ] Error handling updated for new codes
- [ ] Team notified of successful upgrade
- [ ] Monitoring set up for first 24 hours

## 🔄 Maintenance

### Regular Checks
- Monitor contract performance
- Check for any new error patterns
- Test pause/unpause functionality periodically
- Keep backups of contract state

### Future Upgrades
This contract is set up for future upgrades with `upgrade_policy = "compatible"`. Future security enhancements can be deployed using the same process.

---

**Last Updated**: $(date)
**Contract Version**: v2.0.0
**Upgrade Status**: Ready for Production
