#/bin/sh
cd ./ism_manager
output=$(leo execute init_message_id_multisig '[{ bytes: [3u8, 200u8, 66u8, 219u8, 134u8, 166u8, 163u8, 229u8, 36u8, 212u8, 166u8, 97u8, 83u8, 144u8, 193u8, 234u8, 142u8, 43u8, 149u8, 65u8] }, { bytes: [0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8] }, { bytes: [0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8] }, { bytes: [0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8] }, { bytes: [0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8] }, { bytes: [0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8] }]' 1u8 1u8 --broadcast -y)
exit_code=$?
echo "$output"
if echo "$output" | grep -Eq '❌|Transaction rejected' ; then
    exit 1
fi
exit $exit_code