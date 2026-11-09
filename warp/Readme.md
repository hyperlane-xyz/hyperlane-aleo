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
minted on inbound transfers and burned on outbound transfers through the token
interface. It uses `arc20_eth.aleo` as a compile-ready reference binding; a new
instance must replace the static import, network dependency, and token-program
constant together.

### Hyp Synthetic V3 Template

This template extends V2 with ARC-22 support. It adds freezelist checks for
outbound senders and inbound recipients alongside the token's mint/burn
operations. It uses the deployed USDT token and freezelist as compile-ready
reference bindings; a new instance must replace both imports, dependencies, and
program constants together.

V2 and V3 summarize the behavior of already deployed token-specific routes.
They intentionally retain those routes' initialization contract: the deployer
supplies `local_decimals`, which is not verified on-chain against external token
metadata. Deployment tooling must source and validate that value before calling
`init`. Broader changes to that inherited behavior belong in a separate design
change rather than in these reference templates.

## Hyp Collateral Template

This template enables bridging of existing assets that are already registered in the `token_registry` contract.
On inbound transfers, tokens are transferred from the `hyp_collateral` contract to the recipient; on outbound transfers they are transferred from the sender to the `hyp_collateral` contract before dispatch.
