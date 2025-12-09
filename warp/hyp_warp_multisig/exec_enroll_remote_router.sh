set -e

WALLET_ID=$($LEO execute --skip-execute-proof --yes hyp_warp_multisig.aleo/wallet_id | grep '• aleo' | awk '{print $2}')
SIGNING_OP_ID=$($LEO execute --skip-execute-proof --yes hyp_warp_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
BLOCK_EXPIRATION=10u32
echo "Signing op id: $SIGNING_OP_ID"

DESTINATION=1
GAS=12345
RECIPIENT='[12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8, 12u8]'


$LEO execute --skip-execute-proof --yes --broadcast hyp_warp_multisig.aleo/init_multisig_op $SIGNING_OP_ID $BLOCK_EXPIRATION "{op: 4u8, arg_addr_0: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_1: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_2: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_3: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_u128_0: ${DESTINATION}u128, arg_u128_1: ${GAS}u128, arg_u128_2: 0u128, arg_u128_3: 0u128, arg_bytes: $RECIPIENT}"

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-execute-proof --yes --broadcast hyp_multisig_core.aleo/sign $WALLET_ID $SIGNING_OP_ID


$LEO execute --skip-execute-proof --yes --broadcast hyp_warp_multisig.aleo/exec_enroll_remote_router $SIGNING_OP_ID ${DESTINATION}u32  "$RECIPIENT" ${GAS}u128
