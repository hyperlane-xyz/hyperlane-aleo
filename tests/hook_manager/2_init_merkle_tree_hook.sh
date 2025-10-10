#/bin/sh
cd ./hook_manager
output=$(leo execute init_merkle_tree aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px --broadcast -y)
exit_code=$?
echo "$output"
if echo "$output" | grep -Eq '❌|Transaction rejected' ; then
    exit 1
fi
exit $exit_code