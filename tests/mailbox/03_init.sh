#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./mailbox
transact leo execute init 1u32 || exit 1

transact leo execute set_default_ism aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js || exit 1
transact leo execute set_required_hook aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w || exit 1
transact leo execute set_default_hook aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w || exit 1

expected="{\n  local_domain: 1u32,\n  nonce: 0u32,\n  process_count: 0u32,\n  default_ism: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js,\n  default_hook: aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w,\n  required_hook: aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w,\n  mailbox_owner: aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px\n}"
assert_mapping_value mailbox.aleo mailbox true "$expected"