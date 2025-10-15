#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager
gas_overhead=10u128
exchange_rate=5000000000u128
gas_price=4u128
igp=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h
transact leo execute set_destination_gas_config $igp 1u32 "{gas_overhead:$gas_overhead,exchange_rate:$exchange_rate,gas_price:$gas_price}" || exit 1

expected="{\n  gas_overhead: $gas_overhead,\n  exchange_rate: $exchange_rate,\n  gas_price: $gas_price\n}"
assert_mapping_value hook_manager.aleo destination_gas_configs "{igp:$igp,destination:1u32}" "$expected" || exit 1
