# Standalone ARC-20 synthetic route

These generic templates were derived from the deployed mainnet programs:

| Asset | Deployed v2 router | Deployed ARC-20 token |
| --- | --- | --- |
| ETH | [hyp_warp_token_eth_v2.aleo](https://api.explorer.provable.com/v2/mainnet/program/hyp_warp_token_eth_v2.aleo) | [arc20_eth.aleo](https://api.explorer.provable.com/v2/mainnet/program/arc20_eth.aleo) |
| SOL | [hyp_warp_token_sol_v2.aleo](https://api.explorer.provable.com/v2/mainnet/program/hyp_warp_token_sol_v2.aleo) | [arc20_sol.aleo](https://api.explorer.provable.com/v2/mainnet/program/arc20_sol.aleo) |
| USDC | [hyp_warp_token_usdc_v2.aleo](https://api.explorer.provable.com/v2/mainnet/program/hyp_warp_token_usdc_v2.aleo) | [arc20_usdc.aleo](https://api.explorer.provable.com/v2/mainnet/program/arc20_usdc.aleo) |
| USDT | [hyp_warp_token_usdt_v2.aleo](https://api.explorer.provable.com/v2/mainnet/program/hyp_warp_token_usdt_v2.aleo) | [arc20_usdt.aleo](https://api.explorer.provable.com/v2/mainnet/program/arc20_usdt.aleo) |
| WBTC | [hyp_warp_token_wbtc_v2.aleo](https://api.explorer.provable.com/v2/mainnet/program/hyp_warp_token_wbtc_v2.aleo) | [arc20_wbtc.aleo](https://api.explorer.provable.com/v2/mainnet/program/arc20_wbtc.aleo) |

Router Leo source: hyperlane-aleo commit
[`f105af66e8b5db7de46370a4ee3009dc2e7494ec`](https://github.com/hyperlane-xyz/hyperlane-aleo/commit/f105af66e8b5db7de46370a4ee3009dc2e7494ec).
The token's Leo source in `../arc20_token/src/main.leo` reproduces the deployed
`arc20_eth.aleo` instructions, with the generic metadata and constructor changes
listed below. Both templates are standalone Leo projects.

The links return the live Aleo instructions as JSON strings. They were compared
on 2026-09-23; later on-chain upgrades may change those responses. The primary
router source is [the ETH v2 Leo program at the pinned commit](https://github.com/hyperlane-xyz/hyperlane-aleo/blob/f105af66e8b5db7de46370a4ee3009dc2e7494ec/warp/hyp_warp_token_eth_v2/src/main.leo).

## Build

These templates use Leo 4.3, like the deployed v2 source. The existing v1 templates
on `main` use Leo 3; this addition does not migrate them.

```sh
leo build --path warp/arc20_token --disable-update-check
leo build --path warp/hyp_synthetic_v2 --network mainnet \
  --endpoint https://api.explorer.provable.com/v2 --disable-update-check
```

The ARC-20 token is a local Leo dependency and is compiled during the router build.
The manifest resolves `hyp_dispatch_proxy.aleo` and `hyp_mailbox.aleo` from
mainnet. For a different core deployment, change both the import/call names in
`src/main.leo` and the dependencies in `program.json` before building. The v2
source intentionally does not depend on the repository's Leo 3 source packages.

## Configure a new deployment

1. Rename `arc20_token.aleo` and `hyp_synthetic_v2.aleo`, including imports,
   self-references, and manifest entries. Set the token's `name`, `symbol`, and
   `decimals` views and its `MAX_SUPPLY` constant in
   `arc20_token/src/main.leo` before deployment. Keep the `max_supply()` view
   returning `MAX_SUPPLY` so the reported and enforced limits cannot diverge.
   Defaults are `TOKEN`, `TOKEN`, 18 decimals, and the maximum u128 supply.
2. Deploy the token and router. The token constructor gives its deployer role
   `12u16` (role administrator + pauser). No account starts with mint/burn rights.
3. Initialize the router with the desired local/remote decimals, then configure
   its ISM, hook, and remote routers. Its initializer retains the deployed ABI,
   including unused name/symbol arguments; these do not configure the standalone
   token. The initialization caller becomes router owner. Token decimals must
   match the router's configured local decimals.
4. Read the router state back and verify its owner, decimals, security
   configuration, and remote routers. Abort the deployment if the router was
   already initialized or any value differs from the intended configuration.
   Transfer router ownership and configure token roles for the intended owners.
5. Only after verifying the initialized router, call
   `update_role(router_address, 3u16)` as token administrator to grant it mint
   (`1u16`) and burn (`2u16`) permissions. Roles are a bitmask; `update_role`
   replaces the entire mask. Pauser is `4u16`, administrator `8u16`.

The router does not register a token or grant itself mint/burn permissions.
Its `token_id` metadata field remains for compatibility with the deployed ABI.

## Transfer behavior

| Method | Balance debited |
| --- | --- |
| `transfer_remote` | Immediate caller |
| `transfer_remote_with_hook` | Immediate caller |
| `transfer_remote_as_signer` | Transaction signer |
| `transfer_remote_with_hook_as` | Transaction signer |

As in the deployed tokens, authorized burners can burn a specified account's
balance without an allowance. Only trusted programs should receive that role.
The router determines that account from `self.caller` or `self.signer`.

## Deliberate differences from production

- Generic program names and token metadata replace asset-specific names.
- Both templates reject upgrades. Production multisig upgrade dependencies and
  metadata checksum pins are omitted; immutable code fixes the metadata views.
- The token deployer receives initial administrator and pauser roles instead of
  hardcoded production addresses. The router owner controls router pause.
- Legacy token-registry migration methods are omitted for new deployments.
- Token behavior follows ETH/SOL/USDT/WBTC: token pause blocks mint/burn but does
  not block transfers. Deployed USDC additionally checks pause for public
  transfers/conversions; this template does not include that USDC-specific policy.

Router pause continues to block inbound and outbound bridging. Public/private
transfers, allowances, shielding, supply tracking, and token role checks are
preserved from the deployed ETH token.

## Validation

Both projects built with Leo 4.3.0. The compiled token exactly matches the
original generic Aleo artifact after stripping comments and whitespace.
After normalizing program names and whitespace, all shared
router functions, finalizers, and closures match all five live v2 programs,
except the intentionally changed `set_pause` finalizer. All token functions and
finalizers match deployed ETH/SOL/USDT/WBTC; metadata and constructor differences
are listed above. This comparison checks code parity, not live transfer execution.
