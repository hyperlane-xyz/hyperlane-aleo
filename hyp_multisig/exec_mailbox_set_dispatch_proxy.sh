set -e

LEO=~/Projects/aleo/leo/target/release/leo

SIGNING_OP_ID=$($LEO execute --skip-proving --yes hyp_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
echo "Signing op id: $SIGNING_OP_ID"

#HYP_MULTISIG_ADDR=$($LEO execute --skip-proving --yes hyp_multisig.aleo/get_self_address | grep " • aleo" | awk '{print $2}')
#echo "Hyp multisig address: $HYP_MULTISIG_ADDR"

NEW_ADDR=aleo14ls9u9c9mcyvc7zre0255ut4he7kankqpckqnvtvn96jm8pcxugssucen8
#NEW_ADDR=aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc
echo "New address: $NEW_ADDR"

$LEO execute --skip-proving --yes --broadcast hyp_multisig.aleo/init_mailbox_set_dispatch_proxy $SIGNING_OP_ID $NEW_ADDR

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-proving --yes --broadcast multisig.aleo/sign hyp_multisig.aleo $SIGNING_OP_ID


$LEO execute --skip-proving --yes --broadcast hyp_multisig.aleo/exec_mailbox_set_dispatch_proxy $SIGNING_OP_ID $NEW_ADDR
