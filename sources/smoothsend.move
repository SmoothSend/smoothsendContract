module smoothsend::smoothsend {
    use aptos_framework::coin::{Self};
    use aptos_framework::timestamp;
    use aptos_framework::signer;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;
    use std::string::{String};
    use std::vector;

    // Error codes
    const E_EXPIRED: u64 = 1;
    const E_INVALID_NONCE: u64 = 2;
    const E_INSUFFICIENT_BALANCE: u64 = 3;
    const E_PROTOCOL_PAUSED: u64 = 4;
    const E_NOT_ADMIN: u64 = 5;
    const E_INVALID_FEE: u64 = 6;
    const E_INVALID_AMOUNT: u64 = 7;
    const E_INVALID_SLIPPAGE: u64 = 8;
    const E_RELAYER_NOT_REGISTERED: u64 = 9;
    const E_COIN_NOT_SUPPORTED: u64 = 10;
    const E_COIN_ALREADY_SUPPORTED: u64 = 11;
    const E_ARRAY_LENGTH_MISMATCH: u64 = 12;
    const E_INVALID_COIN_LIMITS: u64 = 13;

    // Protocol configuration
    struct ProtocolConfig has key {
        admin: address,
        paused: bool,
        protocol_fee_bps: u64, // 1000 = 10% (basis points)
        treasury: address,
        min_gas_fee: u64, // Minimum gas fee in token units
        max_slippage_bps: u64, // Maximum allowed slippage
    }

    // Registered relayers
    struct RegisteredRelayers has key {
        relayers: Table<address, RelayerInfo>,
    }

    struct RelayerInfo has store {
        is_active: bool,
        total_transactions: u64,
        total_volume: u64,
        registration_time: u64,
    }

    // User nonces for replay protection
    struct UserNonces has key {
        nonces: Table<address, u64>,
    }

    // Supported coins (whitelist)
    struct SupportedCoins has key {
        coins: Table<String, CoinInfo>,
        active_coins: vector<String>, // Tracks active coin types for get_supported_coins
    }

    struct CoinInfo has store {
        is_active: bool,
        min_transfer_amount: u64,
        max_transfer_amount: u64,
        price_feed_address: address, // For future oracle integration
        added_timestamp: u64,
    }

    // Transfer event
    struct GaslessTransferEvent has drop, store {
        from: address,
        to: address,
        amount: u64,
        gas_fee: u64,
        protocol_fee: u64,
        coin_type: String,
        relayer: address,
        timestamp: u64,
    }

    // Coin support event
    struct CoinSupportEvent has drop, store {
        coin_type: String,
        is_active: bool,
        min_amount: u64,
        max_amount: u64,
        timestamp: u64,
    }

    struct ProtocolEvents has key {
        gasless_transfers: EventHandle<GaslessTransferEvent>,
        coin_support: EventHandle<CoinSupportEvent>,
    }

    // [Commented Out: Allowance system for fully gasless]
    /*
    struct Allowance has key {
        allowances: Table<address, Table<String, u64>>, // user -> coin_type -> amount
    }

    public entry fun approve<CoinType>(user: &signer, amount: u64) acquires Allowance {
        let user_addr = signer::address_of(user);
        let coin_type = type_info::type_name<CoinType>();
        let allowances = borrow_global_mut<Allowance>(@smoothsend);
        let user_allowances = table::borrow_mut_with_default(&mut allowances.allowances, user_addr, table::new());
        table::upsert(user_allowances, coin_type, amount);
    }
    */

    // ==================== INITIALIZATION ====================

    // NEW: Simple initialization function that works with CLI
    public entry fun initialize_basic(
        admin: &signer,
        treasury: address,
    ) {
        let admin_addr = signer::address_of(admin);

        // Initialize protocol config
        move_to(admin, ProtocolConfig {
            admin: admin_addr,
            paused: false,
            protocol_fee_bps: 1000, // 10% protocol fee
            treasury,
            min_gas_fee: 100000000, // 0.1 USDT (8 decimals)
            max_slippage_bps: 1000, // 10% max slippage
        });

        move_to(admin, RegisteredRelayers {
            relayers: table::new(),
        });

        move_to(admin, UserNonces {
            nonces: table::new(),
        });

        move_to(admin, ProtocolEvents {
            gasless_transfers: account::new_event_handle<GaslessTransferEvent>(admin),
            coin_support: account::new_event_handle<CoinSupportEvent>(admin),
        });

        // Initialize empty supported coins
        move_to(admin, SupportedCoins {
            coins: table::new<String, CoinInfo>(),
            active_coins: vector::empty<String>(),
        });
    }

    public entry fun initialize_with_coins(
        admin: &signer,
        treasury: address,
        initial_coins: vector<String>,
        min_amounts: vector<u64>,
        max_amounts: vector<u64>
    ) {
        let admin_addr = signer::address_of(admin);

        // Validate array lengths
        assert!(vector::length(&initial_coins) == vector::length(&min_amounts), E_ARRAY_LENGTH_MISMATCH);
        assert!(vector::length(&initial_coins) == vector::length(&max_amounts), E_ARRAY_LENGTH_MISMATCH);

        // Initialize protocol config
        move_to(admin, ProtocolConfig {
            admin: admin_addr,
            paused: false,
            protocol_fee_bps: 1000, // 10% protocol fee
            treasury,
            min_gas_fee: 100000000, // 0.1 USDT (8 decimals)
            max_slippage_bps: 1000, // 10% max slippage
        });

        move_to(admin, RegisteredRelayers {
            relayers: table::new(),
        });

        move_to(admin, UserNonces {
            nonces: table::new(),
        });

        move_to(admin, ProtocolEvents {
            gasless_transfers: account::new_event_handle<GaslessTransferEvent>(admin),
            coin_support: account::new_event_handle<CoinSupportEvent>(admin),
        });

        // Initialize supported coins
        let supported_coins = table::new<String, CoinInfo>();
        let active_coins = vector::empty<String>();
        let i = 0;
        while (i < vector::length(&initial_coins)) {
            let coin_type = *vector::borrow(&initial_coins, i);
            let min_amount = *vector::borrow(&min_amounts, i);
            let max_amount = *vector::borrow(&max_amounts, i);
            assert!(min_amount > 0 && max_amount >= min_amount, E_INVALID_COIN_LIMITS);

            table::add(&mut supported_coins, coin_type, CoinInfo {
                is_active: true,
                min_transfer_amount: min_amount,
                max_transfer_amount: max_amount,
                price_feed_address: @0x0,
                added_timestamp: timestamp::now_seconds(),
            });
            vector::push_back(&mut active_coins, coin_type);
            i = i + 1;
        };

        move_to(admin, SupportedCoins {
            coins: supported_coins,
            active_coins,
        });
    }

    // ==================== MAIN GASLESS TRANSFER FUNCTION ====================

    public entry fun execute_gasless_transfer<CoinType>(
        user: &signer,
        relayer: &signer,
        to_address: address,
        amount: u64,
        estimated_gas_cost: u64,
        max_slippage_bps: u64,
        nonce: u64,
        deadline: u64
    ) acquires ProtocolConfig, RegisteredRelayers, UserNonces, ProtocolEvents, SupportedCoins {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(!config.paused, E_PROTOCOL_PAUSED);
        assert!(timestamp::now_seconds() <= deadline, E_EXPIRED);

        // Check if coin is supported
        let coin_type_name = type_info::type_name<CoinType>();
        let supported_coins = borrow_global<SupportedCoins>(@smoothsend);
        assert!(table::contains(&supported_coins.coins, coin_type_name), E_COIN_NOT_SUPPORTED);
        let coin_info = table::borrow(&supported_coins.coins, coin_type_name);
        assert!(coin_info.is_active, E_COIN_NOT_SUPPORTED);
        assert!(amount >= coin_info.min_transfer_amount, E_INVALID_AMOUNT);
        assert!(amount <= coin_info.max_transfer_amount, E_INVALID_AMOUNT);

        // Validate inputs
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(estimated_gas_cost >= config.min_gas_fee, E_INVALID_FEE);
        assert!(max_slippage_bps <= config.max_slippage_bps, E_INVALID_SLIPPAGE);

        let user_addr = signer::address_of(user);
        let relayer_addr = signer::address_of(relayer);

        // Verify relayer is registered and active
        let relayers = borrow_global<RegisteredRelayers>(@smoothsend);
        assert!(table::contains(&relayers.relayers, relayer_addr), E_RELAYER_NOT_REGISTERED);
        let relayer_info = table::borrow(&relayers.relayers, relayer_addr);
        assert!(relayer_info.is_active, E_RELAYER_NOT_REGISTERED);

        // Calculate gas compensation and protocol fee
        let actual_gas_compensation = calculate_gas_compensation(estimated_gas_cost, max_slippage_bps);
        let protocol_fee = (actual_gas_compensation * config.protocol_fee_bps) / 10000; // 10% of gas fee
        let total_fee = actual_gas_compensation + protocol_fee;

        // Verify user balance
        let user_balance = coin::balance<CoinType>(user_addr);
        assert!(user_balance >= amount + total_fee, E_INSUFFICIENT_BALANCE);

        // Update nonce
        update_user_nonce(user_addr, nonce);

        // Execute transfers
        let transfer_coins = coin::withdraw<CoinType>(user, amount);
        coin::deposit(to_address, transfer_coins);

        let gas_coins = coin::withdraw<CoinType>(user, actual_gas_compensation);
        coin::deposit(relayer_addr, gas_coins);

        let protocol_coins = coin::withdraw<CoinType>(user, protocol_fee);
        coin::deposit(config.treasury, protocol_coins);

        // Update relayer stats
        update_relayer_stats(relayer_addr, amount);

        // Emit transfer event
        let events = borrow_global_mut<ProtocolEvents>(@smoothsend);
        event::emit_event(&mut events.gasless_transfers, GaslessTransferEvent {
            from: user_addr,
            to: to_address,
            amount,
            gas_fee: actual_gas_compensation,
            protocol_fee,
            coin_type: coin_type_name,
            relayer: relayer_addr,
            timestamp: timestamp::now_seconds(),
        });
    }

    // ==================== HELPER FUNCTIONS ====================

    fun calculate_gas_compensation(estimated_gas: u64, max_slippage_bps: u64): u64 {
        estimated_gas + (estimated_gas * max_slippage_bps / 10000)
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

    fun update_relayer_stats(relayer_address: address, transfer_amount: u64) acquires RegisteredRelayers {
        let relayers = borrow_global_mut<RegisteredRelayers>(@smoothsend);
        let relayer_info = table::borrow_mut(&mut relayers.relayers, relayer_address);
        relayer_info.total_transactions = relayer_info.total_transactions + 1;
        relayer_info.total_volume = relayer_info.total_volume + transfer_amount;
    }

    // ==================== RELAYER MANAGEMENT ====================

    public entry fun register_relayer(admin: &signer, relayer_address: address) acquires ProtocolConfig, RegisteredRelayers {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);

        let relayers = borrow_global_mut<RegisteredRelayers>(@smoothsend);
        if (!table::contains(&relayers.relayers, relayer_address)) {
            table::add(&mut relayers.relayers, relayer_address, RelayerInfo {
                is_active: true,
                total_transactions: 0,
                total_volume: 0,
                registration_time: timestamp::now_seconds(),
            });
        } else {
            let relayer_info = table::borrow_mut(&mut relayers.relayers, relayer_address);
            relayer_info.is_active = true;
        };
    }

    public entry fun deactivate_relayer(admin: &signer, relayer_address: address) acquires ProtocolConfig, RegisteredRelayers {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);

        let relayers = borrow_global_mut<RegisteredRelayers>(@smoothsend);
        if (table::contains(&relayers.relayers, relayer_address)) {
            let relayer_info = table::borrow_mut(&mut relayers.relayers, relayer_address);
            relayer_info.is_active = false;
        };
    }

    // ==================== COIN MANAGEMENT ====================

    public entry fun add_supported_coin<CoinType>(
        admin: &signer,
        min_amount: u64,
        max_amount: u64,
        price_feed: address
    ) acquires ProtocolConfig, SupportedCoins, ProtocolEvents {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        assert!(min_amount > 0 && max_amount >= min_amount, E_INVALID_COIN_LIMITS);

        let coin_type_name = type_info::type_name<CoinType>();
        let supported_coins = borrow_global_mut<SupportedCoins>(@smoothsend);
        assert!(!table::contains(&supported_coins.coins, coin_type_name), E_COIN_ALREADY_SUPPORTED);

        table::add(&mut supported_coins.coins, coin_type_name, CoinInfo {
            is_active: true,
            min_transfer_amount: min_amount,
            max_transfer_amount: max_amount,
            price_feed_address: price_feed,
            added_timestamp: timestamp::now_seconds(),
        });
        vector::push_back(&mut supported_coins.active_coins, coin_type_name);

        let events = borrow_global_mut<ProtocolEvents>(@smoothsend);
        event::emit_event(&mut events.coin_support, CoinSupportEvent {
            coin_type: coin_type_name,
            is_active: true,
            min_amount,
            max_amount,
            timestamp: timestamp::now_seconds(),
        });
    }

    public entry fun remove_supported_coin<CoinType>(
        admin: &signer
    ) acquires ProtocolConfig, SupportedCoins, ProtocolEvents {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);

        let coin_type_name = type_info::type_name<CoinType>();
        let supported_coins = borrow_global_mut<SupportedCoins>(@smoothsend);
        if (table::contains(&supported_coins.coins, coin_type_name)) {
            let coin_info = table::borrow_mut(&mut supported_coins.coins, coin_type_name);
            coin_info.is_active = false;
            vector::remove_value(&mut supported_coins.active_coins, &coin_type_name);

            let events = borrow_global_mut<ProtocolEvents>(@smoothsend);
            event::emit_event(&mut events.coin_support, CoinSupportEvent {
                coin_type: coin_type_name,
                is_active: false,
                min_amount: coin_info.min_transfer_amount,
                max_amount: coin_info.max_transfer_amount,
                timestamp: timestamp::now_seconds(),
            });
        };
    }

    public entry fun update_supported_coin<CoinType>(
        admin: &signer,
        min_amount: u64,
        max_amount: u64,
        price_feed: address
    ) acquires ProtocolConfig, SupportedCoins, ProtocolEvents {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        assert!(min_amount > 0 && max_amount >= min_amount, E_INVALID_COIN_LIMITS);

        let coin_type_name = type_info::type_name<CoinType>();
        let supported_coins = borrow_global_mut<SupportedCoins>(@smoothsend);
        assert!(table::contains(&supported_coins.coins, coin_type_name), E_COIN_NOT_SUPPORTED);

        let coin_info = table::borrow_mut(&mut supported_coins.coins, coin_type_name);
        coin_info.min_transfer_amount = min_amount;
        coin_info.max_transfer_amount = max_amount;
        coin_info.price_feed_address = price_feed;

        let events = borrow_global_mut<ProtocolEvents>(@smoothsend);
        event::emit_event(&mut events.coin_support, CoinSupportEvent {
            coin_type: coin_type_name,
            is_active: coin_info.is_active,
            min_amount,
            max_amount,
            timestamp: timestamp::now_seconds(),
        });
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
    public fun estimate_total_cost<CoinType>(
        amount: u64,
        estimated_gas_units: u64,
        gas_price: u64,
        token_price_per_apt: u64,
        markup_bps: u64
    ): (u64, u64, u64, u64) acquires ProtocolConfig {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        let gas_cost_octas = estimated_gas_units * gas_price;
        let gas_cost_tokens = (gas_cost_octas * token_price_per_apt) / 100000000;
        let gas_with_markup = gas_cost_tokens + (gas_cost_tokens * markup_bps / 10000);
        let actual_gas_cost = if (gas_with_markup < config.min_gas_fee) {
            config.min_gas_fee
        } else {
            gas_with_markup
        };
        let protocol_fee = (actual_gas_cost * config.protocol_fee_bps) / 10000; // 10% of gas fee
        let total_fees = actual_gas_cost + protocol_fee;
        let total_cost = amount + total_fees;
        (actual_gas_cost, protocol_fee, total_fees, total_cost)
    }

    #[view]
    public fun can_execute_transfer<CoinType>(
        user_address: address,
        amount: u64,
        gas_fee: u64
    ): bool acquires ProtocolConfig {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        let user_balance = coin::balance<CoinType>(user_address);
        let protocol_fee = (gas_fee * config.protocol_fee_bps) / 10000; // 10% of gas fee
        let total_cost = amount + gas_fee + protocol_fee;
        user_balance >= total_cost
    }

    #[view]
    public fun is_relayer_active(relayer_address: address): bool acquires RegisteredRelayers {
        let relayers = borrow_global<RegisteredRelayers>(@smoothsend);
        if (table::contains(&relayers.relayers, relayer_address)) {
            let relayer_info = table::borrow(&relayers.relayers, relayer_address);
            relayer_info.is_active
        } else {
            false
        }
    }

    #[view]
    public fun get_relayer_stats(relayer_address: address): (u64, u64, u64) acquires RegisteredRelayers {
        let relayers = borrow_global<RegisteredRelayers>(@smoothsend);
        if (table::contains(&relayers.relayers, relayer_address)) {
            let relayer_info = table::borrow(&relayers.relayers, relayer_address);
            (relayer_info.total_transactions, relayer_info.total_volume, relayer_info.registration_time)
        } else {
            (0, 0, 0)
        }
    }

    #[view]
    public fun is_coin_supported<CoinType>(): bool acquires SupportedCoins {
        let coin_type_name = type_info::type_name<CoinType>();
        let supported_coins = borrow_global<SupportedCoins>(@smoothsend);
        if (table::contains(&supported_coins.coins, coin_type_name)) {
            let coin_info = table::borrow(&supported_coins.coins, coin_type_name);
            coin_info.is_active
        } else {
            false
        }
    }

    #[view]
    public fun get_coin_limits<CoinType>(): (u64, u64) acquires SupportedCoins {
        let coin_type_name = type_info::type_name<CoinType>();
        let supported_coins = borrow_global<SupportedCoins>(@smoothsend);
        if (table::contains(&supported_coins.coins, coin_type_name)) {
            let coin_info = table::borrow(&supported_coins.coins, coin_type_name);
            (coin_info.min_transfer_amount, coin_info.max_transfer_amount)
        } else {
            (0, 0)
        }
    }

    #[view]
    public fun get_supported_coins(): vector<String> acquires SupportedCoins {
        borrow_global<SupportedCoins>(@smoothsend).active_coins
    }

    #[view]
    public fun get_protocol_config(): (address, bool, u64, address, u64) acquires ProtocolConfig {
        let config = borrow_global<ProtocolConfig>(@smoothsend);
        (config.admin, config.paused, config.protocol_fee_bps, config.treasury, config.min_gas_fee)
    }

    // ==================== ADMIN FUNCTIONS ====================

    public entry fun update_config(
        admin: &signer,
        new_treasury: address,
        new_protocol_fee_bps: u64,
        new_min_gas_fee: u64,
        new_max_slippage_bps: u64
    ) acquires ProtocolConfig {
        let config = borrow_global_mut<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        config.treasury = new_treasury;
        config.protocol_fee_bps = new_protocol_fee_bps;
        config.min_gas_fee = new_min_gas_fee;
        config.max_slippage_bps = new_max_slippage_bps;
    }

    public entry fun set_paused(admin: &signer, paused: bool) acquires ProtocolConfig {
        let config = borrow_global_mut<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        config.paused = paused;
    }

    public entry fun transfer_admin(admin: &signer, new_admin: address) acquires ProtocolConfig {
        let config = borrow_global_mut<ProtocolConfig>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        config.admin = new_admin;
    }
}