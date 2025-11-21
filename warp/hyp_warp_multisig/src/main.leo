// This is the interface program between multisig.aleo and any one of the warp token programs.
// You will need to deploy a version of this for each warp token you are deploying.
// Note that you will need to search and replace hyp_collateral.aleo with whatever name you use for your
// token.
import multisig.aleo;
import hyp_collateral.aleo;

program hyp_warp_multisig.aleo {
    // TODO
    @admin(address="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px")
    async constructor() {}

    const OP_SET_CUSTOM_HOOK: u8 = 1;
    const OP_SET_CUSTOM_ISM: u8 = 2;
    const OP_SET_OWNER: u8 = 3;
    const OP_ENROLL_REMOTE_ROUTER: u8 = 4;
    const OP_UNROLL_REMOTE_ROUTER: u8 = 5;


    const ALEO_ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;


    struct Op {
        op: u8,

        // OP_SET_CUSTOM_HOOK: hook address
        // OP_SET_CUSTOM_ISM: ism address
        // OP_SET_OWNER: owner address
        arg_addr_0: address,

        // Reserved for future use
        arg_addr_1: address,
        arg_addr_2: address,
        arg_addr_3: address,


        // OP_ENROLL_REMOTE_ROUTER: destination
        // OP_UNROLL_REMOTE_ROUTER: destination
        arg_u128_0: u128,

        // OP_ENROLL_REMOTE_ROUTER: gas
        arg_u128_1: u128,

        // Reserved for future use
        arg_u128_2: u128,
        arg_u128_3: u128,

        // OP_ENROLL_REMOTE_ROUTER: recipient
        arg_bytes: [u8; 32],
    }

    mapping hashed_pending_ops: field => field; // signing_op_id => hash(Op)

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

    // Note: the contents of op are not being checked here aside from ensuring fields reserved for future use are not set.
    // This is acceptable since op will get reconstructed in the various exec_ calls, which receive the specific parameters
    // necessary for each call and an assert statement ensures the op used to initialize the signing operation is the same
    async transition init_multisig_op(public signing_op_id: field, public op: Op) -> Future {
        assert_eq(op.arg_addr_1, ALEO_ZERO_ADDRESS);
        assert_eq(op.arg_addr_3, ALEO_ZERO_ADDRESS);
        assert_eq(op.arg_addr_3, ALEO_ZERO_ADDRESS);

        assert_eq(op.arg_u128_2, 0u128);
        assert_eq(op.arg_u128_3, 0u128);

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
    // set_custom_hook
    //////////////////////////////////////////////////////////////////////////

    async transition exec_set_custom_hook(public signing_op_id: field, public custom_hook: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let set_custom_hook_fut = hyp_collateral.aleo/set_custom_hook(custom_hook);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_SET_CUSTOM_HOOK,
            arg_addr_0: custom_hook,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
            arg_bytes: [0u8; 32],
        });

        return f_set_custom_hook(signing_op_id, hashed_op, signing_complete_fut, set_custom_hook_fut);
    }

    async function f_set_custom_hook(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, set_custom_hook_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        set_custom_hook_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // set_custom_ism
    //////////////////////////////////////////////////////////////////////////

    async transition exec_set_custom_ism(public signing_op_id: field, public custom_ism: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let set_custom_ism_fut = hyp_collateral.aleo/set_custom_ism(custom_ism);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_SET_CUSTOM_ISM,
            arg_addr_0: custom_ism,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
            arg_bytes: [0u8; 32],
        });

        return f_set_custom_ism(signing_op_id, hashed_op, signing_complete_fut, set_custom_ism_fut);
    }

    async function f_set_custom_ism(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, set_custom_ism_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        set_custom_ism_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // set_owner
    //////////////////////////////////////////////////////////////////////////

    async transition exec_set_owner(public signing_op_id: field, public owner: address) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let set_owner_fut = hyp_collateral.aleo/set_owner(owner);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_SET_OWNER,
            arg_addr_0: owner,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
            arg_bytes: [0u8; 32],
        });

        return f_set_owner(signing_op_id, hashed_op, signing_complete_fut, set_owner_fut);
    }

    async function f_set_owner(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, set_owner_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        set_owner_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // enroll_remote_router
    //////////////////////////////////////////////////////////////////////////

    async transition exec_enroll_remote_router(public signing_op_id: field, public destination: u32, public recipient: [u8; 32], public gas: u128) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let enroll_remote_router_fut = hyp_collateral.aleo/enroll_remote_router(destination, recipient, gas);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_ENROLL_REMOTE_ROUTER,
            arg_addr_0: ALEO_ZERO_ADDRESS,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: destination as u128,
            arg_u128_1: gas,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
            arg_bytes: recipient,
        });

        return f_enroll_remote_router(signing_op_id, hashed_op, signing_complete_fut, enroll_remote_router_fut);
    }

    async function f_enroll_remote_router(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, enroll_remote_router_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        enroll_remote_router_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }

    //////////////////////////////////////////////////////////////////////////
    // unroll_remote_router
    //////////////////////////////////////////////////////////////////////////

    async transition exec_unroll_remote_router(public signing_op_id: field, public destination: u32) -> Future {
        let signing_complete_fut = multisig.aleo/assert_signing_completed(self.address, signing_op_id);
        let unroll_remote_router_fut = hyp_collateral.aleo/unroll_remote_router(destination);

        let hashed_op = BHP256::hash_to_field(Op {
            op: OP_UNROLL_REMOTE_ROUTER,
            arg_addr_0: ALEO_ZERO_ADDRESS,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: destination as u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
            arg_bytes: [0u8; 32],
        });

        return f_unroll_remote_router(signing_op_id, hashed_op, signing_complete_fut, unroll_remote_router_fut);
    }

    async function f_unroll_remote_router(signing_op_id: field, hashed_op: field, signing_complete_fut: Future, unroll_remote_router_fut: Future) {
        // Signing must be completed.
        signing_complete_fut.await();

        // The signing op must match the stored one.
        let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
        assert_eq(hashed_pending_op, hashed_op);

        // Execute the pending op.
        unroll_remote_router_fut.await();

        // Removing is crucial, otherwise the operation can be executed twice.
        hashed_pending_ops.remove(signing_op_id);
    }



}
