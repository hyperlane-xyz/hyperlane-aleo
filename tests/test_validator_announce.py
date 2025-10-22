from . import get_mapping_value as get_program_mapping_value, program_exists, transact as cwd_transact, to_aleo_like, message

def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value("validator_announce.aleo", mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="validator_announce", **kwargs)

def test_deploy():
    if program_exists("validator_announce.aleo"):
        return
    result = transact("deploy")
    assert result.get("success"), f"Deployment failed: {result}"

def test_init_validator_announce():
    exists = get_mapping_value("validator_announce", "true")
    if exists:
        return
    mailbox = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 243, 159, 214, 229, 26, 173, 136, 246, 244, 206, 106, 184, 130, 114, 121, 207, 255, 185, 34, 102]
    mailbox_domain = 1337
    result = transact(
        "execute",
        "init",
        to_aleo_like(mailbox, numeric_suffix=8),
        f"{mailbox_domain}u32",
    )
    assert result.get("success"), f"Validator announce init failed: {result}"

def test_announcment():
    validator=list(bytes.fromhex("ff9e86a205c887960599db2403882d248edfbfd8"))
    storage_location=list(b's3://test-storage-location')
    signature=[49,79,115,205,135,168,6,90,7,164,0,230,148,23,61,93,182,200,40,253,157,218,39,190,206,221,132,95,3,202,77,157,33,97,90,125,131,186,219,67,185,117,221,170,15,54,31,3,153,67,116,232,24,104,144,193,253,51,19,105,252,204,110,121,0]
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
    print(eth_address)
    sequence = get_mapping_value("storage_sequences", eth_address)
    assert sequence == '1', f"Incorrect storage sequence, expected 1 but got {sequence}"

    storage_location_key = f'{{validator: {eth_address_bytes}, index: 0u8}}'
    stored_location = get_mapping_value("storage_locations", storage_location_key)

    assert stored_location == storage_location + [0] * (480 - len(storage_location)), f"Incorrect storage location, expected {storage_location} but got {stored_location}"

def test_announcment_replay():
    validator=list(bytes.fromhex("ff9e86a205c887960599db2403882d248edfbfd8"))
    storage_location=list(b's3://test-storage-location')
    signature=[49,79,115,205,135,168,6,90,7,164,0,230,148,23,61,93,182,200,40,253,157,218,39,190,206,221,132,95,3,202,77,157,33,97,90,125,131,186,219,67,185,117,221,170,15,54,31,3,153,67,116,232,24,104,144,193,253,51,19,105,252,204,110,121,0]
    result = transact(
        "execute",
        "announce",
        to_aleo_like(validator, numeric_suffix=8),
        to_aleo_like(storage_location + [0] * (480 - len(storage_location)), numeric_suffix=8),
        to_aleo_like(signature, numeric_suffix=8),
    )
    assert not result.get("success"), f"Validator announce replay should have failed but succeeded: {result}"

def test_invalid_announcement():
    validator=list(bytes.fromhex("ff9e86a205c887960599db2403882d248edfbfd8"))
    storage_location=list(b's3://test-storage-location/some_other_path')
    signature=[49,79,115,205,135,168,6,90,7,164,0,230,148,23,61,93,182,200,40,253,157,218,39,190,206,221,132,95,3,202,77,157,33,97,90,125,131,186,219,67,185,117,221,170,15,54,31,3,153,67,116,232,24,104,144,193,253,51,19,105,252,204,110,121,0]
    result = transact(
        "execute",
        "announce",
        to_aleo_like(validator, numeric_suffix=8),
        to_aleo_like(storage_location + [0] * (480 - len(storage_location)), numeric_suffix=8),
        to_aleo_like(signature, numeric_suffix=8),
    )
    assert not result.get("success"), f"Invalid validator announce should have failed but succeeded: {result}"

