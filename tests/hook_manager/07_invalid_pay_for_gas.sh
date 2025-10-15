#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager

igp=aleo1n2f30mtkm3ttfhxlnw92pn8j4jp88v5x9606fj8u3rl0cgdys5ys2gxf7h
# Some random invalid credits amount that does not equal to the quote
credits_amount=1337
destination=1u32

expected_state="$(get_mapping_value hook_manager.aleo igps $igp)"
transact --expect-fail leo execute pay_for_gas $igp "[0u128,0u128]" $destination 10u128 ${credits_amount}u64 || exit 1

assert_mapping_value hook_manager.aleo igps $igp "$expected_state" || exit 1
