# 🚀 Quick Start: SmoothSend Contract Upgrade

## Ready to Upgrade? Follow These Steps:

### 1. **Verify Your Setup**
```bash
cd /home/ved-mohan/Desktop/smoothsendcontract
aptos config show-profiles | grep smoothsend
```

### 2. **Test Compilation**
```bash
aptos move compile
```
✅ Should show: `"Result": ["6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend"]`

### 3. **Run the Upgrade (Testnet)**
```bash
./scripts/upgrade_contract.sh
```

### 4. **Test the Upgrade**
```bash
./scripts/test_upgrade.sh
```

### 5. **Initialize New Features**
```bash
# Initialize pause functionality (optional)
aptos move run \
    --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::initialize_pause_state \
    --profile smoothsend
```

## 🚨 Emergency Commands

### If Something Goes Wrong:
```bash
./scripts/rollback_contract.sh
```

### Pause Contract (Emergency):
```bash
aptos move run \
    --function-id 0x6d88ee2fde204e756874e13f5d5eddebd50725805c0a332ade87d1ef03f9148b::smoothsend::pause_contract \
    --profile smoothsend
```

## ✅ Success Checklist

After upgrade:
- [ ] Contract compiles successfully
- [ ] Upgrade script completes without errors
- [ ] Test script shows all green checks
- [ ] Backend integration tested with new error codes
- [ ] Small test transfers work correctly

## 📋 New Error Codes for Your Backend

Update your error handling:
```javascript
const NEW_ERROR_CODES = {
    E_AMOUNT_ZERO: 5,        // Amount cannot be zero
    E_SELF_TRANSFER: 6,      // Cannot transfer to self
    E_OVERFLOW: 7,           // Integer overflow protection
    E_RELAYER_FEE_ZERO: 8,   // Relayer fee cannot be zero
    E_INVALID_ADDRESS: 9     // Invalid address provided
};
```

## 🔄 Using `aptos move publish` Alternative

Yes, you can also use `aptos move publish` with your `smoothsend` profile, but **upgrade is safer** for production:

### For New Deployment (different address):
```bash
aptos move publish --profile smoothsend
```

### For Upgrade (same address, recommended):
```bash
aptos move publish --profile smoothsend
```

**Recommendation**: Use `upgrade-package` to maintain the same contract address and preserve existing integrations.

---
**Need Help?** Check `UPGRADE_GUIDE.md` for complete documentation.
