import test_hyp_dispatch_proxy.aleo;
import test_hyp_mailbox.aleo;
import credits.aleo;
import test_hyp_multisig_core.aleo;

/*
 *  The 'hyp_native' implements the Hyperlane Hyp Native Token which is used
 *  for bridging the native Aleo currency (credits program) to other networks.
 *  It needs to define an owner address which is allowed to change the configuration
 *  of the program. If no changes are needed anymore the owner_address can be set to the
 *  NULL_ADDRESS to prevent further modification.
 *  This is independent from the aleo program owner which is allowed to upgrade the contract.
 */
program test_hyp_warp_token_credits.aleo {

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

    // Token Metadata stores necessary information about the program.
    // This can be changed by the contract owner specified in the `app_metadata`
    mapping app_metadata: bool => Metadata;

    const TYPE_NATIVE: u8 = 0u8;

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
            let signing_complete = test_hyp_multisig_core.aleo/completed_signing_ops.contains(wallet_signing_op_id_hash);
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
        // Scales local amount to message amount by up scaling outgoing messages and down scaling incoming messages.
        scale: u8,
    }

    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // Initialize the Native token.
    // Whoever calls this function will be set as the owner
    async transition init(public program_id: [u8; 128], public scale: u8) -> Future {
        let caller = self.caller;
        let token_scale = scale;

        assert_eq(token_scale <= 19u8, true);

        let register_future = test_hyp_mailbox.aleo/register_application(program_id);

        return async {
            let initialized: bool = app_metadata.contains(true);
            assert_eq(initialized, false);
            app_metadata.set(true, Metadata {
                token_type: TYPE_NATIVE,
                token_owner: caller,
                scale: token_scale,
                ism: NULL_ADDRESS,
                hook: NULL_ADDRESS
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

    // `transfer_remote`
    async transition transfer_remote(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u64,
        public allowance: [CreditAllowance; 4],
    ) -> Future {
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata = HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };

        // We assure in the finalize step of this function
        // that scale is <= 19, so 10**scale fits in u64
        let body_amount = upscale(amount, 10u64**unverified_app_metadata.scale);
        let message_body = get_message_body(recipient, body_amount);
        
        let dispatch_future: Future = test_hyp_dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, hook_metadata, allowance);
        let credits_future: Future = credits.aleo/transfer_public_as_signer(self.address, amount);
        return finalize_transfer_remote(dispatch_future, credits_future, unverified_app_metadata, unverified_remote_router, destination);
    }


    // `transfer_remote_with_hook`
    async transition transfer_remote_with_hook(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u64,
        public allowance: [CreditAllowance; 4],
        public custom_hook: address,
        public hook_metadata: HookMetadata
    ) -> Future {
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }

        let body_amount = upscale(amount, 10u64**unverified_app_metadata.scale);
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Future = test_hyp_dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, hook_metadata, allowance);
        let credits_future: Future = credits.aleo/transfer_public_as_signer(self.address, amount);
        return finalize_transfer_remote(dispatch_future, credits_future, unverified_app_metadata, unverified_remote_router, destination);
    }

    async function finalize_transfer_remote(dispatch_future: Future, credits_future: Future, unverified_app_metadata: Metadata, unverified_remote_router: RemoteRouter, destination: u32) {
        let actual_remote_router = remote_routers.get(destination);
        assert_eq(actual_remote_router, unverified_remote_router);

        let actual_app_metadata = app_metadata.get(true);
        assert_eq(actual_app_metadata, unverified_app_metadata);
        dispatch_future.await();
        credits_future.await();
    }

    // `process` is called by the relayer to submit the transaction.
    // This method then needs to take care of calling the underlying mailbox to double check against replay attacks
    // and using the default ISM.
    // Optionally the Warp contract has defined a custom ISM, in this case the default ISM from the mailbox is ignored.
    // ISM verification happens inside the mailbox
    // Parameters:
    // `unverified_ism`: needs to either be the default ism from the mailbox or the custom ism stored in `app_metadata`
    // `app_metadata`: Metadata for scaling
    // `message`: The Hyperlane message
    // `message_length`: Due to static array sizes in Aleo, the hyperlane message is always right-padded with zeros.
    //                   Therefore, the length must be provided for correct hash calculation and signature verification
    // `id`: Keccak256 hash of the Hyperlane message
    // `metadata`: Metadata for ISM verification
    async transition process(
        public unverified_ism: address,
        public unverified_app_metadata: Metadata,
        public message: Message,
        public message_length: u32,
        public id: [u128; 2],
        public metadata: [u8; 512]
    ) -> Future {
        // Aleo warp transfers allow at most u64::MAX credits to be transferred
        let amount = downscale([message.body[2], message.body[3]], 10u64**unverified_app_metadata.scale);

        let mailbox_future: Future = test_hyp_mailbox.aleo/process(unverified_ism, message, message_length, id, metadata);

        let address_raw = [message.body[0], message.body[1]];
        let recipient = bytes_raw_to_address(address_raw);

        let credits_future: Future = credits.aleo/transfer_public(recipient, amount as u64);
        return finalize_process(mailbox_future, unverified_app_metadata, message, credits_future, unverified_ism);
    }

    // Validates the unverified inputs from the process transition and awaits its futures.
    async function finalize_process(mailbox_future: Future, unverified_app_metadata: Metadata, message: Message, credits_future: Future, unverified_ism: address) {
        let metadata = app_metadata.get(true);
        assert_eq(metadata, unverified_app_metadata);

        // Check if custom ISM is provided, otherwise use the default ISM from the mailbox
        let mailbox = Mapping::get(test_hyp_mailbox.aleo/mailbox, true);
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

    inline downscale(payload: [u128; 2], scale: u64) -> u64 {
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
        assert_eq(quotient[2], 0u64);
        
        // We allow for lossy downscaling here
        // and don't check remainder == 0

        return quotient[3];
    }

    inline upscale(amount: u64, scale: u64) -> [u128; 2] {
        // Since amount and scale are u64, their product fits in u128.
        let product: u128 = (amount as u128) * (scale as u128);
        let result = convert_endianness(product);
        return [0u128, result];
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
