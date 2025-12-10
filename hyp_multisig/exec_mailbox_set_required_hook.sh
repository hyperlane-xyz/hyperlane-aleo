set -e

WALLET_ID=$($LEO execute --skip-execute-proof --yes hyp_multisig.aleo/wallet_id | grep '• aleo' | awk '{print $2}')
SIGNING_OP_ID=$($LEO execute --skip-execute-proof --yes hyp_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
BLOCK_EXPIRATION=10u32
echo "Signing op id: $SIGNING_OP_ID"


NEW_ADDR=aleo14ls9u9c9mcyvc7zre0255ut4he7kankqpckqnvtvn96jm8pcxugssucen8
#NEW_ADDR=aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc
echo "New address: $NEW_ADDR"

$LEO execute --skip-execute-proof --yes --broadcast hyp_multisig.aleo/init_multisig_op $SIGNING_OP_ID $BLOCK_EXPIRATION "{op: 5u8, arg_addr_0: $NEW_ADDR, arg_addr_1: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_2: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_3: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_u128_0: 0u128, arg_u128_1: 0u128, arg_u128_2: 0u128, arg_u128_3: 0u128}"

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-execute-proof --yes --broadcast hyp_multisig_core.aleo/sign $WALLET_ID $SIGNING_OP_ID


$LEO execute --skip-execute-proof --yes --broadcast hyp_multisig.aleo/exec_mailbox_set_required_hook $SIGNING_OP_ID $NEW_ADDR
