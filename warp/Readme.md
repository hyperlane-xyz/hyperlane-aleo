# Warp

Warp is the core Hyperlane application for bridging tokens in and out of Aleo.
There might be multiple instances of this contract. Due to Aleo's architecture
regarding namespaces and contracts, one needs to adjust the name of the program
for new deployments. This is automatically done when the deployment is made
via the Hyperlane CLI. In case of manual deployment one would need to change
`program hyp_native.aleo;` in the compiled `main.aleo` file.

## Hyp Native Template

This is the template for the HypNative implementation. It is used to interact
with the native currency of Aleo (i.e. the credits program).

## Hyp Synthetic Template

This template enables bridging of synthetic (wrapped) representations of external
assets. On inbound transfers, synthetic tokens are minted to mirror the origin
chain asset; on outbound transfers they are burned before dispatch. It defines:

- Mint/burn logic tied to verified bridge messages.

## Hyp Collateral Template

This template enables bridging of existing assets that are already registered in the `token_registry` contract.
On inbound transfers, tokens are transferred from the `hyp_collateral` contract to the recipient; on outbound transfers they are transferred from the sender to the `hyp_collateral` contract before dispatch.

## Hyp Synthetic V2 and ARC-20 Templates

[`hyp_synthetic_v2`](./hyp_synthetic_v2) bridges a standalone
[`arc20_token`](./arc20_token), rather than a token registered in
`token_registry.aleo`. See [the template guide](./hyp_synthetic_v2/README.md) for
build requirements, role setup, and differences from the deployed programs.
