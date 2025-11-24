// This program can be used to gate privilleged operations on the Hyperlane Mailbox/ISM/Hook Manager programs by a multisig.
// The idea is that this program becomes the owner of the mailbox, ism_manager, and hook_manager programs, and it then can
// make calls to the privileged operations and will only allow making these calls if sufficient signatures have been provided.
import multisig_impl.aleo;
import mailbox.aleo;
import ism_manager.aleo;
import hook_manager.aleo;
import credits.aleo;

program hyp_multisig.aleo {

    const ALEO_ZERO_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;


    mapping hashed_pending_ops: field => field; // signing_op_id => hash(Op)

    // TODO
    @admin(address="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px")
    async constructor() {}

    //////////////////////////////////////////////////////////////////////////
    // Init function that must be called after deployment before the rest
    // of the program can be used.
    //////////////////////////////////////////////////////////////////////////

    async transition init(public threshold: u8, aleo_signers: [address; 4], ecdsa_signers: [[u8; 20]; 4]) -> Future {
        let f = multisig_impl.aleo/create_wallet(self.address, threshold, aleo_signers, ecdsa_signers);
        return async {
            f.await();
        };
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
    // one used for executing the operation by comparing the hash of the two structs.
    async transition init_multisig_op(public signing_op_id: field, public block_expiration: u32, public op: op::Op) -> Future {
        assert_eq(op.arg_addr_2, ALEO_ZERO_ADDRESS);
        assert_eq(op.arg_addr_3, ALEO_ZERO_ADDRESS);

        let op_hash = BHP256::hash_to_field(op);

        let (wallet_signing_op_id_hash, init_signing_op_fut) = multisig_impl.aleo/initiate_signing_op(self.address, signing_op_id, block_expiration);

        return async {
            // This guarantees signing_op_id is either one that hasn't been used before, or one that has expired.
            init_signing_op_fut.await();

            hashed_pending_ops.set(signing_op_id, op_hash);
        };
    }


    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_dispatch_proxy
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_dispatch_proxy(public signing_op_id: field, public dispatch_proxy: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_dispatch_proxy_fut = mailbox.aleo/set_dispatch_proxy(dispatch_proxy);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::MAILBOX_SET_DISPATCH_PROXY,
            arg_addr_0: dispatch_proxy,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            mailbox_set_dispatch_proxy_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_owner
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_owner(public signing_op_id: field, public owner: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_owner_fut = mailbox.aleo/set_owner(owner);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::MAILBOX_SET_OWNER,
            arg_addr_0: owner,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            mailbox_set_owner_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_default_ism
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_default_ism(public signing_op_id: field, public ism: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_default_ism_fut = mailbox.aleo/set_default_ism(ism);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::MAILBOX_SET_DEFAULT_ISM,
            arg_addr_0: ism,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            mailbox_set_default_ism_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_default_hook
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_default_hook(public signing_op_id: field, public default_hook: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_default_hook_fut = mailbox.aleo/set_default_hook(default_hook);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::MAILBOX_SET_DEFAULT_HOOK,
            arg_addr_0: default_hook,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            mailbox_set_default_hook_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Mailbox: set_required_hook
    //////////////////////////////////////////////////////////////////////////

    async transition exec_mailbox_set_required_hook(public signing_op_id: field, public required_hook: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let mailbox_set_required_hook_fut = mailbox.aleo/set_required_hook(required_hook);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::MAILBOX_SET_REQUIRED_HOOK,
            arg_addr_0: required_hook,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            mailbox_set_required_hook_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // ISM Manager: set_domain
    //////////////////////////////////////////////////////////////////////////

    async transition exec_ism_manager_set_domain(public signing_op_id: field, public ism: address, public domain: u32, public module: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let ism_manager_set_domain_fut = ism_manager.aleo/set_domain(ism, domain, module);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::ISM_MANAGER_SET_DOMAIN,
            arg_addr_0: ism,
            arg_addr_1: module,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: domain as u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            ism_manager_set_domain_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // ISM Manager: remove_domain
    //////////////////////////////////////////////////////////////////////////

    async transition exec_ism_manager_remove_domain(public signing_op_id: field, public ism: address, public domain: u32) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let ism_manager_remove_domain_fut = ism_manager.aleo/remove_domain(ism, domain);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::ISM_MANAGER_REMOVE_DOMAIN,
            arg_addr_0: ism,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: domain as u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            ism_manager_remove_domain_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // ISM Manager: set_owner
    //////////////////////////////////////////////////////////////////////////

    async transition exec_ism_manager_set_owner(public signing_op_id: field, public ism: address, public new_owner: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let ism_manager_set_owner_fut = ism_manager.aleo/transfer_routing_ism_ownership(ism, new_owner);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::ISM_MANAGER_SET_OWNER,
            arg_addr_0: ism,
            arg_addr_1: new_owner,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            ism_manager_set_owner_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Hook Manager: set_destination_gas_config
    //////////////////////////////////////////////////////////////////////////

    // Name shortened to fit in 31 bytes
    async transition exec_hook_mgr_set_gas_config(public signing_op_id: field, public igp: address, public destination_domain: u32, public config: DomainGasConfig) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let hook_manager_set_gas_config_fut = hook_manager.aleo/set_destination_gas_config(igp, destination_domain, config);


        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::HOOK_MANAGER_SET_GAS_CONFIG,
            arg_addr_0: igp,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: destination_domain as u128,
            arg_u128_1: config.gas_overhead,
            arg_u128_2: config.exchange_rate,
            arg_u128_3: config.gas_price,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            hook_manager_set_gas_config_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Hook Manager: transfer_igp_ownership
    //////////////////////////////////////////////////////////////////////////

    async transition exec_hook_manager_set_igp_owner(public signing_op_id: field, public igp: address, public new_owner: address) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let hook_manager_set_owner_fut = hook_manager.aleo/transfer_igp_ownership(igp, new_owner);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::HOOK_MANAGER_SET_IGP_OWNER,
            arg_addr_0: igp,
            arg_addr_1: new_owner,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: 0u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            hook_manager_set_owner_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Hook Manager: remove_destination_gas_config
    //////////////////////////////////////////////////////////////////////////

    // Name shortened to fit in 31 bytes
    async transition exec_hook_mgr_rem_gas_config(public signing_op_id: field, public igp: address, public destination_domain: u32) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let hook_manager_rem_gas_config_fut = hook_manager.aleo/remove_destination_gas_config(igp, destination_domain);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::HOOK_MANAGER_REM_GAS_CONFIG,
            arg_addr_0: igp,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: destination_domain as u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            hook_manager_rem_gas_config_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Hook Manager: claim
    //////////////////////////////////////////////////////////////////////////

    // Name shortened to fit in 31 bytes
    async transition exec_hook_manager_claim(public signing_op_id: field, public igp: address, public amount: u64) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let hook_manager_claim_fut = hook_manager.aleo/claim(igp, amount);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::HOOK_MANAGER_CLAIM,
            arg_addr_0: igp,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: amount as u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            hook_manager_claim_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }

    //////////////////////////////////////////////////////////////////////////
    // Credits: Transfer to caller
    //////////////////////////////////////////////////////////////////////////

    async transition exec_credits_transfer_to_caller(public signing_op_id: field, public amount: u64) -> Future {
        let signing_complete_fut = multisig_impl.aleo/assert_signing_completed(self.address, signing_op_id);
        let transfer_fut = credits.aleo/transfer_public(self.caller, amount);

        let hashed_op = BHP256::hash_to_field(op::Op {
            op: op::CREDITS_TRANSFER_TO_CALLER,
            arg_addr_0: ALEO_ZERO_ADDRESS,
            arg_addr_1: ALEO_ZERO_ADDRESS,
            arg_addr_2: ALEO_ZERO_ADDRESS,
            arg_addr_3: ALEO_ZERO_ADDRESS,
            arg_u128_0: amount as u128,
            arg_u128_1: 0u128,
            arg_u128_2: 0u128,
            arg_u128_3: 0u128,
        });

        return async {
            // Signing must be completed.
            signing_complete_fut.await();

            // The signing op must match the stored one.
            let hashed_pending_op = hashed_pending_ops.get(signing_op_id);
            assert_eq(hashed_pending_op, hashed_op);

            // Execute the pending op.
            transfer_fut.await();

            // Removing is crucial, otherwise the operation can be executed twice.
            hashed_pending_ops.remove(signing_op_id);
        };
    }
}