#/bin/sh
. "$(cd "$(dirname "$0")" && pwd)/../helpers.sh"
cd ./validator_announce
transact leo execute init '[0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 243u8, 159u8, 214u8, 229u8, 26u8, 173u8, 136u8, 246u8, 244u8, 206u8, 106u8, 184u8, 130u8, 114u8, 121u8, 207u8, 255u8, 185u8, 34u8, 102u8]' 1337u32 || exit 1
