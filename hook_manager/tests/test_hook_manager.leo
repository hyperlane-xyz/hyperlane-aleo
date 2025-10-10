import hook_manager.aleo;

program test_hook_manager.aleo {

    struct CreditAllowance {
        spender: address,
        amount: u64,
    }

    // address of the test program
    const ADDRESS: address = aleo1zgxwklpwr2ma3jm4zpgpvc3cqw6ml3wnta2m2yvea5zvp0qhscpqe8j7hc;
    // address of the merkle tree hook that is created with the test program
    const MERKLE_TREE_HOOK: address = aleo1s27krgss6dpp8775vlgryznw3fvdhcvyvnyzn94jyt36rk22tgqqpl4veu;

    @noupgrade
    async constructor() {}

    transition main() {}

    @test
    script test_merkle_tree() {
        // Init the merkle tree
        let future: Future = hook_manager.aleo/init_merkle_tree(ADDRESS);
        future.await();
        
        let expected_roots: [[u8; 32]; 3] = [
            [245, 14, 28, 186, 19, 89, 112, 97, 168, 121, 40, 9, 12, 122, 147, 178, 185, 37, 122, 236, 214, 33, 27, 24, 16, 225, 253, 118, 206, 92, 193, 51],
            [90, 239, 29, 179, 47, 146, 197, 171, 195, 5, 76, 231, 232, 214, 94, 28, 41, 161, 19, 7, 71, 195, 46, 157, 208, 0, 114, 243, 2, 170, 56, 112],
            [199, 210, 89, 154, 191, 112, 209, 67, 109, 220, 108, 136, 204, 66, 20, 144, 92, 148, 11, 228, 34, 112, 128, 186, 117, 26, 84, 206, 31, 219, 20, 178],
        ];

        for i in 0u8..3u8 {
            let msg = [0u8; 256];
            let dispatch: Future = hook_manager.aleo/post_dispatch(MERKLE_TREE_HOOK, msg, [0u8; 256], [CreditAllowance { spender: ADDRESS, amount: 0}; 4]);
            dispatch.await();
        }

        let state = Mapping::get(hook_manager.aleo/merkle_tree_hooks, MERKLE_TREE_HOOK);
        let root: [u8; 32] = u128_to_u8(state.root);
        assert_eq(root, expected_roots[2]);
    }

    inline u128_to_u8(message_id: [u128; 2]) -> [u8; 32] {
        let left = Serialize::to_bits_raw(message_id[0]);
        let right = Serialize::to_bits_raw(message_id[1]);
        let bits = [false; 256];
        for i in 0u8..128u8 {
            bits[i] = left[i];
            bits[i + 128] = right[i];
        }
        return Deserialize::from_bits_raw::[[u8; 32]](bits);
    }
}
