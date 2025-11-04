import dispatch_proxy.aleo;
import mailbox.aleo;
import credits.aleo;

/*
 *  The 'hyp_native_template' implements the Hyperlane Hyp Native Token which is used
 *  for bridging the native Aleo currency (credits program) to other networks.
 *  It needs to define an owner address which is allowed to change the configuration
 *  of the program. If no changes are needed anymore the owner_address can be set to the
 *  NULL_ADDRESS to prevent further modification.
 *  This is independent from the aleo program owner which is allowed to upgrade the contract.
 */
program hyp_native_template.aleo {

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

    // Token Metadata stores necessary information about the program.
    // This can be changed by the contract owner specified in the `token_metadata`
    mapping token_metadata: bool => Metadata;

    // One can either use the default ISM (Interchain Security Module) of the mailbox
    // or one can specify a custom ISM, which is used to validate incoming messages.
    // If the value is set to the NULL_ADDRESS, the default ISM from the mailbox is used.
    mapping ism: bool => address;

    @noupgrade
    async constructor() {}

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
    }

    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // Init the contract
    // Whoever calls this function will be set as the owner
    async transition init() -> Future {
        let caller = self.caller;

        let program_id: [u8; 128] = [0u8; 128];
        program_id[0] = 104u8; // 'h'
        program_id[1] = 121u8; // 'y'
        program_id[2] = 112u8; // 'p'
        program_id[3] = 95u8;  // '_'
        program_id[4] = 110u8; // 'n'
        program_id[5] = 97u8;  // 'a'
        program_id[6] = 116u8; // 't'
        program_id[7] = 105u8; // 'i'
        program_id[8] = 118u8; // 'v'
        program_id[9] = 101u8; // 'e'
        program_id[10] = 95u8; // '_'
        program_id[11] = 116u8; // 't'
        program_id[12] = 101u8; // 'e'
        program_id[13] = 109u8; // 'm'
        program_id[14] = 112u8; // 'p'
        program_id[15] = 108u8; // 'l'
        program_id[16] = 97u8;  // 'a'
        program_id[17] = 116u8; // 't'
        program_id[18] = 101u8; // 'e'
        program_id[19] = 46u8;  // '.'
        program_id[20] = 97u8;  // 'a'
        program_id[21] = 108u8; // 'l'
        program_id[22] = 101u8; // 'e'
        program_id[23] = 111u8; // 'o'

        let register_future = mailbox.aleo/register_application(program_id);

        return async {
            let initialized: bool = token_metadata.contains(true);
            assert_eq(initialized, false);
            token_metadata.set(true, Metadata {
                token_owner: caller,
            });
            ism.set(true, NULL_ADDRESS);
            register_future.await();
        };
    }

    transition get_address() -> address {
        return self.address;
    }

    // Set a custom ISM which will be used instead of the default ISM of the mailbox
    async transition set_custom_ism(ism_address: address) -> Future {
        let caller = self.caller;
        return async {
            let state = token_metadata.get(true);
            assert_eq(state.token_owner, caller);

            ism.set(true, ism_address);
        };
    }

    // Change ownership for the configuration owner.
    async transition set_owner(new_owner: address) -> Future {
        let caller = self.caller;
        return async {
            let state = token_metadata.get(true);
            assert_eq(state.token_owner, caller);

            state.token_owner = new_owner;
            token_metadata.set(true, state);
        };
    }

    async transition enroll_remote_router(destination: u32, recipient: [u8; 32], gas: u128) -> Future {
        let caller = self.caller;
        return async {
            let state = token_metadata.get(true);
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
            let state = token_metadata.get(true);
            assert_eq(state.token_owner, caller);

            remote_routers.remove(destination);
        };
    }

    // `transfer_remote_with_hook`
    async transition transfer_remote(public unverified_mailbox_state: MailboxState, unverified_remote_router: RemoteRouter, public destination: u32, recipient: [u128; 2], amount: u64, allowance: [CreditAllowance; 4], custom_hook: address, custom_hook_metadata: [u8; 256]) -> Future {
        let body_amount = convert_endianness(amount as u128);
        let message_body: [u128; 8] = [recipient[0], recipient[1], 0u128, body_amount, 0u128, 0u128, 0u128, 0u128];
        let dispatch_future: Future = dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, custom_hook_metadata, allowance);
        let credits_future: Future = credits.aleo/transfer_public_as_signer(self.address, amount);
        return finalize_transfer_remote(dispatch_future, credits_future, unverified_remote_router, destination);
    }

    async function finalize_transfer_remote(dispatch_future: Future, credits_future: Future, unverified_remote_router: RemoteRouter, destination: u32) {
        let actual_remote_router = remote_routers.get(destination);
        assert_eq(actual_remote_router.domain, unverified_remote_router.domain);
        assert_eq(actual_remote_router.recipient, unverified_remote_router.recipient);
        assert_eq(actual_remote_router.gas, unverified_remote_router.gas);
        dispatch_future.await();
        credits_future.await();
    }

    // `process` is called by the relayer to submit the transaction.
    // This method then needs to take care of calling the underlying mailbox to double check against replay attacks
    // and using the default ISM.
    // Optionally the Warp contract has defined a custom ISM, in this case the default ISM from the mailbox is ignored.
    // ISM verification happens inside the mailbox
    // Parameters:
    // `unverified_ism`: needs to either be the default ism from the mailbox or the custom ism stored in `token_metadata`
    // `message`: The Hyperlane message
    // `message_length`: Due to static array sizes in Aleo, the hyperlane message is always right-padded with zeros.
    //                   Therefore, the length must be provided for correct hash calculation and signature verification
    // `id`: Keccak256 hash of the Hyperlane message
    // `metadata`: Metadata for ISM verification
    async transition process(public unverified_ism: address, message: Message, message_length: u32, id: [u128; 2], metadata: [u8; 512]) -> Future {
        let mailbox_future: Future = mailbox.aleo/process(unverified_ism, message, message_length, id, metadata);

        let address_raw = [0u128, 0u128];
        address_raw[0] = message.body[0];
        address_raw[1] = message.body[1];
        let recipient = bytes_raw_to_address(address_raw);
        assert_eq(message.body[2], 0u128);
        let amount = convert_endianness(message.body[3]) as u64;

        let credits_future: Future = credits.aleo/transfer_public(recipient, amount);
        return finalize_process(mailbox_future, credits_future, unverified_ism);
    }

    // Validates the unverified inputs from the process transition and awaits its futures.
    async function finalize_process(mailbox_future: Future, credits_future: Future, unverified_ism: address) {
        let mailbox = Mapping::get(mailbox.aleo/mailbox, true);
        let custom_ism = ism.get(true);

        // Check if custom ISM is provided, otherwise use the default ISM from the mailbox
        let verify_ism = custom_ism == NULL_ADDRESS ? mailbox.default_ism : custom_ism;
        assert_eq(verify_ism, unverified_ism);

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

}
