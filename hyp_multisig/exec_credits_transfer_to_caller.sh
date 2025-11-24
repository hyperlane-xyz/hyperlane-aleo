set -e

LEO=~/Projects/aleo/leo/target/release/leo

SIGNING_OP_ID=$($LEO execute --skip-proving --yes hyp_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
BLOCK_EXPIRATION=10u32
echo "Signing op id: $SIGNING_OP_ID"

#HYP_MULTISIG_ADDR=$($LEO execute --skip-proving --yes hyp_multisig.aleo/get_self_address | grep " • aleo" | awk '{print $2}')
#echo "Hyp multisig address: $HYP_MULTISIG_ADDR"

AMOUNT=5

$LEO execute --skip-proving --yes --broadcast hyp_multisig.aleo/init_multisig_op $SIGNING_OP_ID $BLOCK_EXPIRATION "{op: 30u8, arg_addr_0: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_1: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_2: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_3: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_u128_0: ${AMOUNT}u128, arg_u128_1: 0u128, arg_u128_2: 0u128, arg_u128_3: 0u128}"

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-proving --yes --broadcast multisig_impl.aleo/sign hyp_multisig.aleo $SIGNING_OP_ID


$LEO execute --skip-proving --yes --broadcast hyp_multisig.aleo/exec_credits_transfer_to_caller $SIGNING_OP_ID ${AMOUNT}u64