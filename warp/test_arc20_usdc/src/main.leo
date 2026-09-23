import test_arc20_multisig_core.aleo;

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

// Roles can be assigned using bitmasking to allow multiple roles per address
const NONE_ROLE: u16 = 0u16;
const MINTER_ROLE: u16 = 1u16;
const BURNER_ROLE: u16 = 2u16;
const PAUSE_ROLE: u16 = 4u16;   // can pause/unpause transfers
const MANAGER_ROLE: u16 = 8u16; // can only assign roles

const PAUSE_STATUS_INDEX: bool = true;

const TESTNET_HYPERLANE_MANAGER_KEY_0: address = aleo1axurgcdhztu8m23ttzju38qzchtzs8kyk7nga9n58zyrmnxzmuqqf6wqdc;

const MAX_SUPPLY: u128 = 340282366920938463463374607431768211455u128;

final fn add_supply(amount: u128) {
    let supply = token_supply.unwrap_or(0u128);
    let new_supply = supply + amount;
    assert(new_supply <= MAX_SUPPLY);
    token_supply = new_supply;
}

final fn sub_supply(amount: u128) {
    let supply = token_supply.unwrap_or(0u128);
    assert(supply >= amount);
    token_supply = supply - amount;
}

program test_arc20_usdc.aleo: IARC20::IARC20 {
    record Token {
        owner:  address,
        amount: u128,
    }

    mapping address_to_role: address => u16;
    mapping allowances: field   => u128;
    mapping balances:   address => u128;
    mapping pause: bool => bool;
    mapping initialized: bool => bool;

    storage token_supply: u128;

    @custom
    constructor() {
        // Only require multisig for upgrades - initial deployment has no checks.
        if self.edition > 0u16 {
            let signing_op_id = BHP256::hash_to_field(ChecksumEdition { checksum: self.checksum, edition: self.edition });
            let wallet_signing_op_id_hash = BHP256::hash_to_field(test_arc20_multisig_core.aleo::WalletSigningOpId { wallet_id: self.address, signing_op_id: signing_op_id });
            let signing_complete = test_arc20_multisig_core.aleo::completed_signing_ops.contains(wallet_signing_op_id_hash);
            assert(signing_complete);
        } 
    }

    // Read-only ARC-20 metadata and balance accessors.

    view fn balance_of(account: address) -> u128 {
        return balances.get_or_use(account, 0u128);
    }

    view fn allowance(owner: address, spender: address) -> u128 {
        let key = BHP256::hash_to_field(TokenAllowance { account: owner, spender: spender });
        return allowances.get_or_use(key, 0u128);
    }

    view fn supply() -> u128 {
        return token_supply.unwrap_or(0u128);
    }

    view fn max_supply() -> u128 {
        return MAX_SUPPLY;
    }

    view fn decimals() -> u8 {
        return 6u8;
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
            let current: u128 = allowances.get_or_use(key, 0u128);
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
            let prev_from: u128 = balances.get_or_use(from, 0u128);
            assert(prev_from >= amount);
            balances.set(from, prev_from - amount);
            let prev_to: u128 = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, prev_to + amount);
        };
    }

    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final {
        let from: address = self.signer;
        return final {
            let prev_from: u128 = balances.get_or_use(from, 0u128);
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
                let prev: u128 = balances.get_or_use(from, 0u128);
                assert(prev >= amount);
                balances.set(from, prev - amount);
            },
        );
    }

    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final {
        let spender: address = self.caller;
        let key: field = BHP256::hash_to_field(TokenAllowance { account: owner, spender: spender });
        return final {
            let current: u128 = allowances.get_or_use(key, 0u128);
            assert(current >= amount);
            allowances.set(key, current - amount);
            let prev_owner: u128 = balances.get_or_use(owner, 0u128);
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
                let current: u128 = allowances.get_or_use(key, 0u128);
                assert(current >= amount);
                allowances.set(key, current - amount);
                let prev_owner: u128 = balances.get_or_use(owner, 0u128);
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
                let prev: u128 = balances.get_or_use(from, 0u128);
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

            let is_paused: bool = pause.get_or_use(PAUSE_STATUS_INDEX, false);
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

                let is_paused: bool = pause.get_or_use(PAUSE_STATUS_INDEX, false);
                assert_eq(is_paused, false);

                add_supply(amount);
            },
        );
    }

    fn burn_public(public owner: address, public amount: u128) -> Final {
        let caller: address = self.caller;
        return final {
            let role: u16 = address_to_role.get(caller);
            assert(role & BURNER_ROLE == BURNER_ROLE);

            let is_paused: bool = pause.get_or_use(PAUSE_STATUS_INDEX, false);
            assert_eq(is_paused, false);

            // Update the balance
            let balance = balances.get_or_use(owner, 0u128);
            assert(balance >= amount);
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

                let is_paused: bool = pause.get_or_use(PAUSE_STATUS_INDEX, false);
                assert_eq(is_paused, false);

                sub_supply(amount);
            },
        );
    }
    
    // ----------------------------------------------------------------
    //  ADMIN RESTRICTED FUNCTIONS
    // ----------------------------------------------------------------
    
    fn initialize_token(manager_address: address) -> Final {
        assert(self.caller == TESTNET_HYPERLANE_MANAGER_KEY_0);
        return final {
            // Prevent re-initialization of the token info.
            let already_initialized: bool = initialized.get_or_use(true, false);
            assert_eq(already_initialized, false);
            
            // Initialize the circulating supply.
            token_supply = 0u128;

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