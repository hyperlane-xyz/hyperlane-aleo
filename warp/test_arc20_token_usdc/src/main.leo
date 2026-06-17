import test_hyp_multisig_core.aleo;

// The Hyperlane wrapped USDC token that implements `arc20_interface::ARC20Metadata`.

// Read-only accessors are declared with `view fn` so off-consensus callers
// (Rust libraries, JS SDKs, block explorers) can query token state without
// authorizing a transition.

struct ChecksumEdition {
        checksum: [u8; 32],
        edition: u16,
    }

// Allowance keys are stored as `field`. We hash an (account, spender) pair
// through this small struct to derive the key.
struct TokenAllowance {
    account: address,
    spender: address,
}

// Token metadata constants. `identifier` is not a storable type, so we
// surface name/symbol as program-level constants rather than `storage`.
// Public state describing the wrapped token.
struct TokenInfo {
    name: u128,
    symbol: u128,
    decimals: u8,
    supply: u128,
    max_supply: u128,
}

// Roles can be assigned using bitmasking to allow multiple roles per address
const NONE_ROLE: u16 = 0u16;
const MINTER_ROLE: u16 = 1u16;
const BURNER_ROLE: u16 = 2u16;
const PAUSE_ROLE: u16 = 4u16;   // can pause/unpause transfers
const MANAGER_ROLE: u16 = 8u16; // can only assign roles

const PAUSE_STATUS_INDEX: bool = true;

const TESTNET_HYPERLANE_MANAGER_KEY_0: address = aleo1h9x8mx3yc8uqylsrguuqklkq9us4t7vkd7z9wxp04nt0p8sxjgzqhth7t0;

fn default_token_info() -> TokenInfo {
    return TokenInfo {
        // USDC
        name: 113416722041000672961669155589399248896u128,
        // USDC
        symbol: 113416722041000672961669155589399248896u128,
        decimals: 6u8,
        supply: 0u128,
        max_supply: 18000000000000000u128,
    };
}

final fn add_supply(amount: u128) {
    let info = token_info.unwrap_or(default_token_info());

    // Check that the token supply + amount <= max_supply
    let new_supply: u128 = info.supply + amount;
    assert(new_supply <= info.max_supply);

    token_info = TokenInfo {
        name: info.name,
        symbol: info.symbol,
        decimals: info.decimals,
        supply: new_supply,
        max_supply: info.max_supply,
    };
}

final fn sub_supply(amount: u128) {
    let info = token_info.unwrap_or(default_token_info());

    token_info = TokenInfo {
        name: info.name,
        symbol: info.symbol,
        decimals: info.decimals,
        supply: info.supply - amount,
        max_supply: info.max_supply,
    };
}

program test_arc20_token_usdc.aleo: IARC20::IARC20 {
    record Token {
        owner:  address,
        amount: u128,
    }

    mapping address_to_role: address => u16;
    mapping allowances: field   => u128;
    mapping balances:   address => u128;
    mapping pause: bool => bool;
    mapping initialized: bool => bool;

    storage token_info: TokenInfo;

    @custom
    constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(ChecksumEdition { checksum: self.checksum, edition: self.edition });
            let wallet_signing_op_id_hash = BHP256::hash_to_field(test_hyp_multisig_core.aleo::WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
            let signing_complete = test_hyp_multisig_core.aleo::completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        } 
    }

    // ----------------------------------------------------------------
    //  READ-ONLY ACCESSORS (`view fn`)
    //
    // snarkVM requires a view body to contain at least one command
    // (something like `get` / `assert` / `add`). For `decimals`,
    // `name`, and `symbol` the returned value is a compile-time
    // constant, so we touch `total_supply_value` to give the emitted
    // bytecode a `get.or_use` instruction to anchor on.
    // ----------------------------------------------------------------

    view fn balance_of(account: address) -> u128 {
        return balances.get_or_use(account, 0u128);
    }

    view fn allowance(owner: address, spender: address) -> u128 {
        let key = BHP256::hash_to_field(TokenAllowance { account: owner, spender: spender });
        return allowances.get_or_use(key, 0u128);
    }

    view fn supply() -> u128 {
        let info: TokenInfo = token_info.unwrap_or(default_token_info());
        return info.supply;
    }

    view fn max_supply() -> u128 {
        let info: TokenInfo = token_info.unwrap_or(default_token_info());
        return info.max_supply;
    }

    view fn decimals() -> u8 {
        let info: TokenInfo = token_info.unwrap_or(default_token_info());
        return info.decimals;
    }

    view fn name() -> identifier {
        return 'USDC';
    }

    view fn symbol() -> identifier {
        return 'USDC';
    }
    
    // ----------------------------------------------------------------
    //  APPROVAL FUNCTIONS
    // ----------------------------------------------------------------

    fn approve_public(public spender: address, public amount: u128) -> Final {
        let key: field = BHP256::hash_to_field(TokenAllowance { account: self.caller, spender: spender });
        return final {
            let current: u128 = allowances.get_or_use(key, 0u128);
            allowances.set(key, current + amount);
        };
    }

    fn unapprove_public(public spender: address, public amount: u128) -> Final {
        let key: field = BHP256::hash_to_field(TokenAllowance { account: self.caller, spender: spender });
        return final {
            let current: u128 = allowances.get(key);
            assert(current >= amount);
            allowances.set(key, current - amount);
        };
    }

    // ----------------------------------------------------------------
    //  TRANSFER FUNCTIONS
    // ----------------------------------------------------------------

    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let from: address = self.caller;
        return final {
            let prev_from: u128 = balances.get(from);
            assert(prev_from >= amount);
            balances.set(from, prev_from - amount);
            let prev_to: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_to + amount);
        };
    }

    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final {
        let from: address = self.signer;
        return final {
            let prev_from: u128 = balances.get(from);
            assert(prev_from >= amount);
            balances.set(from, prev_from - amount);
            let prev_to: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_to + amount);
        };
    }

    fn transfer_private(input: Token, recipient: address, amount: u128) -> (Token, Token) {
        let change: Token   = Token { owner: input.owner, amount: input.amount - amount };
        let received: Token = Token { owner: recipient,   amount: amount };
        return (change, received);
    }

    fn transfer_private_to_public(input: Token, public recipient: address, public amount: u128) -> (Token, Final) {
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (
            change,
            final {
                let prev: u128 = balances.get_or_use(recipient, 0u128);
                balances.set(recipient, prev + amount);
            },
        );
    }

    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final) {
        let from: address = self.caller;
        let received: Token = Token { owner: recipient, amount: amount };
        return (
            received,
            final {
                let prev: u128 = balances.get(from);
                assert(prev >= amount);
                balances.set(from, prev - amount);
            },
        );
    }

    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final {
        let spender: address = self.caller;
        let key: field = BHP256::hash_to_field(TokenAllowance { account: owner, spender: spender });
        return final {
            let current: u128 = allowances.get(key);
            assert(current >= amount);
            allowances.set(key, current - amount);
            let prev_owner: u128 = balances.get(owner);
            assert(prev_owner >= amount);
            balances.set(owner, prev_owner - amount);
            let prev_to: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_to + amount);
        };
    }

    fn transfer_from_public_to_private(
        public owner: address,
        recipient: address,
        public amount: u128,
    ) -> (Token, Final) {
        let spender: address = self.caller;
        let key: field = BHP256::hash_to_field(TokenAllowance { account: owner, spender: spender });
        let received: Token = Token { owner: recipient, amount: amount };
        return (
            received,
            final {
                let current: u128 = allowances.get(key);
                assert(current >= amount);
                allowances.set(key, current - amount);
                let prev_owner: u128 = balances.get(owner);
                assert(prev_owner >= amount);
                balances.set(owner, prev_owner - amount);
            },
        );
    }

    // ----------------------------------------------------------------
    //  SHIELD / UNSHIELD
    //
    //  Kept here as impl-specific helpers; not part of the ARC20
    //  interface contract.
    // ----------------------------------------------------------------

    fn shield(public amount: u128) -> (Token, Final) {
        let from: address   = self.caller;
        let received: Token = Token { owner: from, amount: amount };
        return (
            received,
            final {
                let prev: u128 = balances.get(from);
                assert(prev >= amount);
                balances.set(from, prev - amount);
            },
        );
    }

    fn unshield(input: Token, amount: u128) -> (Token, Final) {
        let change: Token  = Token { owner: input.owner, amount: input.amount - amount };
        let owner: address = input.owner;
        return (
            change,
            final {
                let prev: u128 = balances.get_or_use(owner, 0u128);
                balances.set(owner, prev + amount);
            },
        );
    }

    // ----------------------------------------------------------------
    //  ARC20: JOIN / SPLIT
    // ----------------------------------------------------------------

    fn join(input_1: Token, input_2: Token) -> Token {
        assert(input_1.owner == input_2.owner);
        return Token { owner: input_1.owner, amount: input_1.amount + input_2.amount };
    }

    fn split(input: Token, amount: u128) -> (Token, Token) {
        let a: Token = Token { owner: input.owner, amount: amount };
        let b: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (a, b);
    }

    // ----------------------------------------------------------------
    //  MINT / BURN
    // ----------------------------------------------------------------

    fn mint_public(public recipient: address, public amount: u128) -> Final {
        let caller: address = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & MINTER_ROLE == MINTER_ROLE);

            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);

            // Update the balance
            let balance = balances.get_or_use(recipient, 0u128);
            let new_balance = amount + balance;
            balances.set(recipient, new_balance);

            add_supply(amount);
        };
    }

    fn mint_private(recipient: address, amount: u128) -> (Token, Final) {
        let caller: address = self.caller;
        let received: Token = Token { owner: recipient, amount: amount };
        return (
            received,
            final {
                let role: u16 = address_to_role.get(caller);
                assert(role & MINTER_ROLE == MINTER_ROLE);

                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);

                let info = token_info.unwrap_or(default_token_info());

                add_supply(amount);
            },
        );
    }

    fn burn_public(public owner: address, public amount: u128) -> Final {
        let caller: address = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & BURNER_ROLE == BURNER_ROLE);

            let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
            assert_eq(is_paused, false);

            // Update the balance
            let balance = balances.get(owner);
            let new_balance = balance - amount;
            balances.set(owner, new_balance);

            sub_supply(amount);
        };
    }

    fn burn_private(input: Token, amount: u128) -> (Token, Final) {
        let caller: address = self.caller;
        let change: Token = Token { owner: input.owner, amount: input.amount - amount };
        return (
            change,
            final {
                let role: u16 = address_to_role.get(caller);
                assert(role & BURNER_ROLE == BURNER_ROLE);

                let is_paused: bool = pause.get(PAUSE_STATUS_INDEX);
                assert_eq(is_paused, false);

                sub_supply(amount);
            },
        );
    }
    
    // ----------------------------------------------------------------
    //  ADMIN RESTRICTED FUNCTIONS
    // ----------------------------------------------------------------
    
    fn initialize_token(name: u128, symbol: u128, decimals: u8, max_supply: u128, manager_address: address) -> Final {
        assert(self.caller == TESTNET_HYPERLANE_MANAGER_KEY_0);
        return final {
            // Prevent re-initialization of the token info.
            let already_initialized: bool = initialized.get_or_use(true, false);
            assert_eq(already_initialized, false);
            
            // Initialize the token info struct with the provided parameters.
            token_info = TokenInfo {
                name: name,
                symbol: symbol,
                decimals: decimals,
                supply: 0u128,
                max_supply: max_supply,
            };

            // Set the manager role for the provided manager address.
            address_to_role.set(manager_address, MANAGER_ROLE);
            // Mark the token as initialized.
            initialized.set(true, true);
        };
    }
    
    // Updates the address assigned to a given role.
    // Can only be called by the current role manager.
    fn update_role(public new_address: address, new_role: u16) -> Final {
        let caller: address = self.caller;
        return final {
            let current_role: u16 = address_to_role.get(caller);
            assert(current_role & MANAGER_ROLE == MANAGER_ROLE);
            
            if (caller == new_address) { 
                assert(new_role & MANAGER_ROLE == MANAGER_ROLE); 
            }

            address_to_role.set(new_address, new_role);
        };
    }

    // Pause or unpause all transfers. Can only be called by addresses with the PAUSE_ROLE.
    fn set_pause_status(public is_paused: bool) -> Final {
        let caller: address = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & PAUSE_ROLE == PAUSE_ROLE);
            pause.set(PAUSE_STATUS_INDEX, is_paused);
        };
    }
}