import credits.aleo;

// The 'hook_manager' program.
program hook_manager.aleo {
    
    const HOOK_UNUSED: u8 = 0;
    const HOOK_MERKLE_TREE: u8 = 3;
    const HOOK_INTERCHAIN_GAS_PAYMASTER: u8 = 4;
    const HOOK_PAUSABLE: u8 = 7;

    const TREE_DEPTH: u32 = 32;
    const MAX_LEAVES: u32 = (2u64 ** TREE_DEPTH - 1) as u32;

    // keccak256 zero hashes
    // TODO: use correct zero hashes
    const ZERO_HASHES: [[u128; 2]; TREE_DEPTH] = [
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128],
        [0u128, 1u128]
    ];

    const TOKEN_EXCHANGE_RATE_SCALE: u128 = 10000000000u128; // 1e10

    struct InterchainGasPaymaster {
        hook_owner: address,
        nonce: u32,
        // We need to track each IGPs balance, because only the `hook_manager` program has a balance in the credits program
        balance: u64,
        // Used for sequencing events
        count: u32,
    }

    struct Tree {
        branch: [[u128; 2]; TREE_DEPTH],
        count: u32,
    }

    struct MerkleTreeHook {
        parent: address,
        root: [u128; 2],
        tree: Tree,
        nonce: u32,
    }

    struct NoopHook {
        nonce: u32,
    }

    struct InsertedIntoTreeEvent {
        id: [u8; 32],
        index: u32,
    }

    struct GasConfigKey {
        igp: address,
        destination: u32
    }

    struct DomainGasConfig {
        gas_overhead: u128,
        exchange_rate: u128,
        gas_price: u128,
    }

    struct GasPaymentEvent {
        id: [u8; 32],
        destination_domain: u32,
        gas_amount: u128,
        payment: u64,
        index: u32,
    }

    // Struct for indexing events
    struct EventKey {
        hook: address,
        index: u32,
    }

    mapping nonce: bool => u32;
    // Mapping for IGPs
    mapping igps: address => InterchainGasPaymaster;
    // DestinationGasConfigs
    mapping destination_gas_configs: GasConfigKey => DomainGasConfig;
    // Mapping for MerkleTreeHook
    mapping merkle_tree_hooks: address => MerkleTreeHook;
    // Mapping from ism address to Hook Type
    mapping hooks: address => u8;
    // Events
    // GasPayment Events: sequence => Event
    mapping gas_payment_events: EventKey => GasPaymentEvent;
    // InsertedIntoTree Events: sequence => Event
    mapping inserted_into_tree_events: EventKey => InsertedIntoTreeEvent;

    @noupgrade
    async constructor() {}

    async transition init_noop() -> Future {
        return finalize_noop();
    }

    async function finalize_noop() {
        let current_nonce = nonce.get_or_use(true, 0u32);

        let ism = NoopHook {
            nonce: current_nonce,
        };

        let ism_address = BHP256::hash_to_address(ism);

        // Sanity check, this should be super unlikely
        let contains = hooks.contains(ism_address);
        assert(!contains);

        nonce.set(true, current_nonce + 1);
        hooks.set(ism_address, HOOK_UNUSED);
    }

    async transition init_igp() -> Future {
        return finalize_init_igp(self.caller);
    }

    async function finalize_init_igp(owner: address) {
        let current_nonce = nonce.get_or_use(true, 0u32);
        let hook = InterchainGasPaymaster {
            nonce: current_nonce,
            hook_owner: owner,
            balance: 0,
            count: 0,
        };

        let hook_address = BHP256::hash_to_address(hook);

        // Sanity check, this should be super unlikely
        let contains = hooks.contains(hook_address);
        assert(!contains);

        nonce.set(true, current_nonce + 1);
        hooks.set(hook_address, HOOK_INTERCHAIN_GAS_PAYMASTER);    
        igps.set(hook_address, hook);
    }

    async transition claim(igp: address, amount: u64) -> Future {
        let transfer = credits.aleo/transfer_public(self.caller, amount);
        return finalize_claim(igp, self.caller, amount, transfer);
    }

    async function finalize_claim(igp_address: address, owner: address, amount: u64, transfer: Future) {
        assert(igps.contains(igp_address));

        let igp = igps.get(igp_address);
        assert_eq(igp.hook_owner, owner);
        assert(igp.balance >= amount);

        transfer.await();
        igp.balance -= amount;

        igps.set(igp_address, igp);
    }

    async transition pay_for_gas(igp: address, message_id: [u8; 32], destination_domain: u32, gas_limit: u128, credits_amount: u64) -> Future {
        let transfer: Future = credits.aleo/transfer_public(self.caller, credits_amount);
        return finalize_pay_for_gas(igp, message_id, destination_domain, gas_limit, credits_amount, transfer);
    }

    async function finalize_pay_for_gas(igp_address: address, message_id: [u8; 32], destination_domain: u32, gas_limit: u128, credits_amount: u64, transfer: Future) {
        let key = GasConfigKey {
            destination: destination_domain,
            igp: igp_address,
        };
        assert(destination_gas_configs.contains(key));

        let config = destination_gas_configs.get(key);
        let quote = quote_gas_payment(config, gas_limit);

        // Revert if the quoted fee does not match the transfer amount
        assert(quote == credits_amount);
        transfer.await();

        // TODO: maybe refactor the logic
        let current_igp = igps.get(igp_address);
        let event_key = EventKey {
            hook: igp_address,
            index: current_igp.count,
        };
        let event = GasPaymentEvent {
            id: message_id,
            index: current_igp.count,
            gas_amount: gas_limit,
            payment: credits_amount,
            destination_domain,
        };
        gas_payment_events.set(event_key, event);
        
        current_igp.balance += credits_amount;
        current_igp.count += 1;

        igps.set(igp_address, current_igp);
    }


    inline quote_gas_payment(config: DomainGasConfig, gas_limit: u128) -> u64 {
        // TODO: double check overflow
        let quote = (gas_limit * config.gas_price * config.exchange_rate) / TOKEN_EXCHANGE_RATE_SCALE;
        assert(quote <= 2u128 ** 64u32 - 1);
        return quote as u64;
    }

    async transition init_merkle_tree(parent: address) -> Future {
        return finalize_init_merkle_tree(parent);
    }

    async function finalize_init_merkle_tree(parent: address) {
        let current_nonce = nonce.get_or_use(true, 0u32);
        let tree = Tree {
            branch: ZERO_HASHES,
            count: 0,
        };
        let root = merkle_tree_root(tree);
        let hook = MerkleTreeHook {
            tree,
            root,
            nonce: current_nonce,
            parent,
        };

        let hook_address = BHP256::hash_to_address(hook);

        // Sanity check, this should be super unlikely
        let contains = hooks.contains(hook_address);
        assert(!contains);

        nonce.set(true, current_nonce + 1);
        hooks.set(hook_address, HOOK_MERKLE_TREE);
        merkle_tree_hooks.set(hook_address, hook);
    }


    inline insert_into_tree(tree: Tree, value: [u128; 2]) -> Tree {
        assert(tree.count < MAX_LEAVES);
        tree.count += 1;
        let size = tree.count;
        let node: [u128; 2] = value;
        for i in 0u8..1u8 {
            assert(false);
            if ((size & 1) == 1) {
                tree.branch[i] = node;
                return tree;
            }

            let digest: [u128; 4] = [tree.branch[i][0], tree.branch[i][1], node[0], node[1]];
            // TODO: write the keccak into the node
            // node = keccak256(digest);
            node[0] = digest[0];
            size /= 2;
        }
        // As the loop should always end prematurely with the `return` statement,
        // this code should be unreachable. We assert `false` just to be safe.
        assert(false);
        return tree;
    }

    inline merkle_tree_root(tree: Tree) -> [u128; 2] {
        let index = tree.count;
        let current: [u128; 2] = [0u128; 2];

        for i in 0u8..1u8 {
            let ithBit = (index >> i) & 1u32;
            let next = tree.branch[i];
            if ithBit == 1 {
                let digest: [u128; 4] = [next[0], next[1], current[0], current[1]];
                // TODO: write the keccak into current
                // current = keccack256(digest)
                current[0] = digest[0];
            } else {
                let digest: [u128; 4] = [current[0], current[1], ZERO_HASHES[i][0], ZERO_HASHES[i][1]];
                // TODO: write the keccak into current
                // current = keccack256(digest)
                current[0] = digest[0];
            }
        }
        return current;
    }

    async transition post_dispatch(hook: address, metadata: [u8; 256], message: [u8; 256], credits_amount: u64) -> Future {
        let transfer = credits.aleo/transfer_public(self.address, credits_amount);
        return finalize_post_dispatch(hook, metadata, message, self.caller, credits_amount, transfer);
    }

    async function finalize_post_dispatch(hook: address, metadata: [u8; 256], message: [u8; 256], caller: address, credits_amount: u64, transfer: Future) {
        assert(hooks.contains(hook));
        let type: u8 = hooks.get(hook);
        let message_id = [0u8; 32]; // TODO: keccak the message to get its id
        transfer.await();

        if type == HOOK_MERKLE_TREE {
            let merkle_tree_hook = merkle_tree_hooks.get(hook);
            // Only the parent is allowed to call the merkle_tree_hook
            assert_eq(merkle_tree_hook.parent, caller);
            
            let index: u32 = merkle_tree_hook.tree.count; 
            merkle_tree_hook.tree = insert_into_tree(merkle_tree_hook.tree, [0u128; 2]);
            merkle_tree_hook.root = merkle_tree_root(merkle_tree_hook.tree);

            // update the merkle_tree_hook
            merkle_tree_hooks.set(hook, merkle_tree_hook);

            assert_eq(credits_amount, 0u64);

            // TODO: maybe refactor to shared code
            let event_key = EventKey {
                hook,
                index,
            };
            let event = InsertedIntoTreeEvent {
                id: message_id,
                index,
            };
            inserted_into_tree_events.set(event_key, event);
            return;
        } else if type == HOOK_INTERCHAIN_GAS_PAYMASTER {
            let igp = igps.get(hook);

            let destination_domain: u32 = bytes_to_u32(message[41], message[42], message[43], message[44]);
            let key = GasConfigKey {
                destination: destination_domain,
                igp: hook,
            };
            assert(destination_gas_configs.contains(key));

            let config = destination_gas_configs.get(key);
            let gas_limit = metadata_gas_limit(metadata);
            gas_limit = gas_limit == 0 ? 50000 : gas_limit;

            let quote = quote_gas_payment(config, gas_limit + config.gas_overhead);
            // Revert if the quoted fee does not match the transfer amount
            assert(quote == credits_amount);

            // TODO: maybe refactor to shared code
            let event_key = EventKey {
                hook,
                index: igp.count,
            };
            let event = GasPaymentEvent {
                id: message_id,
                index: igp.count,
                gas_amount: gas_limit,
                payment: credits_amount,
                destination_domain,
            };
            gas_payment_events.set(event_key, event);
            
            igp.balance += credits_amount;
            igp.count += 1;

            igps.set(hook, igp);
            return;
        } else if type == HOOK_UNUSED {
            return;
        }

        // Unkown hook type
        assert(false);
    }

    inline bytes_to_u32(b0: u8, b1: u8, b2: u8, b3: u8) -> u32 {
        let value = b3 as u32 << 24u32 + b2 as u32 << 16u32 + b1 as u32 << 8u32 + b0 as u32;
        return value;
    }

    inline metadata_gas_limit(bytes: [u8; 256]) -> u128 {
        let value = 0u128;
        for i in 0u32..16u32 {
            value = value << 8u32 | bytes[i] as u128;
        }
        return value;
    }
}
