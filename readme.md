# SmoothSend Smart Contract

This repository contains the **SmoothSend** smart contract for gasless USDC transfers on the **Aptos Testnet**. Users can send USDC without paying gas fees in $APT; instead, a small fee (e.g., 0.1 USDC gas cost + 0.01 USDC protocol fee) is deducted from their USDC balance. The protocol fee (10% margin) is collected in the treasury account.


**Date & Time**: June 29, 2025, 11:02 PM IST

---

## **Contract Details**

- **Contract Address**: `e91b3ff1999a9704b2aa28f772ec40622492b786f31c1b7f2a99e006582c0c8f`
  - Module: `gasless_stablecoin`
  - Profile: `smoothsend` (in `~/.aptos/config.yaml`)
- **Treasury Address**: `0x295bef03694392fd679f7ca0b1e6e1ef542e69856180b1a89c7eb573a7b5657e`
  - Purpose: Collects 10% protocol fee (e.g., 0.01 USDC per transfer)
  - Profile: `treasury` (in `~/.aptos/config.yaml`)
- **USDC Address**: `0x3c27315fb69ba6e4b960f1507d1cefcc9a4247869f26a8d59d6b7869d23782c::test_coins::USDC`
  - Confirm: https://aptos.dev/network/faucet
- **Config File**: `~/.aptos/config.yaml`
  - Rest URL: `https://fullnode.testnet.aptoslabs.com`
- **Contract Location**: `~/Desktop/smoothsend/`
- **Network**: Aptos Testnet

---

## **Progress Tracker**

Total Steps: 5 | Completed: 5 | Progress: **100% (Smart Contract On-Chain Setup)**

### **Completed Steps**
1. **Setup Aptos CLI and Config** ✅
   - Done: Installed Aptos CLI, configured `smoothsend` and `treasury` profiles in `~/.aptos/config.yaml`.
   - Funded accounts with $APT:
     - Admin: `e91b3ff1999a9704b2aa28f772ec40622492b786f31c1b7f2a99e006582c0c8f`
     - Treasury: `0x295bef03694392fd679f7ca0b1e6e1ef542e69856180b1a89c7eb573a7b5657e`

2. **Compile Contract** ✅
   - Command: `aptos move compile --named-addresses smoothsend=e91b3ff1999a9704b2aa28f772ec40622492b786f31c1b7f2a99e006582c0c8f`
   - Output: Module `e91b3ff...::gasless_stablecoin` compiled successfully.
   - Location: `~/Desktop/smoothsend/`

3. **Publish Contract** ✅
   - Command: `aptos move publish --named-addresses smoothsend=e91b3ff1999a9704b2aa28f772ec40622492b786f31c1b7f2a99e006582c0c8f --profile smoothsend`
   - Tx Hash: `0x68871308010a35bd1adc7aba85b2a1a09f8e0c2be6a2c84d70c3792b46d0650f`
   - Verify: https://explorer.aptoslabs.com/txn/0x68871308010a35bd1adc7aba85b2a1a09f8e0c2be6a2c84d70c3792b46d0650f?network=testnet

4. **Initialize Contract** ✅
   - Command: `aptos move run --function-id e91b3ff1999a9704b2aa28f772ec40622492b786f31c1b7f2a99e006582c0c8f::gasless_stablecoin::initialize --args address:0x295bef03694392fd679f7ca0b1e6e1ef542e69856180b1a89c7eb573a7b5657e --profile smoothsend`
   - Tx Hash: `0x27c1ec71f2dad032424476a98451efc818bb3837327b17a9a0a5bcb1eab322d5`
   - Verify: https://explorer.aptoslabs.com/txn/0x27c1ec71f2dad032424476a98451efc818bb3837327b17a9a0a5bcb1eab322d5?network=testnet
   - Output: Set `ProtocolConfig`, `UserNonces`, and `ProtocolEvents` with treasury address.

5. **Initialize USDC Coin Store** ✅
   - Command: `aptos move run --function-id e91b3ff1999a9704b2aa28f772ec40622492b786f31c1b7f2a99e006582c0c8f::gasless_stablecoin::initialize_coin_store --type-args 0x3c27315fb69ba6e4b960f1507d1cefcc9a4247869f26a8d59d6b7869d23782c::test_coins::USDC --profile smoothsend`
   - Tx Hash: `0xa4b6d6f44079b1bb1df04d78af14421c3bc6d9950edcd2dcc9c690edbde41fc6`
   - Verify: https://explorer.aptoslabs.com/txn/0xa4b6d6f44079b1bb1df04d78af14421c3bc6d9950edcd2dcc9c690edbde41fc6?network=testnet
   - Output: USDC support enabled for contract.


- **Frontend Setup**: Create client in `~/Desktop/smoothsend-frontend/` (or any folder).
- **Testing**: Mint USDC, test deposits and transfers.
- **Scaling**: Beta test with 100-200 users, market on X (@smoothsend).

---