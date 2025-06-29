module smoothsend::gasless_stablecoin {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::signer;
    use aptos_framework::ed25519;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;
    use aptos_std::bcs;
    use aptos_std::hash;
    use std::string::{String};
    use std::vector;

    // Error codes
    const E_INVALID_SIGNATURE: u64 = 1;
    const E_EXPIRED: u64 = 2;
    const E_INVALID_NONCE: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_PROTOCOL_PAUSED: u64 = 5;
    const E_NOT_ADMIN: u64 = 6;
    const E_INVALID_FEE: u64 = 7;
    const E_INVALID_AMOUNT: u64 = 8;
    const E_COINS_NOT_DEPOSITED: u64 = 9;
    const E_INSUFFICIENT_COINS: u64 = 10;
    const E_INVALID_SIGNATURE_FORMAT: u64 = 11;
    const E_SIGNATURE_MISMATCH: u64 = 12;

    // Protocol configuration
    struct ProtocolConfig has key {
        admin: address,
        paused: bool,
        protocol_fee_margin: u64, // 110 = 10% margin (gas_cost * 1.1)
        treasury: address,
        base_gas_cost: u64, // Base gas cost in USDC units (e.g., 0.1 USDC)
    }

    // User nonces for replay protection
    struct UserNonces has key {
        nonces: Table<address, u64>,
    }

    // Temporary coin storage for gasless transfers
    struct TempCoinStore<phantom CoinType> has key {
        coins: Table<address, Coin<CoinType>>,
    }

    // Transfer authorization
    struct TransferAuth has drop, copy {
        from: address,
        to: address,
        amount: u64,
        max_fee: u64,
        token_type: String,
        nonce: u64,
        deadline: u64,
        gas_cost: u64, // Added for off-chain gas cost
    }

    // Events
    struct GaslessTransferEvent has drop, store {
        from: address,
        to: address,
        amount: u64,
        gas_cost: u64,
        protocol_fee: u64,
        total_fee: u64,
        coin_type: String,
        relayer: address,
        timestamp: u64,
    }

    struct CoinDepositEvent has drop, store {
        user: address,
        amount: u64,
        coin_type: String,
        timestamp: u64,
    }

    struct ProtocolEvents has key {
        gasless_transfers: EventHandle<GaslessTransferEvent>,
        coin_deposits: EventHandle<CoinDepositEvent>,
    }

    // ==================== INITIALIZATION ====================

    public entry fun initialize(admin: &signer, treasury: address) {
        let admin_addr = signer::address_of(admin);
        
        move_to(admin, ProtocolConfig {
            admin: admin_addr,
            paused: false,
            protocol_fee_margin: 110, // 10% margin
            treasury,
            base_gas_cost: 100000, // 0.1 USDC
        });

        move_to(admin, UserNonces {
            nonces: table::new(),
        });

        move_to(admin, ProtocolEvents {
            gasless_transfers: account::new_event_handle<GaslessTransferEvent>(admin),
            coin_deposits: account::new_event_handle<CoinDepositEvent>(admin),
        });
    }

    public entry fun initialize_coin_store<CoinType>(admin: &signer) {
        assert!(signer::address_of(admin) == @smoothsend, E_NOT_ADMIN);
        
        if (!exists<TempCoinStore<CoinType>>(@smoothsend)) {
            move_to(admin, TempCoinStore<CoinType> {
                coins: table::new(),
            });
        };
    }

    // ==================== COIN DEPOSIT/WITHDRAWAL ====================

    public entry fun deposit_coins<CoinType>(
        user: &signer,
        amount: u64
    ) acquires TempCoinStore, ProtocolEvents {
        let user_addr = signer::address_of(user);
        assert!(exists<TempCoinStore<CoinType>>(@smoothsend), E_COINS_NOT_DEPOSITED);
        
        let coins_to_deposit = coin::withdraw<CoinType>(user, amount);
        let coin_store = borrow_global_mut<TempCoinStore<CoinType>>(@smoothsend);
        
        if (table::contains(&coin_store.coins, user_addr)) {
            let existing_coins = table::borrow_mut(&mut coin_store.coins, user_addr);
            coin::merge(existing_coins, coins_to_deposit);
        } else {
            table::add(&mut coin_store.coins, user_addr, coins_to_deposit);
        };

        let events = borrow_global_mut<ProtocolEvents>(@smoothsend);
        event::emit_event(&mut events.coin_deposits, CoinDepositEvent {
            user: user_addr,
            amount,
            coin_type: type_info::type_name<CoinType>(),
            timestamp: timestamp::now_seconds(),
        });
    }

    public entry fun withdraw_coins<CoinType>(
        user: &signer,
        amount: u64
    ) acquires TempCoinStore {
        let user_addr = signer::address_of(user);
        let coin_store = borrow_global_mut<TempCoinStore<CoinType>>(@smoothsend);
        assert!(table::contains(&coin_store.coins, user_addr), E_COINS_NOT_DEPOSITED);
        
        let user_coins = table::borrow_mut(&mut coin_store.coins, user_addr);
        assert!(coin::value(user_coins) >= amount, E_INSUFFICIENT_COINS);
        
        let coins_to_withdraw = coin::extract(user_coins, amount);
        coin::deposit(user_addr, coins_to_withdraw);
        
        if (coin::value(user_coins) == 0) {
            let empty_coins = table::remove(&mut coin_store.coins, user_addr);
            coin::destroy_zero(empty_coins);
        };
    }

    // ==================== MAIN GASLESS TRANSFER FUNCTION ====================

    public entry fun execute_gasless_transfer<CoinType>(
        relayer: &signer,
        from_address: address,
        to_address: address,
        amount: u64,
        max_fee: u64,
        nonce: u64,
        deadline: u64,
        gas_cost: u64, // Relayer provides estimated gas cost
        signature: vector<u8>,
        public_key: vector<u8>
    ) acquires ProtocolConfig, UserNonces, ProtocolEvents, TempCoinStore {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(!config.paused, E_PROTOCOL_PAUSED);
        assert!(timestamp::now_seconds() <= deadline, E_EXPIRED);
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(gas_cost >= config.base_gas_cost, E_INVALID_FEE);

        let relayer_addr = signer::address_of(relayer);

        // 1. Calculate fees
        let protocol_fee = (gas_cost * (config.protocol_fee_margin - 100)) / 100; // 10% of gas cost
        let total_fee = gas_cost + protocol_fee;
        assert!(total_fee <= max_fee, E_INVALID_FEE);

        // 2. Verify transfer authorization
        verify_transfer_authorization<CoinType>(
            from_address,
            to_address,
            amount,
            max_fee,
            nonce,
            deadline,
            gas_cost,
            signature,
            public_key
        );

        // 3. Update user nonce
        update_user_nonce(from_address, nonce);

        // 4. Check deposited coins
        let coin_store = borrow_global_mut<TempCoinStore<CoinType>>(@smoothsend);
        assert!(table::contains(&coin_store.coins, from_address), E_COINS_NOT_DEPOSITED);
        let user_coins = table::borrow_mut(&mut coin_store.coins, from_address);
        let total_required = amount + total_fee;
        assert!(coin::value(user_coins) >= total_required, E_INSUFFICIENT_COINS);

        // 5. Execute transfers
        let transfer_coins = coin::extract(user_coins, amount);
        coin::deposit(to_address, transfer_coins);
        
        let protocol_fee_coins = coin::extract(user_coins, protocol_fee);
        coin::deposit(config.treasury, protocol_fee_coins);
        
        let gas_fee_coins = coin::extract(user_coins, gas_cost);
        coin::deposit(relayer_addr, gas_fee_coins);

        if (coin::value(user_coins) == 0) {
            let empty_coins = table::remove(&mut coin_store.coins, from_address);
            coin::destroy_zero(empty_coins);
        };

        // 6. Emit event
        let events = borrow_global_mut<ProtocolEvents>(@smoothsend);
        event::emit_event(&mut events.gasless_transfers, GaslessTransferEvent {
            from: from_address,
            to: to_address,
            amount,
            gas_cost,
            protocol_fee,
            total_fee,
            coin_type: type_info::type_name<CoinType>(),
            relayer: relayer_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ==================== HELPER FUNCTIONS ====================

    fun verify_transfer_authorization<CoinType>(
        from: address,
        to: address,
        amount: u64,
        max_fee: u64,
        nonce: u64,
        deadline: u64,
        gas_cost: u64,
        signature: vector<u8>,
        public_key_bytes: vector<u8>
    ) {
        let transfer_auth = TransferAuth {
            from,
            to,
            amount,
            max_fee,
            token_type: type_info::type_name<CoinType>(),
            nonce,
            deadline,
            gas_cost,
        };

        verify_signature(transfer_auth, signature, public_key_bytes);
    }

    fun verify_signature(
        auth: TransferAuth,
        signature: vector<u8>,
        public_key_bytes: vector<u8>
    ) {
        let domain_separator = b"SMOOTHSEND_GASLESS_V1";
        let auth_typehash = b"TransferAuth(address from,address to,uint256 amount,uint256 max_fee,string token_type,uint256 nonce,uint256 deadline,uint256 gas_cost)";
        
        let auth_bytes = bcs::to_bytes(&auth);
        let message = domain_separator;
        vector::append(&mut message, auth_typehash);
        vector::append(&mut message, auth_bytes);
        
        let message_hash = hash::sha3_256(message);
        
        assert!(vector::length(&public_key_bytes) == 32, E_INVALID_SIGNATURE_FORMAT);
        assert!(vector::length(&signature) == 64, E_INVALID_SIGNATURE_FORMAT);
        
        let public_key = ed25519::new_unvalidated_public_key_from_bytes(public_key_bytes);
        let signature_obj = ed25519::new_signature_from_bytes(signature);
        
        assert!(
            ed25519::signature_verify_strict(&signature_obj, &public_key, message_hash),
            E_SIGNATURE_MISMATCH
        );
    }

    fun update_user_nonce(user_address: address, expected_nonce: u64) acquires UserNonces {
        let nonces = borrow_global_mut<UserNonces>(@smoothsend);
        if (!table::contains(&nonces.nonces, user_address)) {
            table::add(&mut nonces.nonces, user_address, 0);
        };
        let current_nonce = table::borrow_mut(&mut nonces.nonces, user_address);
        assert!(*current_nonce == expected_nonce, E_INVALID_NONCE);
        *current_nonce = *current_nonce + 1;
    }

    // ==================== VIEW FUNCTIONS ====================

    #[view]
    public fun get_user_nonce(user_address: address): u64 acquires UserNonces {
        let nonces = borrow_global<UserNonces>(@smoothsend);
        if (table::contains(&nonces.nonces, user_address)) {
            *table::borrow(&nonces.nonces, user_address)
        } else {
            0
        }
    }

    #[view]
    public fun get_user_balance<CoinType>(user_address: address): u64 acquires TempCoinStore {
        if (!exists<TempCoinStore<CoinType>>(@smoothsend)) {
            return 0
        };
        let coin_store = borrow_global<TempCoinStore<CoinType>>(@smoothsend);
        if (table::contains(&coin_store.coins, user_address)) {
            coin::value(table::borrow(&coin_store.coins, user_address))
        } else {
            0
        }
    }

    #[view]
    public fun preview_transfer_fees(gas_cost: u64): (u64, u64, u64) acquires ProtocolConfig {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        let actual_gas_cost = if (gas_cost < config.base_gas_cost) config.base_gas_cost else gas_cost;
        let protocol_fee = (actual_gas_cost * (config.protocol_fee_margin - 100)) / 100;
        let total_fee = actual_gas_cost + protocol_fee;
        (actual_gas_cost, protocol_fee, total_fee)
    }

    #[view]
    public fun get_protocol_config(): (address, bool, u64, address, u64) acquires ProtocolConfig {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        (
            config.admin,
            config.paused,
            config.protocol_fee_margin,
            config.treasury,
            config.base_gas_cost
        )
    }

    #[view]
    public fun can_afford_transfer<CoinType>(
        user_address: address,
        amount: u64,
        max_fee: u64,
        gas_cost: u64
    ): bool acquires TempCoinStore, ProtocolConfig {
        let user_balance = get_user_balance<CoinType>(user_address);
        let (actual_gas_cost, protocol_fee, _) = preview_transfer_fees(gas_cost);
        let total_fee = actual_gas_cost + protocol_fee;
        user_balance >= amount + total_fee && total_fee <= max_fee
    }

    // ==================== ADMIN FUNCTIONS ====================

    public entry fun update_config(
        admin: &signer,
        new_treasury: address,
        new_protocol_fee_margin: u64,
        new_base_gas_cost: u64
    ) acquires ProtocolConfig {
        let config = borrow_global_mut<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        
        config.treasury = new_treasury;
        config.protocol_fee_margin = new_protocol_fee_margin;
        config.base_gas_cost = new_base_gas_cost;
    }

    public entry fun set_paused(admin: &signer, paused: bool) acquires ProtocolConfig {
        let config = borrow_global_mut<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        config.paused = paused;
    }

    public entry fun emergency_withdraw<CoinType>(
        admin: &signer,
        user_address: address,
        amount: u64
    ) acquires ProtocolConfig, TempCoinStore {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        
        let coin_store = borrow_global_mut<TempCoinStore<CoinType>>(@smoothsend);
        assert!(table::contains(&coin_store.coins, user_address), E_COINS_NOT_DEPOSITED);
        
        let user_coins = table::borrow_mut(&mut coin_store.coins, user_address);
        assert!(coin::value(user_coins) >= amount, E_INSUFFICIENT_COINS);
        
        let withdraw_coins = coin::extract(user_coins, amount);
        coin::deposit(user_address, withdraw_coins);
        
        if (coin::value(user_coins) == 0) {
            let empty_coins = table::remove(&mut coin_store.coins, user_address);
            coin::destroy_zero(empty_coins);
        };
    }
}