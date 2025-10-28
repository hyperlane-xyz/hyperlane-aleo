import dispatch_proxy.aleo;
import mailbox.aleo;
import credits.aleo;

// The 'hyp_native_template' program.
program hyp_native_template.aleo {

    @custom
    async constructor() {
        assert(true);
    }

    mapping remote_routers: u32 => RemoteRouter;
    mapping token_metadata: bool => Metadata;

    struct RemoteRouter {
        domain: u32,
        recipient: [u8; 32],
        gas: u128,
    }

    struct Metadata {
        name: [u8; 128],
        token_owner: address,
        custom_ism_address: address,
    }

    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    const EMPTY_METADATA: [u8; 256] = [0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8];
    const EMPTY_ALLOWANCE: [CreditAllowance; 4]  = [CreditAllowance {spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64}, CreditAllowance {spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64}, CreditAllowance {spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64}, CreditAllowance {spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64}];


    async transition init(name: [u8; 128]) -> Future {
        let caller = self.caller;
        return async {
            token_metadata.set(true, Metadata {
                name: name,
                token_owner: caller,
                custom_ism_address: NULL_ADDRESS,
            });
        };
    }

    async transition set_custom_ism(ism: address) -> Future {
        let caller = self.caller;
        return async {
            let state = token_metadata.get(true);
            assert_eq(state.token_owner, caller);

            state.custom_ism_address = ism;
            token_metadata.set(true, state);
        };
    }

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

    async transition transfer_remote(public unverified_mailbox_state: MailboxState, unverified_remote_router: RemoteRouter, public destination: u32, recipient: [u128; 2], amount: u64) -> Future {
        let body_amount = parse_payload_amount(amount as u128);
        let message_body: [u128; 8] = [recipient[0], recipient[1], 0u128, body_amount, 0u128, 0u128, 0u128, 0u128];
        let dispatch_future: Future = dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, NULL_ADDRESS, EMPTY_METADATA, EMPTY_ALLOWANCE);
        let credits_future: Future = credits.aleo/transfer_public_as_signer(self.address, amount);
        return finalize_transfer_remote(dispatch_future, credits_future, unverified_remote_router, destination);
    }

    async transition transfer_remote_with_hook(public unverified_mailbox_state: MailboxState, unverified_remote_router: RemoteRouter, public destination: u32, recipient: [u128; 2], amount: u64, custom_hook: address, custom_hook_metadata: [u8; 256]) -> Future {
        let message_body: [u128; 8] = [recipient[0], recipient[1], 0u128, amount as u128, 0u128, 0u128, 0u128, 0u128];
        let dispatch_future: Future = dispatch_proxy.aleo/dispatch(unverified_mailbox_state, destination, unverified_remote_router.recipient, message_body, custom_hook, custom_hook_metadata, EMPTY_ALLOWANCE);
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

    async transition process(public unverified_ism: address, message: Message, message_length: u32, id: [u128; 2], metadata: [u8; 512]) -> Future {
        let f0: Future = mailbox.aleo/process(unverified_ism, message, message_length, id, metadata);

        let amount = parse_payload_amount(message.body[3]) as u64;
        let address_raw = [0u128, 0u128];
        address_raw[0] = message.body[0];
        address_raw[1] = message.body[1];
        let recipient = bytes_raw_to_address(address_raw);

        let f1: Future = credits.aleo/transfer_public(recipient, amount);
        return finalize_process(f0, f1, unverified_ism);
    }

    async function finalize_process(f0: Future, f1: Future, unverified_ism: address) {
        let mailbox = Mapping::get(mailbox.aleo/mailbox, true);
        let state = token_metadata.get(true);

        let verify_ism = state.custom_ism_address == NULL_ADDRESS ? mailbox.default_ism : state.custom_ism_address;
        assert_eq(verify_ism, unverified_ism);

        f0.await();
        f1.await();
    }

    inline bytes_raw_to_address(a: [u128; 2]) -> address {
        let bits = Serialize::to_bits_raw(a);
        let truncated_bits = [false; 253];
        for i in 0u8..253u8 {
            truncated_bits[i] = bits[i];
        }
        return Deserialize::from_bits_raw::[address](truncated_bits);
    }

    inline parse_payload_amount(payload: u128) -> u128 {
        let res: u128 = 0;
        for i:u8 in 0u8..16u8 {
            res += (((payload >> i*8u8) % 256u128) << (120u8 - i*8u8));
        }
        return res;
    }

}
