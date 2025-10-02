
// The 'ism_manager' program.
program ism_manager.aleo {

    const ORIGIN_MERKLE_TREE_OFFSET: u8 = 0;
    const MERKLE_ROOT_OFFSET: u8 = 32;
    const MERKLE_INDEX_OFFSET: u8 = 64;
    const SIGNATURES_OFFSET: u8 = 68;
    const SIGNATURE_LENGTH: u8 = 65;

    const ISM_UNUSED: u8 = 0;
    const ISM_ROUTING: u8 = 1;
    const ISM_MERKLE_ROOT_MULTISIG: u8 = 4;
    const ISM_MESSAGE_ID_MULTISIG: u8 = 5;

    struct Bytes32 {
        bytes: [u8; 32]
    }

    struct Message {
        version: u8,
        nonce: u32,
        origin_domain: u32,
        sender: Bytes32,
        destination_domain: u32,
        recipient: Bytes32,
        body: [u8; 179],
    }
        
    struct EthAddress {
        bytes: [u8; 20],
    }

    struct MessageIdMultisigIsm {
        validators: [EthAddress; 8],
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

    mapping nonce: bool => u32;
    // Mapping for DomainRoutingIsm
    mapping domain_routing_isms: address => DomainRoutingIsm;
    // Mapping for MsgIdMultisigIsms
    mapping message_id_multisigs: address => MessageIdMultisigIsm;
    // Routes for RoutingIsm
    mapping routes: IsmRouteKey => address;
    // Mapping from ism address to ISM Type
    mapping isms: address => u8;

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

    async transition init_message_id_multisig(validators: [EthAddress; 8], validator_count: u8, threshold: u8) -> Future {
        let owner_address: address = self.caller;
        return finalize_msg_id_multisig(validators, validator_count, threshold, owner_address);
    }

    async function finalize_msg_id_multisig(validators: [EthAddress; 8], validator_count: u8, threshold: u8, owner_address: address) {
        assert(threshold > 0);
        assert(threshold <= 8);

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

    async transition verify(ism: address, message: [u8; 256], message_length: u32, metadata: [u8; 256]) ->  Future {
        return finalize_verify(ism, message, message_length, metadata);
    }

    inline get_message_id(raw_message: [u8; 256], message_length: u32) -> [u8; 32] {
        // assert(message_length > 77);
        // for k in 120u32..128u32 {
        //     if message_length == k {
        //         let message = [0u8; k];
        //         for i in 0u32..k {
        //             message[i] = raw_message[i];
        //         }
        //         let hash = Keccak256::hash_native_raw(message);
        //         return Deserialize::from_bits_raw::[[u8; 32]](hash);
        //     }
        // }
        return [0u8; 32];
    }

    async function finalize_verify(ism: address, raw_message: [u8; 256], message_length: u32, metadata: [u8; 256]) {
        let message_id = get_message_id(raw_message, message_length);
        assert_neq(message_id, [0u8; 32]);
        let message = parse_message(raw_message);
        // We have a max depth of 4 for recursive routing isms
        let ism_address: address = ism;
        for i: u8 in 0u8..4u8 {

            assert(isms.contains(ism));
            let ism_type: u8 = isms.get(ism);

            if ism_type == ISM_MERKLE_ROOT_MULTISIG {
                // MerkleRootIsm logic ...
                // TODO: might not be feasable to calulcate the root. 
                // meaning we can't build the digest and therfore can't use the merkle root ism
                return;
            } else if ism_type == ISM_MESSAGE_ID_MULTISIG {
                // MessageIdIsm logic ...
                let multisig = message_id_multisigs.get(ism_address);
                verify_message_id(multisig, message, message_id, metadata);
                return;
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
                domain: message.origin_domain,
            };
            assert(routes.contains(key));
            ism_address = routes.get(key);
        }
    }

    inline verify_multisig(validators: [EthAddress; 8], validator_count: u8, threshold: u8, digest: [u8; 32], metadata: [u8; 256]) -> bool {
        assert(threshold > 0);

        let signature_index: u8 = 0u8;

        // Assumes that signatures are ordered by validator
        for i: u8 in 0u8..8u8 {
            if i > validator_count {
                return false;
            }
            
            let signer: [u8; 20] = recover(digest, signature_at(metadata, signature_index));
            if signer == validators[i].bytes {
                signature_index += 1;
                if signature_index > threshold {
                    return true;
                }
            }
        }
        return false;
    }

    inline verify_message_id(multisig: MessageIdMultisigIsm, message: Message, message_id: [u8; 32], metadata: [u8; 256]) {
        let merkle_tree_hook = origin_merkle_tree_hook(metadata);
        let hash = domain_hash(message.origin_domain, merkle_tree_hook);

        let msg: [u8; 100] = [0u8; 100];
        for i in 0u8..32u8 {
            msg[i] = hash[i];
            msg[i + 32] = metadata[MERKLE_ROOT_OFFSET + i];
            msg[i + 32 + 32 + 4] = message_id[i];
        }

        msg[64] = metadata[MERKLE_INDEX_OFFSET + 0];
        msg[65] = metadata[MERKLE_INDEX_OFFSET + 1];
        msg[66] = metadata[MERKLE_INDEX_OFFSET + 2];
        msg[67] = metadata[MERKLE_INDEX_OFFSET + 3];

        assert_neq(msg, [0u8; 100]);

        // TODO: keccak_raw the msg
        let checkpoint: [u8; 32] = [0u8; 32];
        let digest = to_eth_signed_message_hash(checkpoint);
        let verify_result = verify_multisig(multisig.validators, multisig.validator_count, multisig.threshold, digest, metadata);
        assert(verify_result);
    }

    inline parse_message(message: [u8; 256]) -> Message {
        // TODO: improve
        // Byte layout of message:
        // [0]         - version (1 byte)
        // [1-4]       - message nonce (4 bytes)
        // [5-8]       - origin domain (4 bytes)
        // [9-40]      - sender address (32 bytes)
        // [41-44]     - destination domain (4 bytes)
        // [45-76]     - recipient address (32 bytes)
        // [77-255]    - message body (179 bytes)

        let version: u8 = message[0];
        let message_nonce: u32 = bytes_to_u32(message[1], message[2], message[3], message[4]);
        let origin_domain: u32 = bytes_to_u32(message[5], message[6], message[7], message[8]);
        let sender: [u8; 32] = [0u8; 32];
        for i: u8 in 0u8..32u8 {
            sender[i] = message[i + 9];
        }

        let destination_domain: u32 = bytes_to_u32(message[41], message[42], message[43], message[44]);
        let recipient: [u8; 32] = [0u8; 32];
        for i: u8 in 0u8..32u8 {
            recipient[i] = message[i + 45];
        }

        let body: [u8; 179] = [0u8; 179];
        for i: u8 in 0u8..179u8 {
            body[i] = message[i + 77];
        }

        return Message {
            version,
            nonce: message_nonce,
            origin_domain,
            sender: Bytes32 { bytes: sender },
            destination_domain,
            recipient: Bytes32 { bytes: recipient },
            body,
        };
    }

    inline bytes_to_u32(b0: u8, b1: u8, b2: u8, b3: u8) -> u32 {
        let value = b3 as u32 << 24u32 + b2 as u32 << 16u32 + b1 as u32 << 8u32 + b0 as u32;
        return value;
    }


    inline origin_merkle_tree_hook(metadata: [u8; 256]) -> [u8; 32] {
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

        // TODO: keccak hash of the complete message
        return [0u8; 32];
    }

    inline to_eth_signed_message_hash(hash: [u8; 32]) -> [u8; 32] {
        // '\x19Ethereum Signed Message:\n32' encoded in UTF-8
        let msg: [u8; 60] = [
            25u8, 69u8, 116u8, 104u8, 101u8, 114u8, 101u8, 117u8, 109u8, 32u8, 
            83u8, 105u8, 103u8, 110u8, 101u8, 100u8, 32u8, 77u8, 101u8, 115u8, 
            115u8, 97u8, 103u8, 101u8, 58u8, 10u8, 51u8, 50u8, 
            hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7], 
            hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15],
            hash[16], hash[17], hash[18], hash[19], hash[20], hash[21], hash[22], hash[23], 
            hash[24], hash[25], hash[26], hash[27], hash[28], hash[29], hash[30], hash[31]
        ];
        assert_neq(msg, [0u8; 60]);

        // TODO: keccak hash of the complete message
        let value = [0u8; 32];
        value[0] = msg[0];
        return value;
    }

    inline signature_at(metadata: [u8; 256], index: u8) -> [u8; 65] {
        let bytes: [u8; 65] = [0u8; 65];
        for i in 0u8..SIGNATURE_LENGTH {
            // TODO: find a dynamic way of indexing the metadata
            // it might very well be necessary to wirte every case by hand
            // bytes[i] = metadata[i + SIGNATURES_OFFSET + index * SIGNATURE_LENGTH];
        }
        return bytes;
    }

    inline recover(digest: [u8; 32], sig: [u8; 65]) -> [u8; 20] {
        // TODO
        let test: [u8; 20] = [0u8; 20];
        test[0] = digest[0];
        test[1] = sig[1];
        return test;
    }

}
