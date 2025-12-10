set -e

WALLET_ID=$($LEO execute --skip-execute-proof --yes hyp_multisig.aleo/wallet_id | grep '• aleo' | awk '{print $2}')
SIGNING_OP_ID=$($LEO execute --skip-execute-proof --yes hyp_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
BLOCK_EXPIRATION=10u32
echo "Signing op id: $SIGNING_OP_ID"

IGP=aleo1luec7p59xlxlldvh697073yn6prwpv59ax32utu6tpq40c4ahs9q3axudk
DST_DOMAIN=1
GAS_OVERHEAD=10
EXCHANGE_RATE=20
GAS_PRICE=30

$LEO execute --skip-execute-proof --yes --broadcast hyp_multisig.aleo/init_multisig_op $SIGNING_OP_ID $BLOCK_EXPIRATION "{op: 20u8, arg_addr_0: $IGP, arg_addr_1: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_2: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_addr_3: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, arg_u128_0: ${DST_DOMAIN}u128, arg_u128_1: ${GAS_OVERHEAD}u128, arg_u128_2: ${EXCHANGE_RATE}u128, arg_u128_3: ${GAS_PRICE}u128}"

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-execute-proof --yes --broadcast test_hyp_multisig_core.aleo/sign $WALLET_ID $SIGNING_OP_ID


$LEO execute --skip-execute-proof --yes --broadcast hyp_multisig.aleo/exec_hook_mgr_set_gas_config $SIGNING_OP_ID $IGP ${DST_DOMAIN}u32 "{gas_overhead: ${GAS_OVERHEAD}u128, exchange_rate: ${EXCHANGE_RATE}u128, gas_price: ${GAS_PRICE}u128}"
