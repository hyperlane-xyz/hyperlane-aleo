Order of operations:

1. Start devnode
2. $LEO devnode advance 20
3. Deploy the hyp_multisig.aleo program (this will also deploy all its dependencies)
4. Init mailbox: `$LEO execute --skip-execute-proof --broadcast --yes test_hyp_mailbox.aleo/init 1u32`
5. Init hyp_multisig (this configures the signers set): See exec_init.sh
6. Switch the mailbox owner to hyp_multisig.aleo: `$LEO execute --skip-execute-proof --broadcast --yes test_hyp_mailbox.aleo/set_owner hyp_multisig.aleo`
7. Try out a multisig operation: See exec_mailbox_set_dispatch_proxy.sh
