#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager

igp=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h
expected_state="$(get_mapping_value hook_manager.aleo igps $igp)"
# Try to claim more balance than available
transact --expect-fail leo execute claim $igp 100u64 || exit 1
# We exepcted the tx to revert and not change the IGP state
assert_mapping_value hook_manager.aleo igps $igp "$expected_state" || exit 1
