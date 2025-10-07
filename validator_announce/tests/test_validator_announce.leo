// The 'test_validator_announce' test program.
import validator_announce.aleo;
program test_validator_announce.aleo {

    const MAILBOX: [u8; 32] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 243, 159, 214, 229, 26, 173, 136, 246, 244, 206, 106, 184, 130, 114, 121, 207, 255, 185, 34, 102];
    const LOCAL_DOMAIN: u32 = 1337u32;

    struct EthAddress {
        bytes: [u8; 20],
    }

    @test
    script test_init() {
        let result: Future = validator_announce.aleo/init(MAILBOX, LOCAL_DOMAIN);
        result.await();

        let state = Mapping::get(validator_announce.aleo/validator_announce, true);
        assert_eq(state.local_domain, LOCAL_DOMAIN);
        assert_eq(state.mailbox, MAILBOX);
    }

    @test
    script test_announce() {
        let validator: [u8; 20] = [255, 158, 134, 162, 5, 200, 135, 150, 5, 153, 219, 36, 3, 136, 45, 36, 142, 223, 191, 216];
        let sig: [u8; 65] = [49, 79, 115, 205, 135, 168, 6, 90, 7, 164, 0, 230, 148, 23, 61, 93, 182, 200, 40, 253, 157, 218, 39, 190, 206, 221, 132, 95, 3, 202, 77, 157, 33, 97, 90, 125, 131, 186, 219, 67, 185, 117, 221, 170, 15, 54, 31, 3, 153, 67, 116, 232, 24, 104, 144, 193, 253, 51, 19, 105, 252, 204, 110, 121, 0];
        let storage_location_packed: [u8; 26] = [115, 51, 58, 47, 47, 116, 101, 115, 116, 45, 115, 116, 111, 114, 97, 103, 101, 45, 108, 111, 99, 97, 116, 105, 111, 110];
        let storage_location = [0u8; 480];
        for i in 0u8..26u8 {
            storage_location[i] = storage_location_packed[i];
        }

        let announce: Future = validator_announce.aleo/announce(validator, storage_location, sig);
        announce.await();
    }

    @test
    @should_fail
    script test_replay() {
        let validator: [u8; 20] = [255, 158, 134, 162, 5, 200, 135, 150, 5, 153, 219, 36, 3, 136, 45, 36, 142, 223, 191, 216];
        let sig: [u8; 65] = [49, 79, 115, 205, 135, 168, 6, 90, 7, 164, 0, 230, 148, 23, 61, 93, 182, 200, 40, 253, 157, 218, 39, 190, 206, 221, 132, 95, 3, 202, 77, 157, 33, 97, 90, 125, 131, 186, 219, 67, 185, 117, 221, 170, 15, 54, 31, 3, 153, 67, 116, 232, 24, 104, 144, 193, 253, 51, 19, 105, 252, 204, 110, 121, 0];
        let storage_location_packed: [u8; 26] = [115, 51, 58, 47, 47, 116, 101, 115, 116, 45, 115, 116, 111, 114, 97, 103, 101, 45, 108, 111, 99, 97, 116, 105, 111, 110];
        let storage_location = [0u8; 480];
        for i in 0u8..26u8 {
            storage_location[i] = storage_location_packed[i];
        }

        let announce: Future = validator_announce.aleo/announce(validator, storage_location, sig);
        announce.await();
    }

    @test
    @should_fail
    script test_invalid_sig() {
        let validator: [u8; 20] = [255, 158, 134, 162, 5, 200, 135, 150, 5, 153, 219, 36, 3, 136, 45, 36, 142, 223, 191, 216];
        let sig: [u8; 65] = [49, 79, 114, 205, 135, 168, 6, 90, 7, 164, 0, 230, 148, 23, 61, 93, 182, 200, 40, 253, 157, 218, 39, 190, 206, 221, 132, 95, 3, 202, 77, 157, 33, 97, 90, 125, 131, 186, 219, 67, 185, 117, 221, 170, 15, 54, 31, 3, 153, 67, 116, 232, 24, 104, 144, 193, 253, 51, 19, 105, 252, 204, 110, 121, 0];
        let storage_location_packed: [u8; 26] = [115, 50, 58, 47, 47, 116, 101, 115, 116, 45, 115, 116, 111, 114, 97, 103, 101, 45, 108, 111, 99, 97, 116, 105, 111, 110];
        let storage_location = [0u8; 480];
        for i in 0u8..26u8 {
            storage_location[i] = storage_location_packed[i];
        }

        let announce: Future = validator_announce.aleo/announce(validator, storage_location, sig);
        announce.await();
    }

    transition main() {}

    @noupgrade
    async constructor() {}
}
