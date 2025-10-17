#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./mailbox

ism="aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js"
default_hook="aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w"
required_hook="aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w"
custom_hook="aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h"
owner="aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px"
nonce=1
process=1

transact leo execute dispatch "{local_domain:1u32,nonce:${nonce}u32,process_count:${process}u32,default_ism:$ism,default_hook:$default_hook,required_hook:$required_hook,mailbox_owner:$owner}" 1u32 '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]' '[0u128, 0u128, 0u128, 0u128, 0u128, 0u128, 0u128, 0u128]' $custom_hook '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]' "[{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64}, {spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h, amount: 100020u64}]" || exit 1

expected="{\n  local_domain: 1u32,\n  nonce: 2u32,\n  process_count: 1u32,\n  default_ism: $ism,\n  default_hook: $default_hook,\n  required_hook: $required_hook,\n  mailbox_owner: $owner\n}"
assert_mapping_value mailbox.aleo mailbox true "$expected"

