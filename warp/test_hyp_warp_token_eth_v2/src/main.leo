import test_hyp_dispatch_proxy.aleo;
import test_hyp_hook_manager.aleo;
import test_hyp_mailbox.aleo;
import test_hyp_multisig_core.aleo;
import test_arc20_eth.aleo;
import test_hyp_warp_token_eth.aleo;
import shield_arc22_freezelist.aleo;

// It uses the u128;2 array representing 32 bytes in little endian encoding.
// This representation gets converted to an Aleo-address.
fn bytes_raw_to_address(a: [u128; 2]) -> address {
    let bits = Serialize::to_bits_raw(a);
    let truncated_bits = [false; 253];
    for i in 0u8..253u8 {
        truncated_bits[i] = bits[i];
    }
    return Deserialize::from_bits_raw::[address](truncated_bits);
}

// The 77-byte header and 64-byte recipient/amount must be authenticated.
// Mints to this program also require the complete 32-byte claim commitment.
fn validated_token_recipient(
    body: [u128; 16],
    message_length: u32,
    warp_address: address,
) -> address {
    assert(message_length >= 141u32);
    let recipient = bytes_raw_to_address([body[0], body[1]]);
    if recipient == warp_address {
        assert(message_length >= 173u32);
        assert(body[4] != 0u128 || body[5] != 0u128);
    }
    return recipient;
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

// Call this directly from entry points so Leo preserves the deployed closure for upgrades.
fn convert_outgoing_amount(amount: u128, local_decimals: u8, remote_decimals: u8) -> [u128; 2] {
    if local_decimals == remote_decimals {
        return [0u128, convert_endianness(amount)];
    }
    if remote_decimals < local_decimals {
        let protection = local_decimals < remote_decimals ? remote_decimals : local_decimals;
        let scale: u8 = protection - remote_decimals;
        let scaled_amount: u128 = amount / (10u128 ** scale);
        // Its save to convert directly as we are scaling down
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
    // Assert that the result fits in u64
    assert_eq(quotient[0], 0u64);
    assert_eq(quotient[1], 0u64);

    // We allow for lossy downscaling here
    // and don't check remainder == 0
    let amount = ((quotient[2] as u128) << 64u32) | (quotient[3] as u128);
    return amount;
}

// This deployed closure must also remain unchanged and be called directly from entry points.
fn get_message_body(recipient: [u128; 2], amount: [u128; 2]) -> [u128; 16] {
    let message_body: [u128; 16] = [0u128; 16];
    message_body[0] = recipient[0];
    message_body[1] = recipient[1];
    message_body[2] = amount[0];
    message_body[3] = amount[1];
    return message_body;
}

// Calculate the outbound burn fee in local ETH-token base units, rounding down. Splitting
// the multiplication prevents overflow even when amount is u128::MAX.
@no_inline
export fn private_transfer_amount(amount: u128, fee_bps: u16) -> (u128, u128) {
    assert(fee_bps < 10000u16);
    assert(amount > 0u128);
    let rate = fee_bps as u128;
    let fee = (amount / 10000u128) * rate + ((amount % 10000u128) * rate) / 10000u128;
    return (amount - fee, fee);
}

export final fn validate_private_transfer_fee(unverified_fee_bps: u16) {
    assert_eq(unverified_fee_bps, private_transfer_fee_bps.unwrap_or(0u16));
}

final fn validate_transfer_remote(
    unverified_remote_router: RemoteRouter,
    destination: u32,
    unverified_metadata: Metadata,
) {
    let paused_status = bridge_pause.get_or_use(true, [false, false]);
    assert_eq(paused_status[1], false);

    let actual_remote_router = remote_routers.get(destination);
    assert_eq(actual_remote_router, unverified_remote_router);

    let actual_metadata = app_metadata.get(true);
    assert_eq(unverified_metadata, actual_metadata);
}

// Keep the futures first to preserve the deployed finalize input order.
final fn finalize_transfer_remote(
    dispatch_future: Final,
    token_future: Final,
    unverified_remote_router: RemoteRouter,
    destination: u32,
    unverified_metadata: Metadata,
) {
    validate_transfer_remote(unverified_remote_router, destination, unverified_metadata);
    dispatch_future.run();
    token_future.run();
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
    // This field is unused for the USAD token
    token_id: field,
    // Local decimals
    local_decimals: u8,
    // Remote decimals
    remote_decimals: u8,
}

const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
const TYPE_SYNTHETIC: u8 = 1u8;
const TESTNET_HYPERLANE_PAUSE_ADMIN: address = aleo1h9x8mx3yc8uqylsrguuqklkq9us4t7vkd7z9wxp04nt0p8sxjgzqhth7t0;
const TESTNET_HYPERLANE_FEE_ADMIN: address = aleo1h9x8mx3yc8uqylsrguuqklkq9us4t7vkd7z9wxp04nt0p8sxjgzqhth7t0;
const INVESTIGATOR_ADDRESS: address = aleo1h9x8mx3yc8uqylsrguuqklkq9us4t7vkd7z9wxp04nt0p8sxjgzqhth7t0;

// The 'hyp_synthetic' implements the Hyperlane Hyp Synthetic Token which is used
// for bridging tokens from other chains to the Aleo network. It uses the stablecoin_program program.
// It needs to define an owner address which is allowed to change the configuration
// of the program. If no changes are needed anymore the owner_address can be set to the
// NULL_ADDRESS to prevent further modification.
// This is independent from the aleo program owner which is allowed to upgrade the contract.
program test_hyp_warp_token_eth_v2.aleo {
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

    // Admin pause mapping to pause the bridging activity
    mapping pause: bool => bool;

    // Mapping to store claimable amounts for each user
    mapping claimable: [u128; 2] => u128;

    // Outbound private burn fee: 100 basis points = 1%, defaulting to zero.
    storage private_transfer_fee_bps: u16;

    // Mapping to store the pause status for inbound and outbound bridge transactions.
    // Replaces previous pause mapping.
    mapping bridge_pause: bool => [bool; 2];

    // Compliance record for private mints and private burns.
    record ComplianceRecord {
        owner: address,
        amount: u128,
        sender: address,
        recipient: address,
    }

    @custom
    constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if std::ctx::edition() > 0u16 {
            let signing_op_id = BHP256::hash_to_field(
                ChecksumEdition { checksum: std::ctx::checksum(), edition: std::ctx::edition() },
            );
            let wallet_signing_op_id_hash = BHP256::hash_to_field(
                test_hyp_multisig_core.aleo::WalletSigningOpId {
                    wallet_id: std::ctx::addr(),
                    signing_op_id: signing_op_id,
                },
            );
            let signing_complete = test_hyp_multisig_core.aleo::completed_signing_ops
                .contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        }
    }

    // Initialize the Synthetic token.
    // Whoever calls this function will be set as the owner
    // `name`, `symbol` and `decimals` are directly passed to the `register_token` transition.
    fn init(
        public program_id: [u8; 128],
        public name: u128,
        public symbol: u128,
        public local_decimals: u8,
        public remote_decimals: u8,
    ) -> Final {
        let caller = std::ctx::caller();
        let max_u128 = !0u128;
        let token_id = std::ctx::addr() as field;

        let difference = remote_decimals as i16 - local_decimals as i16;
        assert_eq(difference.abs() <= 18i16, true);

        let register_future: Final = test_hyp_mailbox.aleo::register_application(program_id);
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
        public unverified_mailbox_state: test_hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [test_hyp_dispatch_proxy.aleo::CreditAllowance; 4],
    ) -> Final {
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata = test_hyp_dispatch_proxy.aleo::HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = test_hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final = test_arc20_eth.aleo::burn_public(std::ctx::caller(), amount);
        return final {
            finalize_transfer_remote(
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
        public unverified_mailbox_state: test_hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [test_hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        public custom_hook: address,
        public hook_metadata: test_hyp_dispatch_proxy.aleo::HookMetadata,
    ) -> Final {
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = test_hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final = test_arc20_eth.aleo::burn_public(std::ctx::caller(), amount);
        return final {
            finalize_transfer_remote(
                dispatch_future,
                token_future,
                unverified_remote_router,
                destination,
                unverified_app_metadata,
            );
        };
    }

    fn transfer_remote_as_signer(
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: test_hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [test_hyp_dispatch_proxy.aleo::CreditAllowance; 4],
    ) -> Final {
        let custom_hook: address = unverified_app_metadata.hook;
        let hook_metadata = test_hyp_dispatch_proxy.aleo::HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = test_hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final = test_arc20_eth.aleo::burn_public(std::ctx::signer(), amount);
        return final {
            finalize_transfer_remote(
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
        public unverified_mailbox_state: test_hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [test_hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        public custom_hook: address,
        public hook_metadata: test_hyp_dispatch_proxy.aleo::HookMetadata,
    ) -> Final {
        if hook_metadata.gas_limit == 0u128 {
            hook_metadata.gas_limit = unverified_remote_router.gas;
        }
        let body_amount = convert_outgoing_amount(
            amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_future: Final = test_hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            custom_hook,
            hook_metadata,
            allowance,
        );
        let token_future: Final = test_arc20_eth.aleo::burn_public(std::ctx::signer(), amount);
        return final {
            finalize_transfer_remote(
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
        public message: test_hyp_mailbox.aleo::Message,
        public message_length: u32,
        public id: [u128; 2],
        public metadata: [u8; 512],
    ) -> Final {
        let recipient = validated_token_recipient(message.body, message_length, std::ctx::addr());
        let mailbox_future: Final = test_hyp_mailbox.aleo::process(
            unverified_ism,
            message,
            message_length,
            id,
            metadata,
        );
        let amount = convert_ingoing_amount(
            [message.body[2], message.body[3]],
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let token_future: Final = test_arc20_eth.aleo::mint_public(recipient, amount);
        return final {
            finalize_process(
                mailbox_future,
                unverified_app_metadata,
                message,
                token_future,
                unverified_ism,
            );
        };
    }

    // Validates the unverified inputs from the process transition and awaits its futures.
    final fn finalize_process(
        mailbox_future: Final,
        unverified_app_metadata: Metadata,
        message: test_hyp_mailbox.aleo::Message,
        token_future: Final,
        unverified_ism: address,
    ) {
        let paused_status = bridge_pause.get_or_use(true, [false, false]);
        assert_eq(paused_status[0], false);

        let metadata = app_metadata.get(true);
        assert_eq(metadata, unverified_app_metadata);

        // Check if custom ISM is provided, otherwise use the default ISM from the mailbox
        let mailbox = Mapping::get(test_hyp_mailbox.aleo::mailbox, true);
        let verify_ism = metadata.ism == NULL_ADDRESS ? mailbox.default_ism : metadata.ism;
        assert_eq(verify_ism, unverified_ism);

        // Assert that a router for the origin domain exists
        let router = remote_routers.get(message.origin_domain);

        // Assert that the router recipient matches the message sender
        assert_eq(router.recipient, message.sender);

        // Check that if the message body contains an encoding, the recipient must be the program itself.
        if message.body[4] != 0u128 || message.body[5] != 0u128 {
            let address_raw = [message.body[0], message.body[1]];
            let recipient = bytes_raw_to_address(address_raw);
            assert_eq(recipient, std::ctx::addr());
            let raw_encoding: [u128; 2] = [message.body[4], message.body[5]];

            // Recompute the amount.
            let amount = convert_ingoing_amount(
                [message.body[2], message.body[3]],
                unverified_app_metadata.local_decimals,
                unverified_app_metadata.remote_decimals,
            );
            // Populate the mapping for claimable amounts.
            let current_amount = claimable.get_or_use(raw_encoding, 0u128);
            claimable.set(raw_encoding, current_amount + amount);
        }
        mailbox_future.run();
        token_future.run();
    }

    // This function enables users to convert their token registry tokens to ARC20 tokens.
    // Note that this function is not part of the normal Hyperlane flow, but is only used to migrate existing users of the token registry based token to the new ARC20 based token.
    // This makes an external call to the legacy warp route, which has burn privileges on the token registry USDC token.  This warp route has mint privileges on the ARC-20 USDC token.
    // Funds are burned from the signer and minted to the signer.
    fn upgrade_token(amount: u128) -> Final {
        let burn_final: Final = test_hyp_warp_token_eth.aleo::burn_token_registry_eth(amount);
        let mint_final: Final = test_arc20_eth.aleo::mint_public(std::ctx::signer(), amount);
        return final {
            burn_final.run();
            mint_final.run();
        };
    }

    // This function is called by an admin to pause or unpause the bridging activity.
    fn set_pause(new_pause: bool) -> Final {
        assert_neq(std::ctx::caller(), std::ctx::caller());
        let caller = std::ctx::caller();
        return final {
            assert_eq(TESTNET_HYPERLANE_PAUSE_ADMIN, caller);
            pause.set(true, new_pause);
        };
    }

    // This function sets the pause status for inbound and outbound transactions.
    fn set_bridge_pause(new_inbound_pause: bool, new_outbound_pause: bool) -> Final {
        let caller = std::ctx::caller();
        return final {
            assert_eq(TESTNET_HYPERLANE_PAUSE_ADMIN, caller);
            bridge_pause.set(true, [new_inbound_pause, new_outbound_pause]);
        };
    }

    // Set the percentage charged on outbound private burns. An unset fee is zero.
    fn set_private_transfer_fee(public fee_bps: u16) -> Final {
        let caller = std::ctx::caller();
        return final {
            assert_eq(caller, TESTNET_HYPERLANE_FEE_ADMIN);
            assert(fee_bps < 10000u16);
            private_transfer_fee_bps = fee_bps;
        };
    }

    // Inbound claims are fee-free; the recipient receives the full claim debit.
    fn claim_private(
        secret_nonce: scalar,
        recipient: address,
        amount: u128,
        merkle_proofs: [shield_arc22_freezelist.aleo::MerkleProof__1cblycBMUKU; 2]
    ) -> (test_arc20_eth.aleo::Token, ComplianceRecord, Final) {
        assert(amount > 0u128);
        let hashed_data = BHP256::commit_to_field(recipient, secret_nonce);
        let field_bits = Serialize::to_bits_raw(hashed_data);
        let padded_bits = [false; 256];
        for i in 0u8..253u8 {
            padded_bits[i] = field_bits[i];
        }
        let raw_bytes = Deserialize::from_bits_raw::[[u128; 2]](padded_bits);
        let (eth_token, claim_private_final): (test_arc20_eth.aleo::Token, Final) = test_arc20_eth.aleo::transfer_public_to_private(
            recipient,
            amount,
        );
        let compliance_record: ComplianceRecord = ComplianceRecord {
            owner: INVESTIGATOR_ADDRESS,
            amount: amount,
            sender: std::ctx::addr(),
            recipient: recipient,
        };
        let freezelist_future: Final =
            shield_arc22_freezelist.aleo::verify_non_inclusion_priv(
                recipient, merkle_proofs,
            );
        return (
            eth_token, compliance_record,
            final {
                let paused_status = bridge_pause.get_or_use(true, [false, false]);
                assert_eq(paused_status[0], false);

                let claimable_amount: u128 = claimable.get(raw_bytes);
                assert(claimable_amount >= amount);
                claimable.set(raw_bytes, claimable_amount - amount);
                freezelist_future.run();
                claim_private_final.run();
            },
        );
    }

    fn transfer_remote_private(
        eth_record: test_arc20_eth.aleo::Token,
        public unverified_app_metadata: Metadata,
        public unverified_mailbox_state: test_hyp_dispatch_proxy.aleo::MailboxState,
        public unverified_remote_router: RemoteRouter,
        public destination: u32,
        public recipient: [u128; 2],
        public amount: u128,
        public allowance: [test_hyp_dispatch_proxy.aleo::CreditAllowance; 4],
        merkle_proofs: [shield_arc22_freezelist.aleo::MerkleProof__1cblycBMUKU; 2],
        public unverified_fee_bps: u16,
    ) -> (test_arc20_eth.aleo::Token, Final) {
        let (net_amount, fee) = private_transfer_amount(amount, unverified_fee_bps);
        let warp_address = std::ctx::addr();
        let (change_record, unshield_final): (test_arc20_eth.aleo::Token, Final) = test_arc20_eth.aleo::transfer_private_to_public(
            eth_record,
            warp_address,
            amount,
        );
        let hook_metadata = test_hyp_dispatch_proxy.aleo::HookMetadata {
            gas_limit: unverified_remote_router.gas,
            extra_data: [0u8; 64],
        };
        let body_amount = convert_outgoing_amount(
            net_amount,
            unverified_app_metadata.local_decimals,
            unverified_app_metadata.remote_decimals,
        );
        let message_body = get_message_body(recipient, body_amount);
        let dispatch_final: Final = test_hyp_dispatch_proxy.aleo::dispatch(
            unverified_mailbox_state,
            destination,
            unverified_remote_router.recipient,
            message_body,
            unverified_app_metadata.hook,
            hook_metadata,
            allowance,
        );
        let record_owner = std::ctx::signer();
        let freezelist_final: Final = shield_arc22_freezelist.aleo::verify_non_inclusion_priv(
            record_owner,
            merkle_proofs,
        );
        let burn_final: Final = test_arc20_eth.aleo::burn_public(warp_address, net_amount);
        let fee_final: Final = test_arc20_eth.aleo::transfer_public(TESTNET_HYPERLANE_FEE_ADMIN, fee);
        return (
            change_record,
            final {
                let paused_status = bridge_pause.get_or_use(true, [false, false]);
                assert_eq(paused_status[1], false);
                validate_private_transfer_fee(unverified_fee_bps);
                validate_transfer_remote(
                    unverified_remote_router,
                    destination,
                    unverified_app_metadata,
                );
                unshield_final.run();
                dispatch_final.run();
                freezelist_final.run();
                burn_final.run();
                fee_final.run();
            },
        );
    }
}
