Order of operations:
1. Start devnode
2.  ~/Projects/aleo/leo/target/release/leo devnode advance 20
3. Deploy the multisig.aleo program from https://github.com/eranrund/aleo-experiments/tree/main/multisig/programs/multisig (this will also deploy multisig_impl.aleo)
4. Deploy the mailbox.aleo program from https://github.com/hyperlane-xyz/hyperlane-aleo/tree/main/mailbox
5. Deploy the hyp_multisig.aleo program
6. Init mailbox: `leo execute --skip-proving --broadcast --yes mailbox.aleo/init 1u32`
7. Init hyp_multisig (this configures the signers set): See exec_init.sh
8. Switch the mailbox owner to hyp_multisig.aleo: `leo execute --skip-proving --broadcast --yes mailbox.aleo/set_owner hyp_multisig.aleo`
9. Try out a multisig operation: See exec_mailbox_set_dispatch_proxy.sh