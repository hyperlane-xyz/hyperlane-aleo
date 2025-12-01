import dispatch_proxy.aleo;
import mailbox.aleo;
import token_registry.aleo;
import multisig_core.aleo;

// The 'hyp_collateral' implements the Hyperlane Hyp Collateral Token which is used
// for bridging tokens from other chains to the Aleo network. It uses the token_registry program.
// It needs to define an owner address which is allowed to change the configuration
// of the program. If no changes are needed anymore the owner_address can be set to the
// NULL_ADDRESS to prevent further modification.
// This is independent from the aleo program owner which is allowed to upgrade the contract.
program hyp_collateral.aleo {

    // The program needs to know with which other contracts from other blockchains it can communicate.
    // For each destination chain it is required to enroll an remote router containing the correspondents address
    // and the expected gas limit which is required to execute the transaction on the destination chain.
    // This can be changed by the contract owner specified in the `app_metadata`.
    mapping remote_routers: u32 => RemoteRouter;

    // Mapping to iterate all remote router entries
    // From an index to the destination domain
    mapping remote_router_iter: u32 => u32;

    // Mapping to get total amount of inserted routes
    mapping remote_router_length: bool => u32;

    // Metadata stores necessary information about the program.
    // This can be changed by the contract owner specified in the `app_metadata`
    // The metadata is queried by the relayer and passed to the process function.
    mapping app_metadata: bool => Metadata;

    const TYPE_COLLATERAL: u8 = 2u8;

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
            let signing_complete = multisig_core.aleo/completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    struct RemoteRouter {
        // Domain according to the Hyperlane Spec. Can be found here: https://github.com/hyperlane-xyz/hyperlane-registry
        domain: u32,
        // Address of the corresponding smart contract on the destination chain as bytes, left-padded.
        recipient: [u8; 32],
        // The expected required gas to execute the transfer on the destination chain
        gas: u128,
    }

    struct Metadata {
        // Type of the token, e.g. native, synthetic, collateral, etc.
        token_type: u8,
        // Owner of the configuration, allowed to change ISM, Hook, and remote routers.
        token_owner: address,
        // One can either use the default ISM (Interchain Security Module) of the mailbox
        // or one can specify a custom ISM, which is used to validate incoming messages.
        // If the value is set to the NULL_ADDRESS, the default ISM from the mailbox is used.
        ism: address,
        // Similar to the ISM, one can either use the default hook from the mailbox or define a custom hook
        // That custom hook will be used for outgoing messages.
        hook: address,
        // Id of the token connected to this program.
        token_id: field,
        // Local decimals
        local_decimals: u8,
        // Remote decimals
        remote_decimals: u8,
    }

    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // Initialize the Collateral token.
    // Whoever calls this function will be set as the owner
    // This method calls the token_registry to gain addition token metadata
    async transition init(public program_id: [u8; 128], public token_id: field, public remote_decimals: u8) -> Future {
        let caller = self.caller;
        let max_u128 = !0u128;
        let register_future = mailbox.aleo/register_application(program_id);

        return async {
            let metadata = Mapping::get(token_registry.aleo/registered_tokens, token_id);
            let local_decimals = metadata.decimals;

            let difference = remote_decimals as i16 - local_decimals as i16;
            assert_eq(difference.abs() <= 18i16, true);

            // Token can only be initialized once
            let initialized: bool = app_metadata.contains(true);
            assert_eq(initialized, false);

            app_metadata.set(true, Metadata {
                token_type: TYPE_COLLATERAL,
                token_owner: caller,
                token_id: token_id,
                ism: NULL_ADDRESS,
                hook: NULL_ADDRESS,
                local_decimals,
                remote_decimals: remote_decimals,
            });

            register_future.await();
        };
    }

    transition get_address() -> address {
        return self.address;
    }

    // Set a custom Hook which will be used instead of the default Hook of the mailbox
    async transition set_custom_hook(hook_address: address) -> Future {
        let caller = self.caller;
        return async {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);
            state.hook = hook_address;
            app_metadata.set(true, state);
        };
    }

    // Set a custom ISM which will be used instead of the default ISM of the mailbox
    async transition set_custom_ism(ism_address: address) -> Future {
        let caller = self.caller;
        return async {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);
            state.ism = ism_address;
            app_metadata.set(true, state);
        };
    }

    // Change ownership for the configuration owner.
    async transition set_owner(new_owner: address) -> Future {
        let caller = self.caller;
        return async {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);

            state.token_owner = new_owner;
            app_metadata.set(true, state);
        };
    }

    async transition enroll_remote_router(destination: u32, recipient: [u8; 32], gas: u128) -> Future {
        let caller = self.caller;
        return async {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);

            if !remote_routers.contains(destination) {
                let current_length = remote_router_length.get_or_use(true, 0u32);
                remote_router_iter.set(current_length, destination);
                remote_router_length.set(true, current_length + 1);
            }

            remote_routers.set(destination, RemoteRouter {
                domain: destination,
                recipient: recipient,
                gas: gas,
            });
        };
    }

    async transition unroll_remote_router(destination: u32) -> Future {
        let caller = self.caller;
        return async {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);

            remote_routers.remove(destination);
        };
    }

    async transition transfer_remote(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [CreditAllowance; 4],
    ) -> Future {
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata = HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };

        let body_amount = convert_outgoing_amount(amount, unverified_app_metadata.local_decimals, unverified_app_metadata.remote_decimals);
        let message_body = get_message_body(recipient, body_amount);
        
        let dispatch_future: Future = dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, hook_metadata, allowance);
        let token_future: Future = token_registry.aleo/transfer_public_as_signer(unverified_app_metadata.token_id, self.address, amount);
        return finalize_transfer_remote(dispatch_future, token_future, unverified_remote_router, destination, unverified_app_metadata);
    }

    async transition transfer_remote_with_hook(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [CreditAllowance; 4],
        public custom_hook: address,
        public hook_metadata: HookMetadata
    ) -> Future {
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }

        let body_amount = convert_outgoing_amount(amount, unverified_app_metadata.local_decimals, unverified_app_metadata.remote_decimals);
        let message_body = get_message_body(recipient, body_amount);
        
        let dispatch_future: Future = dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, hook_metadata, allowance);
        let token_future: Future = token_registry.aleo/transfer_public_as_signer(unverified_app_metadata.token_id, self.address, amount);
        return finalize_transfer_remote(dispatch_future, token_future, unverified_remote_router, destination, unverified_app_metadata);
    }

    async function finalize_transfer_remote(dispatch_future: Future, token_future: Future, unverified_remote_router: RemoteRouter, destination: u32, unverified_metadata: Metadata) {
        let actual_remote_router = remote_routers.get(destination);
        assert_eq(actual_remote_router, unverified_remote_router);

        let actual_metadata = app_metadata.get(true);
        assert_eq(unverified_metadata, actual_metadata);

        dispatch_future.await();
        token_future.await();
    }

    async transition process(
        public unverified_ism: address,
        public unverified_app_metadata: Metadata,
        public message: Message,
        public message_length: u32,
        public id: [u128; 2],
        public metadata: [u8; 512]
    ) -> Future {
        let mailbox_future: Future = mailbox.aleo/process(unverified_ism, message, message_length, id, metadata);

        let address_raw = [message.body[0], message.body[1]];
        let recipient = bytes_raw_to_address(address_raw);
        let amount = convert_ingoing_amount([message.body[2], message.body[3]], unverified_app_metadata.local_decimals, unverified_app_metadata.remote_decimals);

        let token_future: Future = token_registry.aleo/transfer_public(unverified_app_metadata.token_id, recipient, amount);
        return finalize_process(mailbox_future, unverified_app_metadata, message, token_future, unverified_ism);
    }

    // Validates the unverified inputs from the process transition and awaits its futures.
    async function finalize_process(mailbox_future: Future, unverified_app_metadata: Metadata, message: Message, credits_future: Future, unverified_ism: address) {
        let metadata = app_metadata.get(true);
        assert_eq(metadata, unverified_app_metadata);

        // Check if custom ISM is provided, otherwise use the default ISM from the mailbox
        let mailbox = Mapping::get(mailbox.aleo/mailbox, true);
        let verify_ism = metadata.ism == NULL_ADDRESS ? mailbox.default_ism : metadata.ism;
        assert_eq(verify_ism, unverified_ism);

        // Assert that a router for the origin domain exists
        let router = remote_routers.get(message.origin_domain);

        // Assert that the router recipient matches the message sender
        assert_eq(router.recipient, message.sender);

        mailbox_future.await();
        credits_future.await();
    }

    // It uses the u128;2 array representing 32 bytes in little endian encoding.
    // This representation gets converted to an Aleo-address.
    inline bytes_raw_to_address(a: [u128; 2]) -> address {
        let bits = Serialize::to_bits_raw(a);
        let truncated_bits = [false; 253];
        for i in 0u8..253u8 {
            truncated_bits[i] = bits[i];
        }
        return Deserialize::from_bits_raw::[address](truncated_bits);
    }

    // Aleo integers are little-endian encoded. The bytes in the hyperlane-message are big-endian encoded.
    // This function converts the u128 in the message_body bytes to an u128 representing an integer.
    inline convert_endianness(payload: u128) -> u128 {
        let res: u128 = 0;
        for i:u8 in 0u8..16u8 {
            res += (((payload >> i*8u8) % 256u128) << (120u8 - i*8u8));
        }
        return res;
    }

    // Helper function to obtain the balance key for an address and token id.
    transition get_balance_key(a: address, token_id: field) -> field {
        let role_owner: TokenOwner = TokenOwner {
              account: a,
              token_id: token_id
            };
        return BHP256::hash_to_field(role_owner);
    }

    inline convert_outgoing_amount(amount: u128, local_decimals: u8, remote_decimals: u8) -> [u128; 2] {
        if local_decimals == remote_decimals {
            return [0u128, convert_endianness(amount)];
        }

        if remote_decimals < local_decimals {
            let protection = local_decimals < remote_decimals ? remote_decimals : local_decimals;
            let scale: u8 = protection - remote_decimals;
            let scaled_amount: u128 = amount / (10u128 ** scale);
            // Its save to convert directly as we are scaling down
            return [0u128, convert_endianness(scaled_amount)];
        } else {
            // remote_decimals > local_decimals
            let protection = local_decimals > remote_decimals ? remote_decimals : local_decimals;

            let words = [0u64; 4];
            words[2] = (amount >> 64u32) as u64;
            words[3] = (amount & (!0u64 as u128)) as u64;
            let carry = 0u128;

            let scale = remote_decimals - protection;
            let m = 10u64 ** scale;

            let product = [0u64; 4];

            for i in 0u8..4u8 {
                let current = words[3 - i] as u128 * (m as u128) + carry;
                product[3 - i] = (current & (!0u64 as u128)) as u64;
                carry = current >> 64u32;
            }

            // Assert that there is no overflow
            assert_eq(carry, 0u128);

            let upper_le: u128 = ((product[0] as u128) << 64u32) + (product[1] as u128);
            let lower_le: u128 = ((product[2] as u128) << 64u32) + (product[3] as u128);
            
            return [convert_endianness(upper_le),convert_endianness(lower_le)];
        }
    }

    inline convert_ingoing_amount(payload: [u128; 2], local_decimals: u8, remote_decimals: u8) -> u128 {
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

    inline downscale(payload: [u128; 2], scale: u64) -> u128 {
        let bits = Serialize::to_bits_raw(payload);
        let bytes = Deserialize::from_bits_raw::[[u8; 32]](bits);
        let words: [u64; 4] = [0u64; 4];

        // Convert bytes to be u64 words
        for i: u32 in 0u32..4u32 {
            let word: u64 = 0u64;
            for j: u32 in 0u32..8u32 {
                let b = bytes[i*8u32 + j];
                word += (b as u64) << (56u32 - j*8u32);
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

    inline get_message_body(recipient: [u128; 2], amount: [u128; 2]) -> [u128; 16] {
        let message_body: [u128; 16] = [0u128; 16];
        message_body[0] = recipient[0];
        message_body[1] = recipient[1];
        message_body[2] = amount[0];
        message_body[3] = amount[1];
        return message_body;
    }
}
