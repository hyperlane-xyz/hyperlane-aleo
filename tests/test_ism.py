from . import get_mapping_value as get_program_mapping_value, program_exists, transact as cwd_transact, to_aleo_like, message

STATE: dict[str, str] = {}

def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value("ism_manager.aleo", mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="ism_manager", **kwargs)

def _current_nonce() -> int:
    return int(get_mapping_value("nonce", "true") or 0)

def test_create_noop():
    current_nonce = _current_nonce()
    result = transact("execute", "init_noop")
    assert result.get("success"), f"Noop ISM init failed: {result}"
    address = get_mapping_value("ism_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    assert isinstance(address, str) and address.startswith("aleo"), "No noop ISM address returned"
    STATE["noop_ism"] = address

def test_create_message_id_multisig():
    current_nonce = _current_nonce()
    validators = [
        {"bytes": [3, 200, 66, 219, 134, 166, 163, 229, 36, 212, 166, 97, 83, 144, 193, 234, 142, 43, 149, 65]}
    ] + [{"bytes": [0] * 20} for _ in range(5)]
    result = transact(
        "execute",
        "init_message_id_multisig",
        to_aleo_like(validators, numeric_suffix="8"),
        "1u8",
        "1u8",
    )
    assert result.get("success"), f"Message ID multisig init failed: {result}"
    address = get_mapping_value("ism_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    assert isinstance(address, str) and address.startswith("aleo"), "No message_id ISM address returned"
    STATE["message_id_ism"] = address

    message_id_multisig = get_mapping_value("message_id_multisigs", address)
    assert message_id_multisig, "No Message ID Multisig returned"
    assert message_id_multisig.get("threshold") == 1, "Incorrect threshold"
    assert message_id_multisig.get("validators") == validators, "Incorrect validators"
    assert message_id_multisig.get("validator_count") == 1, "Incorrect validator count"

def test_create_domain_routing():
    current_nonce = _current_nonce()
    result = transact("execute", "init_domain_routing")
    assert result.get("success"), f"Domain routing ISM init failed: {result}"
    address = get_mapping_value("ism_addresses", to_aleo_like(current_nonce, numeric_suffix="32"))
    assert isinstance(address, str) and address.startswith("aleo"), "No routing ISM address returned"
    STATE["routing_ism"] = address


# This message Id can be verified with the corresponding metadata
MESSAGE_ID='[327112441231717649600865333815859455984u128,64705380106552971125760530438676031763u128]'
# Metadata is 512 bytes filled with trailing ones
METADATA=[0,0,0,0,0,0,0,0,0,0,0,0,72,230,195,11,151,116,141,30,46,3,191,62,159,190,56,144,202,95,140,202,219,39,134,136,244,249,41,187,3,199,110,87,134,108,164,18,144,220,99,161,6,151,82,80,127,230,210,15,48,127,21,56,0,0,0,0,58,235,121,208,229,66,184,54,49,68,254,82,134,177,248,246,57,45,117,211,34,13,158,202,10,194,11,176,205,65,35,109,14,94,175,204,231,230,16,92,194,130,202,166,140,231,61,9,95,128,241,17,205,229,168,241,62,128,189,141,219,11,145,39,27] + [1] * (512 - 133)

def _verify(ism_addr: str, msg: str, id: str, metadata: list[int], expect_success: bool):
    result = transact("execute", "verify", ism_addr, msg, id, to_aleo_like(metadata, numeric_suffix="8"))
    if expect_success:
        assert result.get("success"), f"Expected success, got failure: {result}"
    else:
        assert not result.get("success"), f"Expected failure, got success: {result}"
    return result

def test_invalid_verify_message_id():
    assert "message_id_ism" in STATE, "Message ID ISM not initialized"
    import random
    metadata = [random.randint(0, 255) for _ in range(512)]
    _verify(STATE["message_id_ism"], message(), MESSAGE_ID, metadata, expect_success=False)


def test_verify_message_id():
    assert "message_id_ism" in STATE, "Message ID ISM not initialized"
    _verify(STATE["message_id_ism"], message(origin=1), MESSAGE_ID, METADATA, expect_success=True)


def test_verify_noop():
    assert "noop_ism" in STATE, "Noop ISM not initialized"
    _verify(STATE["noop_ism"], message(), '[0u128, 0u128]', [0] * 512, expect_success=True)


def test_set_domain():
    assert "routing_ism" in STATE and "message_id_ism" in STATE, "Required ISMs not initialized"
    routing = STATE["routing_ism"]
    message_id = STATE["message_id_ism"]
    # domain 0 -> recursive route
    r1 = transact("execute", "set_domain", routing, "0u32", routing)
    assert r1.get("success"), f"set_domain recursive failed: {r1}"
    # domain 1 -> message id
    r2 = transact("execute", "set_domain", routing, "1u32", message_id)
    assert r2.get("success"), f"set_domain message_id failed: {r2}"

    route0_key = f"{{ism:{routing},domain:0u32}}"
    route1_key = f"{{ism:{routing},domain:1u32}}"
    route0 = get_mapping_value("routes", route0_key)
    route1 = get_mapping_value("routes", route1_key)
    assert route0 == routing, f"Route 0 incorrect: {route0}"
    assert route1 == message_id, f"Route 1 incorrect: {route1}"


def test_verify_domain_routing():
    assert "routing_ism" in STATE, "Routing ISM not initialized"
    _verify(STATE["routing_ism"], message(destination_domain=1, origin=1), MESSAGE_ID, METADATA, expect_success=True)


def test_invalid_verify_domain_routing_recursion():
    assert "routing_ism" in STATE, "Routing ISM not initialized"
    _verify(STATE["routing_ism"], message(destination_domain=0), MESSAGE_ID, METADATA, expect_success=False)
    

def test_remove_domain():
    assert "routing_ism" in STATE, "Routing ISM not initialized"
    routing = STATE["routing_ism"]
    result = transact("execute", "remove_domain", routing, "0u32")
    assert result.get("success"), f"remove_domain failed: {result}"
    route0_key = f"{{ism:{routing},domain:0u32}}"
    route0 = get_mapping_value("routes", route0_key)
    assert route0 in (None, {}), f"Route 0 expected null/empty, got: {route0}"


def test_invalid_verify_domain_routing_unknown_route():
    assert "routing_ism" in STATE, "Routing ISM not initialized"
    _verify(STATE["routing_ism"], message(destination_domain=1337), MESSAGE_ID, METADATA, expect_success=False)


def test_invalid_verify_unknown_ism():
    unknown_addr = "aleo166ttgseesn87kzhj365g9a636ged78t3s2ed0j7razh6ucwkrsqs5ptnv5"
    _verify(unknown_addr, message(), MESSAGE_ID, METADATA, expect_success=False)
