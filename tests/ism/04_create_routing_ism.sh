#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./ism_manager
transact leo execute init_domain_routing || exit 1
assert_mapping_value ism_manager.aleo ism_addresses 2u32 aleo1dslkjqrdaxthmcm8lfqcxj67y277guk0wrpnm4dztc24x8pnkvzsj27rv9 || exit 1
