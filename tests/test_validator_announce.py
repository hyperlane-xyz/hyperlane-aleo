from . import get_mapping_value as get_program_mapping_value, program_exists, transact as cwd_transact, to_aleo_like

def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value("hyp_validator_announce.aleo", mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="validator_announce", **kwargs)

def test_deploy():
    if program_exists("hyp_validator_announce.aleo"):
        return
    result = transact("deploy")
    assert result.get("success"), f"Deployment failed: {result}"

def test_init_validator_announce():
    exists = get_mapping_value("validator_announce", "true")
    if exists:
        return
    mailbox = "aleo1zz48uvscp5ttnhqfw3qsmzt6lkcfadmk8tn9gadn5fteqarepv8sqhnpmw"
    mailbox_domain = 1337
    result = transact(
        "execute",
        "init",
        mailbox,
        f"{mailbox_domain}u32",
    )
    assert result.get("success"), f"Validator announce init failed: {result}"

def test_announcement():
    validator=list(bytes.fromhex("22F082EeA6b04C68DAc4d2040c82be8047a4B83C"))
    storage_location=list(b's3://test-storage-location')
    signature=[120, 41, 103, 197, 252, 144, 43, 244, 27, 189, 202, 30, 87, 138, 87, 11, 103, 59, 37, 15, 250, 7, 90, 28, 37, 191, 94, 231, 23, 177, 152, 135, 8, 253, 62, 1, 114, 215, 98, 99, 122, 81, 206, 41, 126, 118, 222, 10, 144, 64, 55, 62, 220, 115, 62, 84, 37, 253, 115, 47, 168, 145, 80, 207, 0]
    result = transact(
        "execute",
        "announce",
        to_aleo_like(validator, numeric_suffix=8),
        to_aleo_like(storage_location + [0] * (480 - len(storage_location)), numeric_suffix=8),
        to_aleo_like(signature, numeric_suffix=8),
    )
    assert result.get("success"), f"Validator announce failed: {result}"
    eth_address_bytes = to_aleo_like(validator, numeric_suffix=8)
    eth_address = f'{{bytes: {eth_address_bytes}}}'
    sequence = get_mapping_value("storage_sequences", eth_address)
    assert sequence == '1', f"Incorrect storage sequence, expected 1 but got {sequence}"

    storage_location_key = f'{{validator: {eth_address_bytes}, index: 0u8}}'
    stored_location = get_mapping_value("storage_locations", storage_location_key)

    assert stored_location == storage_location + [0] * (480 - len(storage_location)), f"Incorrect storage location, expected {storage_location} but got {stored_location}"

def test_announcement_replay():
    validator=list(bytes.fromhex("22F082EeA6b04C68DAc4d2040c82be8047a4B83C"))
    storage_location=list(b's3://test-storage-location')
    signature=[120, 41, 103, 197, 252, 144, 43, 244, 27, 189, 202, 30, 87, 138, 87, 11, 103, 59, 37, 15, 250, 7, 90, 28, 37, 191, 94, 231, 23, 177, 152, 135, 8, 253, 62, 1, 114, 215, 98, 99, 122, 81, 206, 41, 126, 118, 222, 10, 144, 64, 55, 62, 220, 115, 62, 84, 37, 253, 115, 47, 168, 145, 80, 207, 0]
    result = transact(
        "execute",
        "announce",
        to_aleo_like(validator, numeric_suffix=8),
        to_aleo_like(storage_location + [0] * (480 - len(storage_location)), numeric_suffix=8),
        to_aleo_like(signature, numeric_suffix=8),
    )
    assert not result.get("success"), f"Validator announce replay should have failed but succeeded: {result}"

def test_invalid_announcement():
    validator=list(bytes.fromhex("22F082EeA6b04C68DAc4d2040c82be8047a4B83C"))
    storage_location=list(b's3://test-storage-location/some_other_path')
    signature=[120, 41, 103, 197, 252, 144, 43, 244, 27, 189, 202, 30, 87, 138, 87, 11, 103, 59, 37, 15, 250, 7, 90, 28, 37, 191, 94, 231, 23, 177, 152, 135, 8, 253, 62, 1, 114, 215, 98, 99, 122, 81, 206, 41, 126, 118, 222, 10, 144, 64, 55, 62, 220, 115, 62, 84, 37, 253, 115, 47, 168, 145, 80, 207, 0]
    result = transact(
        "execute",
        "announce",
        to_aleo_like(validator, numeric_suffix=8),
        to_aleo_like(storage_location + [0] * (480 - len(storage_location)), numeric_suffix=8),
        to_aleo_like(signature, numeric_suffix=8),
    )
    assert not result.get("success"), f"Invalid validator announce should have failed but succeeded: {result}"

