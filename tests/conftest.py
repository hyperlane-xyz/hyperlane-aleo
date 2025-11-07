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

SECONDARY_ACCOUNT = {
    "private_key": "APrivateKey1zkpBQcWng4ykyhgup4L5PchWrcCJzcyQg5tiDfhxdYxG8nw",
    "address": "aleo1zz48uvscp5ttnhqfw3qsmzt6lkcfadmk8tn9gadn5fteqarepv8sqhnpmw"
}


@pytest.fixture(scope="session", autouse=True)
def session_setup() -> Dict[str, Any]:
    """Start a leo devnode for the test session and wait until it is ready.
    """
    print("[session_setup] Initializing test session & starting devnode...")

    # Dependency checks (fail fast similar to shell script behavior)
    leo_path = shutil.which("leo")
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
        "devnode",
        "start",
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

        # Advancing 10 blocks to reach ready state
        try:
            subprocess.run(
                [leo_path, "devnode", "advance", "10"],
                cwd=str(devnet_dir),
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
        except Exception as e:
            pytest.exit(f"Failed to invoke devnode advance: {e}")


        # Deploy required programs
        print("[session_setup] Deploying required programs...")
        result = transact("deploy", cwd="warp/hyp_collateral")
        assert result.get("success"), f"Deployment failed: {result}"

        # Fund secondary wallet
        result = transact("execute", "credits.aleo/transfer_public", SECONDARY_ACCOUNT['address'], "1000000000u64")
        assert result.get("success"), f"Funding Secondary account failed: {result}"

        context: Dict[str, Any] = {
            "message": "initialized",
            "version": 1,
            "devnet_pid": devnet_pid,
            "devnet_process": proc,
            "devnet_dir": str(devnet_dir),
            "storage_dir": str(storage_dir),
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