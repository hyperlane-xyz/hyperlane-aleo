import credits.aleo;
import test_hyp_multisig_core.aleo;
import test_hyp_ism_manager.aleo;
import test_hyp_mailbox.aleo;
import test_hyp_hook_manager.aleo;
import test_hyp_dispatch_proxy.aleo;
import token_registry.aleo;
import test_arc20_token_usdc.aleo;
program test_hyp_warp_token_usdc.aleo;

struct ChecksumEdition:
    checksum as [u8; 32u32];
    edition as u16;

struct RemoteRouter:
    domain as u32;
    recipient as [u8; 32u32];
    gas as u128;

struct Metadata:
    token_type as u8;
    token_owner as address;
    ism as address;
    hook as address;
    token_id as field;
    local_decimals as u8;
    remote_decimals as u8;

struct WalletEcdsaSigner:
    wallet_id as address;
    ecdsa_signer as [u8; 20u32];

struct WalletSigningOpId:
    wallet_id as address;
    signing_op_id as field;

struct AdminOp:
    op as u8;
    threshold as u8;
    aleo_signer as address;
    ecdsa_signer as [u8; 20u32];

struct Message:
    version as u8;
    nonce as u32;
    origin_domain as u32;
    sender as [u8; 32u32];
    destination_domain as u32;
    recipient as [u8; 32u32];
    body as [u128; 16u32];

struct EthAddress:
    bytes as [u8; 20u32];

struct Mailbox:
    local_domain as u32;
    nonce as u32;
    process_count as u32;
    default_ism as address;
    default_hook as address;
    required_hook as address;
    dispatch_proxy as address;
    mailbox_owner as address;

struct CreditAllowance:
    spender as address;
    amount as u64;

struct HookMetadata:
    gas_limit as u128;
    extra_data as [u8; 64u32];

struct Tree:
    branch as [[u128; 2u32]; 32u32];
    count as u32;

struct DomainGasConfig:
    gas_overhead as u128;
    exchange_rate as u128;
    gas_price as u128;

struct MailboxState:
    default_hook as address;
    required_hook as address;

struct TokenMetadata:
    token_id as field;
    name as u128;
    symbol as u128;
    decimals as u8;
    supply as u128;
    max_supply as u128;
    admin as address;
    external_authorization_required as boolean;
    external_authorization_party as address;

struct TokenOwner:
    account as address;
    token_id as field;


mapping remote_routers:
    key as u32.public;
    value as RemoteRouter.public;

mapping remote_router_iter:
    key as u32.public;
    value as u32.public;

mapping remote_router_length:
    key as boolean.public;
    value as u32.public;

mapping app_metadata:
    key as boolean.public;
    value as Metadata.public;

function init:
    input r0 as [u8; 128u32].public;
    input r1 as u128.public;
    input r2 as u128.public;
    input r3 as u8.public;
    input r4 as u8.public;
    cast test_hyp_warp_token_usdc.aleo into r5 as field;
    cast r4 into r6 as i16;
    cast r3 into r7 as i16;
    sub r6 r7 into r8;
    abs r8 into r9;
    lte r9 18i16 into r10;
    assert.eq r10 true;
    call token_registry.aleo/register_token r5 r1 r2 r3 340282366920938463463374607431768211455u128 false aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into r11;
    call test_hyp_mailbox.aleo/register_application r0 into r12;
    async init self.caller r5 r3 r4 r11 r12 into r13;
    output r13 as test_hyp_warp_token_usdc.aleo/init.future;

finalize init:
    input r0 as address.public;
    input r1 as field.public;
    input r2 as u8.public;
    input r3 as u8.public;
    input r4 as token_registry.aleo/register_token.future;
    input r5 as test_hyp_mailbox.aleo/register_application.future;
    contains app_metadata[true] into r6;
    assert.eq r6 false;
    cast 1u8 r0 aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc r1 r2 r3 into r7 as Metadata;
    set r7 into app_metadata[true];
    await r4;
    await r5;

function migrate_v1_remote_decimals:
    async migrate_v1_remote_decimals self.caller into r0;
    output r0 as test_hyp_warp_token_usdc.aleo/migrate_v1_remote_decimals.future;

finalize migrate_v1_remote_decimals:
    input r0 as address.public;
    get app_metadata[true] into r1;
    assert.eq r1.token_owner r0;
    cast r1.token_type r1.token_owner r1.ism r1.hook r1.token_id r1.local_decimals 18u8 into r2 as Metadata;
    set r2 into app_metadata[true];

function get_address:
    output test_hyp_warp_token_usdc.aleo as address.private;

function set_custom_hook:
    input r0 as address.private;
    async set_custom_hook self.caller r0 into r1;
    output r1 as test_hyp_warp_token_usdc.aleo/set_custom_hook.future;

finalize set_custom_hook:
    input r0 as address.public;
    input r1 as address.public;
    get app_metadata[true] into r2;
    assert.eq r2.token_owner r0;
    cast r2.token_type r2.token_owner r2.ism r1 r2.token_id r2.local_decimals r2.remote_decimals into r3 as Metadata;
    set r3 into app_metadata[true];

function set_custom_ism:
    input r0 as address.private;
    async set_custom_ism self.caller r0 into r1;
    output r1 as test_hyp_warp_token_usdc.aleo/set_custom_ism.future;

finalize set_custom_ism:
    input r0 as address.public;
    input r1 as address.public;
    get app_metadata[true] into r2;
    assert.eq r2.token_owner r0;
    cast r2.token_type r2.token_owner r1 r2.hook r2.token_id r2.local_decimals r2.remote_decimals into r3 as Metadata;
    set r3 into app_metadata[true];

function set_owner:
    input r0 as address.private;
    async set_owner self.caller r0 into r1;
    output r1 as test_hyp_warp_token_usdc.aleo/set_owner.future;

finalize set_owner:
    input r0 as address.public;
    input r1 as address.public;
    get app_metadata[true] into r2;
    assert.eq r2.token_owner r0;
    cast r2.token_type r1 r2.ism r2.hook r2.token_id r2.local_decimals r2.remote_decimals into r3 as Metadata;
    set r3 into app_metadata[true];

function enroll_remote_router:
    input r0 as u32.private;
    input r1 as [u8; 32u32].private;
    input r2 as u128.private;
    async enroll_remote_router self.caller r0 r1 r2 into r3;
    output r3 as test_hyp_warp_token_usdc.aleo/enroll_remote_router.future;

finalize enroll_remote_router:
    input r0 as address.public;
    input r1 as u32.public;
    input r2 as [u8; 32u32].public;
    input r3 as u128.public;
    get app_metadata[true] into r4;
    assert.eq r4.token_owner r0;
    contains remote_routers[r1] into r5;
    not r5 into r6;
    branch.eq r6 false to end_then_0_0;
    get.or_use remote_router_length[true] 0u32 into r7;
    set r1 into remote_router_iter[r7];
    add r7 1u32 into r8;
    set r8 into remote_router_length[true];
    branch.eq true true to end_otherwise_0_1;
    position end_then_0_0;
    position end_otherwise_0_1;
    cast r1 r2 r3 into r9 as RemoteRouter;
    set r9 into remote_routers[r1];

function unroll_remote_router:
    input r0 as u32.private;
    async unroll_remote_router self.caller r0 into r1;
    output r1 as test_hyp_warp_token_usdc.aleo/unroll_remote_router.future;

finalize unroll_remote_router:
    input r0 as address.public;
    input r1 as u32.public;
    get app_metadata[true] into r2;
    assert.eq r2.token_owner r0;
    remove remote_routers[r1];

closure convert_outgoing_amount:
    input r0 as u128;
    input r1 as u8;
    input r2 as u8;
    is.eq r1 r2 into r3;
    shr r0 0u8 into r4;
    rem r4 256u128 into r5;
    shl r5 120u8 into r6;
    shr r0 8u8 into r7;
    rem r7 256u128 into r8;
    shl r8 112u8 into r9;
    add r6 r9 into r10;
    shr r0 16u8 into r11;
    rem r11 256u128 into r12;
    shl r12 104u8 into r13;
    add r10 r13 into r14;
    shr r0 24u8 into r15;
    rem r15 256u128 into r16;
    shl r16 96u8 into r17;
    add r14 r17 into r18;
    shr r0 32u8 into r19;
    rem r19 256u128 into r20;
    shl r20 88u8 into r21;
    add r18 r21 into r22;
    shr r0 40u8 into r23;
    rem r23 256u128 into r24;
    shl r24 80u8 into r25;
    add r22 r25 into r26;
    shr r0 48u8 into r27;
    rem r27 256u128 into r28;
    shl r28 72u8 into r29;
    add r26 r29 into r30;
    shr r0 56u8 into r31;
    rem r31 256u128 into r32;
    shl r32 64u8 into r33;
    add r30 r33 into r34;
    shr r0 64u8 into r35;
    rem r35 256u128 into r36;
    shl r36 56u8 into r37;
    add r34 r37 into r38;
    shr r0 72u8 into r39;
    rem r39 256u128 into r40;
    shl r40 48u8 into r41;
    add r38 r41 into r42;
    shr r0 80u8 into r43;
    rem r43 256u128 into r44;
    shl r44 40u8 into r45;
    add r42 r45 into r46;
    shr r0 88u8 into r47;
    rem r47 256u128 into r48;
    shl r48 32u8 into r49;
    add r46 r49 into r50;
    shr r0 96u8 into r51;
    rem r51 256u128 into r52;
    shl r52 24u8 into r53;
    add r50 r53 into r54;
    shr r0 104u8 into r55;
    rem r55 256u128 into r56;
    shl r56 16u8 into r57;
    add r54 r57 into r58;
    shr r0 112u8 into r59;
    rem r59 256u128 into r60;
    shl r60 8u8 into r61;
    add r58 r61 into r62;
    shr r0 120u8 into r63;
    rem r63 256u128 into r64;
    shl r64 0u8 into r65;
    add r62 r65 into r66;
    cast 0u128 r66 into r67 as [u128; 2u32];
    lt r2 r1 into r68;
    lt r1 r2 into r69;
    ternary r69 r2 r1 into r70;
    sub r70 r2 into r71;
    pow 10u128 r71 into r72;
    div r0 r72 into r73;
    shr r73 0u8 into r74;
    rem r74 256u128 into r75;
    shl r75 120u8 into r76;
    shr r73 8u8 into r77;
    rem r77 256u128 into r78;
    shl r78 112u8 into r79;
    add r76 r79 into r80;
    shr r73 16u8 into r81;
    rem r81 256u128 into r82;
    shl r82 104u8 into r83;
    add r80 r83 into r84;
    shr r73 24u8 into r85;
    rem r85 256u128 into r86;
    shl r86 96u8 into r87;
    add r84 r87 into r88;
    shr r73 32u8 into r89;
    rem r89 256u128 into r90;
    shl r90 88u8 into r91;
    add r88 r91 into r92;
    shr r73 40u8 into r93;
    rem r93 256u128 into r94;
    shl r94 80u8 into r95;
    add r92 r95 into r96;
    shr r73 48u8 into r97;
    rem r97 256u128 into r98;
    shl r98 72u8 into r99;
    add r96 r99 into r100;
    shr r73 56u8 into r101;
    rem r101 256u128 into r102;
    shl r102 64u8 into r103;
    add r100 r103 into r104;
    shr r73 64u8 into r105;
    rem r105 256u128 into r106;
    shl r106 56u8 into r107;
    add r104 r107 into r108;
    shr r73 72u8 into r109;
    rem r109 256u128 into r110;
    shl r110 48u8 into r111;
    add r108 r111 into r112;
    shr r73 80u8 into r113;
    rem r113 256u128 into r114;
    shl r114 40u8 into r115;
    add r112 r115 into r116;
    shr r73 88u8 into r117;
    rem r117 256u128 into r118;
    shl r118 32u8 into r119;
    add r116 r119 into r120;
    shr r73 96u8 into r121;
    rem r121 256u128 into r122;
    shl r122 24u8 into r123;
    add r120 r123 into r124;
    shr r73 104u8 into r125;
    rem r125 256u128 into r126;
    shl r126 16u8 into r127;
    add r124 r127 into r128;
    shr r73 112u8 into r129;
    rem r129 256u128 into r130;
    shl r130 8u8 into r131;
    add r128 r131 into r132;
    shr r73 120u8 into r133;
    rem r133 256u128 into r134;
    shl r134 0u8 into r135;
    add r132 r135 into r136;
    cast 0u128 r136 into r137 as [u128; 2u32];
    not r68 into r138;
    gt r1 r2 into r139;
    ternary r139 r2 r1 into r140;
    cast 0u64 0u64 0u64 0u64 into r141 as [u64; 4u32];
    shr r0 64u32 into r142;
    cast r142 into r143 as u64;
    and r0 18446744073709551615u128 into r144;
    cast r144 into r145 as u64;
    sub r2 r140 into r146;
    pow 10u64 r146 into r147;
    cast r145 into r148 as u128;
    cast r147 into r149 as u128;
    mul r148 r149 into r150;
    and r150 18446744073709551615u128 into r151;
    cast r151 into r152 as u64;
    shr r150 64u32 into r153;
    cast r143 into r154 as u128;
    cast r147 into r155 as u128;
    mul r154 r155 into r156;
    add r156 r153 into r157;
    and r157 18446744073709551615u128 into r158;
    cast r158 into r159 as u64;
    shr r157 64u32 into r160;
    cast r141[1u32] into r161 as u128;
    cast r147 into r162 as u128;
    mul r161 r162 into r163;
    add r163 r160 into r164;
    and r164 18446744073709551615u128 into r165;
    cast r165 into r166 as u64;
    shr r164 64u32 into r167;
    cast r141[0u32] into r168 as u128;
    cast r147 into r169 as u128;
    mul r168 r169 into r170;
    add r170 r167 into r171;
    and r171 18446744073709551615u128 into r172;
    cast r172 into r173 as u64;
    shr r171 64u32 into r174;
    not r138 into r175;
    or r3 r68 into r176;
    is.eq r174 0u128 into r177;
    or r177 r175 into r178;
    or r178 r176 into r179;
    assert.eq r179 true;
    cast r173 into r180 as u128;
    shl r180 64u32 into r181;
    cast r166 into r182 as u128;
    add r181 r182 into r183;
    cast r159 into r184 as u128;
    shl r184 64u32 into r185;
    cast r152 into r186 as u128;
    add r185 r186 into r187;
    shr r183 0u8 into r188;
    rem r188 256u128 into r189;
    shl r189 120u8 into r190;
    shr r183 8u8 into r191;
    rem r191 256u128 into r192;
    shl r192 112u8 into r193;
    add r190 r193 into r194;
    shr r183 16u8 into r195;
    rem r195 256u128 into r196;
    shl r196 104u8 into r197;
    add r194 r197 into r198;
    shr r183 24u8 into r199;
    rem r199 256u128 into r200;
    shl r200 96u8 into r201;
    add r198 r201 into r202;
    shr r183 32u8 into r203;
    rem r203 256u128 into r204;
    shl r204 88u8 into r205;
    add r202 r205 into r206;
    shr r183 40u8 into r207;
    rem r207 256u128 into r208;
    shl r208 80u8 into r209;
    add r206 r209 into r210;
    shr r183 48u8 into r211;
    rem r211 256u128 into r212;
    shl r212 72u8 into r213;
    add r210 r213 into r214;
    shr r183 56u8 into r215;
    rem r215 256u128 into r216;
    shl r216 64u8 into r217;
    add r214 r217 into r218;
    shr r183 64u8 into r219;
    rem r219 256u128 into r220;
    shl r220 56u8 into r221;
    add r218 r221 into r222;
    shr r183 72u8 into r223;
    rem r223 256u128 into r224;
    shl r224 48u8 into r225;
    add r222 r225 into r226;
    shr r183 80u8 into r227;
    rem r227 256u128 into r228;
    shl r228 40u8 into r229;
    add r226 r229 into r230;
    shr r183 88u8 into r231;
    rem r231 256u128 into r232;
    shl r232 32u8 into r233;
    add r230 r233 into r234;
    shr r183 96u8 into r235;
    rem r235 256u128 into r236;
    shl r236 24u8 into r237;
    add r234 r237 into r238;
    shr r183 104u8 into r239;
    rem r239 256u128 into r240;
    shl r240 16u8 into r241;
    add r238 r241 into r242;
    shr r183 112u8 into r243;
    rem r243 256u128 into r244;
    shl r244 8u8 into r245;
    add r242 r245 into r246;
    shr r183 120u8 into r247;
    rem r247 256u128 into r248;
    shl r248 0u8 into r249;
    add r246 r249 into r250;
    shr r187 0u8 into r251;
    rem r251 256u128 into r252;
    shl r252 120u8 into r253;
    shr r187 8u8 into r254;
    rem r254 256u128 into r255;
    shl r255 112u8 into r256;
    add r253 r256 into r257;
    shr r187 16u8 into r258;
    rem r258 256u128 into r259;
    shl r259 104u8 into r260;
    add r257 r260 into r261;
    shr r187 24u8 into r262;
    rem r262 256u128 into r263;
    shl r263 96u8 into r264;
    add r261 r264 into r265;
    shr r187 32u8 into r266;
    rem r266 256u128 into r267;
    shl r267 88u8 into r268;
    add r265 r268 into r269;
    shr r187 40u8 into r270;
    rem r270 256u128 into r271;
    shl r271 80u8 into r272;
    add r269 r272 into r273;
    shr r187 48u8 into r274;
    rem r274 256u128 into r275;
    shl r275 72u8 into r276;
    add r273 r276 into r277;
    shr r187 56u8 into r278;
    rem r278 256u128 into r279;
    shl r279 64u8 into r280;
    add r277 r280 into r281;
    shr r187 64u8 into r282;
    rem r282 256u128 into r283;
    shl r283 56u8 into r284;
    add r281 r284 into r285;
    shr r187 72u8 into r286;
    rem r286 256u128 into r287;
    shl r287 48u8 into r288;
    add r285 r288 into r289;
    shr r187 80u8 into r290;
    rem r290 256u128 into r291;
    shl r291 40u8 into r292;
    add r289 r292 into r293;
    shr r187 88u8 into r294;
    rem r294 256u128 into r295;
    shl r295 32u8 into r296;
    add r293 r296 into r297;
    shr r187 96u8 into r298;
    rem r298 256u128 into r299;
    shl r299 24u8 into r300;
    add r297 r300 into r301;
    shr r187 104u8 into r302;
    rem r302 256u128 into r303;
    shl r303 16u8 into r304;
    add r301 r304 into r305;
    shr r187 112u8 into r306;
    rem r306 256u128 into r307;
    shl r307 8u8 into r308;
    add r305 r308 into r309;
    shr r187 120u8 into r310;
    rem r310 256u128 into r311;
    shl r311 0u8 into r312;
    add r309 r312 into r313;
    cast r250 r313 into r314 as [u128; 2u32];
    ternary r68 r137[0u32] r314[0u32] into r315;
    ternary r68 r137[1u32] r314[1u32] into r316;
    cast r315 r316 into r317 as [u128; 2u32];
    ternary r3 r67[0u32] r317[0u32] into r318;
    ternary r3 r67[1u32] r317[1u32] into r319;
    cast r318 r319 into r320 as [u128; 2u32];
    output r320 as [u128; 2u32];

closure get_message_body:
    input r0 as [u128; 2u32];
    input r1 as [u128; 2u32];
    cast 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 0u128 into r2 as [u128; 16u32];
    cast r0[0u32] r0[1u32] r1[0u32] r1[1u32] r2[4u32] r2[5u32] r2[6u32] r2[7u32] r2[8u32] r2[9u32] r2[10u32] r2[11u32] r2[12u32] r2[13u32] r2[14u32] r2[15u32] into r3 as [u128; 16u32];
    output r3 as [u128; 16u32];

function transfer_remote:
    input r0 as Metadata.public;
    input r1 as MailboxState.public;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as [u128; 2u32].public;
    input r5 as u128.public;
    input r6 as [CreditAllowance; 4u32].public;
    cast 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 into r7 as [u8; 64u32];
    cast r2.gas r7 into r8 as HookMetadata;
    call convert_outgoing_amount r5 r0.local_decimals r0.remote_decimals into r9;
    call get_message_body r4 r9 into r10;
    call test_hyp_dispatch_proxy.aleo/dispatch r1 r3 r2.recipient r10 r0.hook r8 r6 into r11;
    call test_arc20_token_usdc.aleo/burn_public self.caller r5 into r12;
    async transfer_remote r11 r12 r2 r3 r0 self.caller into r13;
    output r13 as test_hyp_warp_token_usdc.aleo/transfer_remote.future;

finalize transfer_remote:
    input r0 as test_hyp_dispatch_proxy.aleo/dispatch.future;
    input r1 as test_arc20_token_usdc.aleo/burn_public.future;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as Metadata.public;
    input r5 as address.public;
    get remote_routers[r3] into r6;
    assert.eq r6 r2;
    get app_metadata[true] into r7;
    assert.eq r4 r7;
    await r0;
    await r1;

function transfer_remote_with_hook:
    input r0 as Metadata.public;
    input r1 as MailboxState.public;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as [u128; 2u32].public;
    input r5 as u128.public;
    input r6 as [CreditAllowance; 4u32].public;
    input r7 as address.public;
    input r8 as HookMetadata.public;
    is.eq r8.gas_limit 0u128 into r9;
    ternary r9 r2.gas r8.gas_limit into r10;
    call convert_outgoing_amount r5 r0.local_decimals r0.remote_decimals into r11;
    call get_message_body r4 r11 into r12;
    cast r10 r8.extra_data into r13 as HookMetadata;
    call test_hyp_dispatch_proxy.aleo/dispatch r1 r3 r2.recipient r12 r7 r13 r6 into r14;
    call test_arc20_token_usdc.aleo/burn_public self.caller r5 into r15;
    async transfer_remote_with_hook r14 r15 r2 r3 r0 self.signer into r16;
    output r16 as test_hyp_warp_token_usdc.aleo/transfer_remote_with_hook.future;

finalize transfer_remote_with_hook:
    input r0 as test_hyp_dispatch_proxy.aleo/dispatch.future;
    input r1 as test_arc20_token_usdc.aleo/burn_public.future;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as Metadata.public;
    input r5 as address.public;
    get remote_routers[r3] into r6;
    assert.eq r6 r2;
    get app_metadata[true] into r7;
    assert.eq r4 r7;
    await r0;
    await r1;

function transfer_remote_as_signer:
    input r0 as Metadata.public;
    input r1 as MailboxState.public;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as [u128; 2u32].public;
    input r5 as u128.public;
    input r6 as [CreditAllowance; 4u32].public;
    cast 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 0u8 into r7 as [u8; 64u32];
    cast r2.gas r7 into r8 as HookMetadata;
    call convert_outgoing_amount r5 r0.local_decimals r0.remote_decimals into r9;
    call get_message_body r4 r9 into r10;
    call test_hyp_dispatch_proxy.aleo/dispatch r1 r3 r2.recipient r10 r0.hook r8 r6 into r11;
    call test_arc20_token_usdc.aleo/burn_public self.signer r5 into r12;
    async transfer_remote_as_signer r11 r12 r2 r3 r0 self.signer into r13;
    output r13 as test_hyp_warp_token_usdc.aleo/transfer_remote_as_signer.future;

finalize transfer_remote_as_signer:
    input r0 as test_hyp_dispatch_proxy.aleo/dispatch.future;
    input r1 as test_arc20_token_usdc.aleo/burn_public.future;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as Metadata.public;
    input r5 as address.public;
    get remote_routers[r3] into r6;
    assert.eq r6 r2;
    get app_metadata[true] into r7;
    assert.eq r4 r7;
    await r0;
    await r1;

function transfer_remote_with_hook_as:
    input r0 as Metadata.public;
    input r1 as MailboxState.public;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as [u128; 2u32].public;
    input r5 as u128.public;
    input r6 as [CreditAllowance; 4u32].public;
    input r7 as address.public;
    input r8 as HookMetadata.public;
    is.eq r8.gas_limit 0u128 into r9;
    ternary r9 r2.gas r8.gas_limit into r10;
    call convert_outgoing_amount r5 r0.local_decimals r0.remote_decimals into r11;
    call get_message_body r4 r11 into r12;
    cast r10 r8.extra_data into r13 as HookMetadata;
    call test_hyp_dispatch_proxy.aleo/dispatch r1 r3 r2.recipient r12 r7 r13 r6 into r14;
    call test_arc20_token_usdc.aleo/burn_public self.signer r5 into r15;
    async transfer_remote_with_hook_as r14 r15 r2 r3 r0 self.signer into r16;
    output r16 as test_hyp_warp_token_usdc.aleo/transfer_remote_with_hook_as.future;

finalize transfer_remote_with_hook_as:
    input r0 as test_hyp_dispatch_proxy.aleo/dispatch.future;
    input r1 as test_arc20_token_usdc.aleo/burn_public.future;
    input r2 as RemoteRouter.public;
    input r3 as u32.public;
    input r4 as Metadata.public;
    input r5 as address.public;
    get remote_routers[r3] into r6;
    assert.eq r6 r2;
    get app_metadata[true] into r7;
    assert.eq r4 r7;
    await r0;
    await r1;

function process:
    input r0 as address.public;
    input r1 as Metadata.public;
    input r2 as test_hyp_mailbox.aleo/Message.public;
    input r3 as u32.public;
    input r4 as [u128; 2u32].public;
    input r5 as [u8; 512u32].public;
    call test_hyp_mailbox.aleo/process r0 r2 r3 r4 r5 into r6;
    cast r2.body[0u32] r2.body[1u32] into r7 as [u128; 2u32];
    serialize.bits.raw r7 ([u128; 2u32]) into r8 ([boolean; 256u32]);
    cast r8[0u32] r8[1u32] r8[2u32] r8[3u32] r8[4u32] r8[5u32] r8[6u32] r8[7u32] r8[8u32] r8[9u32] r8[10u32] r8[11u32] r8[12u32] r8[13u32] r8[14u32] r8[15u32] r8[16u32] r8[17u32] r8[18u32] r8[19u32] r8[20u32] r8[21u32] r8[22u32] r8[23u32] r8[24u32] r8[25u32] r8[26u32] r8[27u32] r8[28u32] r8[29u32] r8[30u32] r8[31u32] r8[32u32] r8[33u32] r8[34u32] r8[35u32] r8[36u32] r8[37u32] r8[38u32] r8[39u32] r8[40u32] r8[41u32] r8[42u32] r8[43u32] r8[44u32] r8[45u32] r8[46u32] r8[47u32] r8[48u32] r8[49u32] r8[50u32] r8[51u32] r8[52u32] r8[53u32] r8[54u32] r8[55u32] r8[56u32] r8[57u32] r8[58u32] r8[59u32] r8[60u32] r8[61u32] r8[62u32] r8[63u32] r8[64u32] r8[65u32] r8[66u32] r8[67u32] r8[68u32] r8[69u32] r8[70u32] r8[71u32] r8[72u32] r8[73u32] r8[74u32] r8[75u32] r8[76u32] r8[77u32] r8[78u32] r8[79u32] r8[80u32] r8[81u32] r8[82u32] r8[83u32] r8[84u32] r8[85u32] r8[86u32] r8[87u32] r8[88u32] r8[89u32] r8[90u32] r8[91u32] r8[92u32] r8[93u32] r8[94u32] r8[95u32] r8[96u32] r8[97u32] r8[98u32] r8[99u32] r8[100u32] r8[101u32] r8[102u32] r8[103u32] r8[104u32] r8[105u32] r8[106u32] r8[107u32] r8[108u32] r8[109u32] r8[110u32] r8[111u32] r8[112u32] r8[113u32] r8[114u32] r8[115u32] r8[116u32] r8[117u32] r8[118u32] r8[119u32] r8[120u32] r8[121u32] r8[122u32] r8[123u32] r8[124u32] r8[125u32] r8[126u32] r8[127u32] r8[128u32] r8[129u32] r8[130u32] r8[131u32] r8[132u32] r8[133u32] r8[134u32] r8[135u32] r8[136u32] r8[137u32] r8[138u32] r8[139u32] r8[140u32] r8[141u32] r8[142u32] r8[143u32] r8[144u32] r8[145u32] r8[146u32] r8[147u32] r8[148u32] r8[149u32] r8[150u32] r8[151u32] r8[152u32] r8[153u32] r8[154u32] r8[155u32] r8[156u32] r8[157u32] r8[158u32] r8[159u32] r8[160u32] r8[161u32] r8[162u32] r8[163u32] r8[164u32] r8[165u32] r8[166u32] r8[167u32] r8[168u32] r8[169u32] r8[170u32] r8[171u32] r8[172u32] r8[173u32] r8[174u32] r8[175u32] r8[176u32] r8[177u32] r8[178u32] r8[179u32] r8[180u32] r8[181u32] r8[182u32] r8[183u32] r8[184u32] r8[185u32] r8[186u32] r8[187u32] r8[188u32] r8[189u32] r8[190u32] r8[191u32] r8[192u32] r8[193u32] r8[194u32] r8[195u32] r8[196u32] r8[197u32] r8[198u32] r8[199u32] r8[200u32] r8[201u32] r8[202u32] r8[203u32] r8[204u32] r8[205u32] r8[206u32] r8[207u32] r8[208u32] r8[209u32] r8[210u32] r8[211u32] r8[212u32] r8[213u32] r8[214u32] r8[215u32] r8[216u32] r8[217u32] r8[218u32] r8[219u32] r8[220u32] r8[221u32] r8[222u32] r8[223u32] r8[224u32] r8[225u32] r8[226u32] r8[227u32] r8[228u32] r8[229u32] r8[230u32] r8[231u32] r8[232u32] r8[233u32] r8[234u32] r8[235u32] r8[236u32] r8[237u32] r8[238u32] r8[239u32] r8[240u32] r8[241u32] r8[242u32] r8[243u32] r8[244u32] r8[245u32] r8[246u32] r8[247u32] r8[248u32] r8[249u32] r8[250u32] r8[251u32] r8[252u32] into r9 as [boolean; 253u32];
    deserialize.bits.raw r9 ([boolean; 253u32]) into r10 (address);
    cast r2.body[2u32] r2.body[3u32] into r11 as [u128; 2u32];
    is.eq r1.local_decimals r1.remote_decimals into r12;
    shr r11[1u32] 0u8 into r13;
    rem r13 256u128 into r14;
    shl r14 120u8 into r15;
    shr r11[1u32] 8u8 into r16;
    rem r16 256u128 into r17;
    shl r17 112u8 into r18;
    add r15 r18 into r19;
    shr r11[1u32] 16u8 into r20;
    rem r20 256u128 into r21;
    shl r21 104u8 into r22;
    add r19 r22 into r23;
    shr r11[1u32] 24u8 into r24;
    rem r24 256u128 into r25;
    shl r25 96u8 into r26;
    add r23 r26 into r27;
    shr r11[1u32] 32u8 into r28;
    rem r28 256u128 into r29;
    shl r29 88u8 into r30;
    add r27 r30 into r31;
    shr r11[1u32] 40u8 into r32;
    rem r32 256u128 into r33;
    shl r33 80u8 into r34;
    add r31 r34 into r35;
    shr r11[1u32] 48u8 into r36;
    rem r36 256u128 into r37;
    shl r37 72u8 into r38;
    add r35 r38 into r39;
    shr r11[1u32] 56u8 into r40;
    rem r40 256u128 into r41;
    shl r41 64u8 into r42;
    add r39 r42 into r43;
    shr r11[1u32] 64u8 into r44;
    rem r44 256u128 into r45;
    shl r45 56u8 into r46;
    add r43 r46 into r47;
    shr r11[1u32] 72u8 into r48;
    rem r48 256u128 into r49;
    shl r49 48u8 into r50;
    add r47 r50 into r51;
    shr r11[1u32] 80u8 into r52;
    rem r52 256u128 into r53;
    shl r53 40u8 into r54;
    add r51 r54 into r55;
    shr r11[1u32] 88u8 into r56;
    rem r56 256u128 into r57;
    shl r57 32u8 into r58;
    add r55 r58 into r59;
    shr r11[1u32] 96u8 into r60;
    rem r60 256u128 into r61;
    shl r61 24u8 into r62;
    add r59 r62 into r63;
    shr r11[1u32] 104u8 into r64;
    rem r64 256u128 into r65;
    shl r65 16u8 into r66;
    add r63 r66 into r67;
    shr r11[1u32] 112u8 into r68;
    rem r68 256u128 into r69;
    shl r69 8u8 into r70;
    add r67 r70 into r71;
    shr r11[1u32] 120u8 into r72;
    rem r72 256u128 into r73;
    shl r73 0u8 into r74;
    add r71 r74 into r75;
    lt r1.remote_decimals r1.local_decimals into r76;
    lt r1.local_decimals r1.remote_decimals into r77;
    ternary r77 r1.remote_decimals r1.local_decimals into r78;
    sub r78 r1.remote_decimals into r79;
    add r15 r18 into r80;
    add r80 r22 into r81;
    add r81 r26 into r82;
    add r82 r30 into r83;
    add r83 r34 into r84;
    add r84 r38 into r85;
    add r85 r42 into r86;
    add r86 r46 into r87;
    add r87 r50 into r88;
    add r88 r54 into r89;
    add r89 r58 into r90;
    add r90 r62 into r91;
    add r91 r66 into r92;
    add r92 r70 into r93;
    add r93 r74 into r94;
    not r76 into r95;
    is.eq r11[0u32] 0u128 into r96;
    or r96 r95 into r97;
    or r97 r12 into r98;
    assert.eq r98 true;
    pow 10u64 r79 into r99;
    cast r99 into r100 as u128;
    mul r94 r100 into r101;
    gt r1.local_decimals r1.remote_decimals into r102;
    ternary r102 r1.remote_decimals r1.local_decimals into r103;
    sub r1.remote_decimals r103 into r104;
    pow 10u64 r104 into r105;
    serialize.bits.raw r11 ([u128; 2u32]) into r106 ([boolean; 256u32]);
    deserialize.bits.raw r106 ([boolean; 256u32]) into r107 ([u8; 32u32]);
    cast r107[0u32] into r108 as u64;
    shl r108 56u32 into r109;
    cast r107[1u32] into r110 as u64;
    shl r110 48u32 into r111;
    add r109 r111 into r112;
    cast r107[2u32] into r113 as u64;
    shl r113 40u32 into r114;
    add r112 r114 into r115;
    cast r107[3u32] into r116 as u64;
    shl r116 32u32 into r117;
    add r115 r117 into r118;
    cast r107[4u32] into r119 as u64;
    shl r119 24u32 into r120;
    add r118 r120 into r121;
    cast r107[5u32] into r122 as u64;
    shl r122 16u32 into r123;
    add r121 r123 into r124;
    cast r107[6u32] into r125 as u64;
    shl r125 8u32 into r126;
    add r124 r126 into r127;
    cast r107[7u32] into r128 as u64;
    shl r128 0u32 into r129;
    add r127 r129 into r130;
    cast r107[8u32] into r131 as u64;
    shl r131 56u32 into r132;
    cast r107[9u32] into r133 as u64;
    shl r133 48u32 into r134;
    add r132 r134 into r135;
    cast r107[10u32] into r136 as u64;
    shl r136 40u32 into r137;
    add r135 r137 into r138;
    cast r107[11u32] into r139 as u64;
    shl r139 32u32 into r140;
    add r138 r140 into r141;
    cast r107[12u32] into r142 as u64;
    shl r142 24u32 into r143;
    add r141 r143 into r144;
    cast r107[13u32] into r145 as u64;
    shl r145 16u32 into r146;
    add r144 r146 into r147;
    cast r107[14u32] into r148 as u64;
    shl r148 8u32 into r149;
    add r147 r149 into r150;
    cast r107[15u32] into r151 as u64;
    shl r151 0u32 into r152;
    add r150 r152 into r153;
    cast r107[16u32] into r154 as u64;
    shl r154 56u32 into r155;
    cast r107[17u32] into r156 as u64;
    shl r156 48u32 into r157;
    add r155 r157 into r158;
    cast r107[18u32] into r159 as u64;
    shl r159 40u32 into r160;
    add r158 r160 into r161;
    cast r107[19u32] into r162 as u64;
    shl r162 32u32 into r163;
    add r161 r163 into r164;
    cast r107[20u32] into r165 as u64;
    shl r165 24u32 into r166;
    add r164 r166 into r167;
    cast r107[21u32] into r168 as u64;
    shl r168 16u32 into r169;
    add r167 r169 into r170;
    cast r107[22u32] into r171 as u64;
    shl r171 8u32 into r172;
    add r170 r172 into r173;
    cast r107[23u32] into r174 as u64;
    shl r174 0u32 into r175;
    add r173 r175 into r176;
    cast r107[24u32] into r177 as u64;
    shl r177 56u32 into r178;
    cast r107[25u32] into r179 as u64;
    shl r179 48u32 into r180;
    add r178 r180 into r181;
    cast r107[26u32] into r182 as u64;
    shl r182 40u32 into r183;
    add r181 r183 into r184;
    cast r107[27u32] into r185 as u64;
    shl r185 32u32 into r186;
    add r184 r186 into r187;
    cast r107[28u32] into r188 as u64;
    shl r188 24u32 into r189;
    add r187 r189 into r190;
    cast r107[29u32] into r191 as u64;
    shl r191 16u32 into r192;
    add r190 r192 into r193;
    cast r107[30u32] into r194 as u64;
    shl r194 8u32 into r195;
    add r193 r195 into r196;
    cast r107[31u32] into r197 as u64;
    shl r197 0u32 into r198;
    add r196 r198 into r199;
    cast r130 into r200 as u128;
    cast r105 into r201 as u128;
    div r200 r201 into r202;
    cast r202 into r203 as u64;
    cast r105 into r204 as u128;
    rem r200 r204 into r205;
    shl r205 64u32 into r206;
    cast r153 into r207 as u128;
    or r206 r207 into r208;
    cast r105 into r209 as u128;
    div r208 r209 into r210;
    cast r210 into r211 as u64;
    cast r105 into r212 as u128;
    rem r208 r212 into r213;
    shl r213 64u32 into r214;
    cast r176 into r215 as u128;
    or r214 r215 into r216;
    cast r105 into r217 as u128;
    div r216 r217 into r218;
    cast r218 into r219 as u64;
    cast r105 into r220 as u128;
    rem r216 r220 into r221;
    shl r221 64u32 into r222;
    cast r199 into r223 as u128;
    or r222 r223 into r224;
    cast r105 into r225 as u128;
    div r224 r225 into r226;
    cast r226 into r227 as u64;
    cast r105 into r228 as u128;
    rem r224 r228 into r229;
    assert.eq r203 0u64;
    assert.eq r211 0u64;
    cast r219 into r230 as u128;
    shl r230 64u32 into r231;
    cast r227 into r232 as u128;
    or r231 r232 into r233;
    ternary r76 r101 r233 into r234;
    ternary r12 r75 r234 into r235;
    call test_arc20_token_usdc.aleo/mint_public r10 r235 into r236;
    async process r6 r1 r2 r236 r0 r10 into r237;
    output r237 as test_hyp_warp_token_usdc.aleo/process.future;

finalize process:
    input r0 as test_hyp_mailbox.aleo/process.future;
    input r1 as Metadata.public;
    input r2 as test_hyp_mailbox.aleo/Message.public;
    input r3 as test_arc20_token_usdc.aleo/mint_public.future;
    input r4 as address.public;
    input r5 as address.public;
    get app_metadata[true] into r6;
    assert.eq r6 r1;
    get test_hyp_mailbox.aleo/mailbox[true] into r7;
    is.eq r6.ism aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc into r8;
    ternary r8 r7.default_ism r6.ism into r9;
    assert.eq r9 r4;
    get remote_routers[r2.origin_domain] into r10;
    assert.eq r10.recipient r2.sender;
    await r0;
    await r3;

function upgrade_token:
    input r0 as u128.private;
    call token_registry.aleo/burn_public 0field self.caller r0 into r1;
    call test_arc20_token_usdc.aleo/mint_public self.caller r0 into r2;
    async upgrade_token r1 r2 into r3;
    output r3 as test_hyp_warp_token_usdc.aleo/upgrade_token.future;

finalize upgrade_token:
    input r0 as token_registry.aleo/burn_public.future;
    input r1 as test_arc20_token_usdc.aleo/mint_public.future;
    await r0;
    await r1;

function get_balance_key:
    input r0 as address.private;
    input r1 as field.private;
    cast r0 r1 into r2 as token_registry.aleo/TokenOwner;
    hash.bhp256 r2 into r3 as field;
    output r3 as field.private;

constructor:
    gt edition 0u16 into r0;
    branch.eq r0 false to end_then_0_2;
    cast checksum edition into r1 as ChecksumEdition;
    hash.bhp256 r1 into r2 as field;
    cast test_hyp_warp_token_usdc.aleo r2 into r3 as WalletSigningOpId;
    hash.bhp256 r3 into r4 as field;
    contains test_hyp_multisig_core.aleo/completed_signing_ops[r4] into r5;
    assert.eq r5 true;
    branch.eq true true to end_otherwise_0_3;
    position end_then_0_2;
    position end_otherwise_0_3;
