from Crypto.Hash import keccak
from . import LOCAL_DOMAIN, get_mapping_value as get_program_mapping_value, transact as cwd_transact, to_aleo_like, CALLER, NULL_ADDRESS
import random
import pytest

STATE: dict[str, str] = {}
DEFAULT_GAS_LIMIT=50000
TOKEN_EXCHANGE_RATE=10000000000

# Python implementation of https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/main/solidity/contracts/libs/Merkle.sol
ZERO_HASHES=[
    "0000000000000000000000000000000000000000000000000000000000000000",
    "ad3228b676f7d3cd4284a5443f17f1962b36e491b30a40b2405849e597ba5fb5",
    "b4c11951957c6f8f642c4af61cd6b24640fec6dc7fc607ee8206a99e92410d30",
    "21ddb9a356815c3fac1026b6dec5df3124afbadb485c9ba5a3e3398a04b7ba85",
    "e58769b32a1beaf1ea27375a44095a0d1fb664ce2dd358e7fcbfb78c26a19344",
    "0eb01ebfc9ed27500cd4dfc979272d1f0913cc9f66540d7e8005811109e1cf2d",
    "887c22bd8750d34016ac3c66b5ff102dacdd73f6b014e710b51e8022af9a1968",
    "ffd70157e48063fc33c97a050f7f640233bf646cc98d9524c6b92bcf3ab56f83",
    "9867cc5f7f196b93bae1e27e6320742445d290f2263827498b54fec539f756af",
    "cefad4e508c098b9a7e1d8feb19955fb02ba9675585078710969d3440f5054e0",
    "f9dc3e7fe016e050eff260334f18a5d4fe391d82092319f5964f2e2eb7c1c3a5",
    "f8b13a49e282f609c317a833fb8d976d11517c571d1221a265d25af778ecf892",
    "3490c6ceeb450aecdc82e28293031d10c7d73bf85e57bf041a97360aa2c5d99c",
    "c1df82d9c4b87413eae2ef048f94b4d3554cea73d92b0f7af96e0271c691e2bb",
    "5c67add7c6caf302256adedf7ab114da0acfe870d449a3a489f781d659e8becc",
    "da7bce9f4e8618b6bd2f4132ce798cdc7a60e7e1460a7299e3c6342a579626d2",
    "2733e50f526ec2fa19a22b31e8ed50f23cd1fdf94c9154ed3a7609a2f1ff981f",
    "e1d3b5c807b281e4683cc6d6315cf95b9ade8641defcb32372f1c126e398ef7a",
    "5a2dce0a8a7f68bb74560f8f71837c2c2ebbcbf7fffb42ae1896f13f7c7479a0",
    "b46a28b6f55540f89444f63de0378e3d121be09e06cc9ded1c20e65876d36aa0",
    "c65e9645644786b620e2dd2ad648ddfcbf4a7e5b1a3a4ecfe7f64667a3f0b7e2",
    "f4418588ed35a2458cffeb39b93d26f18d2ab13bdce6aee58e7b99359ec2dfd9",
    "5a9c16dc00d6ef18b7933a6f8dc65ccb55667138776f7dea101070dc8796e377",
    "4df84f40ae0c8229d0d6069e5c8f39a7c299677a09d367fc7b05e3bc380ee652",
    "cdc72595f74c7b1043d0e1ffbab734648c838dfb0527d971b602bc216c9619ef",
    "0abf5ac974a1ed57f4050aa510dd9c74f508277b39d7973bb2dfccc5eeb0618d",
    "b8cd74046ff337f0a7bf2c8e03e10f642c1886798d71806ab1e888d9e5ee87d0",
    "838c5655cb21c6cb83313b5a631175dff4963772cce9108188b34ac87c81c41e",
    "662ee4dd2dd7b2bc707961b1e646c4047669dcb6584f0d8d770daf5d7e7deb2e",
    "388ab20e2573d171a88108e79d820e98f26c0b84aa8b2f4aa4968dbb818ea322",
    "93237c50ba75ee485f4c22adf2f741400bdf8d6a9cc7df7ecae576221665d735",
    "8448818bb4ae4562849e949e17ac16e0be16688e156b5cf15e098c627c0056a9",
]
class MerkleTree:
    """
    Python implementation mirroring the Solidity Merkle tree logic.
    Branch nodes are stored as 32-byte hashes (hex string, 64 chars).
    """

    def __init__(self, context: list[str]):
        self.ZERO_HASHES = context
        self.TREE_DEPTH = len(context)
        # Initialize branch with zero hashes
        self.branch: list[str] = list(context)
        self.count: int = 0
        # Max leaves = 2 ** TREE_DEPTH (same as Solidity constant pattern)
        self.MAX_LEAVES = 1 << self.TREE_DEPTH

    @staticmethod
    def _keccak_concat(a_hex: str, b_hex: str) -> str:
        """
        keccak256(abi.encodePacked(a, b)) equivalent:
        concatenate raw bytes of the two 32-byte hex strings, then hash.
        """
        return keccak.new(digest_bits=256, data=bytes.fromhex(a_hex + b_hex)).hexdigest()

    def insert(self, leaf_hex: str) -> None:
        """
        Insert a new leaf (32-byte hex string). Mirrors Solidity insert logic.
        """
        if self.count >= self.MAX_LEAVES:
            raise ValueError("merkle tree full")

        self.count += 1
        size = self.count
        node = leaf_hex

        for i in range(self.TREE_DEPTH):
            if (size & 1) == 1:
                # Store raw hash
                self.branch[i] = node
                return
            # Hash existing branch node with current node
            node = self._keccak_concat(self.branch[i], node)
            size //= 2

        # Should always have returned earlier
        raise AssertionError("unreachable")

    def root(self) -> str:
        """
        Compute current root following Solidity root() logic.
        Starts with zero bytes32 (all zeros).
        """
        current = "0" * 64  # bytes32(0)
        index = self.count

        for i in range(self.TREE_DEPTH):
            ith_bit = (index >> i) & 0x01
            next_hash = self.branch[i]
            if ith_bit == 1:
                current = self._keccak_concat(next_hash, current)
            else:
                current = self._keccak_concat(current, self.ZERO_HASHES[i])

        return current

    @staticmethod
    def hash_to_u128_pair(h: str) -> list[int]:
        """
        Convert 32-byte hex string to two little-endian u128 integers.
        """
        b = bytes.fromhex(h)
        return [
            int.from_bytes(b[:16], "little"),
            int.from_bytes(b[16:], "little"),
        ]

    def branch_as_u128_pairs(self) -> list[list[int]]:
        return [self.hash_to_u128_pair(h) for h in self.branch]


def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value("test_hyp_hook_manager.aleo", mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="hook_manager", **kwargs)

def _current_nonce() -> int:
    return int(get_mapping_value("nonce", "true") or 0)

def hash(data: str) -> str:
    k = keccak.new(digest_bits=256)
    k.update(bytes.fromhex(data))
    return k.hexdigest()

def hash_to_u128(data: str) -> list[int]:
    b = bytes.fromhex(data)
    first = int.from_bytes(b[:16], "little")
    second = int.from_bytes(b[16:], "little")
    return [first, second]

def u128_to_hash(u128_pair: list[int]) -> str:
    first_bytes = u128_pair[0].to_bytes(16, "little")
    second_bytes = u128_pair[1].to_bytes(16, "little")
    return (first_bytes + second_bytes).hex()

def test_create_noop():
    current_nonce = _current_nonce()
    result = transact("execute", "init_noop")
    assert result.get("success"), f"Noop Hook init failed: {result}"
    address = get_mapping_value("hook_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    assert isinstance(address, str) and address.startswith("aleo"), "No noop Hook address returned"
    STATE["noop_hook"] = address

def test_init_merkle_tree_hook():
    current_nonce = _current_nonce()
    result = transact("execute", "init_merkle_tree", CALLER)
    assert result.get("success"), f"Merkle Tree Hook init failed: {result}"
    address = get_mapping_value("hook_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    assert isinstance(address, str) and address.startswith("aleo"), "No Merkle Tree Hook address returned"
    merkle_tree_hook = get_mapping_value("merkle_tree_hooks", address)
    tree = merkle_tree_hook.get("tree")
    for i, branch in enumerate(tree.get("branch")):
        converted_branch = hash_to_u128(ZERO_HASHES[i])
        assert branch == converted_branch, f"Unexpected non-zero hash in branch {i}"
    local_tree = MerkleTree(ZERO_HASHES)
    assert tree.get("count") == local_tree.count, "Incorrect leaf count"
    assert merkle_tree_hook.get("root") == hash_to_u128(local_tree.root()), "Incorrect root"
    STATE["merkle_tree_hook"] = address

def test_init_igp():
    current_nonce = _current_nonce()
    result = transact("execute", "init_igp")
    assert result.get("success"), f"IGP Hook init failed: {result}"
    address = get_mapping_value("hook_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    assert isinstance(address, str) and address.startswith("aleo"), "No IGP Hook address returned"
    STATE["igp_hook"] = address

def test_set_destination_gas_igp():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]
    config = {
        "gas_overhead": 10,
        "exchange_rate": 5000000000,
        "gas_price": 4,
    }

    result = transact("execute", "set_destination_gas_config", igp_address, "1u32", to_aleo_like(config, numeric_suffix="128"))
    assert result.get("success"), f"Set destination gas failed: {result}"

    key = f"{{igp:{igp_address},destination:1u32}}"
    destination_gas = get_mapping_value("destination_gas_configs", key)
    assert destination_gas == config, "Incorrect destination gas config"

def test_invalid_set_destination_gas_igp():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]
    config = {
        "gas_overhead": 10,
        "exchange_rate": 5000000000,
        "gas_price": 4,
    }
    # Call set_destination_gas_config from an account without owner privileges
    result = transact("execute", "set_destination_gas_config", igp_address, "1u32", to_aleo_like(config, numeric_suffix="128"), "--private-key", "APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh")
    assert not result.get("success"), "Set destination gas should have failed due to missing gas_price"

def test_pay_for_gas():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]

    gas_limit = 10
    exchange_rate = 5000000000
    gas_price = 4
    credits_amount = (gas_limit * exchange_rate * gas_price) // TOKEN_EXCHANGE_RATE
    destination = 1
    igp = get_mapping_value("igps", igp_address)
    event_count_before = int(igp.get("count"))

    result = transact("execute", "pay_for_gas", igp_address, "[0u128,0u128]", f"{destination}u32", f"{gas_limit}u128", f"{credits_amount}u64")
    assert result.get("success"), f"Pay for gas failed: {result}"

    expected_event = {
        "id": [0, 0],
        "destination_domain": destination,
        "gas_amount": gas_limit,
        "payment": credits_amount,
        "index": event_count_before,
    }
    key = f"{{hook:{igp_address},index:{event_count_before}u32}}"
    gas_payment_event = get_mapping_value("gas_payment_events", key)
    assert gas_payment_event == expected_event, "Incorrect gas payment event"

    igp_state = get_mapping_value("igps", igp_address)
    assert igp_state == {
        "hook_owner": igp.get("hook_owner"),
        "nonce": igp.get("nonce"),
        "balance": igp.get("credits_amount", 0) + credits_amount,
        "count": event_count_before + 1,
    }, "Incorrect IGP state after payment"

def test_invalid_pay_for_gas():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]

    gas_limit = 10
    invalid_credits_amount = 1337  # Some random invalid credits amount that does not equal to the quote
    destination = "1u32"
    igp = get_mapping_value("igps", igp_address)

    result = transact("execute", "pay_for_gas", igp_address, "[0u128,0u128]", destination, f"{gas_limit}u128", f"{invalid_credits_amount}u64")
    assert not result.get("success"), "Pay for gas should have failed due to incorrect credits amount"

    igp_state_after = get_mapping_value("igps", igp_address)
    assert igp_state_after == igp, "IGP state should not have changed after failed payment"

def test_claim_igp():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]
    igp = get_mapping_value("igps", igp_address)
    result = transact("execute", "claim", igp_address, f"{igp.get('balance')}u64")
    assert result.get("success"), f"Claim failed: {result}"
    igp_after = get_mapping_value("igps", igp_address)
    assert igp_after == {
        "hook_owner": igp.get("hook_owner"),
        "nonce": igp.get("nonce"),
        "balance": 0,
        "count": igp.get("count"),
    }, "Incorrect IGP state after claim"

def test_igp_claim_cannot_exceed_amount_even_if_hook_manager_has_enough_balance():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]
    igp = get_mapping_value("igps", igp_address)

    empty_igp = {
        "hook_owner": igp.get("hook_owner"),
        "nonce": igp.get("nonce"),
        "balance": 0,
        "count": igp.get("count"),
    }
    igp_before = get_mapping_value("igps", igp_address)
    assert empty_igp == igp_before, "Incorrect IGP state after claim"

    result = transact("execute", "credits.aleo/transfer_public", igp_address, "2000u64")
    assert result.get("success"), "Couldnt transfer aleo credits to hook manager"

    result = transact("execute", "claim", igp_address, "1000u64")
    assert not result.get("success"), f"Claim should have failed: {result}"

    igp_after = get_mapping_value("igps", igp_address)
    assert igp_after == empty_igp, "Incorrect IGP state after claim"

    balance_after = get_program_mapping_value("credits.aleo", "account", igp_address)
    assert balance_after == "2000"

def test_invalid_claim_igp():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]
    result = transact("execute", "claim", igp_address, "1337u64")
    assert not result.get("success"), f"Claim should have failed: {result}"

def _dispatch_random_message():
    recipient = [random.randint(0, 255) for _ in range(32)]
    # message body is 8 u128 values (1024 bits)
    message_body = [random.randint(0, 2**128 - 1) for _ in range(16)]
    # now we manually craft a message and dispatch it
    # because we don't use the dispatch proxy here, we have to call the hooks manually
    result = cwd_transact("execute", "dispatch", "1u32", to_aleo_like(recipient, numeric_suffix=8), to_aleo_like(message_body, numeric_suffix=128), CALLER, cwd="mailbox")
    assert result.get("success"), f"Dispatch failed: {result}"

@pytest.fixture(scope='module', autouse=True)
def initialize_mailbox():
    mailbox = get_program_mapping_value("test_hyp_mailbox.aleo", "mailbox", "true")

    if not mailbox:
        # Initialize mailbox and set dispatch proxy
        result = cwd_transact("execute", "init", f"{LOCAL_DOMAIN}u32", cwd="mailbox")
        assert result.get("success"), f"Mailbox init failed: {result}"

    result = cwd_transact("execute", "set_dispatch_proxy", CALLER, cwd="mailbox")
    assert result.get("success"), f"Set dispatch proxy failed: {result}"
    _dispatch_random_message()
    yield STATE

def test_post_dispatch_igp():
    assert "igp_hook" in STATE, "IGP Hook not initialized"
    igp_address = STATE["igp_hook"]
    config = get_mapping_value("destination_gas_configs", f"{{igp:{igp_address},destination:1u32}}")
    credits_amount = ((DEFAULT_GAS_LIMIT + config["gas_overhead"]) * config["exchange_rate"] * config["gas_price"]) // TOKEN_EXCHANGE_RATE
    hook_allowance = [{"spender":igp_address,"amount":credits_amount}] + [{"spender":NULL_ADDRESS,"amount":0}] * 3
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    
    result = transact("execute", "post_dispatch", igp_address, to_aleo_like(metadata, numeric_suffix=8), to_aleo_like(hook_allowance, numeric_suffix=64))
    assert result.get("success"), f"Post dispatch failed: {result}"

def test_post_dispatch_merkle_tree():
    assert "merkle_tree_hook" in STATE, "Merkle Tree Hook not initialized"
    merkle_tree_address = STATE["merkle_tree_hook"]
    tree = MerkleTree(ZERO_HASHES)
    for iteration in range(1, 4):
        _dispatch_random_message()
        mailbox = get_program_mapping_value("test_hyp_mailbox.aleo", "mailbox", "true")
        # Insert the id locally to check whether or not it is correctly inserted
        count = mailbox.get("nonce")
        id_to_insert = get_program_mapping_value("test_hyp_mailbox.aleo", "dispatch_id_events", f"{count-1}u32")
        tree.insert(u128_to_hash(id_to_insert))

        # parameters for the hook call
        hook_allowance = [{"spender":NULL_ADDRESS,"amount":0}] * 4
        metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}

        result = transact("execute", "post_dispatch", merkle_tree_address, to_aleo_like(metadata, numeric_suffix="8"), to_aleo_like(hook_allowance, numeric_suffix=64))
        assert result.get("success"), f"Post dispatch failed: {result}"

        merkle_tree_hook_after = get_mapping_value("merkle_tree_hooks", merkle_tree_address)

        for i, branch in enumerate(merkle_tree_hook_after.get("tree").get("branch")):
            converted_branch = hash_to_u128(tree.branch[i])
            assert branch == converted_branch, f"Unexpected non-zero hash in branch {i} with iteration {iteration}"
        
        assert merkle_tree_hook_after.get("tree").get("count") == tree.count, f"Incorrect leaf count after post dispatch with iteration {iteration}"
        assert merkle_tree_hook_after.get("root") == hash_to_u128(tree.root()), f"Incorrect root after post dispatch with iteration {iteration}"

def test_post_dispatch_noop_hook():
    assert "noop_hook" in STATE, "IGP Noop not initialized"

    # parameters for the hook call
    hook_allowance = [{"spender":NULL_ADDRESS,"amount":0}] * 4
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    address = STATE["noop_hook"]
    result = transact("execute", "post_dispatch", address, to_aleo_like(metadata, numeric_suffix="8"), to_aleo_like(hook_allowance, numeric_suffix=64))
    assert result.get("success"), "Post dispatch should have failed due to unknown hook"


def test_post_dispatch_merkle_tree_wrong_caller():
    assert "merkle_tree_hook" in STATE, "Merkle Tree Hook not initialized"
    merkle_tree_address = STATE["merkle_tree_hook"]

    # parameters for the hook call
    hook_allowance = [{"spender":NULL_ADDRESS,"amount":0}] * 4
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}

    result = transact("execute", "post_dispatch", merkle_tree_address, to_aleo_like(metadata, numeric_suffix="8"), to_aleo_like(hook_allowance, numeric_suffix=64), "--private-key", "APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh")
    assert not result.get("success"), "Post dispatch should have failed due to wrong caller"

def test_post_dispatch_unknown_hook():
    # parameters for the hook call
    hook_allowance = [{"spender":NULL_ADDRESS,"amount":0}] * 4
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}

    result = transact("execute", "post_dispatch", CALLER, to_aleo_like(metadata, numeric_suffix="8"), to_aleo_like(hook_allowance, numeric_suffix=64), "--private-key", "APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh")
    assert not result.get("success"), "Post dispatch should have failed due to unknown hook"
