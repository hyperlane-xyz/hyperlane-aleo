// Official ARC token interfaces plus the issuer operations used by Warp.
// mint_public/burn_public are extensions, not part of the official standards.
// These signatures match arc20_eth.aleo and shield_arc22_usdt.aleo.
// Each token implementation remains responsible for role-based authorization.

export interface IWarpARC20: IARC20::IARC20 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn burn_public(public owner: address, public amount: u128) -> Final;
}

export interface IWarpARC22: IARC22::IARC22 {
    fn mint_public(public recipient: address, public amount: u128) -> Final;
    fn burn_public(public owner: address, public amount: u128) -> Final;
}
