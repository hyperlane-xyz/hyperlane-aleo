"""Exercise warp transfers through a program, where caller differs from signer."""
import json
import shutil
from pathlib import Path

from . import NULL_ADDRESS, get_mapping_value, transact, to_aleo_like

METHODS = (
    "transfer_remote",
    "transfer_remote_as_signer",
    "transfer_remote_with_hook",
    "transfer_remote_with_hook_as",
)


def build_intermediary(kind, directory):
    """Generate a test program that asserts actual balance changes around await."""
    router = f"hyp_{kind}.aleo"
    native = kind == "native"
    amount_type = "u64" if native else "u128"
    source = f"import {router};\nprogram transfer_test_{kind}.aleo {{\n"
    source += "    @noupgrade\n    async constructor() {}\n"
    if native:
        fund_call = "credits.aleo/transfer_public_as_signer(self.address, amount)"
    else:
        fund_call = "token_registry.aleo/transfer_public_as_signer(token_id, self.address, amount)"
    token_arg = "" if native else "public token_id: field, "
    source += f"""
    async transition fund({token_arg}public amount: {amount_type}) -> Future {{
        let funding = {fund_call};
        return await_funding(funding);
    }}
    async function await_funding(funding: Future) {{ funding.await(); }}
"""
    if kind == "collateral":
        source += """
    async transition approve(public token_id: field, public amount: u128) -> Future {
        let router = hyp_collateral.aleo/get_address();
        let approval = token_registry.aleo/approve_public(token_id, router, amount);
        return await_funding(approval);
    }
"""
    for method in METHODS:
        with_hook = "with_hook" in method
        signer_funded = native or method.endswith("signer") or method.endswith("_as")
        hook_args = ", public custom_hook: address, public hook_metadata: HookMetadata" if with_hook else ""
        call_args = ", custom_hook, hook_metadata" if with_hook else ""
        token_id = "" if native else ", metadata.token_id"
        source += f"""
    async transition {method}(
        public metadata: Metadata, public mailbox: MailboxState,
        public router: RemoteRouter, public destination: u32,
        public recipient: [u128; 2], public amount: {amount_type},
        public allowance: [CreditAllowance; 4]{hook_args}
    ) -> Future {{
        assert_neq(self.signer, self.address);
        let transfer = {router}/{method}(metadata, mailbox, router, destination,
            recipient, amount, allowance{call_args});
        return check_balances(transfer, self.signer, self.address, amount,
            {str(signer_funded).lower()}{token_id});
    }}
"""
    token_arg = "" if native else ", token_id: field"
    if native:
        keys = ""
        before = """
        let signer_before = Mapping::get(credits.aleo/account, signer);
        let caller_before = Mapping::get(credits.aleo/account, caller);
"""
        after = """
        let signer_after = Mapping::get(credits.aleo/account, signer);
        let caller_after = Mapping::get(credits.aleo/account, caller);
"""
        balance = ""
    else:
        keys = """
        let signer_key = BHP256::hash_to_field(TokenOwner { account: signer, token_id: token_id });
        let caller_key = BHP256::hash_to_field(TokenOwner { account: caller, token_id: token_id });
"""
        before = """
        let signer_before = Mapping::get(token_registry.aleo/authorized_balances, signer_key);
        let caller_before = Mapping::get(token_registry.aleo/authorized_balances, caller_key);
"""
        after = """
        let signer_after = Mapping::get(token_registry.aleo/authorized_balances, signer_key);
        let caller_after = Mapping::get(token_registry.aleo/authorized_balances, caller_key);
"""
        balance = ".balance"
    source += f"""
    async function check_balances(transfer: Future, signer: address, caller: address,
        amount: {amount_type}, signer_funded: bool{token_arg}) {{
        {keys}
        {before}
        transfer.await();
        {after}
        let signer_debit = signer_funded ? amount : 0{amount_type};
        let caller_debit = signer_funded ? 0{amount_type} : amount;
        assert_eq(signer_before{balance} - signer_after{balance}, signer_debit);
        assert_eq(caller_before{balance} - caller_after{balance}, caller_debit);
    }}
}}
"""
    (directory / "src").mkdir(parents=True)
    (directory / "src/main.leo").write_text(source)
    (directory / "program.json").write_text(json.dumps({
        "program": f"transfer_test_{kind}.aleo", "version": "0.1.0",
        "description": "Caller versus signer regression assertions", "license": "MIT",
        "leo": "3.3.1", "dependencies": [{
            "name": router, "location": "local",
            "path": str(Path(__file__).resolve().parents[1] / "warp" / f"hyp_{kind}"),
            "edition": None,
        }], "dev_dependencies": None,
    }))


def check_intermediary_transfers(kind, tmp_path, hook, signer_args=()):
    directory = tmp_path / kind
    build_intermediary(kind, directory)
    shutil.copyfile(Path(__file__).resolve().parents[1] / ".env.template", directory / ".env")
    # The helper is deployed after the existing suite has initialized the router.
    result = transact("deploy", "--skip", "hyp_", "manager", "dispatch", "mailbox", "token", cwd=directory)
    assert result["success"], result
    program = f"hyp_{kind}.aleo"
    metadata = get_mapping_value(program, "app_metadata", "true")
    mailbox = get_mapping_value("mailbox.aleo", "mailbox", "true")
    # Select the suite's free merkle hook so native balance deltas exclude IGP fees.
    result = transact("execute", "set_custom_hook", hook, cwd=f"warp/hyp_{kind}")
    assert result["success"], result
    metadata["hook"] = hook
    mailbox_state = {key: mailbox[key] for key in ("default_hook", "required_hook")}
    router = get_mapping_value(program, "remote_routers", "1u32")
    native = kind == "native"
    token_args = [] if native else [metadata["token_id"]]
    amount_type = "u64" if native else "u128"
    result = transact("execute", "fund", *token_args, f"100{amount_type}", *signer_args, cwd=directory)
    assert result["success"], result

    def bridge(method):
        args = [to_aleo_like(metadata, numeric_suffix=8), to_aleo_like(mailbox_state),
                f"{{domain: 1u32, recipient: {to_aleo_like(router['recipient'], numeric_suffix=8)}, gas: {router['gas']}u128}}", "1u32", "[0u128, 1u128]", f"7{amount_type}",
                to_aleo_like([{"spender": NULL_ADDRESS, "amount": 0}] * 4, numeric_suffix=64)]
        if "with_hook" in method:
            args.extend([hook, "{gas_limit: 0u128, extra_data: " + to_aleo_like([0] * 64, numeric_suffix=8) + "}"])
        return transact("execute", method, *args, *signer_args, cwd=directory)

    if kind == "collateral":
        # A funded intermediary must approve the router before caller-funded transfers.
        result = bridge("transfer_remote")
        assert not result["success"], "Caller-funded collateral transfer accepted without approval"
        result = transact("execute", "approve", *token_args, "14u128", *signer_args, cwd=directory)
        assert result["success"], result
    for method in METHODS:
        result = bridge(method)
        assert result["success"], f"{kind}/{method}: {result}"
    if kind == "collateral":
        result = bridge("transfer_remote_with_hook")
        assert not result["success"], "Caller-funded collateral transfer accepted after allowance exhausted"
