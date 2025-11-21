set -e

LEO=~/Projects/aleo/leo/target/release/leo

SIGNING_OP_ID=$($LEO execute --skip-proving --yes hyp_collateral_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
echo "Signing op id: $SIGNING_OP_ID"

NEW_ISM=aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px


$LEO execute --skip-proving --yes --broadcast hyp_collateral_multisig.aleo/init_multisig_op $SIGNING_OP_ID "{op: 2u8, arg_addr_0: $NEW_ISM, arg_addr_1: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_2: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_3: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_u128_0: 0u128, arg_u128_1: 0u128, arg_u128_2: 0u128, arg_u128_3: 0u128, arg_bytes: [0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8]}"

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-proving --yes --broadcast multisig.aleo/sign hyp_collateral_multisig.aleo $SIGNING_OP_ID


$LEO execute --skip-proving --yes --broadcast hyp_collateral_multisig.aleo/exec_set_custom_ism $SIGNING_OP_ID $NEW_ISM
