// Standalone ARC-20 template derived from deployed arc20_eth.aleo.
// Mint/burn permissions trust the caller; burns do not require an allowance.
struct TokenAllowance {
    account: address,
    spender: address,
}

const MAX_SUPPLY: u128 = 340282366920938463463374607431768211455u128;

program arc20_token.aleo {
    record Token {
        owner: address,
        amount: u128,
    }

    mapping address_to_role: address => u16;
    mapping allowances: field => u128;
    mapping balances: address => u128;
    storage pause: bool;
    storage token_supply: u128;

    // Immutable template. The deployer administers roles and pause initially.
    // Grant the router 3u16 (mint | burn) with update_role after deployment.
    @custom
    constructor() {
        assert_eq(self.edition, 0u16);
        address_to_role.set(self.program_owner, 12u16);
        token_supply = 0u128;
    }

    fn approve_public(public spender: address, public amount: u128) -> Final {
        let key = BHP256::hash_to_field(TokenAllowance { account: self.caller, spender });
        return final {
            let current = allowances.get_or_use(key, 0u128);
            allowances.set(key, current + amount);
        };
    }

    fn unapprove_public(public spender: address, public amount: u128) -> Final {
        let key = BHP256::hash_to_field(TokenAllowance { account: self.caller, spender });
        return final {
            let current = allowances.get_or_use(key, 0u128);
            assert(current >= amount);
            allowances.set(key, current - amount);
        };
    }

    fn transfer_public(public recipient: address, public amount: u128) -> Final {
        let sender = self.caller;
        return final {
            let balance = balances.get_or_use(sender, 0u128);
            assert(balance >= amount);
            balances.set(sender, balance - amount);
            let received = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, received + amount);
        };
    }

    fn transfer_public_as_signer(public recipient: address, public amount: u128) -> Final {
        let sender = self.signer;
        return final {
            let balance = balances.get_or_use(sender, 0u128);
            assert(balance >= amount);
            balances.set(sender, balance - amount);
            let received = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, received + amount);
        };
    }

    fn transfer_private(token: Token, recipient: address, amount: u128) -> (Token, Token) {
        let remainder = token.amount - amount;
        return (Token { owner: token.owner, amount: remainder }, Token { owner: recipient, amount });
    }

    fn transfer_private_to_public(token: Token, public recipient: address, public amount: u128) -> (Token, Final) {
        let remainder = token.amount - amount;
        let change = Token { owner: token.owner, amount: remainder };
        return (change, final {
            let balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, balance + amount);
        });
    }

    fn transfer_public_to_private(recipient: address, public amount: u128) -> (Token, Final) {
        let output = Token { owner: recipient, amount };
        let sender = self.caller;
        return (output, final {
            let balance = balances.get_or_use(sender, 0u128);
            assert(balance >= amount);
            balances.set(sender, balance - amount);
        });
    }

    fn transfer_from_public(public owner: address, public recipient: address, public amount: u128) -> Final {
        let key = BHP256::hash_to_field(TokenAllowance { account: owner, spender: self.caller });
        return final {
            let approved = allowances.get_or_use(key, 0u128);
            assert(approved >= amount);
            allowances.set(key, approved - amount);
            let balance = balances.get_or_use(owner, 0u128);
            assert(balance >= amount);
            balances.set(owner, balance - amount);
            let received = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, received + amount);
        };
    }

    fn transfer_from_public_to_private(public owner: address, recipient: address, public amount: u128) -> (Token, Final) {
        let key = BHP256::hash_to_field(TokenAllowance { account: owner, spender: self.caller });
        let output = Token { owner: recipient, amount };
        return (output, final {
            let approved = allowances.get_or_use(key, 0u128);
            assert(approved >= amount);
            allowances.set(key, approved - amount);
            let balance = balances.get_or_use(owner, 0u128);
            assert(balance >= amount);
            balances.set(owner, balance - amount);
        });
    }

    fn shield(public amount: u128) -> (Token, Final) {
        let output = Token { owner: self.caller, amount };
        let sender = self.caller;
        return (output, final {
            let balance = balances.get_or_use(sender, 0u128);
            assert(balance >= amount);
            balances.set(sender, balance - amount);
        });
    }

    fn unshield(token: Token, amount: u128) -> (Token, Final) {
        let remainder = token.amount - amount;
        let change = Token { owner: token.owner, amount: remainder };
        let owner = token.owner;
        return (change, final {
            let balance = balances.get_or_use(owner, 0u128);
            balances.set(owner, balance + amount);
        });
    }

    fn join(first: Token, second: Token) -> Token {
        assert(first.owner == second.owner);
        let amount = first.amount + second.amount;
        return Token { owner: first.owner, amount };
    }

    fn split(token: Token, amount: u128) -> (Token, Token) {
        let output = Token { owner: token.owner, amount };
        let remainder = token.amount - amount;
        return (output, Token { owner: token.owner, amount: remainder });
    }

    fn mint_public(public recipient: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let role = address_to_role.get(caller);
            assert((role & 1u16) == 1u16);
            assert_eq(pause.unwrap_or(false), false);
            let balance = balances.get_or_use(recipient, 0u128);
            balances.set(recipient, amount + balance);
            let supply = token_supply.unwrap_or(0u128) + amount;
            assert(supply <= MAX_SUPPLY);
            token_supply = supply;
        };
    }

    fn mint_private(recipient: address, amount: u128) -> (Token, Final) {
        let output = Token { owner: recipient, amount };
        let caller = self.caller;
        return (output, final {
            let role = address_to_role.get(caller);
            assert((role & 1u16) == 1u16);
            assert_eq(pause.unwrap_or(false), false);
            let supply = token_supply.unwrap_or(0u128) + amount;
            assert(supply <= MAX_SUPPLY);
            token_supply = supply;
        });
    }

    fn burn_public(public owner: address, public amount: u128) -> Final {
        let caller = self.caller;
        return final {
            let role = address_to_role.get(caller);
            assert((role & 2u16) == 2u16);
            assert_eq(pause.unwrap_or(false), false);
            let balance = balances.get_or_use(owner, 0u128);
            assert(balance >= amount);
            balances.set(owner, balance - amount);
            let supply = token_supply.unwrap_or(0u128);
            assert(supply >= amount);
            token_supply = supply - amount;
        };
    }

    fn burn_private(token: Token, amount: u128) -> (Token, Final) {
        let remainder = token.amount - amount;
        let change = Token { owner: token.owner, amount: remainder };
        let caller = self.caller;
        return (change, final {
            let role = address_to_role.get(caller);
            assert((role & 2u16) == 2u16);
            assert_eq(pause.unwrap_or(false), false);
            let supply = token_supply.unwrap_or(0u128);
            assert(supply >= amount);
            token_supply = supply - amount;
        });
    }

    // Roles: mint=1, burn=2, pause=4, administer=8. Replaces the full mask.
    fn update_role(public account: address, role: u16) -> Final {
        let caller = self.caller;
        return final {
            let current = address_to_role.get(caller);
            assert((current & 8u16) == 8u16);
            if caller == account {
                assert((role & 8u16) == 8u16);
            }
            address_to_role.set(account, role);
        };
    }

    fn set_pause_status(public paused: bool) -> Final {
        let caller = self.caller;
        return final {
            let role = address_to_role.get(caller);
            assert((role & 4u16) == 4u16);
            pause = paused;
        };
    }

    view fn balance_of(account: address) -> u128 {
        return balances.get_or_use(account, 0u128);
    }

    view fn allowance(owner: address, spender: address) -> u128 {
        let key = BHP256::hash_to_field(TokenAllowance { account: owner, spender });
        return allowances.get_or_use(key, 0u128);
    }

    view fn supply() -> u128 { return token_supply.unwrap_or(0u128); }
    view fn max_supply() -> u128 { return MAX_SUPPLY; }
    view fn decimals() -> u8 { return 18u8; }
    view fn name() -> identifier { return 'TOKEN'; }
    view fn symbol() -> identifier { return 'TOKEN'; }
}
