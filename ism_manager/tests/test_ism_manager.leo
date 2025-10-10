// The 'test_ism_manager' test program.
import ism_manager.aleo;
program test_ism_manager.aleo {

    const ISM_ADDRESS: address = aleo1jng84kfxuwvhzepgtmnvchgm2xqgzrmde2u350rv8dhdln0pa5zstj3u9d;

    struct EthAddress {
        bytes: [u8; 20],
    }

    @noupgrade
    async constructor() {}

    @test
    script test_valid_message() {
        let validators: [EthAddress; 6] = [EthAddress { bytes: [3, 200, 66, 219, 134, 166, 163, 229, 36, 212, 166, 97, 83, 144, 193, 234, 142, 43, 149, 65] }, EthAddress { bytes: [0u8; 20] }, EthAddress { bytes: [0u8; 20] }, EthAddress { bytes: [0u8; 20] }, EthAddress { bytes: [0u8; 20] }, EthAddress { bytes: [0u8; 20] }];

        let future: Future = ism_manager.aleo/init_message_id_multisig(validators, 1, 1);
        future.await();

        let message_packed: [u8; 83] = [3, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 242, 191, 88, 195, 138, 65, 173, 124, 156, 188, 20, 231, 128, 232, 167, 237, 187, 212, 141, 0, 0, 33, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 129, 24, 8, 221, 41, 186, 139, 15, 198, 192, 236, 11, 85, 55, 3, 94, 89, 116, 81, 98, 72, 101, 108, 108, 111, 33];
        let message = [0u8; 256];
        for i in 0u32..83u32 {
            message[i] = message_packed[i];
        }
        let message_id: [u8; 32] = [240, 167, 111, 141, 16, 143, 237, 63, 213, 120, 88, 252, 135, 144, 23, 246, 19, 41, 220, 234, 127, 225, 112, 172, 79, 250, 142, 147, 139, 205, 173, 48];
        let bits = [false; 256];
        for i in 0u32..32u32 {
            let byte_bits = Serialize::to_bits_raw(message_id[i]);
            for j in 0u32..8u32 {
                bits[(i * 8) + j] = byte_bits[j];
            }
        }
        let message_id_u128 = Deserialize::from_bits_raw::[[u128; 2]](bits);
        let metadata_packed: [u8; 133] = [0,0,0,0,0,0,0,0,0,0,0,0,72,230,195,11,151,116,141,30,46,3,191,62,159,190,56,144,202,95,140,202,219,39,134,136,244,249,41,187,3,199,110,87,134,108,164,18,144,220,99,161,6,151,82,80,127,230,210,15,48,127,21,56,0,0,0,0,58,235,121,208,229,66,184,54,49,68,254,82,134,177,248,246,57,45,117,211,34,13,158,202,10,194,11,176,205,65,35,109,14,94,175,204,231,230,16,92,194,130,202,166,140,231,61,9,95,128,241,17,205,229,168,241,62,128,189,141,219,11,145,39,27];
        let metadata: [u8; 512] = [0u8; 512];
        for i in 0u32..133u32 {
            metadata[i] = metadata_packed[i];
        }

        let verify: Future = ism_manager.aleo/verify(ISM_ADDRESS, message, message_id_u128, metadata);
        verify.await();
    }

    @test
    @should_fail
    script test_invalid_signature() {
        let message_packed: [u8; 83] = [3, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 127, 242, 191, 88, 195, 138, 65, 173, 124, 156, 188, 20, 231, 128, 232, 167, 237, 187, 212, 141, 0, 0, 33, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 129, 24, 8, 221, 41, 186, 139, 15, 198, 192, 236, 11, 85, 55, 3, 94, 89, 116, 81, 98, 72, 101, 108, 108, 111, 33];
        let message = [0u8; 256];
        for i in 0u32..83u32 {
            message[i] = message_packed[i];
        }
        let message_id: [u8; 32] = [240, 167, 111, 141, 16, 143, 237, 63, 213, 120, 88, 252, 135, 144, 23, 246, 19, 41, 220, 234, 127, 225, 112, 172, 79, 250, 142, 147, 139, 205, 173, 48];
        let bits = [false; 256];
        for i in 0u32..32u32 {
            let byte_bits = Serialize::to_bits_raw(message_id[i]);
            for j in 0u32..8u32 {
                bits[(i * 8) + j] = byte_bits[j];
            }
        }
        let message_id_u128 = Deserialize::from_bits_raw::[[u128; 2]](bits);

        let metadata_packed: [u8; 133] = [0,0,0,0,0,0,0,0,0,0,0,0,72,230,195,11,151,116,141,30,46,3,191,62,159,190,56,144,202,95,140,202,219,39,134,136,244,249,41,187,3,199,110,87,134,108,164,18,144,220,99,161,6,151,82,80,127,230,210,15,48,127,21,56,0,0,0,0,58,235,121,208,229,66,184,54,49,68,254,82,134,177,248,246,57,45,117,211,34,13,158,202,10,194,11,176,205,65,35,109,14,94,175,204,231,230,16,92,194,130,202,166,140,231,61,9,95,128,241,17,205,229,168,241,62,128,189,141,219,11,145,40,27];
        let metadata: [u8; 512] = [0u8; 512];
        for i in 0u32..133u32 {
            metadata[i] = metadata_packed[i];
        }

        let verify: Future = ism_manager.aleo/verify(ISM_ADDRESS, message, message_id_u128, metadata);
        verify.await();
    }

    transition main() {}
}
