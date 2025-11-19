<!--

"Features" for new features.
"Improvements" for changes in existing functionality.
"Deprecated" for soon-to-be removed features.
"Bug Fixes" for any bug fixes.
"Client Breaking" for breaking CLI commands and REST routes used by end-users.
"API Breaking" for breaking interface APIs used by other programs building ontop.

-->

# CHANGELOG

An '!' indicates a state machine breaking change.

## [v1.0.0-beta0](https://github.com/hyperlane-xyz/hyperlane-aleo/releases/tag/v1.0.0-beta0) - 2025-11-19

**Initial Release of the Hyperlane Aleo Contracts**

These Aleo contracts integrate the **Hyperlane messaging protocol**
([Hyperlane Docs](https://docs.hyperlane.xyz/)), enabling seamless interchain
communication. It also provides full support for **token bridges**,
secured by **multi-signature Interchain Security Modules**.

### **Key Features**

- **Mailbox Functionality** – Send and receive messages securely across chains.
- **Validator Announce** – Allows validators to announce their storage locations for off-chain signatures.
- **Warp Routes (Token Bridging)**
  - **Native Token** – Asset bridging for the native `credits.aleo` program.
  - **Collateral Tokens** – Asset bridging of existing tokens in the TokenRegistry.
  - **Synthetic Tokens** – Wrapped asset representation of remote assets, like ETH.
- **Interchain Security Modules (ISMs)**
  - **MessageId-Multisig-ISM** – Ensures integrity with message ID-based validation.
  - **Routing-ISM** – Delegates verification to other ISMs based on message origin.
- **Post Dispatch Hooks**
  - **Merkle Tree Hook** – Supports Merkle-based verification for Multisig ISMs.
  - **InterchainGasPaymaster** – Provides gas prices for destination chains and interchain gas payments.
