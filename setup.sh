
# [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8,]

# '[0u128,0u128,0u128,0u128,1u128,1u128,1u128,1u128]'
# '[0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128]'
# '[{spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64}]'

 #   async transition dispatch(
 #   passed_state: MailboxState,
 #   destination_domain: u32,
 #   recipient_address: [u8; 32],
 #   message_body: [u128; 8],
 #   hook_address: address,
 #   metadata: [u8; 256],
 #   hook_allowance: [CreditAllowance; 4]) -> Future {

#'[0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8]'
# aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc
leo --path dispatch_proxy execute dispatch --broadcast --yes \
  '{default_ism: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, default_hook: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js, required_hook: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js}'\
  1u32 \
   '[1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8]' \
    '[0u128,0u128,0u128,0u128,0u128,0u128,0u128,0u128]' \
    aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc \
    '[0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8,0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8]' \
     '[{spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64},{spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64},{spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64},{spender: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, amount: 0u64}]'

# Deploy all contracts
leo deploy --path dispatch_proxy --broadcast --yes
# Create mailbox
leo execute --path mailbox init 12u32 --broadcast --yes
# Create merkleTreeHook and get address
leo execute --path hook_manager init_merkle_tree aleo1999jqmw6mazgnlk22fgt3qytykw8s0248hnkqt6m557xqcx6w5xsg4raem --broadcast
leo query program hook_manager --mapping-value hook_addresses 0u32 # aleo127axy4lv67mvcnxcj06r6x0cvarm3dnjmxzjse4n4k0vsxqemgrqvvy428
# Set merkle tree hook twice
leo execute --path mailbox set_default_hook aleo127axy4lv67mvcnxcj06r6x0cvarm3dnjmxzjse4n4k0vsxqemgrqvvy428 --broadcast --yes
leo execute --path mailbox set_required_hook aleo127axy4lv67mvcnxcj06r6x0cvarm3dnjmxzjse4n4k0vsxqemgrqvvy428 --broadcast --yes

leo execute --path dispatch_proxy get_address --yes
# Dispatch proxy address: aleo1jgnn4lla2d6v0llffwhp6s87x03xqtdezwkzxv0u2ehq2wmqcsqqganvw4
leo execute --path mailbox set_dispatch_proxy aleo1jgnn4lla2d6v0llffwhp6s87x03xqtdezwkzxv0u2ehq2wmqcsqqganvw4 --broadcast --yes

# aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js

leo execute --path mailbox set_default_hook aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js --broadcast --yes
leo execute --path mailbox set_required_hook aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js --broadcast --yes


leo execute --path warp/hyp_native_template init --broadcast --yes \
  '[1u8, 2u8, 3u8, 4u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8, 0u8]'

leo execute --path warp/hyp_native_template enroll_remote_router --broadcast --yes \
  1u32 \
  '[1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8]' \
  1000u128

leo execute --path warp transfer_remote --broadcast --yes \
  '{default_ism: aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss, default_hook: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js, required_hook: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js}'\
  '{domain: 1u32, recipient: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], gas: 1000u128}'\
  1u32 \
  '[2126040514u128, 66990966576285940241065975807012634945u128]' \
  1000000000u64


leo execute --path warp/hyp_native_template transfer_remote --broadcast --yes \
  '{default_ism: aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss, default_hook: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js, required_hook: aleo1q6u34ygdgvkvfkk5qavqlpzx9ylshhhzzxucyekv772a5mttm5pshsx8js}'\
  '{domain: 1u32, recipient: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], gas: 1000u128}'\
  1u32 \
  '[258938393984388867711851864522651336704u128, 86407088643764425831394674034555577650u128]' \
  70000000u64


leo execute --path ism_manager init_noop --broadcast --yes
leo query program ism_manager --mapping-value ism_addresses 1u32 #aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss

leo execute --path mailbox set_default_ism aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss --broadcast --yes

leo execute --path warp process --broadcast --yes \
  aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss \
  '{version: 3u8, nonce: 1u32, origin_domain: 1u32, sender: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], destination_domain: 12u32, recipient: [235u8, 107u8, 38u8, 207u8, 208u8, 174u8, 45u8, 187u8, 34u8, 48u8, 243u8, 242u8, 211u8, 197u8, 141u8, 183u8, 103u8, 45u8, 135u8, 28u8, 65u8, 115u8, 210u8, 154u8, 152u8, 118u8, 225u8, 54u8, 221u8, 225u8, 24u8, 7u8], body: [243984849512716593991068208300841921515u128, 9433792163668743145747486686489029991u128, 0u128, 1329227995784915872903807060280344576u128, 0u128, 0u128, 0u128, 0u128] }' \
  141u32 \
  '[226194728125194576473983132621102114146u128, 194540086066275258888138659387577534856u128]' \
  '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]'

leo execute --path warp test_process --broadcast --yes \
    '{version: 3u8, nonce: 0u32, origin_domain: 1u32, sender: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], destination_domain: 12u32, recipient: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], body: [243984849512716593991068208300841921515u128, 9433792163668743145747486686489029991u128, 0u128, 100u128, 0u128, 0u128, 0u128, 0u128]}'

leo execute --path warp test_process --broadcast --yes \
    '{version: 3u8, nonce: 0u32, origin_domain: 1u32, sender: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], destination_domain: 12u32, recipient: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], body: [243984849512716593991068208300841921515u128, 9433792163668743145747486686489029991u128, 0u128, 1329227995784915872903807060280344576u128, 0u128, 0u128, 0u128, 0u128] }'

leo run --path mailbox dyn_message_id \
      '{version: 3u8, nonce: 0u32, origin_domain: 1u32, sender: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], destination_domain: 12u32, recipient: [235u8, 107u8, 38u8, 207u8, 208u8, 174u8, 45u8, 187u8, 34u8, 48u8, 243u8, 242u8, 211u8, 197u8, 141u8, 183u8, 103u8, 45u8, 135u8, 28u8, 65u8, 115u8, 210u8, 154u8, 152u8, 118u8, 225u8, 54u8, 221u8, 225u8, 24u8, 7u8], body: [243984849512716593991068208300841921515u128, 9433792163668743145747486686489029991u128, 0u128, 1051972130964585879804366154293575680u128, 0u128, 0u128, 0u128, 0u128] }' \
      141u32


leo execute --path warp/hyp_native_template process --broadcast --yes \
  aleo1qtgn2vsxqxxvet4lzgkehlrctdhxuaeu2dvk6ndh2hkza38mfgrqjpkxss \
  '{version: 3u8, nonce: 5u32, origin_domain: 1u32, sender: [1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8, 1u8, 2u8], destination_domain: 12u32, recipient: [36u8, 8u8, 186u8, 151u8, 199u8, 243u8, 5u8, 50u8, 76u8, 35u8, 192u8, 142u8, 207u8, 163u8, 33u8, 109u8, 174u8, 242u8, 88u8, 130u8, 75u8, 194u8, 204u8, 97u8, 82u8, 93u8, 86u8, 195u8, 149u8, 143u8, 159u8, 6u8], body: [36025315697973611711167287460133629034u128, 16793802089471577057198106861191159981u128, 0u128, 99692099683868690467785529521025843200u128, 0u128, 0u128, 0u128, 0u128] }' \
  141u32 \
  '[71495271700694137279101483479108673577u128, 201920092276058258560806310670725367884u128]' \
  '[0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8,0u8]'

