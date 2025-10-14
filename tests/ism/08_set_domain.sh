#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./ism_manager

routing_ism=aleo1dslkjqrdaxthmcm8lfqcxj67y277guk0wrpnm4dztc24x8pnkvzsj27rv9
message_id_ism=aleo1jng84kfxuwvhzepgtmnvchgm2xqgzrmde2u350rv8dhdln0pa5zstj3u9d

# domain: 0u32 recursive route 
transact leo execute set_domain $routing_ism 0u32 $routing_ism || exit 1
# domain: 1u32 message_id_multisig 
transact leo execute set_domain $routing_ism 1u32 $message_id_ism || exit 1

assert_mapping_value ism_manager.aleo routes "{ism:$routing_ism,domain:0u32}" "$routing_ism" || exit 1
assert_mapping_value ism_manager.aleo routes "{ism:$routing_ism,domain:1u32}" "$message_id_ism" || exit 1
