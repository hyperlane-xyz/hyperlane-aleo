from scripts.hypertools.hypertools import Message
from . import get_mapping_value as get_program_mapping_value,get_mapping_value_raw, program_exists, transact as cwd_transact, to_aleo_like, \
    NULL_ADDRESS, CALLER
from .conftest import SECONDARY_ACCOUNT

PROGRAM = "hyp_collateral.aleo"
LOCAL_DECIMALS = 6
REMOTE_DECIMALS = 18
MAILBOX = {
    "default_ism": "aleo12x2p8lhu2xk9fxuj56c5d8salwks4zv02x7nh72xvkhlc0594qrstkms35",
    "default_hook": "aleo1k8h4rvk7q4jplv4w8a2qk8zn8ahgtsk3urgj2z5f9krxwm606gys9c607w",
    "required_hook": "aleo1k8h4rvk7q4jplv4w8a2qk8zn8ahgtsk3urgj2z5f9krxwm606gys9c607w"
}
TOKEN_ID = "1field"
METADATA = {
    "token_type": 2,
    "token_owner": CALLER,
    "ism": NULL_ADDRESS,
    "hook": NULL_ADDRESS,
    "token_id": TOKEN_ID,
    "local_decimals": LOCAL_DECIMALS,
    "remote_decimals": REMOTE_DECIMALS,
}
IGP = "aleo1mvqh6w2739a7mzxusx3cvr264fdtpfpp94jz3dzrkugjn6p8vv8qzxrnpv"
GAS_LIMIT = 1000

HYP_PROGRAM_HEX = bytes.fromhex("0d8b7893b9cc5c84735cd1d353cd155e2a00e96960a60184d84f6a0bc84a4e08")

def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value(PROGRAM, mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="warp/hyp_collateral", **kwargs)

def test_deploy():
    if program_exists(PROGRAM):
        return
    result = transact("deploy")
    assert result.get("success"), f"Deployment failed: {result}"

def test_init():
    exists = get_mapping_value("app_metadata", "true")
    if exists:
        return
    
    # create a collateral token and mint some to caller for testing
    # execute token_registry.aleo/register_token 1field 0u128 0u128 6u8 1000000u128 false aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc
    transact(
        "execute",
        "token_registry.aleo/register_token",
        TOKEN_ID,
        "0u128",
        "0u128",
        "6u8",
        "10000000000000u128",
        "false",
        CALLER,
    )

    # mint some to caller
    transact(
        "execute",
        "token_registry.aleo/mint_public",
        TOKEN_ID,
        CALLER,
        "1000000000u128",
        "100000000u32"
    )

    program_id = list(b"hyp_collateral.aleo")
    program_id = program_id + [0] * (128 - len(program_id))
    result = transact(
        "execute",
        "init",
        to_aleo_like(program_id, numeric_suffix='8'),
        TOKEN_ID,
        f"{REMOTE_DECIMALS}u8",
    )
    assert result.get("success"), f"Warp Hyp Synthetic init failed: {result}"
    app_metadata = get_mapping_value("app_metadata", "true")
    assert app_metadata["token_owner"] == CALLER
    assert app_metadata["local_decimals"] == LOCAL_DECIMALS
    assert app_metadata["remote_decimals"] == REMOTE_DECIMALS
    assert app_metadata["ism"] == NULL_ADDRESS
    assert app_metadata["hook"] == NULL_ADDRESS
    assert app_metadata["token_type"] == 2
    assert app_metadata["token_id"] == METADATA["token_id"]

def test_init_again():
    exists = get_mapping_value("app_metadata", "true")
    assert exists is not None
    program_id = list(b"hyp_collateral.aleo")
    program_id = program_id + [0] * (128 - len(program_id))
    result = transact(
        "execute",
        "init",
        to_aleo_like(program_id, numeric_suffix='8'),
        TOKEN_ID,
        f"{REMOTE_DECIMALS}u8",
    )
    assert not result.get("success"), f"Warp Hyp Synthetic init should have failed: {result}"


def test_enroll_remote_router():
    address = [1, 2] * 16
    result = transact(
        "execute",
        "enroll_remote_router",
        "1337u32",
        to_aleo_like(address, numeric_suffix='8'),
        "1000u128"
    )
    result = transact(
        "execute",
        "enroll_remote_router",
        "1u32",
        to_aleo_like(address, numeric_suffix='8'),
        "1000u128"
    )
    assert result.get("success"), f"Warp Hyp Synthetic enroll remote router failed: {result}"
    enrolled_router = get_mapping_value("remote_routers", "1u32")
    assert enrolled_router["domain"] == 1
    assert enrolled_router["recipient"] == address
    assert enrolled_router["gas"] == 1000

def test_enroll_remote_router_not_owner():
    try_address = [10, 20] * 16
    current_address = [1, 2] * 16
    result = transact(
        "execute",
        "--private-key",
        SECONDARY_ACCOUNT["private_key"],
        "enroll_remote_router",
        "1u32",
        to_aleo_like(try_address, numeric_suffix='8'),
        "2000u128",
    )
    assert not result.get("success"), f"Warp Hyp Synthetic enroll remote router not owner should have failed: {result}"
    # Assert nothing changed
    enrolled_router = get_mapping_value("remote_routers", "1u32")
    assert enrolled_router["domain"] == 1
    assert enrolled_router["recipient"] == current_address
    assert enrolled_router["gas"] == 1000

def test_unenroll_remote_router_not_owner():
    current_address = [1, 2] * 16
    result = transact(
        "execute",
        "--private-key",
        SECONDARY_ACCOUNT["private_key"],
        "unroll_remote_router",
        "1337u32",
    )
    assert not result.get("success"), f"Warp Hyp Synthetic enroll remote router not owner should have failed: {result}"
    # Assert nothing changed
    enrolled_router = get_mapping_value("remote_routers", "1337u32")
    assert enrolled_router["domain"] == 1337
    assert enrolled_router["recipient"] == current_address
    assert enrolled_router["gas"] == 1000

def test_unenroll_remote_router():
    result = transact(
        "execute",
        "unroll_remote_router",
        "1337u32",
    )
    assert result.get("success"), f"Warp Hyp Synthetic unenroll remote router failed: {result}"
    # Assert nothing changed
    enrolled_router = get_mapping_value("remote_routers", "1337u32")
    assert enrolled_router == None

def test_transfer_remote():
    balance_key = "7213415891747529145288949579066784132924874185950300252806153069107681527219field"
    balance_before = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    balance_before = balance_before["balance"] if balance_before else 0

    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: {GAS_LIMIT}u128 }}"
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    result = transact(
        "execute",
        "transfer_remote",
        to_aleo_like(METADATA, numeric_suffix='8'),
        to_aleo_like(MAILBOX, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1234u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
    )
    assert result.get("success"), f"Warp Hyp Synthetic transfer_remote failed: {result}"

    mailbox = get_program_mapping_value("mailbox.aleo", "mailbox", "true")
    nonce = (int(mailbox["nonce"]) - 1)
    event = get_mapping_value_raw("mailbox.aleo", "dispatch_events", str(nonce) + "u32")

    message_body = (
        "0000000000000000000000007eb8cdc23265fda88f5b9b72aed1f8a362660141" # dummy user address
        "0000000000000000000000000000000000000000000000000004625103a72000" # 1234 * 10**12 in hex
        "0000000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000000000"
        "0000000000000000000000000000000000000000000000000000000000000000"
    )

    # Assert events
    m = Message.from_aleo_event(str(event))
    assert m.message_body.hex() == message_body
    assert m.version == 3
    assert m.destination_domain == 1
    assert m.origin_domain == 1
    assert m.nonce == nonce
    assert m.recipient.hex() == "0102010201020102010201020102010201020102010201020102010201020102"
    assert m.sender.hex() == HYP_PROGRAM_HEX.hex()

    balance_after = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    balance_after = balance_after["balance"] if balance_after else 0

    assert int(balance_after) - int(balance_before) == 1234

def test_invalid_transfer_remote_wrong_mailbox():
    unverified_mailbox_state = {
        "default_ism": "aleo1k8h4rvk7q4jplv4w8a2qk8zn8ahgtsk3urgj2z5f9krxwm606gys9c607w",
        "default_hook": "aleo1k8h4rvk7q4jplv4w8a2qk8zn8ahgtsk3urgj2z5f9krxwm606gys9c607w",
        "required_hook": "aleo1ysyt49787vznynprcz8vlgepdkh0ykyzf0pvcc2jt4tv89v0nurqceqcjp"
    }
    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: 1000u128 }}"
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    result = transact(
        "execute",
        "transfer_remote",
        to_aleo_like(METADATA, numeric_suffix='8'),
        to_aleo_like(unverified_mailbox_state, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
    )
    assert not result.get("success"), f"Warp Hyp Synthetic invalid transfer_remote should have failed: {result}"

def test_invalid_transfer_remote_wrong_metadata():
    unverified_metadata = METADATA.copy()
    unverified_metadata["remote_decimals"] = 8

    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: 1000u128 }}"
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    result = transact(
        "execute",
        "transfer_remote",
        to_aleo_like(unverified_metadata, numeric_suffix='8'),
        to_aleo_like(MAILBOX, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
    )
    assert not result.get("success"), f"Warp Hyp Synthetic invalid transfer_remote should have failed: {result}"

def test_transfer_custom_hook():
    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: 1000u128 }}"
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    igp = get_program_mapping_value("hook_manager.aleo", "igps", IGP)["count"]
    # Allowance for IGP only
    credits = (GAS_LIMIT + 10) * 5000000000 * 4 / 10000000000
    hook_allowance = [{"spender": IGP, "amount": int(credits)}] + [{"spender": NULL_ADDRESS, "amount": 0}] * 3
    result = transact(
        "execute",
        "transfer_remote_with_hook",
        to_aleo_like(METADATA, numeric_suffix='8'),
        to_aleo_like(MAILBOX, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1234u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
        IGP,
        to_aleo_like(metadata, numeric_suffix=8),
    )

    assert result.get("success"), f"Warp Hyp Synthetic transfer with custom hook failed: {result}"

    post_igp = get_program_mapping_value("hook_manager.aleo", "igps", IGP)["count"]
    assert post_igp - igp == 1, "IGP event count did not increment"
    assert result.get("success"), f"Warp Hyp Synthetic transfer with custom hook failed: {result}"

def test_transfer_custom_hook_metadata():
    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: 1000u128 }}"
    gas_limit = GAS_LIMIT + 500
    metadata = {"gas_limit": f"{gas_limit}u128", "extra_data": [0] * 64}
    
    igp = get_program_mapping_value("hook_manager.aleo", "igps", IGP)["count"]
    # Allowance for IGP only
    credits = (gas_limit + 10) * 5000000000 * 4 / 10000000000
    hook_allowance = [{"spender": IGP, "amount": int(credits)}] + [{"spender": NULL_ADDRESS, "amount": 0}] * 3
    result = transact(
        "execute",
        "transfer_remote_with_hook",
        to_aleo_like(METADATA, numeric_suffix='8'),
        to_aleo_like(MAILBOX, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1234u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
        IGP,
        to_aleo_like(metadata, numeric_suffix=8),
    )

    post_igp = get_program_mapping_value("hook_manager.aleo", "igps", IGP)["count"]
    assert post_igp - igp == 1, "IGP event count did not increment"
    assert result.get("success"), f"Warp Hyp Synthetic transfer with custom hook failed: {result}"

def test_invalid_transfer_wrong_custom_hook():
    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: 1000u128 }}"
    metadata = {"gas_limit": "0u128", "extra_data": [0] * 64}
    hook_allowance = [{"spender": NULL_ADDRESS, "amount": 0}] * 4
    result = transact(
        "execute",
        "transfer_remote_with_hook",
        to_aleo_like(METADATA, numeric_suffix='8'),
        to_aleo_like(MAILBOX, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1234u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
        "aleo12tf856xd9we5ay090zkep0s3q5e8srzwqr37ds0ppvv5kkzad5fqvwndmx", # random invalid hook
        to_aleo_like(metadata, numeric_suffix=8),
    )

    assert not result.get("success"), f"Warp Hyp Synthetic invalid transfer with custom hook should have failed: {result}"

def test_set_hook():
    result = transact(
        "execute",
        "set_custom_hook",
        IGP
    )
    assert result.get("success"), "Setting custom hook failed"
    METADATA["hook"] = IGP

def test_transfer_after_set_hook():
    unverified_remote_router = f"{{domain: 1u32, recipient:{to_aleo_like([1, 2] * 16, numeric_suffix='8')}, gas: 1000u128 }}"
    igp = get_program_mapping_value("hook_manager.aleo", "igps", IGP)["count"]
    # Allowance for IGP only
    credits = (GAS_LIMIT + 10) * 5000000000 * 4 / 10000000000
    hook_allowance = [{"spender": IGP, "amount": int(credits)}] + [{"spender": NULL_ADDRESS, "amount": 0}] * 3
    METADATA["hook"] = IGP
    result = transact(
        "execute",
        "transfer_remote",
        to_aleo_like(METADATA, numeric_suffix='8'),
        to_aleo_like(MAILBOX, numeric_suffix='8'),
        unverified_remote_router,
        "1u32",
        '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]',
        "1234u128",
        to_aleo_like(hook_allowance, numeric_suffix=64),
    )

    assert result.get("success"), f"Warp Hyp Synthetic transfer with custom hook failed: {result}"

    post_igp = get_program_mapping_value("hook_manager.aleo", "igps", IGP)["count"]
    assert post_igp - igp == 1, "IGP event count did not increment"
    assert result.get("success"), f"Warp Hyp Synthetic transfer with custom hook failed: {result}"

def test_process_incoming_message():
    # recipient balance key 
    balance_key = "6549600441318707016229280757338109351753120267779465369626388101920503643146field"

    user_balance_before = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    user_balance_before = user_balance_before["balance"] if user_balance_before else 0

    enrolled_router = bytes.fromhex("0102010201020102010201020102010201020102010201020102010201020102")

    body = (
        "10aa7e32180d16b9dc0974410d897afdb09eb7763ae65475b3a2579074790b0f" # Aleo user hex encoded
        "00000000000000000000000000000000000000000000000000038c95d0217000" # 999 * 10**12 in hex
    )

    m = Message(3, 10, 1, enrolled_router, 1, HYP_PROGRAM_HEX, bytes.fromhex(body))

    result = transact(
        "execute",
        "process",
        MAILBOX["default_ism"],
        to_aleo_like(METADATA, numeric_suffix='8'),
        str(m.get_aleo_struct()),
        "141u32",
        str(m.get_aleo_message_id()),
        to_aleo_like([0]*512, numeric_suffix=8)
    )

    user_balance_after = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    user_balance_after = user_balance_after["balance"] if user_balance_after else 0

    assert result.get("success"), "Process transaction failed"
    assert int(user_balance_after) - int(user_balance_before) == 999

def test_invalid_process_incoming_message_invalid_payload():
    enrolled_router = bytes.fromhex("0102010201020102010201020102010201020102010201020102010201020102")

    body = (
        "10aa7e32180d16b9dc0974410d897afdb09eb7763ae65475b3a2579074790b0f" # Aleo user hex encoded
        "10aa7e32180d16b9dc0974410d897afdb09eb7763ae65475b3a2579074790b0f" # A super large amount that won't fit in u128 after downscaling
    )

    m = Message(3, 1, 1, enrolled_router, 1, HYP_PROGRAM_HEX, bytes.fromhex(body))

    result = transact(
        "execute",
        "process",
        MAILBOX["default_ism"],
        to_aleo_like(METADATA, numeric_suffix='8'),
        str(m.get_aleo_struct()),
        "141u32",
        str(m.get_aleo_message_id()),
        to_aleo_like([0]*512, numeric_suffix=8)
    )

    assert not result.get("success"), "Process transaction with invalid payload should have failed"

def test_process_incoming_message_payload_fraction():
    # recipient balance key 
    balance_key = "6549600441318707016229280757338109351753120267779465369626388101920503643146field"

    enrolled_router = bytes.fromhex("0102010201020102010201020102010201020102010201020102010201020102")
    user_balance_before = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    user_balance_before = user_balance_before["balance"] if user_balance_before else 0

    body = (
        "10aa7e32180d16b9dc0974410d897afdb09eb7763ae65475b3a2579074790b0f" # Aleo user hex encoded
        "00000000000000000000000000000000000000000000000000038c95d0217001" # This amount has a fraction when downscaled, it should be truncated
    )


    m = Message(3, 2, 1, enrolled_router, 1, HYP_PROGRAM_HEX, bytes.fromhex(body))

    result = transact(
        "execute",
        "process",
        MAILBOX["default_ism"],
        to_aleo_like(METADATA, numeric_suffix='8'),
        str(m.get_aleo_struct()),
        "141u32",
        str(m.get_aleo_message_id()),
        to_aleo_like([0]*512, numeric_suffix=8)
    )

    user_balance_after = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    user_balance_after = user_balance_after["balance"] if user_balance_after else 0

    assert result.get("success"), "Process transaction failed"
    assert int(user_balance_after) - int(user_balance_before) == 999

def test_invalid_process_incoming_message_unknown_router():
    unknown_router = bytes.fromhex("0102010201020102010201020102010201020102010201020102010201020101")

    body = (
        "10aa7e32180d16b9dc0974410d897afdb09eb7763ae65475b3a2579074790b0f" # Aleo user hex encoded
        "00000000000000000000000000000000000000000000000000038c95d0217000" # 999 * 10**12 in hex
    )

    m = Message(3, 3, 1, unknown_router, 1, HYP_PROGRAM_HEX, bytes.fromhex(body))

    result = transact(
        "execute",
        "process",
        "aleo1k8h4rvk7q4jplv4w8a2qk8zn8ahgtsk3urgj2z5f9krxwm606gys9c607w",
        to_aleo_like(METADATA, numeric_suffix='8'),
        str(m.get_aleo_struct()),
        "141u32",
        str(m.get_aleo_message_id()),
        to_aleo_like([0]*512, numeric_suffix=8)
    )

    assert not result.get("success"), "Process transaction with unknown router should have failed"

def test_custom_ism():
    # deploy a routing ism first
    nonce = int(get_program_mapping_value("ism_manager.aleo", "nonce", "true") or 0)
    cwd_transact("execute", "init_domain_routing", cwd="ism_manager")
    routing_ism = get_program_mapping_value("ism_manager.aleo", "ism_addresses", to_aleo_like(nonce, numeric_suffix="32"))

    # Set for origin domain 1 the mailbox default's ism
    cwd_transact(
        "execute",
        "set_domain",
        routing_ism,
        "1u32",
        MAILBOX["default_ism"],
        cwd="ism_manager"
    )

    # set the warp hyp native's ism to the routing ism
    result = transact(
        "execute",
        "set_custom_ism",
        routing_ism,
    )

    assert result.get("success"), "Setting custom ISM failed"

    onchain_metadata = get_mapping_value("app_metadata", "true")
    assert onchain_metadata["ism"] == routing_ism, "Custom ISM not set correctly on-chain"

    METADATA["ism"] = routing_ism

    # recipient balance key 
    balance_key = "6549600441318707016229280757338109351753120267779465369626388101920503643146field"

    user_balance_before = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    user_balance_before = user_balance_before["balance"] if user_balance_before else 0

    enrolled_router = bytes.fromhex("0102010201020102010201020102010201020102010201020102010201020102")

    body = (
        "10aa7e32180d16b9dc0974410d897afdb09eb7763ae65475b3a2579074790b0f" # Aleo user hex encoded
        "00000000000000000000000000000000000000000000000000038c95d0217000" # 999 * 10**12 in hex
    )

    m = Message(3, 4, 1, enrolled_router, 1, HYP_PROGRAM_HEX, bytes.fromhex(body))

    result = transact(
        "execute",
        "process",
        routing_ism,
        to_aleo_like(METADATA, numeric_suffix='8'),
        str(m.get_aleo_struct()),
        "141u32",
        str(m.get_aleo_message_id()),
        to_aleo_like([0]*512, numeric_suffix=8)
    )

    user_balance_after = get_program_mapping_value("token_registry.aleo", "authorized_balances", balance_key)
    user_balance_after = user_balance_after["balance"] if user_balance_after else 0

    assert result.get("success"), "Process transaction with custom ISM failed"
    assert int(user_balance_after) - int(user_balance_before) == 999

def test_ownership_transfer():
    
    result = transact(
        "execute",
        "set_owner",
        SECONDARY_ACCOUNT["address"],
    )

    assert result.get("success"), "Ownership transfer failed"

    onchain_metadata = get_mapping_value("app_metadata", "true")
    assert onchain_metadata["token_owner"] == SECONDARY_ACCOUNT["address"], "Ownership not transferred correctly on-chain"
