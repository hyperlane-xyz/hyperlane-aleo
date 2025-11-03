// The 'ism_manager' program.
program ism_manager.aleo {

    mapping nonce: bool => u32;
    // Mapping for DomainRoutingIsm
    mapping domain_routing_isms: address => DomainRoutingIsm;
    // Routes for RoutingIsm
    mapping routes: IsmRouteKey => address;
    // Mapping to iterate all route entries
    mapping route_iter: RouteIndexKey => IsmRouteKey;
    // Mapping to get total amount of inserted routes for the given routing ism
    mapping route_length: address => u32;

    // Mapping for MsgIdMultisigIsms
    mapping message_id_multisigs: address => MessageIdMultisigIsm;
    // ISM Addresses
    mapping ism_addresses: u32 => address;
    // Mapping from ism address to ISM Type
    mapping isms: address => u8;

    struct Message {
        version: u8,
        nonce: u32,
        origin_domain: u32,
        sender: [u8; 32],
        destination_domain: u32,
        recipient: [u8; 32],
        body: [u128; 8],
    }

    struct EthAddress {
        bytes: [u8; 20],
    }

    struct MessageIdMultisigIsm {
        validators: [EthAddress; MAX_VALIDATORS],
        validator_count: u8,
        threshold: u8,
        nonce: u32,
    }

    struct DomainRoutingIsm {
        ism_owner: address,
        nonce: u32,
    }

    struct NoopIsm {
        nonce: u32,
    }

    struct IsmRouteKey {
        ism: address,
        domain: u32,
    }

    struct RouteIndexKey {
        ism: address,
        index: u32,
    }

    const ORIGIN_MERKLE_TREE_OFFSET: u8 = 0;
    const MERKLE_ROOT_OFFSET: u8 = 32;
    const MERKLE_INDEX_OFFSET: u8 = 64;
    const SIGNATURES_OFFSET: u8 = 68;
    const SIGNATURE_LENGTH: u8 = 65;

    const ISM_UNUSED: u8 = 0;
    const ISM_ROUTING: u8 = 1;
    const ISM_MERKLE_ROOT_MULTISIG: u8 = 4;
    const ISM_MESSAGE_ID_MULTISIG: u8 = 5;

    const MAX_VALIDATORS: u8 = 6;
    const METADATA_LENGTH: u32 = 512;

    @noupgrade
    async constructor() {}

    async transition init_noop() -> Future {
        return finalize_noop();
    }

    async function finalize_noop() {
        let current_nonce = nonce.get_or_use(true, 0u32);

        let ism = NoopIsm {
            nonce: current_nonce,
        };

        let ism_address = BHP256::hash_to_address(ism);

        // Sanity check, this should be super unlikely
        let contains = isms.contains(ism_address);
        assert(!contains);

        nonce.set(true, current_nonce + 1);
        isms.set(ism_address, ISM_UNUSED);
        ism_addresses.set(current_nonce, ism_address);
    }

    async transition init_message_id_multisig(validators: [EthAddress; MAX_VALIDATORS], validator_count: u8, threshold: u8) -> Future {
        return finalize_msg_id_multisig(validators, validator_count, threshold);
    }

    async function finalize_msg_id_multisig(validators: [EthAddress; MAX_VALIDATORS], validator_count: u8, threshold: u8) {
        assert(threshold > 0);
        assert(threshold <= MAX_VALIDATORS);
        assert(validator_count <= MAX_VALIDATORS);

        let current_nonce = nonce.get_or_use(true, 0u32);

        let ism = MessageIdMultisigIsm {
            validators,
            validator_count,
            threshold,
            nonce: current_nonce,
        };

        let ism_address = BHP256::hash_to_address(ism);

        // Sanity check, this should be super unlikely
        let contains = message_id_multisigs.contains(ism_address);
        assert(!contains);
        message_id_multisigs.set(ism_address, ism);
        nonce.set(true, current_nonce + 1);
        isms.set(ism_address, ISM_MESSAGE_ID_MULTISIG);
        ism_addresses.set(current_nonce, ism_address);
    }

    async transition init_domain_routing() -> Future {
        let owner_address: address = self.caller;
        return finalize_domain_routing(owner_address);
    }

    async function finalize_domain_routing(owner_address: address) {
        let current_nonce = nonce.get_or_use(true, 0u32);

        let ism = DomainRoutingIsm {
            ism_owner: owner_address,
            nonce: current_nonce,
        };

        let ism_address = BHP256::hash_to_address(ism);

        // Sanity check, this should be super unlikely
        let contains = domain_routing_isms.contains(ism_address);
        assert(!contains);

        domain_routing_isms.set(ism_address, ism);
        nonce.set(true, current_nonce + 1);
        isms.set(ism_address, ISM_ROUTING);
        ism_addresses.set(current_nonce, ism_address);
    }

    async transition set_domain(ism: address, domain: u32, module: address) -> Future {
        return finalize_set_domain(ism, domain, module, self.caller);
    }

    async function finalize_set_domain(ism: address, domain: u32, module: address, caller: address) {
        assert(domain_routing_isms.contains(ism));

        let routing_ism: DomainRoutingIsm = domain_routing_isms.get(ism);

        assert_eq(routing_ism.ism_owner, caller);

        let key: IsmRouteKey = IsmRouteKey {
            ism,
            domain,
        };

        if !routes.contains(key) {
            let current_length = route_length.get_or_use(ism, 0u32);
            route_iter.set(RouteIndexKey { ism, index: current_length }, key);
            route_length.set(ism, current_length + 1);
        }

        routes.set(key, module);
    }

    async transition remove_domain(ism: address, domain: u32) -> Future {
        return finalize_remove_domain(ism, domain, self.caller);
    }

    async function finalize_remove_domain(ism: address, domain: u32, caller: address) {
        assert(domain_routing_isms.contains(ism));

        let routing_ism: DomainRoutingIsm = domain_routing_isms.get(ism);

        assert_eq(routing_ism.ism_owner, caller);
        let key: IsmRouteKey = IsmRouteKey {
            ism,
            domain,
        };

        routes.remove(key);
    }

    async transition transfer_routing_ism_ownership(ism: address, new_owner: address) -> Future {
        let caller = self.caller;
        return async {
            assert(domain_routing_isms.contains(ism));
            let routing_ism: DomainRoutingIsm = domain_routing_isms.get(ism);

            assert_eq(routing_ism.ism_owner, caller);
            routing_ism.ism_owner = new_owner;
            domain_routing_isms.set(ism, routing_ism);
        };
    }

    /// Verifies the message validity by using the given ism
    /// This method assumes that the caller makes sure that the passed message_id belongs to the passed message
    async transition verify(public ism: address, public message: Message, public message_id: [u128; 2], public metadata: [u8; METADATA_LENGTH]) -> Future {
        return finalize_verify(ism, message, message_id, metadata);
    }

    async function finalize_verify(ism: address, message: Message, message_id: [u128; 2], metadata: [u8; METADATA_LENGTH]) {
        // We have a max depth of 4 for recursive routing isms
        // Local variable for re-assignment
        let ism_address: address = ism;

        // Calculate signatures and digest outside of the loop
        // This reduces the amount of code that gets generated
        let signatures = parse_signatures(metadata);
        let digest = get_message_id_digest(
            message.origin_domain,
            metadata,
            message_id,
        );
        let ism_type: u8 = isms.get(ism);
        for i: u8 in 0u8..4u8 {
            assert(isms.contains(ism_address));
            if ism_type == ISM_MESSAGE_ID_MULTISIG {
                // MessageIdIsm logic
                let multisig = message_id_multisigs.get(ism_address);
                let validators = multisig.validators;
                let valid_signatures = 0u8;

                // We assume that the signatures are passed in the same order as the validators.
                for index in 0u8..MAX_VALIDATORS {
                    let valid = ECDSA::verify_digest_eth(signatures[index], validators[index].bytes, digest);
                    // TODO: we should check following: signature_index < multisig.validator_count && validator_index < multisig.validator_count
                    // However, it is equally likely to generate a malicious signature for the null-address as it is for every other address
                    // We therefore don't test for this cases, as aleo will have to go through every statement anyways and this would add extra complexity
                    valid_signatures += valid ? 1 : 0;
                }
                assert(valid_signatures >= multisig.threshold);
            } else if ism_type == ISM_UNUSED || ism_type == ISM_ROUTING {
                // NoopIsm and RoutingISM continue and do nothing
            } else {
                // unknown ism
                assert(false);
            }
            // We have to execute the RoutingISM logic in the inner loop
            // Otherwise the compiler complains that an outer variable, here the `ism_address`, is not assigned on every iteration
            let key = IsmRouteKey {
                ism: ism_address,
                domain: message.origin_domain,
            };

            // This logic here will be executed for every ISM type, there is no way around this as Aleo forbids branching
            // This means the `routes.get(key)` function will be executed for every ism type and will fail for non-routing isms.
            // We bypass this by using `get_or_use`
            ism_address = routes.get_or_use(key, ism_address);
            ism_type = isms.get(ism_address);
        }

        // When the ism_type is still the RoutingISM after iterating over the loop
        // it means that we've encounter recursion
        if ism_type == ISM_ROUTING {
            assert(false);
        }
    }

    inline get_message_id_digest(origin_domain: u32, metadata: [u8; METADATA_LENGTH], message_id: [u128; 2]) -> [u8; 32] {
        let merkle_tree_hook = origin_merkle_tree_hook(metadata);
        let hash = domain_hash(origin_domain, merkle_tree_hook);
        let id_bytes = message_id_bytes(message_id);
        let msg: [u8; 100] = [0u8; 100];
        
        // domain hash (32 bytes)
        for i in 0u8..32u8 {
            msg[i] = hash[i];
        }
        
        // checkpoint root (32 bytes)
        for i in 0u8..32u8 {
            msg[32u8 + i] = metadata[MERKLE_ROOT_OFFSET + i];
        }
        
        // merkle index (4 bytes)
        for i in 0u8..4u8 {
            msg[64u8 + i] = metadata[MERKLE_INDEX_OFFSET + i];
        }
        
        // message id (32 bytes)
        for i in 0u8..32u8 {
            msg[68u8 + i] = id_bytes[i];
        }

        let checkpoint_bits = Keccak256::hash_native_raw(msg);
        let checkpoint = Deserialize::from_bits_raw::[[u8; 32]](checkpoint_bits);

        return to_eth_signed_message_hash(checkpoint);
    }

    inline origin_merkle_tree_hook(metadata: [u8; METADATA_LENGTH]) -> [u8; 32] {
        let merkle_tree_hook: [u8; 32] = [0u8; 32];
        for i: u8 in 0u8..32u8 {
            merkle_tree_hook[i] = metadata[i + ORIGIN_MERKLE_TREE_OFFSET];
        }
        return merkle_tree_hook;
    }

    inline domain_hash(origin: u32, merkle_tree_hook: [u8; 32]) -> [u8; 32] {
        let b3: u8 = (origin >> 24u32) as u8;
        let b2: u8 = ((origin >> 16u32) % 256u32) as u8;
        let b1: u8 = ((origin >> 8u32) % 256u32) as u8;
        let b0: u8 = (origin % 256u32) as u8;
        let msg: [u8; 45] = [0u8; 45];
        
        // Set origin bytes (BE encoded)
        msg[0] = b3;
        msg[1] = b2;
        msg[2] = b1;
        msg[3] = b0;
        
        // Copy merkle_tree_hook (32 bytes)
        for i in 0u8..32u8 {
            msg[4u8 + i] = merkle_tree_hook[i];
        }
        
        // Set 'HYPERLANE' string
        msg[36] = 72u8;  // H
        msg[37] = 89u8;  // Y
        msg[38] = 80u8;  // P
        msg[39] = 69u8;  // E
        msg[40] = 82u8;  // R
        msg[41] = 76u8;  // L
        msg[42] = 65u8;  // A
        msg[43] = 78u8;  // N
        msg[44] = 69u8;  // E

        let hash = Keccak256::hash_native_raw(msg);
        return Deserialize::from_bits_raw::[[u8; 32]](hash);
    }

    inline to_eth_signed_message_hash(hash: [u8; 32]) -> [u8; 32] {
        let digest: [u8; 60] = [0u8; 60];
        
        // Ethereum Signed Message prefix: "\x19Ethereum Signed Message:\n32"
        digest[0] = 25u8;   // \x19
        digest[1] = 69u8;   // E
        digest[2] = 116u8;  // t
        digest[3] = 104u8;  // h
        digest[4] = 101u8;  // e
        digest[5] = 114u8;  // r
        digest[6] = 101u8;  // e
        digest[7] = 117u8;  // u
        digest[8] = 109u8;  // m
        digest[9] = 32u8;   // (space)
        digest[10] = 83u8;  // S
        digest[11] = 105u8; // i
        digest[12] = 103u8; // g
        digest[13] = 110u8; // n
        digest[14] = 101u8; // e
        digest[15] = 100u8; // d
        digest[16] = 32u8;  // (space)
        digest[17] = 77u8;  // M
        digest[18] = 101u8; // e
        digest[19] = 115u8; // s
        digest[20] = 115u8; // s
        digest[21] = 97u8;  // a
        digest[22] = 103u8; // g
        digest[23] = 101u8; // e
        digest[24] = 58u8;  // :
        digest[25] = 10u8;  // \n
        digest[26] = 51u8;  // '3'
        digest[27] = 50u8;  // '2'
        
        // Copy hash bytes (32 bytes)
        for i in 0u8..32u8 {
            digest[28u8 + i] = hash[i];
        }

        let hash_bits = Keccak256::hash_native_raw(digest);
        return Deserialize::from_bits_raw::[[u8; 32]](hash_bits);
    }

    inline parse_signatures(metadata: [u8; METADATA_LENGTH]) -> [[u8; SIGNATURE_LENGTH]; MAX_VALIDATORS] {
        let signatures = [[0u8; SIGNATURE_LENGTH]; MAX_VALIDATORS];
        for j in 0u8..MAX_VALIDATORS {
            for i in 0u8..SIGNATURE_LENGTH {
                signatures[j][i] = metadata[i as u32 + SIGNATURES_OFFSET as u32 + j as u32 * SIGNATURE_LENGTH as u32];
            }
        }
        return signatures;
    }

    inline message_id_bytes(message_id: [u128; 2]) -> [u8; 32] {
        let left = Serialize::to_bits_raw(message_id[0]);
        let right = Serialize::to_bits_raw(message_id[1]);
        let bits = [false; 256];
        for i in 0u8..128u8 {
            bits[i] = left[i];
            bits[i + 128] = right[i];
        }
        return Deserialize::from_bits_raw::[[u8; 32]](bits);
    }
}
