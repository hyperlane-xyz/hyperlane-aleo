#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager

address="aleo1xpype6z9te6w6pk2xw6w7vr7swejurs09f5e3ypryevd2n4c4vzqvyh2ds"
expected_state="$(get_mapping_value hook_manager.aleo merkle_tree_hooks $address)"

zero_address="[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]"
transact --expect-fail leo execute post_dispatch $address "{version:3u8,nonce:0u32,origin_domain:0u32,sender:${zero_address},destination_domain:0u32,recipient:${zero_address},body:[0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128]}" '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]' '[{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64}, {spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64},{spender: aleo1wwfh5e70v42fal3dxn5j58gny7ahpuypz4y5qav482vxecvg7yxqqr52n6, amount: 0u64}]' || exit 1

# state should not change
assert_mapping_value hook_manager.aleo merkle_tree_hooks $address "$expected_state" || exit 1