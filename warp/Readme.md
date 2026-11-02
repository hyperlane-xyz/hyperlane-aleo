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

### Hyp Synthetic V2 Template

This template bridges assets using a dedicated ARC-20 token program. Tokens are
minted on inbound transfers and burned on outbound transfers through the token interface.

### Hyp Synthetic V3 Template

This template extends V2 with ARC-22 support. It adds freezelist checks for
outbound senders and inbound recipients alongside the token's mint/burn operations.

## Hyp Collateral Template

This template enables bridging of existing assets that are already registered in the `token_registry` contract.
On inbound transfers, tokens are transferred from the `hyp_collateral` contract to the recipient; on outbound transfers they are transferred from the sender to the `hyp_collateral` contract before dispatch.
