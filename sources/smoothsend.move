module smoothsend::smoothsend {
    use aptos_framework::coin;
    use aptos_framework::signer;
    use aptos_std::table::{Self, Table};
    use std::string::{String};

    // Error codes
    const E_NOT_ADMIN: u64 = 1;
    const E_COIN_NOT_SUPPORTED: u64 = 2;
    const E_RELAYER_NOT_WHITELISTED: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;

    // Contract state
    struct Config has key {
        admin: address,
        supported_coins: Table<String, bool>,
        whitelisted_relayers: Table<address, bool>,
    }

    // Initialize contract
    public entry fun initialize(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        move_to(admin, Config {
            admin: admin_addr,
            supported_coins: table::new(),
            whitelisted_relayers: table::new(),
        });
    }

    // Main gasless transfer function
    public entry fun send_with_fee<CoinType>(
        user: &signer,
        relayer_address: address,  // Pass relayer address to verify
        recipient: address,
        amount: u64,
        relayer_fee: u64
    ) acquires Config {
        let config = borrow_global<Config>(@smoothsend);
        
        // Check if coin is supported (USDC/USDT only)
        let coin_name = coin::symbol<CoinType>();
        assert!(
            table::contains(&config.supported_coins, coin_name) && 
            *table::borrow(&config.supported_coins, coin_name),
            E_COIN_NOT_SUPPORTED
        );
        
        // Check if relayer is whitelisted
        assert!(
            table::contains(&config.whitelisted_relayers, relayer_address) &&
            *table::borrow(&config.whitelisted_relayers, relayer_address),
            E_RELAYER_NOT_WHITELISTED
        );
        
        // Check user has enough balance
        let user_addr = signer::address_of(user);
        let total_needed = amount + relayer_fee;
        assert!(coin::balance<CoinType>(user_addr) >= total_needed, E_INSUFFICIENT_BALANCE);
        
        // Execute atomic transfers
        coin::transfer<CoinType>(user, recipient, amount);
        coin::transfer<CoinType>(user, relayer_address, relayer_fee);
    }

    // Admin function: Add supported coin
    public entry fun add_supported_coin<CoinType>(admin: &signer) acquires Config {
        let config = borrow_global_mut<Config>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        
        let coin_name = coin::symbol<CoinType>();
        if (!table::contains(&config.supported_coins, coin_name)) {
            table::add(&mut config.supported_coins, coin_name, true);
        } else {
            *table::borrow_mut(&mut config.supported_coins, coin_name) = true;
        };
    }

    // Admin function: Remove supported coin  
    public entry fun remove_supported_coin<CoinType>(admin: &signer) acquires Config {
        let config = borrow_global_mut<Config>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        
        let coin_name = coin::symbol<CoinType>();
        if (table::contains(&config.supported_coins, coin_name)) {
            *table::borrow_mut(&mut config.supported_coins, coin_name) = false;
        };
    }

    // Admin function: Add whitelisted relayer
    public entry fun add_relayer(admin: &signer, relayer: address) acquires Config {
        let config = borrow_global_mut<Config>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        
        if (!table::contains(&config.whitelisted_relayers, relayer)) {
            table::add(&mut config.whitelisted_relayers, relayer, true);
        } else {
            *table::borrow_mut(&mut config.whitelisted_relayers, relayer) = true;
        };
    }

    // Admin function: Remove whitelisted relayer
    public entry fun remove_relayer(admin: &signer, relayer: address) acquires Config {
        let config = borrow_global_mut<Config>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        
        if (table::contains(&config.whitelisted_relayers, relayer)) {
            *table::borrow_mut(&mut config.whitelisted_relayers, relayer) = false;
        };
    }

    // View function: Check if coin is supported
    #[view]
    public fun is_coin_supported<CoinType>(): bool acquires Config {
        let config = borrow_global<Config>(@smoothsend);
        let coin_name = coin::symbol<CoinType>();
        
        if (table::contains(&config.supported_coins, coin_name)) {
            *table::borrow(&config.supported_coins, coin_name)
        } else {
            false
        }
    }

    // View function: Check if relayer is whitelisted
    #[view]
    public fun is_relayer_whitelisted(relayer: address): bool acquires Config {
        let config = borrow_global<Config>(@smoothsend);
        
        if (table::contains(&config.whitelisted_relayers, relayer)) {
            *table::borrow(&config.whitelisted_relayers, relayer)
        } else {
            false
        }
    }

    // Transfer admin (for security)
    public entry fun transfer_admin(admin: &signer, new_admin: address) acquires Config {
        let config = borrow_global_mut<Config>(@smoothsend);
        assert!(signer::address_of(admin) == config.admin, E_NOT_ADMIN);
        config.admin = new_admin;
    }
}