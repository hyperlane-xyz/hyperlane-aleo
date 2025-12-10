set -e


CHECKSUM='[221u8, 102u8, 111u8, 130u8, 253u8, 61u8, 91u8, 85u8, 4u8, 67u8, 173u8, 39u8, 188u8, 170u8, 42u8, 176u8, 231u8, 254u8, 39u8, 240u8, 138u8, 10u8, 93u8, 228u8, 231u8, 32u8, 171u8, 94u8, 227u8, 102u8, 223u8, 218u8]'
EDITION=1u16

SIGNING_OP_ID=$($LEO execute --skip-execute-proof --yes test_upgrades.aleo/get_signing_op_id_for_deploy "$CHECKSUM" $EDITION | grep field | awk '{print $2}')
BLOCK_EXPIRATION=10u32
echo "Signing op id: $SIGNING_OP_ID"

$LEO execute --skip-execute-proof --yes --broadcast test_hyp_multisig_core.aleo/initiate_signing_op hyp_multisig.aleo $SIGNING_OP_ID $BLOCK_EXPIRATION

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-execute-proof --yes --broadcast test_hyp_multisig_core.aleo/sign hyp_multisig.aleo $SIGNING_OP_ID

$LEO upgrade --broadcast --consensus-heights 0,1,2,3,4,5,6,7,8,9,10,11 -y --skip hyp_multisig_core
