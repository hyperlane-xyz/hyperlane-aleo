from typing import Mapping
from urllib import request
import json
import os
import re
from urllib.parse import quote

BASE = "http://localhost:3030/testnet/program/"
CALLER="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px"
NULL_ADDRESS="aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc"
LOCAL_DOMAIN = 1

def message(
    version: int = 3,
    nonce: int = 0,
    origin: int = 0,
    sender: list[int] | None = None,
    destination_domain: int = 0,
    recipient: list[int] | None = None,
    body: list[int] | None = None,
) -> str:
    """
    Construct a message string in aleo-like format.

    Parameters
    ----------
    version : int (u8)
    nonce : int (u32)
    origin : int (u32)
    sender : list[int] length 32 (each u8)
    destination_domain : int (u32)
    recipient : list[int] length 32 (each u8)
    body : list[int] length 8 (each u128)
    multiline : bool
        If True, pretty-print across multiple lines.
    """
    sender = sender or [0] * 32
    recipient = recipient or [0] * 32
    body = body or [0] * 8

    def fmt(lst: list[int], suffix: str) -> str:
        return ", ".join(f"{b}u{suffix}" for b in lst)

    return (
        "{"
        f"version: {version}u8, "
        f"nonce: {nonce}u32, "
        f"origin_domain: {origin}u32, "
        f"sender: [{fmt(sender,'8')}], "
        f"destination_domain: {destination_domain}u32, "
        f"recipient: [{fmt(recipient,'8')}], "
        f"body: [{fmt(body,'128')}]"
        "}"
    )

def _parse_mapping_response(raw: str) -> dict:
    if not raw:
        return {}
    if "\\n" in raw and "\n" not in raw:
        raw = raw.encode("utf-8").decode("unicode_escape")
    raw = raw.strip()
    if len(raw) > 2 and ((raw[0] == raw[-1] == '"') or (raw[0] == raw[-1] == "'")) and raw[1] == '{':
        raw = raw[1:-1].strip()
    raw = re.sub(r'(\b[a-zA-Z_][a-zA-Z0-9_]*)\s*:', r'"\1":', raw)
    raw = re.sub(r'(\d+)u(128|64|32|16|8)', r'\1', raw)
    raw = re.sub(r'(:\s*)(aleo[0-9a-zA-Z]+)', r'\1"\2"', raw)
    raw = re.sub(r'(:\s*)([0-9a-zA-Z]+field)', r'\1"\2"', raw)
    raw = re.sub(r'"(\[\s*(?:\d+\s*(?:,\s*\d+\s*)*)\])"', r'\1', raw)
    try:
        return json.loads(raw)
    except Exception:
        return {}

def to_aleo_like(data, numeric_suffix: str | None = None) -> str:
    """
    Convert any Python value (dict, list, scalar) into a simplified 'aleo-like' string.

    Parameters
    ----------
    data : Any
        Input data (dict, list/tuple, scalar).
    numeric_suffix : str | None
        If provided (e.g. '128'), append as u{suffix} to every int value.

    Returns
    -------
    str
        Aleo-like representation:
          - Dict keys unquoted if identifier-like
          - Aleo addresses (aleo...) left bare
          - Lists rendered with brackets
          - Ints optionally suffixed
    """

    def fmt_key(k: str) -> str:
        if isinstance(k, str) and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', k):
            return k
        return json.dumps(str(k))

    def fmt_val(v):
        if isinstance(v, Mapping):
            return _inner_map(v)
        if isinstance(v, (list, tuple, set)):
            return "[" + ", ".join(fmt_val(x) for x in v) + "]"
        if isinstance(v, bool):
            return "true" if v else "false"
        if v is None:
            return "null"
        if isinstance(v, int) and not isinstance(v, bool) or isinstance(v, float):
            return f"{v}u{numeric_suffix}" if numeric_suffix else str(v)
        if isinstance(v, bytes):
            try:
                s = v.decode("utf-8")
            except Exception:
                s = v.hex()
            return json.dumps(s)
        if isinstance(v, str):
            if re.fullmatch(r'(aleo[0-9A-Za-z]+)|([0-9]+field)', v):
                return v
            return json.dumps(v)
        # Fallback: JSON stringified representation
        try:
            return json.dumps(v)
        except Exception:
            return json.dumps(str(v))

    def _inner_map(m) -> str:
        parts = []
        for k, v in m.items():
            parts.append(f"{fmt_key(k)}: {fmt_val(v)}")
        return "{" + ", ".join(parts) + "}"

    # Top-level formatting
    return fmt_val(data)

def get_mapping_value_raw(program: str, mapping: str, key: str) -> str:
    encoded_key = quote(key, safe='')
    url = f"{BASE}{program}/mapping/{mapping}/{encoded_key}"
    try:
        with request.urlopen(url, timeout=5) as resp:
            data = resp.read().decode("utf-8")
        return data
    except Exception:
        return ""

def get_mapping_value(program: str, mapping: str, key: str) -> dict:
    return _parse_mapping_response(get_mapping_value_raw(program, mapping, key))

def program_exists(program: str) -> bool:
    url = f"{BASE}{program}/mappings"
    try:
        with request.urlopen(url, timeout=5) as resp:
            data = resp.read().decode("utf-8")
            if json.loads(data):
                return True
    except Exception:
        return False
    return False

def transact(*cmd, cwd=os.getcwd(), timeout: float = 600.0) -> dict:
    """Run a leo/aleo CLI transaction command, appending broadcast flags.

    Mirrors logic in `tests/helpers.sh` transact:
      - Adds --broadcast -y flags
      - Captures combined stdout/stderr
      - Detects failure patterns (❌ or 'Transaction rejected')

    Parameters
    ----------
    *cmd : str
        The base command and arguments as individual string items, e.g.
        transact('run', 'my_program')
    timeout : float
        Seconds before the process is forcibly terminated.

    Returns
    -------
    dict with keys:
        command: list[str] full executed command
        output: str combined stdout+stderr
        exit_code: int process return code
        success: bool (currently True if failure detected)
        cwd: str current working directory when executed
    """
    import subprocess

    if not cmd:
        raise ValueError("transact: at least one command element required")

    base_cmd = [str(c) for c in cmd]

    full_cmd = ["leo"] + base_cmd + ["--broadcast", "-y", "--max-wait", "180", "--blocks-to-check", "500"]
    if "execute" in base_cmd:
        full_cmd += ["--skip-proving"]
    try:
        proc = subprocess.run(
            full_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            text=True,
            cwd=cwd,
        )
        output = proc.stdout
        exit_code = proc.returncode
    except subprocess.TimeoutExpired as e:
        output = (e.stdout or "") + (e.stderr or "") + "\n<timeout>"
        exit_code = -1
    except FileNotFoundError:
        output = "Command not found"
        exit_code = 127

    success = True
    if re.search(r'(❌|Transaction rejected)', output):
        success = False
    if exit_code != 0:
        success = False

    return {
        "command": full_cmd,
        "output": output,
        "exit_code": exit_code,
        "success": success,
        "cwd": cwd,
    }
