from . import LOCAL_DOMAIN, NULL_ADDRESS, get_mapping_value as get_program_mapping_value, program_exists, transact as cwd_transact, to_aleo_like, message
from Crypto.Hash import keccak
import random 

STATE: dict[str, str] = {}
DISPATCH_PROXY = "aleo1jgnn4lla2d6v0llffwhp6s87x03xqtdezwkzxv0u2ehq2wmqcsqqganvw4"
SENDER=[29,208,222,123,215,65,0,216,154,82,63,49,200,202,69,26,172,55,11,91,152,136,211,189,19,192,232,147,97,223,189,7]

def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value("mailbox.aleo", mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="mailbox", **kwargs)

def test_init_mailbox():
    mailbox = get_mapping_value("mailbox", "true")
    if not mailbox:
        result = transact("execute", "init", f"{LOCAL_DOMAIN}u32")
        assert result.get("success"), f"Mailbox initialization failed: {result}"

def test_invalid_init_mailbox():
    result = transact("execute", "init", f"{LOCAL_DOMAIN}u32")
    assert not result.get("success"), "Mailbox initialization should have failed due to already being initialized"

def hook_nonce():
    return int(get_program_mapping_value("hook_manager.aleo", "nonce", "true") or 0)

def get_noop_ism():
    nonce = int(get_program_mapping_value("ism_manager.aleo", "nonce", "true") or 0)
    cwd_transact("execute", "init_noop", cwd="ism_manager")
    address = get_program_mapping_value("ism_manager.aleo", "ism_addresses", to_aleo_like(nonce, numeric_suffix="32"))
    return address
    
def deploy_noop_hook():
    current_nonce = hook_nonce()
    cwd_transact("execute", "init_noop", cwd="hook_manager")
    address = get_program_mapping_value("hook_manager.aleo", "hook_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    return address

def deploy_merkle_tree_hook():
    current_nonce = hook_nonce()
    cwd_transact("execute", "init_merkle_tree", DISPATCH_PROXY, cwd="hook_manager")
    address = get_program_mapping_value("hook_manager.aleo", "hook_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    return address

def test_configure_mailbox():
    default_ism = get_noop_ism()
    result = transact("execute", "set_default_ism", default_ism)
    assert result.get("success"), f"Setting default ISM failed: {result}"

    default_hook = deploy_noop_hook()
    result = transact("execute", "set_default_hook", default_hook)
    assert result.get("success"), f"Setting default hook failed: {result}"

    required_hook = deploy_merkle_tree_hook()
    result = transact("execute", "set_required_hook", required_hook)
    assert result.get("success"), f"Setting required hook failed: {result}"

    result = transact("execute", "set_dispatch_proxy", DISPATCH_PROXY)
    assert result.get("success"), f"Setting dispatch proxy failed: {result}"

    mailbox = get_mapping_value("mailbox", "true")
    assert mailbox.get("default_ism") == default_ism, "Default ISM not set correctly"
    assert mailbox.get("default_hook") == default_hook, "Default hook not set correctly"
    assert mailbox.get("required_hook") == required_hook, "Required hook not set correctly"

    STATE["default_ism"] = default_ism
    STATE["default_hook"] = default_hook
    STATE["required_hook"] = required_hook

def get_message_id(message: dict, byte_length: int = 0) -> list[int]:
    # Helper to pack unsigned ints to big-endian bytes
    def _pack_u(value: int, bits: int) -> bytes:
        size = bits // 8
        return value.to_bytes(size, "big")

    # Construct concatenated byte array:
    # Layout:
    #   version: u8 (1)
    #   nonce: u32 (4)
    #   origin_domain: u32 (4)
    #   sender: 32 * u8 (32)
    #   destination_domain: u32 (4)
    #   recipient: 32 * u8 (32)
    #   body: 8 * u128 (128 total; each u128 = 16 bytes)
    byte_arr = bytearray()
    byte_arr += _pack_u(message.get("version"), 8)
    byte_arr += _pack_u(message.get("nonce"), 32)
    byte_arr += _pack_u(message.get("origin_domain"), 32)
    sender_bytes = bytes(message.get("sender"))
    byte_arr += sender_bytes
    byte_arr += _pack_u(message.get("destination_domain"), 32)
    byte_arr += bytes(message.get("recipient"))
    for word in message.get("body"):
        # Each u128 is 16 bytes (128 bits)
        byte_arr += word.to_bytes(16, "little")

    if byte_length > 0:
        byte_arr = byte_arr[:byte_length]

    digest = keccak.new(digest_bits=256).update(byte_arr).digest()
    first = int.from_bytes(digest[:16], "little")
    second = int.from_bytes(digest[16:], "little")
    return [first, second]

def construct_local_message(nonce: int, recipient: list[int], body: list[int]) -> dict:
    """Constructs a local message dict and its corresponding ID."""
    # Build message dict
    version = 3                   # u8
    destination_domain = 1        # u32
    message = {
        "version": version,
        "nonce": nonce,
        "origin_domain": LOCAL_DOMAIN,
        "sender": SENDER,
        "destination_domain": destination_domain,
        "recipient": recipient,
        "body": body,
    }

    return message

def state_without_ism():
    state_copy = STATE.copy()
    state_copy.pop("default_ism", None)
    return to_aleo_like(state_copy)

def test_dispatch_message():
    recipient = [random.randint(0, 255) for _ in range(32)]
    body = [random.randint(0, 2**128-1) for _ in range(16)]
    destination = "1u32"
    hook_address = NULL_ADDRESS
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    nonce = int(get_mapping_value("mailbox", "true").get("nonce", 0))
    result = cwd_transact(
        "execute",
        "dispatch",
        state_without_ism(),
        destination,
        to_aleo_like(recipient, numeric_suffix=8),
        to_aleo_like(body, numeric_suffix=128),
        hook_address,
        to_aleo_like(metadata, numeric_suffix=8),
        to_aleo_like(hook_allowance, numeric_suffix=64),
        cwd="dispatch_proxy"
    )
    assert result.get("success"), f"Dispatching message failed: {result}"

    dispatched_message = construct_local_message(nonce, recipient, body)
    stored_message = get_mapping_value("dispatch_events", f"{nonce}u32")
    stored_message_id = get_mapping_value("dispatch_id_events", f"{nonce}u32")

    assert stored_message == dispatched_message, "Dispatched message does not match stored message"
    assert stored_message_id == get_message_id(dispatched_message), "Dispatched message ID does not match stored message ID"

def test_invalid_dispatch_wrong_state():
    recipient = [random.randint(0, 255) for _ in range(32)]
    body = [random.randint(0, 2**128-1) for _ in range(16)]
    destination = "1u32"
    hook_address = NULL_ADDRESS
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    state_copy = STATE.copy()
    state_copy["default_ism"] = None
    state_copy["default_hook"] = NULL_ADDRESS  # Invalid state
    result = cwd_transact(
        "execute",
        "dispatch",
        to_aleo_like(state_copy),
        destination,
        to_aleo_like(recipient, numeric_suffix=8),
        to_aleo_like(body, numeric_suffix=128),
        hook_address,
        to_aleo_like(metadata, numeric_suffix=8),
        to_aleo_like(hook_allowance, numeric_suffix=64),
        cwd="dispatch_proxy"
    )
    assert not result.get("success"), "Dispatching message should have failed due to invalid state"

def test_post_dispatch_custom_hook():
    hook_address = STATE["required_hook"]
    merkle_tree_hook = get_program_mapping_value("hook_manager.aleo", "merkle_tree_hooks", hook_address)
    
    # set the required hook to the noop hook
    transact("execute", "set_required_hook", STATE["default_hook"])
    STATE["required_hook"] = STATE["default_hook"]
    recipient = [random.randint(0, 255) for _ in range(32)]
    body = [random.randint(0, 2**128-1) for _ in range(16)]
    destination = "1u32"
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    nonce = int(get_mapping_value("mailbox", "true").get("nonce", 0))
    result = cwd_transact(
        "execute",
        "dispatch",
        state_without_ism(),
        destination,
        to_aleo_like(recipient, numeric_suffix=8),
        to_aleo_like(body, numeric_suffix=128),
        hook_address,
        to_aleo_like(metadata, numeric_suffix=8),
        to_aleo_like(hook_allowance, numeric_suffix=64),
        cwd="dispatch_proxy"
    )
    assert result.get("success"), f"Dispatching message failed: {result}"

    dispatched_message = construct_local_message(nonce, recipient, body)
    stored_message = get_mapping_value("dispatch_events", f"{nonce}u32")
    stored_message_id = get_mapping_value("dispatch_id_events", f"{nonce}u32")

    assert stored_message == dispatched_message, "Dispatched message does not match stored message"
    assert stored_message_id == get_message_id(dispatched_message), "Dispatched message ID does not match stored message ID"

    # assert that the hook was called by checking whether the count increased
    post_merkle_tree_hook = get_program_mapping_value("hook_manager.aleo", "merkle_tree_hooks", hook_address)
    assert int(post_merkle_tree_hook.get("tree").get("count", 0)) == int(merkle_tree_hook.get("tree").get("count", 0)) + 1, "Merkle tree hook count did not increase"

def get_test_message(recipient: list[int] = None):
    message = {
        "version": 3,
        "nonce": 0,
        "origin_domain": 0,
        "sender": [0]*32,
        "destination_domain": LOCAL_DOMAIN,
        "recipient": recipient or [0]*32,
        "body": [0]*16,
    }
    aleo_message = (
        "{"
        f"version: {message['version']}u8, "
        f"nonce: {message['nonce']}u32, "
        f"origin_domain: {message['origin_domain']}u32, "
        f"sender: [{', '.join(f'{b}u8' for b in message['sender'])}], "
        f"destination_domain: {message['destination_domain']}u32, "
        f"recipient: [{', '.join(f'{b}u8' for b in message['recipient'])}], "
        f"body: [{', '.join(f'{w}u128' for w in message['body'])}]"
        "}"
    )
    return aleo_message, 141, get_message_id(message, 141)

def test_process_message():
    aleo_message, message_length, message_id = get_test_message(recipient=[29,208,222,123,215,65,0,216,154,82,63,49,200,202,69,26,172,55,11,91,152,136,211,189,19,192,232,147,97,223,189,7],)
    metadata = [1] * 512
    result = transact(
        "execute",
        "process",
        STATE["default_ism"],
        aleo_message,
        to_aleo_like(message_length, numeric_suffix=32),
        to_aleo_like(message_id, numeric_suffix=128),
        to_aleo_like(metadata, numeric_suffix=8),
    )
    assert result.get("success"), f"Processing message failed: {result}"

def test_invalid_process_replay():
    message, message_length, message_id = get_test_message()
    metadata = [1] * 512
    result = transact(
        "execute",
        "process",
        STATE["default_ism"],
        message,
        to_aleo_like(message_length, numeric_suffix=32),
        to_aleo_like(message_id, numeric_suffix=128),
        to_aleo_like(metadata, numeric_suffix=8),
    )
    assert not result.get("success"), "Processing message should have failed due to replay"


def test_invalid_process_wrong_caller():
    message, message_length, message_id = get_test_message()
    metadata = [1] * 512
    result = transact(
        "execute",
        "process",
        STATE["default_ism"],
        message,
        to_aleo_like(message_length, numeric_suffix=32),
        to_aleo_like(message_id, numeric_suffix=128),
        to_aleo_like(metadata, numeric_suffix=8),
    )
    assert not result.get("success"), "Processing message should have failed due to wrong caller"

def test_set_owner():
    result = transact(
        "execute",
        "set_owner",
        NULL_ADDRESS
    )
    assert result.get("success"), f"Setting owner failed: {result}"

def test_invalid_set_owner_not_owner():
    result = transact(
        "execute",
        "set_owner",
        NULL_ADDRESS
    )
    assert not result.get("success"), "Setting owner should have failed due to not being the owner"


def test_process_all_message_lengths():
    def _test_message_with_body_length(body_length):
        from scripts.hypertools.hypertools import Message

        m = Message(3, 1, 1000000, bytes([1] * 32), 1,
                       bytes([29,208,222,123,215,65,0,216,154,82,63,49,200,202,69,26,172,55,11,91,152,136,211,189,19,192,232,147,97,223,189,7]),
                       bytes([3] * body_length))

        metadata = [1] * 512
        result = transact(
            "execute",
            "process",
            "aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss",
            m.get_aleo_struct(),
            to_aleo_like(77 + body_length, numeric_suffix=32),
            m.get_aleo_message_id(),
            to_aleo_like(metadata, numeric_suffix=8),
        )

        assert result.get("success"), f"Processing message failed: {result}"

    # all length in steps of 16
    _test_message_with_body_length(0)
    _test_message_with_body_length(16)
    _test_message_with_body_length(32)
    _test_message_with_body_length(48)
    _test_message_with_body_length(64)
    _test_message_with_body_length(80)
    _test_message_with_body_length(96)
    _test_message_with_body_length(112)
    _test_message_with_body_length(128)
    _test_message_with_body_length(144)
    _test_message_with_body_length(160)
    _test_message_with_body_length(176)
    _test_message_with_body_length(192)
    _test_message_with_body_length(208)
    _test_message_with_body_length(224)
    _test_message_with_body_length(240)
    _test_message_with_body_length(256)

    # special lengths
    _test_message_with_body_length(129)
    _test_message_with_body_length(72)
    _test_message_with_body_length(90)