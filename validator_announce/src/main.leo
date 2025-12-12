import hyp_multisig_core.aleo;

// The 'validator_announce' program.
program hyp_validator_announce.aleo {
    
    struct EthAddress {
        bytes: [u8; 20],
    }

    struct StorageLocationKey {
        validator: [u8; 20],
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

    struct ChecksumEdition {
        checksum: [u8; 32],
        edition: u16,
    }

    @custom
    async constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(ChecksumEdition { checksum: self.checksum, edition: self.edition });

            let wallet_signing_op_id_hash = BHP256::hash_to_field(WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
            let signing_complete = hyp_multisig_core.aleo/completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    async transition init(mailbox: address, local_domain: u32) -> Future {
        let mailbox_bytes = address_to_bytes(mailbox);
        return async {
            assert(!validator_announce.contains(true));
            validator_announce.set(true, ValidatorAnnounce {
                mailbox: mailbox_bytes,
                local_domain: local_domain,
            });
        };
    }

    transition get_address() -> address {
        return self.address;
    }

    /// Announce is called by a third party wallet to push a storage location for a validator on chain
    /// `sig` must be a valid signature from `validator` for the digest generated using `storage_location`
    /// Every storage location can only be announced once and there is a maximum of 256 storage locations per validator.
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
        let valid = ECDSA::verify_digest_eth(sig, validator, digest);

        assert_eq(valid, true);

        let location_key = StorageLocationKey {
            validator,
            index: sequence,
        };

        // We assume that a validator will not announce more than 256 storage locations
        sequence += 1;
        replay_protection.set(replay_id, true);
        storage_locations.set(location_key, storage_location);
        storage_sequences.set(validator_eth_address, sequence);
    }

    inline replay_hash(validator: [u8; 20], storage_location: [u8; 480]) -> HashKey {
        let packed = [0u8; 500];
        for i in 0u8..20u8 {
            packed[i] = validator[i];
        }
        for i in 0u32..480u32 {
            packed[i + 20] = storage_location[i];
        }
        let hash_bits = Keccak256::hash_to_bits_raw(packed);
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

        let hash_bits = Keccak256::hash_to_bits_raw(packed);
        let message = Deserialize::from_bits_raw::[[u8; 32]](hash_bits);
        return to_eth_signed_message_hash(message);
    }

    inline get_domain_hash(local_domain: u32, mailbox: [u8; 32]) -> [u8; 32] {
        let b3: u8 = (local_domain >> 24u32) as u8;
        let b2: u8 = ((local_domain >> 16u32) % 256u32) as u8;
        let b1: u8 = ((local_domain >> 8u32) % 256u32) as u8;
        let b0: u8 = (local_domain % 256u32) as u8;

        // Initialize msg with all values (local_domain in BE encoding + mailbox + "HYPERLANE_ANNOUNCEMENT")
        let msg: [u8; 58] = [0u8; 58];
        
        // local_domain BE encoded
        msg[0] = b3;
        msg[1] = b2;
        msg[2] = b1;
        msg[3] = b0;
        
        // mailbox (32 bytes)
        for i in 0u8..32u8 {
            msg[4 + i] = mailbox[i];
        }
        
        // 'HYPERLANE_ANNOUNCEMENT' encoded as UTF-8
        msg[36] = 72u8;  // H
        msg[37] = 89u8;  // Y
        msg[38] = 80u8;  // P
        msg[39] = 69u8;  // E
        msg[40] = 82u8;  // R
        msg[41] = 76u8;  // L
        msg[42] = 65u8;  // A
        msg[43] = 78u8;  // N
        msg[44] = 69u8;  // E
        msg[45] = 95u8;  // _
        msg[46] = 65u8;  // A
        msg[47] = 78u8;  // N
        msg[48] = 78u8;  // N
        msg[49] = 79u8;  // O
        msg[50] = 85u8;  // U
        msg[51] = 78u8;  // N
        msg[52] = 67u8;  // C
        msg[53] = 69u8;  // E
        msg[54] = 77u8;  // M
        msg[55] = 69u8;  // E
        msg[56] = 78u8;  // N
        msg[57] = 84u8;  // T

        let hash = Keccak256::hash_to_bits_raw(msg);
        return Deserialize::from_bits_raw::[[u8; 32]](hash);
    }

    inline to_eth_signed_message_hash(hash: [u8; 32]) -> [u8; 32] {
        let digest: [u8; 60] = [0u8; 60];
        
        // "\x19Ethereum Signed Message:\n32"
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
        
        // Copy hash bytes
        for i in 0u8..32u8 {
            digest[28 + i] = hash[i];
        }

        let hash_bits = Keccak256::hash_to_bits_raw(digest);
        return Deserialize::from_bits_raw::[[u8; 32]](hash_bits);
    }

    inline address_to_bytes(a: address) -> [u8; 32] {
        let bits = Serialize::to_bits_raw(a);
        let padded_bits = [false; 256];
        for i in 0u8..253u8 {
            padded_bits[i] = bits[i];
        }
        return Deserialize::from_bits_raw::[[u8; 32]](padded_bits);
    }
}
