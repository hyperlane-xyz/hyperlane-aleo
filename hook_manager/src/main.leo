import mailbox.aleo;
import credits.aleo;

// The 'hook_manager' program.
program hook_manager.aleo {
    
    mapping nonce: bool => u32;
    // Mapping for IGPs
    mapping igps: address => InterchainGasPaymaster;
    // DestinationGasConfigs
    mapping destination_gas_configs: GasConfigKey => DomainGasConfig;
    // Mapping for MerkleTreeHook
    mapping merkle_tree_hooks: address => MerkleTreeHook;
    // Mapping from hook address to Hook Type
    mapping hooks: address => u8;
    // Mapping to find hook addresses
    mapping hook_addresses: u32 => address;
    // Events
    // GasPayment Events: sequence => Event
    mapping gas_payment_events: EventKey => GasPaymentEvent;
    // InsertedIntoTree Events: sequence => Event
    mapping inserted_into_tree_events: EventKey => InsertedIntoTreeEvent;
    // Mapping to get the last event index for a given block_height
    // We need this to be able to query events by block height
    mapping last_event_index: EventIndexKey => u32;

    struct Message {
        version: u8,
        nonce: u32,
        origin_domain: u32,
        sender: [u8; 32],
        destination_domain: u32,
        recipient: [u8; 32],
        body: [u128; 8],
    }

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
        id: [u128; 2],
        index: u32,
    }

    struct GasConfigKey {
        igp: address,
        destination: u32,
    }

    struct DomainGasConfig {
        gas_overhead: u128,
        exchange_rate: u128,
        gas_price: u128,
    }

    struct GasPaymentEvent {
        id: [u128; 2],
        destination_domain: u32,
        gas_amount: u128,
        payment: u64,
        index: u32,
    }

    struct EventKey {
        hook: address,
        index: u32,
    }

    struct EventIndexKey {
        hook: address,
        block_height: u32,
    }

    struct CreditAllowance {
        spender: address,
        amount: u64,
    }

    const HOOK_UNUSED: u8 = 0;
    const HOOK_MERKLE_TREE: u8 = 3;
    const HOOK_INTERCHAIN_GAS_PAYMASTER: u8 = 4;
    const HOOK_PAUSABLE: u8 = 7;

    const TREE_DEPTH: u32 = 32;
    const MAX_LEAVES: u32 = 4294967295u32; // 2**32-1
    const DEFAULT_GAS_LIMIT: u128 = 50000;

    // Merkle root with empty leafs
    const ZERO_ROOT: [u128; 2] = [96697620089336775378094670865426525735u128, 116761479129358376777137895554163725990u128];
    // keccak256 zero hashes
    const ZERO_HASHES: [[u128; 2]; TREE_DEPTH] = [
        [0u128,0u128],
        [200636014418684474793900124069647889069u128,241087320001230136080519585693436229163u128],
        [93974531276030024843854739648391266740u128,63871773629875849864439396521971482176u128],
        [66294067272630431583104841350689447201u128,177756802695730322470865725932422475556u128],
        [17747458619593854979588589471465572325u128,91154039873745303917061774773470934559u128],
        [41440521891025744745128838831940743182u128,60894629520669430433793374864326529801u128],
        [59903522946444936989019680377850199176u128,138372656349779401676123096700574490028u128],
        [3180262733561280138502805056821254143u128,174708888174609290132996609679840034611u128],
        [48455171203811811641967620231072081816u128,233066451124647651551022141310218850885u128],
        [334080689485914854275740245880500189902u128,298184847794429370937316245747346618882u128],
        [282653557140816677488147447345498217721u128,220339046210024952190566302967731665406u128],
        [145672768088204442335147548738764583416u128,195359773238112912523174698163665391889u128],
        [21418297075731751014499913670238572596u128,208490304233564026108050214927462029255u128],
        [281404733672930043025800266103516225473u128,249742050973351594617409037165098847317u128],
        [289879148739902069907218623618383439708u128,272153760179965878774948581978868862730u128],
        [293159551140992943817529578958841871322u128,279338235662809517033392482105447374970u128],
        [322093384055859711002317835595919209255u128,42000488150413793222910142038008516924u128],
        [122254499464535460357349615889605317601u128,163409875357997099341612933566874181274u128],
        [59132542617709958082991564676137889114u128,213307109849065044721731388145721391918u128],
        [81821347195604723027123097456320473780u128,213231151757453664031032733501577239314u128],
        [336114429845119848727407931190249152198u128,301360598096960973755532425519001651903u128],
        [320542506166910886628941017057425965556u128,289604304606881051317113816162407361165u128],
        [270315001578019215236444169667452771418u128,159359836010757059645879798671718049365u128],
        [222279943939488608983982977534856788045u128,110191212380795297761298100413926971842u128],
        [133196525511722763539122868050171643853u128,317818349342580659794271157815744496524u128],
        [155004929552231825612177418997554921226u128,187928388822560161625857840976354543861u128],
        [133005247855215888074055167590444355000u128,277185228623223348062409148812927309868u128],
        [297025694464961376815096585744545123459u128,40897156374938635533147054173498873588u128],
        [6336040213458809633392154838101667430u128,62367222880804479430297662353502398838u128],
        [202117996738898010692652600915964103224u128,46042986625269866222220954975551057138u128],
        [85413120008009180910770793363078390675u128,71567477878241302074513460496530530059u128],
        [297864792032486788802704391190316402820u128,225086078672275754295496924647458870974u128]
    ];

    const TOKEN_EXCHANGE_RATE_SCALE: u128 = 10000000000u128; // 1e10

    @noupgrade
    async constructor() {}

    async transition init_noop() -> Future {
        return finalize_noop();
    }

    async function finalize_noop() {
        let current_nonce = nonce.get_or_use(true, 0u32);

        let hook = NoopHook {
            nonce: current_nonce,
        };

        let hook_address = BHP256::hash_to_address(hook);

        // Sanity check, this should be super unlikely
        let contains = hooks.contains(hook_address);
        assert(!contains);

        hook_addresses.set(current_nonce, hook_address);
        nonce.set(true, current_nonce + 1);
        hooks.set(hook_address, HOOK_UNUSED);
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

        hook_addresses.set(current_nonce, hook_address);
        nonce.set(true, current_nonce + 1);
        hooks.set(hook_address, HOOK_INTERCHAIN_GAS_PAYMASTER);
        igps.set(hook_address, hook);
    }

    async transition set_destination_gas_config(public igp: address, public destination_domain: u32, public config: DomainGasConfig) -> public Future {
        return finalize_set_gas_config(igp, destination_domain, config, self.caller);
    }

    async function finalize_set_gas_config(igp_address: address, destination_domain: u32, config: DomainGasConfig, caller: address) {
        assert(igps.contains(igp_address));

        let igp = igps.get(igp_address);
        assert_eq(igp.hook_owner, caller);

        let key = GasConfigKey {
            igp: igp_address,
            destination: destination_domain,
        };
        destination_gas_configs.set(key, config);
    }

    async transition remove_destination_gas_config(public igp: address, public destination_domain: u32) -> public Future {
        return finalize_remove_gas_config(igp, destination_domain, self.caller);
    }

    async function finalize_remove_gas_config(igp_address: address, destination_domain: u32, caller: address) {
        assert(igps.contains(igp_address));

        let igp = igps.get(igp_address);
        assert_eq(igp.hook_owner, caller);

        let key = GasConfigKey {
            igp: igp_address,
            destination: destination_domain,
        };
        destination_gas_configs.remove(key);
    }

    async transition claim(igp: address, amount: u64) -> Future {
        // transfer credits to the caller
        let transfer = credits.aleo/transfer_public(self.caller, amount);
        return finalize_claim(igp, self.caller, amount, transfer);
    }

    async function finalize_claim(igp_address: address, owner: address, amount: u64, transfer: Future) {
        assert(igps.contains(igp_address));

        let igp = igps.get(igp_address);
        // Assert that the caller is the hook owner and the IGP has enough balance
        assert_eq(igp.hook_owner, owner);
        assert(igp.balance >= amount);

        transfer.await();
        igp.balance -= amount;

        igps.set(igp_address, igp);
    }

    async transition pay_for_gas(igp: address, message_id: [u128; 2], destination_domain: u32, gas_limit: u128, credits_amount: u64) -> Future {
        let transfer: Future = credits.aleo/transfer_public_as_signer(self.address, credits_amount);
        return finalize_pay_for_gas(igp, message_id, destination_domain, gas_limit, credits_amount, transfer);
    }

    async function finalize_pay_for_gas(igp_address: address, message_id: [u128; 2], destination_domain: u32, gas_limit: u128, credits_amount: u64, transfer: Future) {
        let key = GasConfigKey {
            igp: igp_address,
            destination: destination_domain,
        };
        assert(destination_gas_configs.contains(key));

        let config = destination_gas_configs.get(key);
        let quote = quote_gas_payment(config, gas_limit);

        // Revert if the quoted fee does not match the transfer amount
        assert_eq(quote, credits_amount);
        transfer.await();

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
        
        let event_index_key = EventIndexKey {
            hook: igp_address,
            block_height: block.height,
        };
        last_event_index.set(event_index_key, current_igp.count);

        current_igp.balance += credits_amount;
        current_igp.count += 1;

        igps.set(igp_address, current_igp);
    }

    inline quote_gas_payment(config: DomainGasConfig, gas_limit: u128) -> u64 {
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
        let hook = MerkleTreeHook {
            tree,
            root: ZERO_ROOT,
            nonce: current_nonce,
            parent,
        };

        let hook_address = BHP256::hash_to_address(hook);
        // Sanity check, this should be super unlikely
        let contains = hooks.contains(hook_address);
        assert(!contains);

        hook_addresses.set(current_nonce, hook_address);
        nonce.set(true, current_nonce + 1);
        hooks.set(hook_address, HOOK_MERKLE_TREE);
        merkle_tree_hooks.set(hook_address, hook);
    }

    /// Inserts a new value into the merkle tree
    inline insert_into_tree(tree: Tree, value: [u128; 2]) -> Tree {
        assert(tree.count < MAX_LEAVES);
        tree.count += 1;
        let index = tree.count;
        let node: [u128; 2] = value;
        let inserted = false;
        for i in 0u32..TREE_DEPTH {
            if ((index & 1) > 0 && !inserted) {
                tree.branch[i] = node;
                inserted = true;
            } else {
                let branch = tree.branch[i];
                let digest: [u128; 4] = [branch[0], branch[1], node[0], node[1]];
                let hash = Keccak256::hash_native_raw(digest);
                node = Deserialize::from_bits_raw::[[u128; 2]](hash);
                index /= 2;
            }
        }
        return tree;
    }

    /// Computes the merkle root from the current tree
    inline merkle_tree_root(tree: Tree) -> [u128; 2] {
        let index = tree.count;
        let current: [u128; 2] = [0u128; 2];

        for i in 0u32..TREE_DEPTH {
            let ithBit = (index >> i) & 1u32;
            if ithBit == 1 {
                let next = tree.branch[i];
                let digest: [u128; 4] = [next[0], next[1], current[0], current[1]];
                let hash = Keccak256::hash_native_raw(digest);
                current = Deserialize::from_bits_raw::[[u128; 2]](hash);
            } else {
                let digest: [u128; 4] = [current[0], current[1], ZERO_HASHES[i][0], ZERO_HASHES[i][1]];
                let hash = Keccak256::hash_native_raw(digest);
                current = Deserialize::from_bits_raw::[[u128; 2]](hash);
            }
        }
        return current;
    }

    
    /// Post Dispatch
    /// Fetches the latest message from the mailbox and perfroms the post_dispatch function on that.
    /// - hook_allowance: mapping from hook_address -> allowed credits to spend. This is used to correctly initialize credit transfers in the `post_dispatch` hooks
    async transition post_dispatch(public hook: address, public metadata: [u8; 256], public hook_allowance: [CreditAllowance; 4]) -> Future {
        // find the allowance for the given hook, default to 0
        let credits_amount = 0u64;
        for i in 0u8..4u8 {
            let allowance = hook_allowance[i];
            if allowance.spender == hook {
                credits_amount = allowance.amount;
            }
        }

        let transfer = credits.aleo/transfer_public_as_signer(self.address, credits_amount);
        return finalize_post_dispatch(hook, metadata, self.caller, credits_amount, transfer);
    }

    async function finalize_post_dispatch(hook: address, metadata: [u8; 256], caller: address, credits_amount: u64, transfer: Future) {
        assert(hooks.contains(hook));
        let type: u8 = hooks.get(hook);
        transfer.await();

        // This gets the latest dispatched message from the mailbox
        let mailbox = Mapping::get(mailbox.aleo/mailbox, true);
        assert(mailbox.nonce > 0);
        let message = Mapping::get(mailbox.aleo/dispatch_events, mailbox.nonce - 1);
        let message_id = Mapping::get(mailbox.aleo/dispatch_id_events, mailbox.nonce - 1);

        // Event index key for last_event_index mapping
        let event_index_key = EventIndexKey {
            hook,
            block_height: block.height,
        };

        if type == HOOK_MERKLE_TREE {
            let merkle_tree_hook = merkle_tree_hooks.get(hook);
            // Only the parent is allowed to call the merkle_tree_hook
            // We assume that the parent calls the merkle tree hook & dispatch function of the mailbox in the correct order
            // This means the parent has to make sure, that the merkle tree hook won't get invoked twice for the same message
            // In pratice the parent is usually the dispatch_proxy
            assert_eq(merkle_tree_hook.parent, caller);
            
            let index: u32 = merkle_tree_hook.tree.count;
            merkle_tree_hook.tree = insert_into_tree(merkle_tree_hook.tree, message_id);
            merkle_tree_hook.root = merkle_tree_root(merkle_tree_hook.tree);

            // update the merkle_tree_hook
            merkle_tree_hooks.set(hook, merkle_tree_hook);
            // the merkle tree hook expects no payment
            assert_eq(credits_amount, 0u64);

            let event_key = EventKey {
                hook,
                index,
            };
            let event = InsertedIntoTreeEvent {
                id: message_id,
                index,
            };
            inserted_into_tree_events.set(event_key, event);
            last_event_index.set(event_index_key, index);

        } else if type == HOOK_INTERCHAIN_GAS_PAYMASTER {
            let igp = igps.get(hook);

            let key = GasConfigKey {
                destination: message.destination_domain,
                igp: hook,
            };
            
            // If the config does not exist, we default to a zero quote
            let config = destination_gas_configs.get_or_use(key, DomainGasConfig {
                gas_overhead: 0u128,
                exchange_rate: 0u128,
                gas_price: 0u128,
            });

            let gas_limit = metadata_gas_limit(metadata);
            gas_limit = gas_limit == 0 ? DEFAULT_GAS_LIMIT : gas_limit;
            let destination_gas_limit = gas_limit + config.gas_overhead;

            let quote = quote_gas_payment(config, destination_gas_limit);
            // Revert if the quoted fee does not match the transfer amount
            assert_eq(quote, credits_amount);

            let event_key = EventKey {
                hook,
                index: igp.count,
            };
            let event = GasPaymentEvent {
                id: message_id,
                index: igp.count,
                gas_amount: destination_gas_limit,
                payment: quote,
                destination_domain: message.destination_domain,
            };
            gas_payment_events.set(event_key, event);
            last_event_index.set(event_index_key, igp.count);
            
            igp.balance += credits_amount;
            igp.count += 1;

            igps.set(hook, igp);
        } else if type == HOOK_UNUSED {
            assert_eq(credits_amount, 0u64);
            // Do nothing ...
        } else {
            // Unknown hook type
            assert(false);
        }
    }

    /// Extracts the gas limit from the metadata bytes
    /// The gas limit is stored in the first 16 bytes of the metadata as a big-endian u128
    inline metadata_gas_limit(bytes: [u8; 256]) -> u128 {
        let value = 0u128;
        for i in 0u32..16u32 {
            value = value << 8u32 | bytes[i] as u128;
        }
        return value;
    }
}
