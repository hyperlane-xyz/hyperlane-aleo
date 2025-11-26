// Definitions for possible privileged operations and a way to represent them.
// Ideally we would've had a union/enum type, but that is not currently supported by Leo.

const MAILBOX_SET_DISPATCH_PROXY: u8 = 1;
const MAILBOX_SET_OWNER: u8 = 2;
const MAILBOX_SET_DEFAULT_ISM: u8 = 3;
const MAILBOX_SET_DEFAULT_HOOK: u8 = 4;
const MAILBOX_SET_REQUIRED_HOOK: u8 = 5;

const ISM_MANAGER_SET_DOMAIN: u8 = 10;
const ISM_MANAGER_REMOVE_DOMAIN: u8 = 11;
const ISM_MANAGER_SET_OWNER: u8 = 12;

const HOOK_MANAGER_SET_GAS_CONFIG: u8 = 20;
const HOOK_MANAGER_SET_IGP_OWNER: u8 = 21;
const HOOK_MANAGER_REM_GAS_CONFIG: u8 = 22;
const HOOK_MANAGER_CLAIM: u8 = 23;

const CREDITS_TRANSFER_TO_CALLER: u8 = 30;

struct Op {
    op: u8,

    // MAILBOX_SET_DISPATCH_PROXY: The new dispatch proxy address
    // MAILBOX_SET_OWNER: The new owner address
    // MAILBOX_SET_DEFAULT_ISM: The new default ISM address
    // MAILBOX_SET_DEFAULT_HOOK: The new default hook address
    // MAILBOX_SET_REQUIRED_HOOK: The new required hook address
    // ISM_MANAGER_SET_DOMAIN: The ISM address
    // ISM_MANAGER_REMOVE_DOMAIN: The ISM address
    // ISM_MANAGER_SET_OWNER: The ISM address
    // HOOK_MANAGER_SET_GAS_CONFIG: IGP address
    // HOOK_MANAGER_SET_IGP_OWNER: IGP address
    // HOOK_MANAGER_REM_GAS_CONFIG: IGP address
    // HOOK_MANAGER_CLAIM: IGP address
    arg_addr_0: address,

    // ISM_MANAGER_SET_DOMAIN: The module address
    // ISM_MANAGER_SET_OWNER: The new owner address
    // HOOK_MANAGER_SET_IGP_OWNER: The new owner address
    arg_addr_1: address,

    // Reserved for future use
    arg_addr_2: address,
    arg_addr_3: address,

    // ISM_MANAGER_SET_DOMAIN: The domain
    // ISM_MANAGER_REMOVE_DOMAIN: The domain
    // HOOK_MANAGER_SET_GAS_CONFIG: The destination domain
    // HOOK_MANAGER_REM_GAS_CONFIG: The destination domain
    // HOOK_MANAGER_CLAIM: Amount to claim
    // CREDITS_TRANSFER_TO_CALLER: Amount to transfer
    arg_u128_0: u128,

    // HOOK_MANAGER_SET_GAS_CONFIG: gas_overhead
    arg_u128_1: u128,

    // HOOK_MANAGER_SET_GAS_CONFIG: exchange_rate
    arg_u128_2: u128,

    // HOOK_MANAGER_SET_GAS_CONFIG: gas_price
    arg_u128_3: u128,
}
