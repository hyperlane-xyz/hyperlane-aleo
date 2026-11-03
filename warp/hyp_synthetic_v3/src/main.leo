import hyp_dispatch_proxy.aleo;
import hyp_mailbox.aleo;
import hyp_multisig_core.aleo;

// Wire enum: Public = 0, Private = 1, encoded as Solidity abi.encode(mode).
// TokenMessage metadata follows the 32-byte recipient and 32-byte amount.
const PUBLIC: u128 = 0u128;
const PRIVATE: u128 = 1u128 << 120u8;

fn is_private(metadata: [u128; 2], message_length: u32) -> bool {
    // Legacy messages have no metadata; trailing array padding is unauthenticated.
    assert(message_length >= 141u32 && message_length <= 333u32);
    if message_length == 141u32 {
        return false;
    }
    // Require the entire 32-byte ABI word. Its final byte is the top byte of
    // the second little-endian u128, hence PRIVATE is shifted by 120 bits.
    assert(message_length >= 173u32);
    assert_eq(metadata[0], 0u128);
    assert(metadata[1] == PUBLIC || metadata[1] == PRIVATE);
    return metadata[1] == PRIVATE;
}

fn bytes_raw_to_address(a: [u128; 2]) -> address {
    let bits = Serialize::to_bits_raw(a);
    let truncated_bits = [false; 253];
    for i in 0u8..253u8 {
        truncated_bits[i] = bits[i];
    }
    return Deserialize::from_bits_raw::[address](truncated_bits);
}

// Aleo integers are little-endian encoded. The bytes in the hyperlane-message are big-endian encoded.
// This function converts the u128 in the message_body bytes to an u128 representing an integer.
fn convert_endianness(payload: u128) -> u128 {
    let res: u128 = 0;
    for i: u8 in 0u8..16u8 {
        res += (((payload >> i * 8u8) % 256u128) << (120u8 - i * 8u8));
    }
    return res;
}

fn convert_outgoing_amount(amount: u128, local_decimals: u8, remote_decimals: u8) -> [u128; 2] {
    if local_decimals == remote_decimals {
        return [0u128, convert_endianness(amount)];
    }
    if remote_decimals < local_decimals {
        let protection = local_decimals < remote_decimals ? remote_decimals : local_decimals;
        let scale: u8 = protection - remote_decimals;
        let scaled_amount: u128 = amount / (10u128 ** scale);
        // Safe to convert directly because the amount is being scaled down.
        return [0u128, convert_endianness(scaled_amount)];
    } else {
        // remote_decimals > local_decimals
        let protection = local_decimals > remote_decimals ? remote_decimals : local_decimals;

        let words = [0u64; 4];
        words[2] = (amount >> 64u32) as u64;
        words[3] = (amount & (!0u64 as u128)) as u64;
        let carry = 0u128;

        let scale = remote_decimals - protection;
        let m = 10u64 ** scale;

        let product = [0u64; 4];
        for i in 0u8..4u8 {
            let current = words[3 - i] as u128 * (m as u128) + carry;
            product[3 - i] = (current & (!0u64 as u128)) as u64;
            carry = current >> 64u32;
        }
        assert_eq(carry, 0u128);

        let upper_le: u128 = ((product[0] as u128) << 64u32) + (product[1] as u128);
        let lower_le: u128 = ((product[2] as u128) << 64u32) + (product[3] as u128);
        return [convert_endianness(upper_le), convert_endianness(lower_le)];
    }
}

fn convert_ingoing_amount(payload: [u128; 2], local_decimals: u8, remote_decimals: u8) -> u128 {
    if local_decimals == remote_decimals {
        return convert_endianness(payload[1]);
    }
    if remote_decimals < local_decimals {
        // upscale the incoming amount to local decimals
        let protection = local_decimals < remote_decimals ? remote_decimals : local_decimals;
        let scale: u8 = protection - remote_decimals;

        let amount = convert_endianness(payload[1]);

        // Assert that we don't have an overflow
        assert_eq(payload[0], 0u128);

        // If the u128 overflows here, the amount is too big and invalid anyway
        let scaled_amount: u128 = amount * (10u64 ** scale) as u128;

        return scaled_amount;
    } else {
        // remote_decimals > local_decimals
        // downscale the incoming amount to local decimals
        let protection = local_decimals > remote_decimals ? remote_decimals : local_decimals;
        let scale = remote_decimals - protection;

        return downscale(payload, 10u64 ** scale);
    }
}

fn downscale(payload: [u128; 2], scale: u64) -> u128 {
    let bits = Serialize::to_bits_raw(payload);
    let bytes = Deserialize::from_bits_raw::[[u8; 32]](bits);
    let words: [u64; 4] = [0u64; 4];

    // Convert bytes to be u64 words
    for i: u32 in 0u32..4u32 {
        let word: u64 = 0u64;
        for j: u32 in 0u32..8u32 {
            let b = bytes[i * 8u32 + j];
            word += (b as u64) << (56u32 - j * 8u32);
        }
        words[i] = word;
    }
    let quotient: [u64; 4] = [0u64; 4];
    let remainder: u128 = 0u128;
    for i in 0u32..4u32 {
        let dividend: u128 = (remainder << 64u32) | words[i] as u128;
        quotient[i] = (dividend / scale as u128) as u64;
        remainder = dividend % scale as u128;
    }
    // Assert that the result fits in u128.
    assert_eq(quotient[0], 0u64);
    assert_eq(quotient[1], 0u64);

    // We allow for lossy downscaling here
    // and don't check remainder == 0
    let amount = ((quotient[2] as u128) << 64u32) | (quotient[3] as u128);
    return amount;
}

fn get_message_body(recipient: [u128; 2], amount: [u128; 2]) -> [u128; 16] {
    let message_body: [u128; 16] = [0u128; 16];
    message_body[0] = recipient[0];
    message_body[1] = recipient[1];
    message_body[2] = amount[0];
    message_body[3] = amount[1];
    return message_body;
}

final fn finalize_transfer_remote(
    freezelist_future: Final,
    dispatch_future: Final,
    token_future: Final,
    unverified_remote_router: RemoteRouter,
    destination: u32,
    unverified_metadata: Metadata,
) {
    let paused_status = pause.unwrap_or(false);
    assert_eq(paused_status, false);

    let actual_remote_router = remote_routers.get(destination);
    assert_eq(actual_remote_router, unverified_remote_router);

    let actual_metadata = app_metadata.get(true);
    assert_eq(unverified_metadata, actual_metadata);

    // The official freezelist function checks the public burn owner at finalization.
    freezelist_future.run();

    dispatch_future.run();
    token_future.run();
}

struct Redemption {
    recipient: address,
    secret: scalar,
}

struct ChecksumEdition {
    checksum: [u8; 32],
    edition: u16,
}

struct RemoteRouter {
    // Domain according to the Hyperlane Spec. Can be found here: https://github.com/hyperlane-xyz/hyperlane-registry
    domain: u32,
    // Address of the corresponding smart contract on the destination chain as bytes, left-padded.
    recipient: [u8; 32],
    // The expected required gas to execute the transfer on the destination chain
    gas: u128,
}

struct Metadata {
    // Type of the token, e.g. native, synthetic, collateral, etc.
    token_type: u8,
    // Owner of the configuration, allowed to change ISM, Hook, and remote routers.
    token_owner: address,
    // One can either use the default ISM (Interchain Security Module) of the mailbox
    // or one can specify a custom ISM, which is used to validate incoming messages.
    // If the value is set to the NULL_ADDRESS, the default ISM from the mailbox is used.
    ism: address,
    // Similar to the ISM, one can either use the default hook from the mailbox or define a custom hook
    // That custom hook will be used for outgoing messages.
    hook: address,
    // Id of the token connected to this program.
    // Retained for the Warp metadata ABI; TOKEN_PROGRAM selects the external asset.
    token_id: field,
    // Local decimals
    local_decimals: u8,
    // Remote decimals
    remote_decimals: u8,
}

const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
const TYPE_SYNTHETIC: u8 = 1u8;
// Fixed deployment bindings; never accept an unchecked token target from a caller.
const TOKEN_PROGRAM: identifier = 'token';
const FREEZELIST_PROGRAM: identifier = 'freezelist';
// Replace with the intended pause authority before deploying an instance.
const PAUSE_ADMIN: address = NULL_ADDRESS;

// Generic V3 synthetic Warp route using an external ARC-22 token program.
// Set TOKEN_PROGRAM to the selected token program name (without .aleo).
// It needs to define an owner address which is allowed to change the configuration
// of the program. If no changes are needed anymore the owner_address can be set to the
// NULL_ADDRESS to prevent further modification.
// This is independent from the aleo program owner which is allowed to upgrade the contract.
program hyp_synthetic_v3.aleo {
    // The program needs to know with which other contracts from other blockchains it can communicate.
    // For each destination chain it is required to enroll an remote router containing the correspondents address
    // and the expected gas limit which is required to execute the transaction on the destination chain.
    // This can be changed by the contract owner specified in the `app_metadata`.
    mapping remote_routers: u32 => RemoteRouter;

    // Mapping to iterate all remote router entries
    // From an index to the destination domain
    mapping remote_router_iter: u32 => u32;

    // Mapping to get total amount of inserted routes
    mapping remote_router_length: bool => u32;

    // Metadata stores necessary information about the program.
    // This can be changed by the contract owner specified in the `app_metadata`
    // The metadata is queried by the relayer and passed to the process function.
    mapping app_metadata: bool => Metadata;

    // Unclaimed funds per commitment. Fully redeemed entries are removed;
    // later authenticated deposits may fund the same commitment again.
    mapping pending_redemptions: [u128; 2] => u128;

    // Admin pause mapping to pause the bridging activity
    storage pause: bool;

    @custom
    constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if std::ctx::edition() > 0u16 {
            let signing_op_id = BHP256::hash_to_field(
                ChecksumEdition { checksum: std::ctx::checksum(), edition: std::ctx::edition() },
            );
            let wallet_signing_op_id_hash = BHP256::hash_to_field(
                hyp_multisig_core.aleo::WalletSigningOpId {
                    wallet_id: std::ctx::addr(),
                    signing_op_id: signing_op_id,
                },
            );
            let signing_complete = hyp_multisig_core.aleo::completed_signing_ops
                .contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    // Initialize the Synthetic token.
    // Whoever calls this function will be set as the owner
    // `name` and `symbol` are retained for the existing init ABI.
    // Token metadata and mint/burn roles must be initialized on the external token separately.
    fn init(
        public program_id: [u8; 128],
        public name: u128,
        public symbol: u128,
        public local_decimals: u8,
        public remote_decimals: u8,
    ) -> Final {
        let caller = std::ctx::caller();
        let token_id = std::ctx::addr() as field;

        let difference = remote_decimals as i16 - local_decimals as i16;
        assert_eq(difference.abs() <= 18i16, true);

        let register_future: Final = hyp_mailbox.aleo::register_application(program_id);
        return final {
            // Token can only be initialized once
            let initialized: bool = app_metadata.contains(true);
            assert_eq(initialized, false);
            app_metadata.set(true, Metadata {
                token_type: TYPE_SYNTHETIC,
                token_owner: caller,
                token_id: token_id,
                ism: NULL_ADDRESS,
                hook: NULL_ADDRESS,
                local_decimals: local_decimals,
                remote_decimals: remote_decimals,
            });
            register_future.run();
        };
    }

    fn get_address() -> address {
        return std::ctx::addr();
    }

    // Set a custom Hook which will be used instead of the default Hook of the mailbox
    fn set_custom_hook(hook_address: address) -> Final {
        let caller = std::ctx::caller();
        return final {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);
            state.hook = hook_address;
            app_metadata.set(true, state);
        };
    }

    // Set a custom ISM which will be used instead of the default ISM of the mailbox
    fn set_custom_ism(ism_address: address) -> Final {
        let caller = std::ctx::caller();
        return final {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);
            state.ism = ism_address;
            app_metadata.set(true, state);
        };
    }

    // Change ownership for the configuration owner.
    fn set_owner(new_owner: address) -> Final {
        let caller = std::ctx::caller();
        return final {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);

            state.token_owner = new_owner;
            app_metadata.set(true, state);
        };
    }

    fn enroll_remote_router(destination: u32, recipient: [u8; 32], gas: u128) -> Final {
        let caller = std::ctx::caller();
        return final {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);
            if !remote_routers.contains(destination) {
                let current_length = remote_router_length.get_or_use(true, 0u32);
                remote_router_iter.set(current_length, destination);
                remote_router_length.set(true, current_length + 1);
            }
            remote_routers
                .set(destination, RemoteRouter { domain: destination, recipient: recipient, gas: gas });
        };
    }

    fn unroll_remote_router(destination: u32) -> Final {
        let caller = std::ctx::caller();
        return final {
            let state = app_metadata.get(true);
            assert_eq(state.token_owner, caller);

            remote_routers.remove(destination);
        };
    }

    fn transfer_remote(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_dispatch_proxy.aleo::CreditAllowance; 4],
    ) -> Final {
        let caller = std::ctx::caller();
        let freezelist_future: Final =
            IARC22::IARC22Freezelist@(FREEZELIST_PROGRAM)::verify_non_inclusion_pub(caller);
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata: hyp_dispatch_proxy.aleo::HookMetadata = hyp_dispatch_proxy.aleo::HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::burn_public(caller, amount);
        return final {
            finalize_transfer_remote(
                freezelist_future,
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        };
    }

    fn transfer_remote_with_hook(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        public custom_hook: address,
        public hook_metadata: hyp_dispatch_proxy.aleo::HookMetadata,
    ) -> Final {
        let caller = std::ctx::caller();
        let freezelist_future: Final =
            IARC22::IARC22Freezelist@(FREEZELIST_PROGRAM)::verify_non_inclusion_pub(caller);
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::burn_public(caller, amount);
        return final {
            finalize_transfer_remote(
                freezelist_future,
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        };
    }

    // Private outbound transfers always burn the freshly credited route balance.
    fn transfer_remote_private(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        input_record: dyn record,
        private sender_merkle_proofs: [IARC22::MerkleProof; 2],
    ) -> (dyn record, dyn record, Final) {
        assert(amount > 0u128);
        let route = std::ctx::addr();
        // Consume the user's private record and credit this route. ARC-22 also
        // verifies the hidden sender and public route recipient in this call.
        let (compliance, change, transfer_future): (dyn record, dyn record, Final) =
            IARC22::IARC22@(TOKEN_PROGRAM)::transfer_private_to_public(
                route, amount, input_record, sender_merkle_proofs,
            );
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata: hyp_dispatch_proxy.aleo::HookMetadata = hyp_dispatch_proxy.aleo::HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::burn_public(route, amount);
        return (compliance, change, final {
            finalize_transfer_remote(
                transfer_future,
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        });
    }

    fn transfer_remote_private_hook(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        input_record: dyn record,
        private sender_merkle_proofs: [IARC22::MerkleProof; 2],
        public custom_hook: address,
        public hook_metadata: hyp_dispatch_proxy.aleo::HookMetadata,
    ) -> (dyn record, dyn record, Final) {
        assert(amount > 0u128);
        let route = std::ctx::addr();
        // Consume the user's private record and credit this route. ARC-22 also
        // verifies the hidden sender and public route recipient in this call.
        let (compliance, change, transfer_future): (dyn record, dyn record, Final) =
            IARC22::IARC22@(TOKEN_PROGRAM)::transfer_private_to_public(
                route, amount, input_record, sender_merkle_proofs,
            );
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::burn_public(route, amount);
        return (compliance, change, final {
            finalize_transfer_remote(
                transfer_future,
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        });
    }

    fn transfer_remote_as_signer(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_dispatch_proxy.aleo::CreditAllowance; 4],
    ) -> Final {
        let signer = std::ctx::signer();
        let freezelist_future: Final =
            IARC22::IARC22Freezelist@(FREEZELIST_PROGRAM)::verify_non_inclusion_pub(signer);
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata = hyp_dispatch_proxy.aleo::HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::burn_public(signer, amount);
        return final {
            finalize_transfer_remote(
                freezelist_future,
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        };
    }

    fn transfer_remote_with_hook_as(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        public custom_hook: address,
        public hook_metadata: hyp_dispatch_proxy.aleo::HookMetadata,
    ) -> Final {
        let signer = std::ctx::signer();
        let freezelist_future: Final =
            IARC22::IARC22Freezelist@(FREEZELIST_PROGRAM)::verify_non_inclusion_pub(signer);
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::burn_public(signer, amount);
        return final {
            finalize_transfer_remote(
                freezelist_future,
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        };
    }

    fn process(
        public unverified_ism: address,
        public unverified_app_metadata: Metadata,
        public message: hyp_mailbox.aleo::Message,
        public message_length: u32,
        public id: [u128; 2],
        public metadata: [u8; 512],
    ) -> Final {
        // Read the mint mode from the authenticated token body, not ISM metadata.
        let private_mint = is_private(
            [message.body[4], message.body[5]], message_length,
        );
        // A commitment is not an address. Sanitize before decoding because
        // transition branches may evaluate both sides even in private mode.
        let address_raw = private_mint
            ? [0u128; 2]
            : [message.body[0], message.body[1]];
        let recipient = private_mint
            ? std::ctx::addr()
            : bytes_raw_to_address(address_raw);
        let amount = convert_ingoing_amount(
            [message.body[2], message.body[3]],
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let freezelist_future: Final =
            IARC22::IARC22Freezelist@(FREEZELIST_PROGRAM)::verify_non_inclusion_pub(recipient);
        let mailbox_future: Final = hyp_mailbox.aleo::process(
            unverified_ism,
            message,
            message_length,
            id,
            metadata,
        );
        let token_final: Final =
            warp_token_interfaces::IWarpARC22@(TOKEN_PROGRAM)::mint_public(recipient, amount);
        return final {
            finalize_process(
                freezelist_future,
                mailbox_future,
                unverified_app_metadata,
                message,
                token_final,
                unverified_ism,
                amount,
                private_mint,
            );
        };
    }

    // Validates the unverified inputs from the process transition and awaits its futures.
    final fn finalize_process(
        freezelist_future: Final,
        mailbox_future: Final,
        unverified_app_metadata: Metadata,
        message: hyp_mailbox.aleo::Message,
        token_future: Final,
        unverified_ism: address,
        amount: u128,
        private_mint: bool,
    ) {
        let paused_status = pause.unwrap_or(false);
        assert_eq(paused_status, false);

        let metadata = app_metadata.get(true);
        assert_eq(metadata, unverified_app_metadata);

        // Check if custom ISM is provided, otherwise use the default ISM from the mailbox
        let mailbox = Mapping::get(hyp_mailbox.aleo::mailbox, true);
        let verify_ism = metadata.ism == NULL_ADDRESS ? mailbox.default_ism : metadata.ism;
        assert_eq(verify_ism, unverified_ism);

        // Assert that a router for the origin domain exists
        let router = remote_routers.get(message.origin_domain);

        // Assert that the router recipient matches the message sender
        assert_eq(router.recipient, message.sender);

        if private_mint {
            let commitment = [message.body[0], message.body[1]];
            assert(amount > 0u128);
            let pending = pending_redemptions.get_or_use(commitment, 0u128);
            pending_redemptions.set(commitment, pending + amount);
        }

        // Check the public recipient or private route escrow before committing the mint.
        freezelist_future.run();

        mailbox_future.run();
        token_future.run();
    }

    // Redeem a proved amount, leaving any remainder available for a later claim.
    // Draining the current balance removes the pending entry. The recipient
    // remains private and need not be the signer; a relayer may broadcast it.
    fn redeem(
        public commitment: [u128; 2],
        public amount: u128,
        private recipient: address,
        private secret: scalar,
        private recipient_merkle_proofs: [IARC22::MerkleProof; 2],
    ) -> (dyn record, dyn record, Final) {
        assert(amount > 0u128);
        // The wallet derives secret = hash_to_scalar(view_key, counter, domain).
        let expected = BHP256::hash_to_field(Redemption {
            recipient: recipient,
            secret: secret,
        });
        // Canonical 32-byte encoding: 253 little-endian field bits, then 3 zeros.
        let bits = Serialize::to_bits_raw(expected);
        let padded_bits = [false; 256];
        for i: u32 in 0u32..253u32 {
            padded_bits[i] = bits[i];
        }
        assert_eq(commitment, Deserialize::from_bits_raw::[[u128; 2]](padded_bits));
        let freezelist_future: Final =
            IARC22::IARC22Freezelist@(FREEZELIST_PROGRAM)::verify_non_inclusion_priv(
                recipient, recipient_merkle_proofs,
            );
        let (compliance, token, transfer_future): (dyn record, dyn record, Final) =
            IARC22::IARC22@(TOKEN_PROGRAM)::transfer_public_to_private(recipient, amount);
        return (compliance, token, final {
            assert_eq(pause.unwrap_or(false), false);
            // Checked subtraction rejects spending more than this commitment holds.
            let remaining = pending_redemptions.get(commitment) - amount;
            if remaining == 0u128 {
                pending_redemptions.remove(commitment);
            } else {
                pending_redemptions.set(commitment, remaining);
            }
            freezelist_future.run();
            transfer_future.run();
        });
    }

    // This function is called by an admin to pause or unpause the bridging activity.
    fn set_pause(new_pause: bool) -> Final {
        let caller = std::ctx::caller();
        return final {
            assert_eq(PAUSE_ADMIN, caller);
            pause = new_pause;
        };
    }
}
