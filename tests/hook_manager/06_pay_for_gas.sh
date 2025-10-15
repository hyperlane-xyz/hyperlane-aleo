#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager

igp=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h

# we expect following chain state
gas_limit=10
exchange_rate=5000000000
gas_price=4
credits_amount=$((($gas_limit * $exchange_rate * $gas_price) / 10000000000))
destination=1u32

transact leo execute pay_for_gas $igp "[0u128,0u128]" $destination ${gas_limit}u128 ${credits_amount}u64 || exit 1

expected_event="{\n  id: [\n    0u128,\n    0u128\n  ],\n  destination_domain: $destination,\n  gas_amount: ${gas_limit}u128,\n  payment: ${credits_amount}u64,\n  index: 0u32\n}"
assert_mapping_value hook_manager.aleo gas_payment_events "{hook:$igp,index:0u32}" "$expected_event" || exit 1

expected_state="{\n  hook_owner: aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px,\n  nonce: 1u32,\n  balance: ${credits_amount}u64,\n  count: 1u32\n}"
assert_mapping_value hook_manager.aleo igps $igp "$expected_state" || exit 1
