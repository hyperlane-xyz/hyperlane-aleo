import hyp_warp_token_usad.aleo;
import hyp_ism_manager.aleo;
import hyp_multisig_core.aleo;
import usad_stablecoin.aleo;

// It uses the u128;2 array representing 32 bytes in little endian encoding.
// This representation gets converted to an Aleo-address.
fn bytes_raw_to_address(a: [u128; 2]) -> address {
    let bits = Serialize::to_bits_raw(a);
    let truncated_bits = [false; 253];
    for i in 0u8..253u8 {
        truncated_bits[i] = bits[i];
    }
    return Deserialize::from_bits_raw::[address](truncated_bits);
}

fn convert_ingoing_amount(payload: [u128; 2], local_decimals: u8, remote_decimals: u8) -> u128 {
    if local_decimals == remote_decimals {
        return convert_endianness(payload[1]);
    }
    if remote_decimals < local_decimals {
        // upscale the incoming amount to local decimals
        let protection = local_decimals < remote_decimals ? remote_decimals : local_decimals;
        let scale: u8 = protection - remote_decimals;

        let amount = convert_endianness(payload[1]);

        // Assert that we don't have an overflow
        assert_eq(payload[0], 0u128);

        // If the u128 overflows here, the amount is too big and invalid anyway
        let scaled_amount: u128 = amount * (10u64 ** scale) as u128;

        return scaled_amount;
    } else {
        // remote_decimals > local_decimals
        // downscale the incoming amount to local decimals
        let protection = local_decimals > remote_decimals ? remote_decimals : local_decimals;
        let scale = remote_decimals - protection;

        return downscale(payload, 10u64 ** scale);
    }
}

fn downscale(payload: [u128; 2], scale: u64) -> u128 {
    let bits = Serialize::to_bits_raw(payload);
    let bytes = Deserialize::from_bits_raw::[[u8; 32]](bits);
    let words: [u64; 4] = [0u64; 4];

    // Convert bytes to be u64 words
    for i: u32 in 0u32..4u32 {
        let word: u64 = 0u64;
        for j: u32 in 0u32..8u32 {
            let b = bytes[i * 8u32 + j];
            word += (b as u64) << (56u32 - j * 8u32);
        }
        words[i] = word;
    }
    let quotient: [u64; 4] = [0u64; 4];
    let remainder: u128 = 0u128;
    for i in 0u32..4u32 {
        let dividend: u128 = (remainder << 64u32) | words[i] as u128;
        quotient[i] = (dividend / scale as u128) as u64;
        remainder = dividend % scale as u128;
    }
    // Assert that the result fits in u64
    assert_eq(quotient[0], 0u64);
    assert_eq(quotient[1], 0u64);

    // We allow for lossy downscaling here
    // and don't check remainder == 0
    let amount = ((quotient[2] as u128) << 64u32) | (quotient[3] as u128);
    return amount;
}

// Aleo integers are little-endian encoded. The bytes in the hyperlane-message are big-endian encoded.
// This function converts the u128 in the message_body bytes to an u128 representing an integer.
fn convert_endianness(payload: u128) -> u128 {
    let res: u128 = 0;
    for i: u8 in 0u8..16u8 {
        res += (((payload >> i * 8u8) % 256u128) << (120u8 - i * 8u8));
    }
    return res;
}

// Used for program upgrades.
struct ChecksumEdition {
        checksum: [u8; 32],
        edition: u16,
    }

// The Private USAD mint and burn wrapper program.
program private_usad_wrapper.aleo {
    // This is the constructor for the program.
    // The constructor allows you to manage program upgrades.
    // It is called when the program is deployed or upgraded.
    // It is currently configured to **prevent** upgrades.
    // Other configurations include:
    //  - @admin(address="aleo1...")
    //  - @checksum(mapping="credits.aleo/fixme", key="0field")
    //  - @custom
    // For more information, please refer to the documentation: `https://docs.leo-lang.org/guides/upgradability`
    @custom
    constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(ChecksumEdition { checksum: self.checksum, edition: self.edition });

            let wallet_signing_op_id_hash = BHP256::hash_to_field(hyp_multisig_core.aleo::WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
            let signing_complete = hyp_multisig_core.aleo::completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    fn private_mint(
        public unverified_ism: address,
        public unverified_app_metadata: hyp_warp_token_usad.aleo::Metadata,
        public message: hyp_warp_token_usad.aleo::Message,
        public message_length: u32,
        public id: [u128; 2],
        public metadata: [u8; 512],
        recipient: address,
        secret: scalar,
    ) -> Final {
        let public_mint_final: Final = hyp_warp_token_usad.aleo::process(
            unverified_ism,
            unverified_app_metadata,
            message,
            message_length,
            id,
            metadata,
        );
        let hashed_data = BHP256::commit_to_field(recipient, secret);
        let field_bits = Serialize::to_bits_raw(hashed_data);
        let padded_bits = [false; 256];
        for i in 0u8..253u8 {
            padded_bits[i] = field_bits[i];
        }
        let field_bytes = Deserialize::from_bits_raw::[[u128; 2]](padded_bits);

        // Fetch the encoding from the boyd of the message.
        let encoding: [u128; 2] = [message.body[4], message.body[5]];
        // Assert that the encoding matches the hashed recipient and secret.
        assert_eq(encoding, field_bytes);

        // Deserialize the address bytes of the public recipient and ensure that it matches self.address.
        let public_recipient = bytes_raw_to_address([message.body[0], message.body[1]]);
        assert_eq(public_recipient, self.address);

        // Deserialize the amount from the message body.
        let amount = convert_ingoing_amount(
            [message.body[2], message.body[3]],
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        // If the assertions pass, we can proceed with the minting logic.
        let (receipt, usad_record, transfer_final) = usad_stablecoin.aleo::transfer_public_to_private(
            recipient,
            amount,
        );
        return final {
            public_mint_final.run();
            transfer_final.run();
        };
    }

    fn private_burn(
        usad_record: usad_stablecoin.aleo::Token,
        merkle_proof: [usad_stablecoin.aleo::MerkleProof; 2],
        public unverified_app_metadata: hyp_warp_token_usad.aleo::Metadata,
        public unverified_mailbox_state: hyp_warp_token_usad.aleo::MailboxState,
        public unverified_remote_router: hyp_warp_token_usad.aleo::RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_warp_token_usad.aleo::CreditAllowance; 4],
    ) -> Final {
        let (receipt, return_token, usad_transfer_final) = usad_stablecoin.aleo::transfer_private_to_public(
            self.address,
            amount,
            usad_record,
            merkle_proof,
        );
        let transfer_remote_final = hyp_warp_token_usad.aleo::transfer_remote(
            unverified_app_metadata,
            unverified_mailbox_state,
            unverified_remote_router,
            destination,
            recipient,
            amount,
            allowance,
        );
        return final {
            usad_transfer_final.run();
            transfer_remote_final.run();
        };
    }
}
