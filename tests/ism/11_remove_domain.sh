#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./ism_manager

routing_ism=aleo1dslkjqrdaxthmcm8lfqcxj67y277guk0wrpnm4dztc24x8pnkvzsj27rv9

# domain: remove 0u32 recursive route 
transact leo execute remove_domain $routing_ism 0u32 || exit 1
assert_mapping_value ism_manager.aleo routes "{ism:$routing_ism,domain:0u32}" null || exit 1
