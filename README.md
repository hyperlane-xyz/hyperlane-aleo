# Hyperlane-Aleo

> [!WARNING]  
> This project is currently under development and not intended to be used in production.

This project is an implementation of Hyperlane for the Aleo, designed for
a seamless interchain communication following the Hyperlane spec.

## [hook_manager/src](./hook_manager/src)

`hook_manager` implements the hook management system for Hyperlane on Aleo. It provides functionality for registering, executing, and managing post-dispatch hooks that are called after message dispatch operations. The hook manager coordinates between different hook types including merkle tree hooks for message verification and other custom hooks that extend the protocol's capabilities.

## [ism_manager/src](./ism_manager/src)

`ism_manager` implements the Interchain Security Module (ISM) management system for message verification on Aleo. It handles the validation of incoming messages by coordinating with various ISM types including multisig ISMs for signature verification and other security modules. The ISM manager ensures that only properly authenticated messages are processed, providing the security foundation for cross-chain communication.

## [mailbox/src](./mailbox/src)

`mailbox` implements the core message passing functionality for Hyperlane on Aleo. It serves as the central hub for dispatching outbound messages and processing inbound messages. The mailbox coordinates with both the hook manager for post-dispatch operations and the ISM manager for message verification, providing a unified interface for cross-chain message delivery and execution.

## Development

Getting started:

Install the latest version of the leo compiler.

```bash
// Download the source code.
> git clone https://github.com/ProvableHQ/leo.git

// Install the compiler.
> cargo install --path .

// Run the compiler.
> leo ...
```

**Building the project:**

```bash
cd mailbox
leo build
```

**Running tests:**

```bash
./run_tests.sh
```

**Running a local devnet:**

```bash
// Download the snarkOS repo
> git clone https://github.com/ProvableHQ/snarkOS.git

// Checkout the feature branch
> git checkout feat/bytes

// Install snarkOs
> cargo install --path . --features=test_network

// Run the devnet
> leo devnet --storage tmp --snarkos "$(which snarkos)" --snarkos-features test_network --clear-storage --num-clients 1 -y
```

## Open Issues

- [x] `merkle_tree_hook` use `keccak`
- [x] Use `u128` for byte arrays
- [x] Hook usage: Figure out a way for dynamic `credit_amounts` when calling hooks
- [x] Verify Signatures dynamically in `ism_manager`
- [x] Finish Process & Dispatch logic
- [x] Validator Announce
- [ ] Corrent Events for agents
- [ ] `hyp_token_manager`
- [x] Add CI/CD pipeline

## License

This project is licensed under the Apache License, Version 2.0.  
See the [LICENSE](LICENSE) file for the full terms.

Copyright 2025 Abacus Works, Inc.
