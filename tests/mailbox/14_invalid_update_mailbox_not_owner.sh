#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./mailbox
transact --expect-fail leo execute set_default_ism aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js || exit 1
transact --expect-fail leo execute set_required_hook aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w || exit 1
transact --expect-fail leo execute set_default_hook aleo17m49ce86fak78cz2ufndh083h5uk6s8mhe06r6m0g3kdvgz2avrq4m5y6w || exit 1
