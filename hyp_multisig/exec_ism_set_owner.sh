set -e

LEO=~/Projects/aleo/leo/target/release/leo

SIGNING_OP_ID=$($LEO execute --skip-proving --yes hyp_multisig.aleo/nonce_to_signing_op_id ${RANDOM}u32 | grep field | awk '{print $2}')
echo "Signing op id: $SIGNING_OP_ID"

#HYP_MULTISIG_ADDR=$($LEO execute --skip-proving --yes hyp_multisig.aleo/get_self_address | grep " • aleo" | awk '{print $2}')
#echo "Hyp multisig address: $HYP_MULTISIG_ADDR"

ISM=aleo1f5mzhgkks98p6ues5axvsjh49fw5frk7nnnrumz2n6ez5zw4ws9qh42cf6
NEW_OWNER=aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px


$LEO execute --skip-proving --yes --broadcast hyp_multisig.aleo/init_multisig_op $SIGNING_OP_ID "{op: 12u8, arg_addr_0: $ISM, arg_addr_1: $NEW_OWNER, arg_u32_0: 0u32}"

PRIVATE_KEY=APrivateKey1zkp2RWGDcde3efb89rjhME1VYA8QMxcxep5DShNBR6n8Yjh $LEO execute --skip-proving --yes --broadcast multisig.aleo/sign hyp_multisig.aleo $SIGNING_OP_ID


$LEO execute --skip-proving --yes --broadcast hyp_multisig.aleo/exec_ism_manager_set_owner $SIGNING_OP_ID $ISM $NEW_OWNER
