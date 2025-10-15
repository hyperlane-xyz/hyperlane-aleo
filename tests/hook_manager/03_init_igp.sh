#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager
transact leo execute init_igp || exit 1

address=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h
assert_mapping_value hook_manager.aleo hook_addresses 1u32 $address || exit 1
