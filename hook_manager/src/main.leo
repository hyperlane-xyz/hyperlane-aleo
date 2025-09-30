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
    const ZERO_HASHES: [[u128; 2]; TREE_DEPTH] = [
        [0u128, 0u128], // z_0
        [230216883866445747098778635897249722774u128,   57441823781995671911818760868895285173u128],    // z_1
        [240263666058967033894958457452758479430u128,   86393468519143739268242962569331019056u128],    // z_2
        [45015786653377684003472046733104897841u128,    48764649700049312998987031904754580101u128],    // z_3
        [305096314958529531009455294039330478605u128,   42153110473729902431466573830635492164u128],    // z_4
        [19523659855451289700171858603246300447u128,    12065855842882473784776283360841551661u128],    // z_5
        [181419556855134304686613769130340192301u128,   229777064902468756916291338405768993128u128],   // z_6
        [340069509995716074834042958469547385858u128,   68784393344990428128398620118293507971u128],    // z_7
        [202581607113306211134148399648487797796u128,   92810053901478079072919448164937193135u128],    // z_8
        [275123359363120281706367072075081405947u128,   3627274865724835303191243546657051872u128],     // z_9
        [332121343900046078017596319938297505236u128,   337920470342672549726723327079617774501u128],   // z_10
        [330568761732134610766982541692778682221u128,   23019973894522867208781202044190783634u128],    // z_11
        [69871578839360086321259286572835216656u128,    265633931325731835151316570974477212060u128],   // z_12
        [257701539352583822781831662927235822803u128,   113383749465262743773318579614806827707u128],   // z_13
        [122827308141081102393538332704478663898u128,   14371799865847963281189365382191300300u128],    // z_14
        [290414546392669579637104672936971308252u128,   162668979068810670326181334132301637330u128],   // z_15
        [52109344861130342596934364761173086450u128,    80844020991667477318170434866325198879u128],    // z_16
        [300175560652909881101476631815797930331u128,   205856524315200396356139391598026354554u128],   // z_17
        [119868351990799432709852159310402124844u128,   62119584296380258005357245911933417888u128],    // z_18
        [239812248500126165432064057592738451005u128,   24070851719214097997751638317560195744u128],    // z_19
        [263678266929334348738951521654163430908u128,   254269339963940458010335475455228950498u128],   // z_20
        [324671838676244411098953723196242470641u128,   187642818603058616552642693286412345305u128],   // z_21
        [120440981574040734373233765310720793803u128,   113516290307314216600717830194298545015u128],   // z_22
        [103639852731181762358106724617207888295u128,   258666751358695450330329364973734520402u128],   // z_23
        [273525768541442991319824899635506787428u128,   186774990005974790598944806840565111279u128],   // z_24
        [14285850035650323843098036768689986676u128,    325703198119112477941740905352232198541u128],   // z_25
        [245644725191497703162774001046429699940u128,   58613374412410289254184334038219524048u128],    // z_26
        [174857540092504873303004538516572042719u128,   325111600128255124267684912995967812638u128],   // z_27
        [135824743138555157890880117566796645380u128,   157398571249734860871609464780247395118u128],   // z_28
        [75156916120127781196251038633653571224u128,    322234176658075210364568501930492338978u128],   // z_29
        [195580767185181987638058274516641464640u128,   15782258419547975757522536621813389109u128],    // z_30
        [175834568316894845881863876332699260640u128,   252669670357648618037915900175129269929u128]    // z_31
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
            let hash = Keccak256::hash_native_raw(digest);
            node = Deserialize::from_bits_raw::[[u128; 2]](hash);
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
                let hash = Keccak256::hash_native_raw(digest);
                current = Deserialize::from_bits_raw::[[u128; 2]](hash);
            } else {
                let digest: [u128; 4] = [current[0], current[1], ZERO_HASHES[i][0], ZERO_HASHES[i][1]];
                // TODO: write the keccak into current
                let hash = Keccak256::hash_native_raw(digest);
                current = Deserialize::from_bits_raw::[[u128; 2]](hash);
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
