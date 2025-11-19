import multisig.aleo;
import mailbox.aleo;

program hyp_multisig.aleo {
    const OP_MAILBOX_SET_DISPATCH_PROXY: u8 = 1;

    struct Op {
        op: u8,

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
    // Mailbox: set_dispatch_proxy
    //////////////////////////////////////////////////////////////////////////

    inline mb_set_dispatch_proxy_op_hash(dispatch_proxy: address) -> field {
        let op = Op {
            op: OP_MAILBOX_SET_DISPATCH_PROXY,
            arg_addr: dispatch_proxy,
        };
        return BHP256::hash_to_field(op);
    }

    async transition init_mailbox_set_dispatch_proxy(public signing_op_id: field, public dispatch_proxy: address) -> Future {
            let (wallet_signing_op_id_hash, init_signing_op_fut) = multisig.aleo/initiate_signing_op(self.address, signing_op_id);
            let op_hash = mb_set_dispatch_proxy_op_hash(dispatch_proxy);
            return fin_init_op(signing_op_id, op_hash, init_signing_op_fut);
    }

    async function fin_init_op(signing_op_id: field, op_hash: field, init_signing_op_fut: Future) {
        assert(!hashed_pending_ops.contains(signing_op_id));
        hashed_pending_ops.set(signing_op_id, op_hash);

        init_signing_op_fut.await();
    }

   async transition exec_mailbox_set_dispatch_proxy(public signing_op_id: field, public dispatch_proxy: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_dispatch_proxy_fut = mailbox.aleo/set_dispatch_proxy(dispatch_proxy);

        let hashed_op = mb_set_dispatch_proxy_op_hash(dispatch_proxy);

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
}
