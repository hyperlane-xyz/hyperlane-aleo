// Definitions for possible privileged operations and a way to represent them.
// Ideally we would've had a union/enum type, but that is not currently supported by Leo.

const SET_CUSTOM_HOOK: u8 = 1;
const SET_CUSTOM_ISM: u8 = 2;
const SET_OWNER: u8 = 3;
const ENROLL_REMOTE_ROUTER: u8 = 4;
const UNROLL_REMOTE_ROUTER: u8 = 5;

 struct Op {
    op: u8,

    // SET_CUSTOM_HOOK: hook address
    // SET_CUSTOM_ISM: ism address
    // SET_OWNER: owner address
    arg_addr_0: address,

    // Reserved for future use
    arg_addr_1: address,
    arg_addr_2: address,
    arg_addr_3: address,


    // ENROLL_REMOTE_ROUTER: destination
    // UNROLL_REMOTE_ROUTER: destination
    arg_u128_0: u128,

    // ENROLL_REMOTE_ROUTER: gas
    arg_u128_1: u128,

    // Reserved for future use
    arg_u128_2: u128,
    arg_u128_3: u128,

    // ENROLL_REMOTE_ROUTER: recipient
    arg_bytes: [u8; 32],
}
