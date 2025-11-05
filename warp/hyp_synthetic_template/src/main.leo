import dispatch_proxy.aleo;
import mailbox.aleo;
import token_registry.aleo;

// The 'hyp_synthetic_template' implements the Hyperlane Hyp Synthetic Token which is used
// for bridging tokens from other chains to the Aleo network. It uses the token_registry program.
// It needs to define an owner address which is allowed to change the configuration
// of the program. If no changes are needed anymore the owner_address can be set to the
// NULL_ADDRESS to prevent further modification.
// This is independent from the aleo program owner which is allowed to upgrade the contract.
program hyp_synthetic_template.aleo {

    // The program needs to know with which other contracts from other blockchains it can communicate.
    // For each destination chain it is required to enroll an remote router containing the correspondents address
    // and the expected gas limit which is required to execute the transaction on the destination chain.
    // This can be changed by the contract owner specified in the `token_metadata`.
    mapping remote_routers: u32 => RemoteRouter;

    // Mapping to iterate all remote router entries
    // From an index to the destination domain
    mapping remote_router_iter: u32 => u32;

    // Mapping to get total amount of inserted routes
    mapping remote_router_length: bool => u32;

    // Metadata stores necessary information about the program.
    // This can be changed by the contract owner specified in the `token_metadata`
    // The metadata is queried by the relayer and passed to the process function.
    mapping metadata: bool => Metadata;

    // One can either use the default ISM (Interchain Security Module) of the mailbox
    // or one can specify a custom ISM, which is used to validate incoming messages.
    // If the value is set to the NULL_ADDRESS, the default ISM from the mailbox is used.
    // This field is queried by the relayer and passed to the process function. If the value is set
    // to the NULL_ADDRESS, the mailbox default_ism is passed.
    mapping ism: bool => address;

    @custom
    async constructor() {
        assert(true);
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
        token_owner: address,

        // Id of the token connected to this program.
        token_id: field,
    }

    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // Initialize the Synthetic token.
    // Whoever calls this function will be set as the owner
    // This method calls the token_registry to create a new token.
    // `name`, `symbol` and `decimals` are directly passed to the `register_token` transition.
    async transition init(public name: u128, public symbol: u128, public decimals: u8) -> Future {
        let caller = self.caller;
        let max_u128 = !0u128;
        let token_id = self.address as field;
        // Register a new token with no supply limit and no external authority.
        // This program will be the owner of the token.
        let register_token_future: Future = token_registry.aleo/register_token(token_id, name, symbol, decimals, max_u128, false, NULL_ADDRESS);

        return async {
            // Token can only be initialized once
            let initialized: bool = metadata.contains(true);
            assert_eq(initialized, false);

            metadata.set(true, Metadata {
                token_owner: caller,
                token_id: token_id,
            });
            ism.set(true, NULL_ADDRESS);

            register_token_future.await();
        };
    }

    // Set a custom ISM which will be used instead of the default ISM of the mailbox
    async transition set_custom_ism(ism_address: address) -> Future {
        let caller = self.caller;
        return async {
            let state = metadata.get(true);
            assert_eq(state.token_owner, caller);

            ism.set(true, ism_address);
        };
    }

    // Change ownership for the configuration owner.
    async transition set_owner(new_owner: address) -> Future {
        let caller = self.caller;
        return async {
            let state = metadata.get(true);
            assert_eq(state.token_owner, caller);

            state.token_owner = new_owner;
            metadata.set(true, state);
        };
    }

    async transition enroll_remote_router(destination: u32, recipient: [u8; 32], gas: u128) -> Future {
        let caller = self.caller;
        return async {
            let state = metadata.get(true);
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
            let state = metadata.get(true);
            assert_eq(state.token_owner, caller);

            remote_routers.remove(destination);
        };
    }

    // `transfer_remote_with_hook`
    async transition transfer_remote(public unverified_mailbox_state: MailboxState, public unverified_metadata: Metadata, unverified_remote_router: RemoteRouter, public destination: u32, recipient: [u128; 2], amount: u128, allowance: [CreditAllowance; 4], custom_hook: address, custom_hook_metadata: [u8; 256]) -> Future {
        let body_amount = convert_endianness(amount as u128);
        let message_body: [u128; 8] = [recipient[0], recipient[1], 0u128, body_amount, 0u128, 0u128, 0u128, 0u128];
        let dispatch_future: Future = dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, custom_hook_metadata, allowance);
        let token_future: Future = token_registry.aleo/burn_public(unverified_metadata.token_id, self.caller, amount);
        return finalize_transfer_remote(dispatch_future, token_future, unverified_remote_router, destination, unverified_metadata);
    }

    async function finalize_transfer_remote(dispatch_future: Future, token_future: Future, unverified_remote_router: RemoteRouter, destination: u32, unverified_metadata: Metadata) {
        let actual_remote_router = remote_routers.get(destination);
        assert_eq(actual_remote_router.domain, unverified_remote_router.domain);
        assert_eq(actual_remote_router.recipient, unverified_remote_router.recipient);
        assert_eq(actual_remote_router.gas, unverified_remote_router.gas);

        let actual_metadata = metadata.get(true);
        assert_eq(unverified_metadata, actual_metadata);

        dispatch_future.await();
        token_future.await();
    }

    async transition process(public unverified_ism: address, public unverified_metadata: Metadata, message: Message, message_length: u32, id: [u128; 2], ism_metadata: [u8; 512]) -> Future {
        let mailbox_future: Future = mailbox.aleo/process(unverified_ism, message, message_length, id, ism_metadata);

        let address_raw = [0u128, 0u128];
        address_raw[0] = message.body[0];
        address_raw[1] = message.body[1];
        let recipient = bytes_raw_to_address(address_raw);
        assert_eq(message.body[2], 0u128);
        let amount = convert_endianness(message.body[3]);

        let token_future: Future = token_registry.aleo/mint_public(unverified_metadata.token_id, recipient, amount, !0u32);
        return finalize_process(mailbox_future, token_future, unverified_ism, message, unverified_metadata);
    }

    // Validates the unverified inputs from the process transition and awaits its futures.
    async function finalize_process(mailbox_future: Future, token_future: Future, unverified_ism: address, unverified_message: Message, unverified_metadata: Metadata) {
        let actual_metadata = metadata.get(true);
        assert_eq(actual_metadata, unverified_metadata);

        let mailbox = Mapping::get(mailbox.aleo/mailbox, true);
        let custom_ism = ism.get(true);

        // Check if custom ISM is provided, otherwise use the default ISM from the mailbox
        let verify_ism = custom_ism == NULL_ADDRESS ? mailbox.default_ism : custom_ism;
        assert_eq(verify_ism, unverified_ism);

        // Validate sender does match remote router
        let remote_router = remote_routers.get(unverified_message.origin_domain);
        assert_eq(remote_router.recipient, unverified_message.sender);

        mailbox_future.await();
        token_future.await();
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

    // Helper function to obtain the
    transition get_balance_key(a: address, token_id: field) -> field {
        let role_owner: TokenOwner = TokenOwner {
              account: a,
              token_id: token_id
            };
        return BHP256::hash_to_field(role_owner);
    }

    transition get_address() -> address {
        return self.address;
    }

}
