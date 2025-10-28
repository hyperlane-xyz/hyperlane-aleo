from . import get_mapping_value as get_program_mapping_value, program_exists, transact as cwd_transact, to_aleo_like, \
    message, NULL_ADDRESS, CALLER


def get_mapping_value(mapping: str, key: str):
    return get_program_mapping_value("hyp_native_template.aleo", mapping, key)

def transact(*args, **kwargs):
    return cwd_transact(*args, cwd="warp/hyp_native_template", **kwargs)

def test_deploy():
    if program_exists("hyp_native_template.aleo"):
        return
    result = transact("deploy")
    assert result.get("success"), f"Deployment failed: {result}"

def test_init():
    exists = get_mapping_value("token_metadata", "true")
    if exists:
        return
    name = [ord('N'), ord('A'), ord('T'), ord('I'), ord('V'), ord('E')] + ([0] * (128-6))
    result = transact(
        "execute",
        "init",
        to_aleo_like(name, numeric_suffix='8'),
    )
    assert result.get("success"), f"Warp Hyp Native init failed: {result}"
    token_metadata = get_mapping_value("token_metadata", "true")
    assert token_metadata["custom_ism_address"] == NULL_ADDRESS
    assert token_metadata["token_owner"] == CALLER
    assert token_metadata["name"] == name

# TODO do not allow to init again

def test_enroll_remote_router():
    exists = get_mapping_value("token_metadata", "true")
    if exists:
        return
    name = [ord('N'), ord('A'), ord('T'), ord('I'), ord('V'), ord('E')] + ([0] * (128-6))
    result = transact(
        "execute",
        "init",
        to_aleo_like(name, numeric_suffix='8'),
    )
    assert result.get("success"), f"Warp Hyp Native init failed: {result}"
    token_metadata = get_mapping_value("token_metadata", "true")
    assert token_metadata["custom_ism_address"] == NULL_ADDRESS
    assert token_metadata["token_owner"] == CALLER
    assert token_metadata["name"] == name
