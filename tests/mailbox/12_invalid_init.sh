#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./mailbox
transact --expect-fail leo execute init 1u32 || exit 1
