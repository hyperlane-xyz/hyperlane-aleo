import mailbox.aleo;
import hook_manager.aleo;

// The 'dispatch_proxy' program.
program dispatch_proxy.aleo {

    struct MailboxState {
        default_hook: address,
        required_hook: address,
    }

    @noupgrade
    async constructor() {}

    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    transition get_address() -> address {
        return self.address;
    }

    /// Dispatch
    /// Creates a new message based on given inputs and dispatch it
    /// We can't initialize the hook_manager.aleo futures in the Mailbox, as the hook_manager imports the mailbox and this would create a cycling dependency.
    /// The hook_manager has to import the mailbox to query the latest dispatched message.
    /// We could pass the whole mailbox state in the transition and construct a message based on this, but that would effectively limit the possible messages per block to 1, as the mailbox state changes with every message.
    /// - passed_mailbox: Is the current mailbox state, this is necessary to initialize `post_dispatch` futures
    /// - hook_allowance: mapping from hook_address -> allowed credits to spent. This is used to correctly initialize credit transfers in the `post_dispatch` hooks
    async transition dispatch(
        public passed_state: MailboxState,
        public destination_domain: u32,
        public recipient_address: [u8; 32],
        public message_body: [u128; 16],
        public hook_address: address,
        public hook_metadata: HookMetadata,
        public hook_allowance: [CreditAllowance; 4]
    ) -> Future {
        assert_neq(passed_state.default_hook, NULL_ADDRESS);
        assert_neq(passed_state.required_hook, NULL_ADDRESS);

        let default_hook = hook_address == NULL_ADDRESS ? passed_state.default_hook : hook_address;
        let mailbox_dispatch_future = mailbox.aleo/dispatch(destination_domain, recipient_address, message_body, self.caller);
        // initialize futures for the post_dispatch hook assuming all of the passed arguments are correct.
        let default_hook_future = hook_manager.aleo/post_dispatch(default_hook, hook_metadata, hook_allowance);
        let required_hook_future = hook_manager.aleo/post_dispatch(passed_state.required_hook, hook_metadata, hook_allowance);

        return finalize_dispatch(
            passed_state,
            mailbox_dispatch_future,
            default_hook_future,
            required_hook_future,
        );
    }

    async function finalize_dispatch(passed_state: MailboxState, mailbox_dispatch: Future, default_hook: Future, required_hook: Future) {
        let mailbox = Mapping::get(mailbox.aleo/mailbox, true);
        assert_eq(mailbox.default_ism, passed_state.default_ism);
        assert_eq(mailbox.default_hook, passed_state.default_hook);
        assert_eq(mailbox.required_hook, passed_state.required_hook);

        mailbox_dispatch.await();
        default_hook.await();
        required_hook.await();
    }
}
