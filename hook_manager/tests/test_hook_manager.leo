program test_hook_manager.aleo {
    @test
    transition create_noop() {
        assert_neq(5u32, 5u32);
    }
}
