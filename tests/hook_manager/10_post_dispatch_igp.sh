#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager

address=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h

# we expect following chain state
gas_limit=50010 # this is the default gas limit
exchange_rate=5000000000
gas_price=4
credits_amount=$((($gas_limit * $exchange_rate * $gas_price) / 10000000000)) # this should equal to 1e6=1ALEO
destination=1u32

zero_address="[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]"

transact leo execute post_dispatch $address "{version:3u8,nonce:0u32,origin_domain:0u32,sender:${zero_address},destination_domain:$destination,recipient:${zero_address},body:[0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128]}" '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]' "[{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64}, {spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: $address, amount: ${credits_amount}u64}]" || exit 1

expected_event="{\n  id: [\n    305500755047380549860477129764077125867u128,\n    221627462165964962787487218581854376358u128\n  ],\n  destination_domain: $destination,\n  gas_amount: ${gas_limit}u128,\n  payment: ${credits_amount}u64,\n  index: 1u32\n}"
assert_mapping_value hook_manager.aleo gas_payment_events "{hook:$address,index:1u32}" "$expected_event" || exit 1

expected_state="{\n  hook_owner: aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px,\n  nonce: 1u32,\n  balance: ${credits_amount}u64,\n  count: 2u32\n}"
assert_mapping_value hook_manager.aleo igps $address "$expected_state" || exit 1
