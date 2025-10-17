#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./mailbox

ism="aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js"
default_hook="aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w"
required_hook="aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w"
owner="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px"
nonce=0
process=0

transact leo execute dispatch "{local_domain:1u32,nonce:${nonce}u32,process_count:${process}u32,default_ism:$ism,default_hook:$default_hook,required_hook:$required_hook,mailbox_owner:$owner}" 1u32 '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]' '[0u128, 0u128, 0u128, 0u128, 0u128, 0u128, 0u128, 0u128]' aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]' "[{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64}, {spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h, amount: 100020u64}]" || exit 1

expected="{\n  local_domain: 1u32,\n  nonce: 1u32,\n  process_count: 0u32,\n  default_ism: $ism,\n  default_hook: $default_hook,\n  required_hook: $required_hook,\n  mailbox_owner: $owner\n}"
assert_mapping_value mailbox.aleo mailbox true "$expected"

expected_event="{\n  version: 3u8,\n  nonce: 0u32,\n  origin_domain: 1u32,\n  sender: [\n    29u8,\n    208u8,\n    222u8,\n    123u8,\n    215u8,\n    65u8,\n    0u8,\n    216u8,\n    154u8,\n    82u8,\n    63u8,\n    49u8,\n    200u8,\n    202u8,\n    69u8,\n    26u8,\n    172u8,\n    55u8,\n    11u8,\n    91u8,\n    152u8,\n    136u8,\n    211u8,\n    189u8,\n    19u8,\n    192u8,\n    232u8,\n    147u8,\n    97u8,\n    223u8,\n    189u8,\n    7u8\n  ],\n  destination_domain: 1u32,\n  recipient: [\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8,\n    0u8\n  ],\n  body: [\n    0u128,\n    0u128,\n    0u128,\n    0u128,\n    0u128,\n    0u128,\n    0u128,\n    0u128\n  ]\n}"
assert_mapping_value mailbox.aleo dispatch_events 0u32 "$expected_event"

expected_id="[\n  206311151436130677509391867032744449862u128,\n  102162400840208163612337854125384328904u128\n]"
assert_mapping_value mailbox.aleo dispatch_id_events 0u32 "$expected_id"
