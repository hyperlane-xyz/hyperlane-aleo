Order of operations:
1. Start devnode
2. $LEO devnode advance 20
3. Deploy the multisig_core.aleo program from https://github.com/eranrund/aleo-experiments/tree/main/multisig/programs/multisig
4. Deploy the hook_manager.aleo program from https://github.com/hyperlane-xyz/hyperlane-aleo/tree/main/hook_manager (this will also deploy the ism_manager and mailbox programs)
5. Deploy the hyp_multisig.aleo program
6. Init mailbox: `$LEO execute --skip-execute-proof --broadcast --yes mailbox.aleo/init 1u32`
7. Init hyp_multisig (this configures the signers set): See exec_init.sh
8. Switch the mailbox owner to hyp_multisig.aleo: `$LEO execute --skip-execute-proof --broadcast --yes mailbox.aleo/set_owner hyp_multisig.aleo`
9. Try out a multisig operation: See exec_mailbox_set_dispatch_proxy.sh
