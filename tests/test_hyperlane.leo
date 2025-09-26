// The 'test_hyperlane_aleo' test program.
import hyperlane.aleo;
program test_hyperlane.aleo {

    @noupgrade
    async constructor() {}

    @test
    transition do_nothing() {
        let result: u32 = hyperlane.aleo/main(2u32, 3u32);
        let value: [u32; 64] = [0u32; 64];
        assert_eq(result, value[0]);
    }
}
