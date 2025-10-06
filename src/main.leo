// The 'hyperlane' program.
program hyperlane.aleo {
    @noupgrade
    async constructor() {}

    transition main(a: u32, b: u32) -> u32 {
        return a + b;
    }
}
