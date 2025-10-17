#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./mailbox
transact leo deploy || exit 1
