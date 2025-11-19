import multisig.aleo;
import mailbox.aleo;

program hyp_multisig.aleo {
    const OP_MAILBOX_SET_DISPATCH_PROXY: u8 = 1;
    const OP_MAILBOX_SET_OWNER: u8 = 2;
    const OP_MAILBOX_SET_DEFAULT_ISM: u8 = 3;
    const OP_MAILBOX_SET_DEFAULT_HOOK: u8 = 4;
    const OP_MAILBOX_SET_REQUIRED_HOOK: u8 = 5;


    const ALEO_ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    struct Op {
        op: u8,

        // OP_MAILBOX_SET_DISPATCH_PROXY: The new dispatch proxy address
        // OP_MAILBOX_SET_OWNER: The new owner address
        // OP_MAILBOX_SET_DEFAULT_ISM: The new default ISM address
        // OP_MAILBOX_SET_DEFAULT_HOOK: The new default hook address
        // OP_MAILBOX_SET_REQUIRED_HOOK: The new required hook address
        arg_addr: address,
    }


    mapping hashed_pending_ops: field => field; // signing_op_id => hash(Op)

    // TODO
    @admin(address="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px")
    async constructor() {}

    //////////////////////////////////////////////////////////////////////////
    // Init function that must be called after deployment before the rest
    // of the program can be used.
    //////////////////////////////////////////////////////////////////////////

    async transition init(public threshold: u8, aleo_signers: [address; 4], ecdsa_signers: [[u8; 20]; 4]) -> Future {
        let f = multisig.aleo/create_wallet(self.address, threshold, aleo_signers, ecdsa_signers);
        return f_init(f);
    }

    async function f_init(f: Future) {
        f.await();
    }

    //////////////////////////////////////////////////////////////////////////
    // Testing helper functions
    //////////////////////////////////////////////////////////////////////////

    transition nonce_to_signing_op_id(nonce: u32) -> field {
        return BHP256::hash_to_field(nonce);
    }

    transition get_self_address() -> address {
        return self.address;
    }

    //////////////////////////////////////////////////////////////////////////
    // Initialize a multisigning operation. This is shared between
    // all exec_ calls.
    //////////////////////////////////////////////////////////////////////////

    async transition init_multisig_op(public signing_op_id: field, public op: Op) -> Future {
        if (op.op == OP_MAILBOX_SET_DISPATCH_PROXY ||
            op.op == OP_MAILBOX_SET_OWNER ||
            op.op == OP_MAILBOX_SET_DEFAULT_ISM ||
            op.op == OP_MAILBOX_SET_DEFAULT_HOOK ||
            op.op == OP_MAILBOX_SET_REQUIRED_HOOK) {
            assert_neq(op.arg_addr, ALEO_ZERO_ADDRESS);
        } else {
            assert(false);
        }

        let op_hash = BHP256::hash_to_field(op);

        let (wallet_signing_op_id_hash, init_signing_op_fut) = multisig.aleo/initiate_signing_op(self.address, signing_op_id);
        return fin_init_multisig_op(signing_op_id, op_hash, init_signing_op_fut);
    }

    async function fin_init_multisig_op(signing_op_id: field, op_hash: field, init_signing_op_fut: Future) {
        assert(!hashed_pending_ops.contains(signing_op_id));

        hashed_pending_ops.set(signing_op_id, op_hash);

        init_signing_op_fut.await();
    }


    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_dispatch_proxy
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_dispatch_proxy(public signing_op_id: field, public dispatch_proxy: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_dispatch_proxy_fut = mailbox.aleo/set_dispatch_proxy(dispatch_proxy);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_MAILBOX_SET_DISPATCH_PROXY,
            arg_addr: dispatch_proxy,
        });

        return f_mailbox_set_dispatch_proxy(signing_op_id, hashed_op, signing_complete_fut, mailbox_set_dispatch_proxy_fut);
    }

    async function f_mailbox_set_dispatch_proxy(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, mailbox_set_dispatch_proxy_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        mailbox_set_dispatch_proxy_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_owner
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_owner(public signing_op_id: field, public owner: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_owner_fut = mailbox.aleo/set_owner(owner);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_MAILBOX_SET_OWNER,
            arg_addr: owner,
        });

        return f_mailbox_set_owner(signing_op_id, hashed_op, signing_complete_fut, mailbox_set_owner_fut);
    }

    async function f_mailbox_set_owner(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, mailbox_set_owner_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        mailbox_set_owner_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_default_ism
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_default_ism(public signing_op_id: field, public ism: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_default_ism_fut = mailbox.aleo/set_default_ism(ism);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_MAILBOX_SET_DEFAULT_ISM,
            arg_addr: ism,
        });

        return f_mailbox_set_default_ism(signing_op_id, hashed_op, signing_complete_fut, mailbox_set_default_ism_fut);
    }

    async function f_mailbox_set_default_ism(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, mailbox_set_default_ism_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        mailbox_set_default_ism_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_default_hook
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_default_hook(public signing_op_id: field, public default_hook: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_default_hook_fut = mailbox.aleo/set_default_hook(default_hook);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_MAILBOX_SET_DEFAULT_HOOK,
            arg_addr: default_hook,
        });

        return f_mailbox_set_default_hook(signing_op_id, hashed_op, signing_complete_fut, mailbox_set_default_hook_fut);
    }

    async function f_mailbox_set_default_hook(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, mailbox_set_default_hook_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        mailbox_set_default_hook_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_required_hook
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_required_hook(public signing_op_id: field, public required_hook: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_required_hook_fut = mailbox.aleo/set_required_hook(required_hook);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_MAILBOX_SET_REQUIRED_HOOK,
            arg_addr: required_hook,
        });

        return f_mailbox_set_required_hook(signing_op_id, hashed_op, signing_complete_fut, mailbox_set_required_hook_fut);
    }

    async function f_mailbox_set_required_hook(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, mailbox_set_required_hook_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        mailbox_set_required_hook_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }
}