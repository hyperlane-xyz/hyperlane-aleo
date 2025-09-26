// The 'test_ism_manager' test program.
import ism_manager.aleo;
program test_ism_manager.aleo {
    @test
    script test_it() {
        let result: u32 = ism_manager.aleo/main(1u32, 2u32);
        assert_eq(result, 3u32);
    }

    @test
    @should_fail
    transition do_nothing() {
        let result: u32 = ism_manager.aleo/main(2u32, 3u32);
        assert_eq(result, 3u32);
    }

    @noupgrade
    async constructor() {}
}
