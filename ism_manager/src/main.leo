
// The 'ism_manager' program.
program ism_manager.aleo {

    mapping nonce: bool => u32;
    // Mapping for DomainRoutingIsm
    mapping domain_routing_isms: address => DomainRoutingIsm;
    // Mapping for MsgIdMultisigIsms
    mapping message_id_multisigs: address => MessageIdMultisigIsm;
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
        ism_owner: address,
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

    const MAX_VALIDATORS: u8 = 10;
    const MAX_THRESHOLD: u8 = 6;
    const METADATA_LENGTH: u32 = 512;
    const MESSAGE_LENGTH: u32 = 256;
    const MESSAGE_BODY_LENGTH: u8 = (MESSAGE_LENGTH - 77) as u8; // Message has 77Bytes without the body

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
        let owner_address: address = self.caller;
        return finalize_msg_id_multisig(validators, validator_count, threshold, owner_address);
    }

    async function finalize_msg_id_multisig(validators: [EthAddress; MAX_VALIDATORS], validator_count: u8, threshold: u8, owner_address: address) {
        assert(threshold > 0);
        assert(threshold <= MAX_THRESHOLD);

        let current_nonce = nonce.get_or_use(true, 0u32);

        let ism = MessageIdMultisigIsm {
            validators,
            validator_count,
            threshold,
            ism_owner: owner_address,
            nonce: current_nonce,
        };

        let ism_address = BHP256::hash_to_address(ism);

        // Sanity check, this should be super unlikely
        let contains = message_id_multisigs.contains(ism_address);
        assert(!contains);

        message_id_multisigs.set(ism_address, ism);
        nonce.set(true, current_nonce + 1);
        isms.set(ism_address, ISM_MESSAGE_ID_MULTISIG);
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
        for i: u8 in 0u8..4u8 {
            assert(isms.contains(ism));
            let ism_type: u8 = isms.get(ism);

            if ism_type == ISM_MESSAGE_ID_MULTISIG {
                // MessageIdIsm logic
                let multisig = message_id_multisigs.get(ism_address);
                let signatures = parse_signatures(metadata);

                // TODO: calculate digest in a better way
                let merkle_tree_hook = origin_merkle_tree_hook(metadata);
                let hash = domain_hash(origin_domain_id, merkle_tree_hook);

                let msg: [u8; 100] = [0u8; 100];
                let id_bytes = message_id_bytes(message_id);
                for k in 0u8..32u8 {
                    msg[k] = hash[k];
                    msg[k + 32] = metadata[MERKLE_ROOT_OFFSET + k];
                    msg[k + 32 + 32 + 4] = id_bytes[k];
                }

                msg[64] = metadata[MERKLE_INDEX_OFFSET + 0];
                msg[65] = metadata[MERKLE_INDEX_OFFSET + 1];
                msg[66] = metadata[MERKLE_INDEX_OFFSET + 2];
                msg[67] = metadata[MERKLE_INDEX_OFFSET + 3];

                let checkpoint_bits = Keccak256::hash_native_raw(msg);
                let checkpoint = Deserialize::from_bits_raw::[[u8; 32]](checkpoint_bits);

                let digest = to_eth_signed_message_hash(checkpoint);

                let validators = multisig.validators;
                let valid_signatures = 0u8;

                // We can assume that the signatures are passed in the same order as the validators.
                // However, aleo doesn't support branching and dynamic array indexing
                // This makes it impossible for us to implement a more time efficient algorithm like in the EVM implementation
                for signature_index in 0u8..MAX_THRESHOLD {
                    for validator_index in 0u8..MAX_VALIDATORS {
                        let valid = ECDSA::verify_digest_eth(digest, validators[validator_index].bytes, signatures[signature_index]);
                        valid_signatures += valid ? 1 : 0;
                    }
                }
                assert(valid_signatures >= multisig.threshold);
            } else if ism_type == ISM_UNUSED {
                // NoopIsm continue with no verification
                return;
            }

            assert_eq(ism_type, ISM_ROUTING);
            // ISM can only be the RoutingIsm at this point
            // Route to the underlying ism based on the message `origin_domain`
            // We have to assume the routing ism on the default path,
            let key = IsmRouteKey {
                ism: ism_address,
                domain: origin_domain_id,
            };
            assert(routes.contains(key));
            ism_address = routes.get(key);
        }
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

        let msg: [u8; 45] = [0u8; 45];

        // origin is BE encoded
        msg[0] = b3;
        msg[1] = b2;
        msg[2] = b1;
        msg[3] = b0;
        // merkle tree hook
        for i in 0u8..32u8 {
            msg[i + 4] = merkle_tree_hook[i];
        }
        // 'HYPERLANE' encoded as UTF-8 (9 bytes)
        msg[36] = 72u8; // H
        msg[37] = 89u8; // Y
        msg[38] = 80u8; // P
        msg[39] = 69u8; // E
        msg[40] = 82u8; // R
        msg[41] = 76u8; // L
        msg[42] = 65u8; // A
        msg[43] = 78u8; // N
        msg[44] = 69u8; // E

        let hash = Keccak256::hash_native_raw(msg);
        return Deserialize::from_bits_raw::[[u8; 32]](hash);
    }

    inline message_origin_domain_id(message: [u8; MESSAGE_LENGTH]) -> u32 {
        // [5-8]       - origin domain (4 bytes)
        let origin_domain_id = 0u32;
        for i in 0u8..4u8 {
            origin_domain_id = origin_domain_id << 1u32 + message[5 + i] as u32;
        }
        return origin_domain_id;
    }

    inline to_eth_signed_message_hash(hash: [u8; 32]) -> [u8; 32] {
        let digest: [u8; 60] = [0u8; 60];
        // "\x19Ethereum Signed Message:\n32"
        digest[0]  = 25u8;  // \x19
        digest[1]  = 69u8;  // E
        digest[2]  = 116u8; // t
        digest[3]  = 104u8; // h
        digest[4]  = 101u8; // e
        digest[5]  = 114u8; // r
        digest[6]  = 101u8; // e
        digest[7]  = 117u8; // u
        digest[8]  = 109u8; // m
        digest[9]  = 32u8;  // (space)
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

        // Append 32-byte hash
        for i in 0u8..32u8 {
            digest[28 + i] = hash[i];
        }

        let hash_bits = Keccak256::hash_native_raw(digest);
        return Deserialize::from_bits_raw::[[u8; 32]](hash_bits);
    }

    inline parse_signatures(metadata: [u8; METADATA_LENGTH]) -> [[u8; SIGNATURE_LENGTH]; MAX_THRESHOLD] {
        let signatures = [[0u8; SIGNATURE_LENGTH]; MAX_THRESHOLD];
        for j in 0u8..MAX_THRESHOLD {
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
