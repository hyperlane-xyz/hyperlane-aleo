#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager

igp=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h
transact leo execute claim $igp 20u64 || exit 1

expected_state="{\n  hook_owner: aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px,\n  nonce: 1u32,\n  balance: 0u64,\n  count: 1u32\n}"
assert_mapping_value hook_manager.aleo igps $igp "$expected_state" || exit 1
