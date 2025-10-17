#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./hook_manager
transact leo execute init_noop || exit 1

address=aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w
assert_mapping_value hook_manager.aleo hook_addresses 2u32 $address || exit 1
