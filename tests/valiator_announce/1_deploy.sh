#/bin/sh
cd ./validator_announce
output=$(leo deploy --broadcast -y)
exit_code=$?
echo "$output"
if echo "$output" | grep -Eq '❌|Transaction rejected' ; then
    exit 1
fi
exit $exit_code