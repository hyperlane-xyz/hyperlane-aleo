// The 'ism_manager' program.
program ism_manager.aleo {

    mapping nonce: bool => u32;
    // Mapping for DomainRoutingIsm
    mapping domain_routing_isms: address => DomainRoutingIsm;
    // Mapping for MsgIdMultisigIsms
    mapping message_id_multisigs: address => MessageIdMultisigIsm;
    // ISM Addresses
    mapping ism_addresses: u32 => address;
    // Routes for RoutingIsm
    mapping routes: IsmRouteKey => address;
    // Mapping from ism address to ISM Type
    mapping isms: address => u8;

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
    const MESSAGE_LENGTH: u32 = 256;
    const MESSAGE_BODY_LENGTH: u8 = 179; // Message has 77Bytes without the body: 256 - 77 = 179

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

        routes.set(key, module);
    }

    /// Verifies the message validity by using the given ism
    /// This method assumes that the caller makes sure that the passed message_id belongs to the passed message
    async transition verify(ism: address, message: [u8; MESSAGE_LENGTH], message_id: [u128; 2], metadata: [u8; METADATA_LENGTH]) -> Future {
        return finalize_verify(ism, message, message_id, metadata);
    }

    async function finalize_verify(ism: address, raw_message: [u8; MESSAGE_LENGTH], message_id: [u128; 2], metadata: [u8; METADATA_LENGTH]) {
        // We have a max depth of 4 for recursive routing isms
        let origin_domain_id = message_origin_domain_id(raw_message);
        let ism_address: address = ism;

        // Calculate signatures and digest outside of the loop
        // This reduces the amount of code that gets generated
        let signatures = parse_signatures(metadata);
        let digest = get_message_id_digest(
            origin_domain_id,
            metadata,
            message_id,
        );

        for i: u8 in 0u8..4u8 {
            assert(isms.contains(ism));
            let ism_type: u8 = isms.get(ism);
            if ism_type == ISM_MESSAGE_ID_MULTISIG {
                // MessageIdIsm logic
                let multisig = message_id_multisigs.get(ism_address);
                let validators = multisig.validators;
                let valid_signatures = 0u8;

                // We assume that the signatures are passed in the same order as the validators.
                for index in 0u8..MAX_VALIDATORS {
                    let valid = ECDSA::verify_digest_eth(signatures[index], validators[index].bytes, digest);
                    // TODO: we should check following: signature_index < multisig.validator_count && validator_index < multisig.validator_count
                    // However, it is equally likely to generate a malicous signature for the null-address as it is for every other address
                    // We therefore don't test for this cases, as aleo will have to go through every statement anyways and this would add extra complexity
                    valid_signatures += valid ? 1 : 0;
                }
                assert(valid_signatures >= multisig.threshold);
            } else if ism_type == ISM_UNUSED || ism_type == ISM_ROUTING {
                // NoopIsm and RoutingISM continue and do nothing
            } else {
                // unkown ism
                assert(false);
            }

            // We have to execute the RoutingISM logic in the inner loop
            // Otherwise the compiler complains that an outer variable, here the `ism_address`, is not assigned on every iteration
            let key = IsmRouteKey {
                ism: ism_address,
                domain: origin_domain_id,
            };

            // This logic here will be executed for every ISM type, there is no way around this as Aleo forbids branching
            // This means the `routes.get(key)` function will be executed for every ism type and will fail for non-routing isms.
            // We bypass this by using `get_or_use`
            ism_address = routes.get_or_use(key, ism_address);
        }
    }

    inline get_message_id_digest(origin_domain: u32, metadata: [u8; METADATA_LENGTH], message_id: [u128; 2]) -> [u8; 32] {
        // TODO: calculate digest in a better way
        let merkle_tree_hook = origin_merkle_tree_hook(metadata);
        let hash = domain_hash(origin_domain, merkle_tree_hook);
        let id_bytes = message_id_bytes(message_id);
        let msg: [u8; 100] = [
            // domain hash
            hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15],
            hash[16], hash[17], hash[18], hash[19], hash[20], hash[21], hash[22], hash[23],
            hash[24], hash[25], hash[26], hash[27], hash[28], hash[29], hash[30], hash[31],
            
            // checkpoint root
            metadata[MERKLE_ROOT_OFFSET], metadata[MERKLE_ROOT_OFFSET + 1], metadata[MERKLE_ROOT_OFFSET + 2], metadata[MERKLE_ROOT_OFFSET + 3],
            metadata[MERKLE_ROOT_OFFSET + 4], metadata[MERKLE_ROOT_OFFSET + 5], metadata[MERKLE_ROOT_OFFSET + 6], metadata[MERKLE_ROOT_OFFSET + 7],
            metadata[MERKLE_ROOT_OFFSET + 8], metadata[MERKLE_ROOT_OFFSET + 9], metadata[MERKLE_ROOT_OFFSET + 10], metadata[MERKLE_ROOT_OFFSET + 11],
            metadata[MERKLE_ROOT_OFFSET + 12], metadata[MERKLE_ROOT_OFFSET + 13], metadata[MERKLE_ROOT_OFFSET + 14], metadata[MERKLE_ROOT_OFFSET + 15],
            metadata[MERKLE_ROOT_OFFSET + 16], metadata[MERKLE_ROOT_OFFSET + 17], metadata[MERKLE_ROOT_OFFSET + 18], metadata[MERKLE_ROOT_OFFSET + 19],
            metadata[MERKLE_ROOT_OFFSET + 20], metadata[MERKLE_ROOT_OFFSET + 21], metadata[MERKLE_ROOT_OFFSET + 22], metadata[MERKLE_ROOT_OFFSET + 23],
            metadata[MERKLE_ROOT_OFFSET + 24], metadata[MERKLE_ROOT_OFFSET + 25], metadata[MERKLE_ROOT_OFFSET + 26], metadata[MERKLE_ROOT_OFFSET + 27],
            metadata[MERKLE_ROOT_OFFSET + 28], metadata[MERKLE_ROOT_OFFSET + 29], metadata[MERKLE_ROOT_OFFSET + 30], metadata[MERKLE_ROOT_OFFSET + 31],
            
            // merkle index
            metadata[MERKLE_INDEX_OFFSET + 0], metadata[MERKLE_INDEX_OFFSET + 1], metadata[MERKLE_INDEX_OFFSET + 2], metadata[MERKLE_INDEX_OFFSET + 3],
            
            // message id
            id_bytes[0], id_bytes[1], id_bytes[2], id_bytes[3], id_bytes[4], id_bytes[5], id_bytes[6], id_bytes[7],
            id_bytes[8], id_bytes[9], id_bytes[10], id_bytes[11], id_bytes[12], id_bytes[13], id_bytes[14], id_bytes[15],
            id_bytes[16], id_bytes[17], id_bytes[18], id_bytes[19], id_bytes[20], id_bytes[21], id_bytes[22], id_bytes[23],
            id_bytes[24], id_bytes[25], id_bytes[26], id_bytes[27], id_bytes[28], id_bytes[29], id_bytes[30], id_bytes[31],
        ];

        let checkpoint_bits = Keccak256::hash_native_raw(msg);
        let checkpoint = Deserialize::from_bits_raw::[[u8; 32]](checkpoint_bits);

        return to_eth_signed_message_hash(checkpoint);
    }

    // Interpret bytes as big-endian: b0 is most significant, b3 is least.
    inline bytes_to_u32_be(b0: u8, b1: u8, b2: u8, b3: u8) -> u32 {
        let value =
            ((b0 as u32) << 24u32) +
            ((b1 as u32) << 16u32) +
            ((b2 as u32) << 8u32) +
            (b3 as u32);
        return value;
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
        let msg: [u8; 45] = [
            b3, b2, b1, b0, // origin is BE encoded
            merkle_tree_hook[0], merkle_tree_hook[1], merkle_tree_hook[2], merkle_tree_hook[3],
            merkle_tree_hook[4], merkle_tree_hook[5], merkle_tree_hook[6], merkle_tree_hook[7],
            merkle_tree_hook[8], merkle_tree_hook[9], merkle_tree_hook[10], merkle_tree_hook[11],
            merkle_tree_hook[12], merkle_tree_hook[13], merkle_tree_hook[14], merkle_tree_hook[15],
            merkle_tree_hook[16], merkle_tree_hook[17], merkle_tree_hook[18], merkle_tree_hook[19],
            merkle_tree_hook[20], merkle_tree_hook[21], merkle_tree_hook[22], merkle_tree_hook[23],
            merkle_tree_hook[24], merkle_tree_hook[25], merkle_tree_hook[26], merkle_tree_hook[27],
            merkle_tree_hook[28], merkle_tree_hook[29], merkle_tree_hook[30], merkle_tree_hook[31],
            72u8, 89u8, 80u8, 69u8, 82u8, 76u8, 65u8, 78u8, 69u8 // 'HYPERLANE' encoded as UTF-8
        ];

        let hash = Keccak256::hash_native_raw(msg);
        return Deserialize::from_bits_raw::[[u8; 32]](hash);
    }

    inline message_origin_domain_id(message: [u8; MESSAGE_LENGTH]) -> u32 {
        // [5-8]       - origin domain (4 bytes)
        let origin_domain_id = 0u32;
        for i in 0u8..4u8 {
            origin_domain_id = origin_domain_id << 8u32 | message[i + 5] as u32;
        }
        return origin_domain_id;
    }

    inline to_eth_signed_message_hash(hash: [u8; 32]) -> [u8; 32] {
        let digest: [u8; 60] = [
            25u8,   // \x19
            69u8,   // E
            116u8,  // t
            104u8,  // h
            101u8,  // e
            114u8,  // r
            101u8,  // e
            117u8,  // u
            109u8,  // m
            32u8,   // (space)
            83u8,   // S
            105u8,  // i
            103u8,  // g
            110u8,  // n
            101u8,  // e
            100u8,  // d
            32u8,   // (space)
            77u8,   // M
            101u8,  // e
            115u8,  // s
            115u8,  // s
            97u8,   // a
            103u8,  // g
            101u8,  // e
            58u8,   // :
            10u8,   // \n
            51u8,   // '3'
            50u8,   // '2'
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15],
            hash[16], hash[17], hash[18], hash[19],
            hash[20], hash[21], hash[22], hash[23],
            hash[24], hash[25], hash[26], hash[27],
            hash[28], hash[29], hash[30], hash[31]
        ];

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
