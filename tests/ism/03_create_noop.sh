#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./ism_manager
transact leo execute init_noop || exit 1
assert_mapping_value ism_manager.aleo ism_addresses 1u32 aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js || exit 1