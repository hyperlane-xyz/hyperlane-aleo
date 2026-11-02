# Warp token interfaces

`src/lib.leo` exposes `IWarpARC20` and `IWarpARC22`: the official token
interfaces extended with the two issuer operations used by Warp:

```leo
fn mint_public(public recipient: address, public amount: u128) -> Final;
fn burn_public(public owner: address, public amount: u128) -> Final;
```

These two signatures match `arc20_eth.aleo` and `shield_arc22_usdt.aleo`.
They are local extensions, **not** official ARC requirements. The token program
is responsible for enforcing mint/burn authorization. In particular, `owner`
is explicit: burning from the immediate caller is not equivalent to burning
from the transaction signer.

V3 calls the official `IARC22::IARC22Freezelist::verify_non_inclusion_pub`
through dynamic dispatch. Its returned `Final` must run in the same transaction
as messaging and mint/burn; constructing the call alone does not enforce the
list. It checks the public burn owner on outbound transfers and the decoded
public recipient on inbound processing.

## Upstream source

Leo fetches the official libraries as Git dependencies from
[aleo-labs-protocol/ARCs](https://github.com/aleo-labs-protocol/ARCs) at commit
`7e66621306953bc58822a393fb45d0e8749ebb5d`:

- [IARC20](https://github.com/aleo-labs-protocol/ARCs/blob/7e66621306953bc58822a393fb45d0e8749ebb5d/arc-0020/IARC20/src/lib.leo)
- [IARC22 and IARC22Freezelist](https://github.com/aleo-labs-protocol/ARCs/blob/7e66621306953bc58822a393fb45d0e8749ebb5d/arc-0022/IARC22/src/lib.leo)

The commit pin keeps interface resolution reproducible. Leo downloads the
libraries into its local cache on the first build; subsequent builds can use
`--offline` once all dependencies are cached. No upstream source is vendored.
The libraries contain type declarations and helpers, not deployed token code.

The current official libraries do not include a mintable extension. The older
`MintableToken` proposal used a different public-burn signature. A fuller
[ARC-20 demo interface](https://github.com/mohammadfawaz/arc20-view-demo/blob/7f77c3bdb7a7efebc7cf0206325fbc2701e10491/arc20_iface/src/lib.leo)
includes mint/burn but differs from the current standard in other signatures;
it is not used as a substitute for the official ARC interfaces.

## Bindings and execution

The templates select program names through `TOKEN_PROGRAM` and (V3)
`FREEZELIST_PROGRAM`. Set these fixed identifiers when instantiating a route;
never accept an unchecked program identifier from a transfer caller. The
interface checks argument/output types, not the trustworthiness of a target.

The target token and freezelist must exist when executing the transaction.
Off-chain proving tools must resolve the dynamic callees and include their
executions. Building the Warp source alone does not need their implementations.
This changes static `call` instructions to `call.dynamic`; consumers that
infer the token solely from static imports/calls need to support the configured
dynamic target before using these templates.
