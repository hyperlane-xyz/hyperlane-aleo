// The 'validator_announce' program.
program validator_announce.aleo {
    
    struct EthAddress {
        bytes: [u8; 20],
    }

    struct StorageLocationKey {
        validator: EthAddress,
        index: u8,
    }

    struct ValidatorAnnounce {
        mailbox: [u8; 32],
        local_domain: u32,
    }

    struct HashKey {
        hash: [u8; 32],
    }

    // Validators must be able to announce multiple storage locations. 
    // There are no dynamic arrays in Aleo and we have to model an array with mappings.
    // storage_sequences returns the number of storage locations one validator has announced
    // access to a storage location is indexed by the validator address and the index of the announcement
    mapping storage_sequences: EthAddress => u8;
    mapping storage_locations: StorageLocationKey => [u8; 480];
    mapping replay_protection: HashKey => bool;
    // stores the current validator announce state
    mapping validator_announce: bool => ValidatorAnnounce;

    // TODO: consider upgradability
    @noupgrade
    async constructor() {}

    async transition init(mailbox: [u8; 32], local_domain: u32) -> Future {
        return finalize_init(mailbox, local_domain);
    }

    async function finalize_init(mailbox: [u8; 32], local_domain: u32) {
        assert(!validator_announce.contains(true));
        // TODO: consider upgradability
        validator_announce.set(true, ValidatorAnnounce {
            mailbox,
            local_domain,
        });
    }

    async transition announce(validator: [u8; 20], storage_location: [u8; 480], sig: [u8; 65]) -> Future {
        return finalize_announce(validator, storage_location, sig);
    }

    async function finalize_announce(validator: [u8; 20], storage_location: [u8; 480], sig: [u8; 65]) {
        assert(validator_announce.contains(true));

        let state = validator_announce.get(true);

        let replay_id = replay_hash(validator, storage_location);
        assert(!replay_protection.contains(replay_id));

        let validator_eth_address = EthAddress { bytes: validator };
        let sequence = storage_sequences.get_or_use(validator_eth_address, 0u8);

        let digest = announcement_digest(state.local_domain, state.mailbox, storage_location);
        let valid = ECDSA::verify_digest_eth(digest, validator, sig);

        assert_eq(valid, true);

        let location_key = StorageLocationKey {
            index: sequence,
            validator: validator_eth_address,
        };

        storage_locations.set(location_key, storage_location);

        sequence += 1;
        replay_protection.set(replay_id, true);
        storage_sequences.set(validator_eth_address, sequence);
    }

    inline replay_hash(validator: [u8; 20], storage_location: [u8; 480]) -> HashKey {
        let packed = [0u8; 200];
        for i in 0u8..20u8 {
            packed[i] = validator[i];
        }
        for i in 0u32..180u32 {
            packed[i + 20] = storage_location[i];
        }
        let hash_bits = Keccak256::hash_native_raw(packed);
        return HashKey {
            hash: Deserialize::from_bits_raw::[[u8; 32]](hash_bits),
        };
    }

    inline announcement_digest(local_domain: u32, mailbox: [u8; 32], storage_location: [u8; 480]) -> [u8; 32] {
        let domain_hash = get_domain_hash(local_domain, mailbox);

        let packed = [0u8; 512];
        for i in 0u8..32u8 {
            packed[i] = domain_hash[i];
        }
        for i in 0u32..480u32 {
            packed[i+32] = storage_location[i];
        }
        
        let hash_bits = Keccak256::hash_native_raw(packed);
        let message = Deserialize::from_bits_raw::[[u8; 32]](hash_bits);
        return to_eth_signed_message_hash(message);
    }

    inline get_domain_hash(local_domain: u32, mailbox: [u8; 32]) -> [u8; 32] {
        let b3: u8 = (local_domain >> 24u32) as u8;
        let b2: u8 = ((local_domain >> 16u32) % 256u32) as u8;
        let b1: u8 = ((local_domain >> 8u32) % 256u32) as u8;
        let b0: u8 = (local_domain % 256u32) as u8;

        // Initialize msg with all values (local_domain in BE encoding + mailbox + "HYPERLANE_ANNOUNCMENT")
        let msg: [u8; 58] = [
            // local_domain BE encoded (first byte always 0)
            b3, b2, b1, b0,
            
            // merkle tree hook (mailbox 32 bytes)
            mailbox[0], mailbox[1], mailbox[2], mailbox[3],
            mailbox[4], mailbox[5], mailbox[6], mailbox[7],
            mailbox[8], mailbox[9], mailbox[10], mailbox[11],
            mailbox[12], mailbox[13], mailbox[14], mailbox[15],
            mailbox[16], mailbox[17], mailbox[18], mailbox[19],
            mailbox[20], mailbox[21], mailbox[22], mailbox[23],
            mailbox[24], mailbox[25], mailbox[26], mailbox[27],
            mailbox[28], mailbox[29], mailbox[30], mailbox[31],
            
            // 'HYPERLANE_ANNOUNCEMENT' encoded as UTF-8
            72u8, 89u8, 80u8, 69u8, 82u8, 76u8, 65u8, 78u8, 
            69u8, 95u8, 65u8, 78u8, 78u8, 79u8, 85u8, 78u8, 
            67u8, 69u8, 77u8, 69u8, 78u8, 84u8
        ];

        let hash = Keccak256::hash_native_raw(msg);
        return Deserialize::from_bits_raw::[[u8; 32]](hash);
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
}
