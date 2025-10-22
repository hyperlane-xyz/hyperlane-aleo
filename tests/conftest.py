import os
import shutil
import subprocess
import time
import json
import signal
from pathlib import Path
from typing import Dict, Any
import urllib.request
import urllib.error
import pytest

from tests import transact


DEVNET_READY_HEIGHT = 10  # Must be strictly greater than 9
DEVNET_TIMEOUT_SECONDS = 300  # Max wait time to reach ready height

def _read_latest_block_height() -> int | None:
    """Query the local devnet endpoint for the latest block height.

    Returns None if unavailable or unparsable.
    """
    url = "http://localhost:3030/testnet/block/latest"
    try:
        with urllib.request.urlopen(url, timeout=2) as resp:  # nosec B310 (local devnet)
            data = resp.read().decode("utf-8")
            # Attempt JSON parse first
            try:
                obj = json.loads(data)
                # Expect obj like {"block": {..., "height": <int>, ...}} or {"height": <int>} depending on version
                if isinstance(obj, dict):
                    if "height" in obj and isinstance(obj["height"], int):
                        return obj["height"]
                    # Fallback: search nested
                    for v in obj.values():
                        if isinstance(v, dict) and "height" in v and isinstance(v["height"], int):
                            return v["height"]
            except json.JSONDecodeError:
                pass
            # Fallback regex-like parse for '"height": <number>'
            import re
            m = re.search(r'"height"\s*:\s*(\d+)', data)
            if m:
                return int(m.group(1))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ValueError):
        return None
    return None


@pytest.fixture(scope="session", autouse=True)
def session_setup() -> Dict[str, Any]:
    """Start a leo devnet for the test session and wait until it is ready.

    Mirrors logic from run_tests.sh: ensure 'snarkos' exists, create tests/devnet dir,
    start devnet, wait for block height > 9, then yield context dict. On teardown, kill process.
    """
    print("[session_setup] Initializing test session & starting devnet...")

    # Dependency checks (fail fast similar to shell script behavior)
    snarkos_path = shutil.which("snarkos")
    leo_path = shutil.which("leo")
    if not snarkos_path:
        pytest.exit("snarkos is not installed or not in PATH. Refer to README for installation.")
    if not leo_path:
        pytest.exit("leo is not installed or not in PATH. Please install Leo CLI.")

    # Paths
    repo_root = Path(__file__).resolve().parent.parent  # python_tests/ -> repo root
    devnet_dir = repo_root / "tests" / "devnet"
    storage_dir = devnet_dir / "tmp"
    devnet_dir.mkdir(parents=True, exist_ok=True)

    # Start devnet (suppress output similar to redirect in bash script)
    cmd = [
        leo_path,
        "devnet",
        "--storage", "tmp",
        "--snarkos", snarkos_path,
        "--snarkos-features", "test_network",
        "--clear-storage",
        "--num-clients", "1",
        "-y",
    ]

    # Environment (pass through existing env; could add flags if needed)
    env = os.environ.copy()

    # Logging controls via env vars:
    # DEVNET_LOG=1 -> stream to console
    # DEVNET_LOG_FILE=/path/to/file -> write combined stdout+stderr to file (overrides streaming)
    log_to_console = os.getenv("DEVNET_LOG", "0") in {"1", "true", "True"}
    log_file_path = os.getenv("DEVNET_LOG_FILE")
    stdout_target = subprocess.DEVNULL
    stderr_target = subprocess.DEVNULL
    log_file_handle = None
    if log_file_path:
        try:
            log_file_handle = open(log_file_path, "w", buffering=1)  # line-buffered
            stdout_target = log_file_handle
            stderr_target = log_file_handle
        except OSError as e:
            print(f"[session_setup] Warning: could not open DEVNET_LOG_FILE '{log_file_path}': {e}. Falling back to console logging if enabled.")
            log_file_handle = None
    if log_file_handle is None and log_to_console:
        # Stream to parent stdout/stderr
        stdout_target = None  # inherit
        stderr_target = None

    proc: subprocess.Popen | None = None
    interrupted = False

    def _kill_devnet(force: bool = False):
        nonlocal proc
        if proc is None:
            return
        try:
            if proc.poll() is None:
                # Kill process group if started with new session
                sig = signal.SIGKILL if force else signal.SIGTERM
                try:
                    os.killpg(proc.pid, sig.value if hasattr(sig, 'value') else sig)
                except ProcessLookupError:
                    pass
                # Wait briefly
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    if not force:
                        _kill_devnet(force=True)
        except Exception as e:
            print(f"[session_setup] _kill_devnet error: {e}")

    # Temporary signal handlers to ensure cleanup if user Ctrl-C before fixture yields
    original_sigint = signal.getsignal(signal.SIGINT)
    original_sigterm = signal.getsignal(signal.SIGTERM)

    def _signal_handler(signum, frame):  # noqa: D401
        nonlocal interrupted
        interrupted = True
        print(f"[session_setup] Caught signal {signum}. Shutting down devnet...")
        _kill_devnet(force=False)
        # Call original handlers if they are not default ignore
        handler = original_sigint if signum == signal.SIGINT else original_sigterm
        if callable(handler):
            handler(signum, frame)
        else:
            raise KeyboardInterrupt()

    signal.signal(signal.SIGINT, _signal_handler)
    signal.signal(signal.SIGTERM, _signal_handler)

    try:
        try:
            proc = subprocess.Popen(
                cmd,
                cwd=str(devnet_dir),
                stdout=stdout_target,
                stderr=stderr_target,
                start_new_session=True,  # create its own process group for robust teardown
            )
        except OSError as e:
            pytest.exit(f"Failed to start leo devnet: {e}")

        devnet_pid = proc.pid
        print(f"[session_setup] Leo devnet started (PID: {devnet_pid})")

        time.sleep(2)  # initial grace period

        print(f"[session_setup] Waiting for devnet block height >= {DEVNET_READY_HEIGHT} (timeout {DEVNET_TIMEOUT_SECONDS}s)...")
        start_time = time.time()
        last_height = None
        while True:
            if interrupted:
                pytest.exit("Interrupted before devnet readiness.")
            retcode = proc.poll()
            if retcode is not None:
                pytest.exit(f"Devnet process terminated unexpectedly (exit code {retcode}) before readiness.")
            height = _read_latest_block_height()
            if height is not None:
                last_height = height
                if height >= DEVNET_READY_HEIGHT:
                    print(f"[session_setup] Devnet ready (height={height}).")
                    break
            elapsed = time.time() - start_time
            if elapsed > DEVNET_TIMEOUT_SECONDS:
                _kill_devnet(force=False)
                pytest.exit(f"Timeout waiting for devnet readiness. Last height={last_height}.")
            if int(elapsed) % 5 == 0:
                print(f"[session_setup] Waiting... height={last_height}")
            time.sleep(1)
        # Deploy required programs
        print("[session_setup] Deploying required programs...")
        result = transact("deploy", cwd="dispatch_proxy")
        assert result.get("success"), f"Deployment failed: {result}"

        context: Dict[str, Any] = {
            "message": "initialized",
            "version": 1,
            "devnet_pid": devnet_pid,
            "devnet_process": proc,
            "devnet_dir": str(devnet_dir),
            "storage_dir": str(storage_dir),
            "snarkos_path": snarkos_path,
            "leo_path": leo_path,
        }
    finally:
        # Restore original signal handlers BEFORE yielding (so tests run with normal behavior)
        signal.signal(signal.SIGINT, original_sigint)
        signal.signal(signal.SIGTERM, original_sigterm)

    # Yield and ensure teardown after tests
    try:
        yield context
    finally:
        print("[session_setup] Tearing down devnet...")
        _kill_devnet(force=False)
        if log_file_handle:
            try:
                log_file_handle.flush()
                log_file_handle.close()
            except Exception:
                pass
        print("[session_setup] Devnet stopped.")


@pytest.fixture(scope="session")
def session_data(session_setup):
    """Provide initialized session context to tests (backwards compatible alias)."""
    return session_setup