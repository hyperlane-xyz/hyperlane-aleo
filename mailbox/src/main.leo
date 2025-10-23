import ism_manager.aleo;

// The 'mailbox' program.
program mailbox.aleo {

    // messageId => Delivery
    mapping deliveries: DeliveryKey => Delivery;
    // dispatches events map from index => message
    mapping dispatch_events: u32 => Message;
    // dispatches id events map from index => message
    mapping dispatch_id_events: u32 => [u128; 2];
    // delivery events map from index => message id
    mapping process_events: u32 => ProcessEvent;
    // Mailbox state
    mapping mailbox: bool => Mailbox;

    struct Mailbox {
        local_domain: u32,
        nonce: u32,
        process_count: u32,
        default_ism: address,
        default_hook: address,
        required_hook: address,
        dispatch_proxy: address,
        mailbox_owner: address,
    }

    struct Message {
        version: u8,
        nonce: u32,
        origin_domain: u32,
        sender: [u8; 32],
        destination_domain: u32,
        recipient: [u8; 32],
        body: [u128; 8],
    }

    struct Delivery {
        processor: address,
        block_number: u32,
    }

    struct DeliveryKey {
        id: [u128; 2],
    }

    struct CreditAllowance {
        spender: address,
        amount: u64,
    }

    struct ProcessEvent {
        sequence: u32,
        id: [u128; 2],
    }

    const MAILBOX_VERSION: u8 = 3u8;
    const NULL_ADDRESS: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    @noupgrade
    async constructor() {}

    async transition init(local_domain: u32) -> Future {
        return finalize_init(local_domain, self.caller);
    }

    async function finalize_init(local_domain: u32, caller: address) {
        assert(!mailbox.contains(true));
        mailbox.set(true, Mailbox {
            local_domain,
            nonce: 0u32,
            process_count: 0u32,
            default_ism: NULL_ADDRESS,
            default_hook: NULL_ADDRESS,
            required_hook: NULL_ADDRESS,
            dispatch_proxy: NULL_ADDRESS,
            mailbox_owner: caller
        });
    }

    async transition set_dispatch_proxy(dispatch_proxy: address) -> Future {
        return finalize_set_dispatch_proxy(dispatch_proxy, self.caller);
    }

    async function finalize_set_dispatch_proxy(dispatch_proxy: address, caller: address) {
        let state = mailbox.get(true);
        assert_eq(state.mailbox_owner, caller);

        state.dispatch_proxy = dispatch_proxy;
        mailbox.set(true, state);
    }

    async transition set_owner(new_owner: address) -> Future {
        return finalize_set_owner(new_owner, self.caller);
    }

    async function finalize_set_owner(new_owner: address, caller: address) {
        let state = mailbox.get(true);
        assert_eq(state.mailbox_owner, caller);

        state.mailbox_owner = new_owner;
        mailbox.set(true, state);
    }

    async transition set_default_ism(ism: address) -> Future {
        return finalize_set_default_ism(ism, self.caller);
    }

    async function finalize_set_default_ism(ism: address, caller: address) {
        let state = mailbox.get(true);
        assert_eq(state.mailbox_owner, caller);

        state.default_ism = ism;
        mailbox.set(true, state);
    }

    async transition set_default_hook(hook: address) -> Future {
        return finalize_set_default_hook(hook, self.caller);
    }

    async function finalize_set_default_hook(hook: address, caller: address) {
        let state = mailbox.get(true);
        assert_eq(state.mailbox_owner, caller);

        state.default_hook = hook;
        mailbox.set(true, state);
    }

    async transition set_required_hook(hook: address) -> Future {
        return finalize_set_required_hook(hook, self.caller);
    }

    async function finalize_set_required_hook(hook: address, caller: address) {
        let state = mailbox.get(true);
        assert_eq(state.mailbox_owner, caller);

        state.required_hook = hook;
        mailbox.set(true, state);
    }

    /// Process
    /// Verifies and processes a message.
    /// This methods assumes that the caller ensures that the passed ism is correct.
    /// We accept the message id as a parameter to avoid having large computation inside of transitions.
    /// We verify whether or not the id is correct inside the finalize step of the transition.
    /// - message_length: the raw message length in bytes
    async transition process(ism: address, message: Message, message_length: u32, id: [u128; 2], metadata: [u8; 512]) -> Future {
        let processor = self.caller;
        let verify_future = ism_manager.aleo/verify(ism, message, id, metadata);
        return finalize_process(ism, message, message_length, id, processor, verify_future);
    }

    async function finalize_process(ism: address, message: Message, message_length: u32, id: [u128; 2], processor: address, verify_future: Future) {
        assert(mailbox.contains(true));

        // Assert that the passed id matches the calculated id
        let calculated_id = dynamic_message_id(message, message_length);
        assert_eq(calculated_id, id);

        let current_mailbox: Mailbox = mailbox.get(true);
        verify_future.await();
        let processor_bytes = address_to_bytes_raw(processor);
        assert_eq(message.recipient, processor_bytes);
        assert_eq(message.version, MAILBOX_VERSION);
        assert_eq(message.destination_domain, current_mailbox.local_domain);

        let delivery_key = DeliveryKey { id };
        let delivered: bool = deliveries.contains(delivery_key);
        assert(!delivered);

        deliveries.set(delivery_key, Delivery {
            processor,
            block_number: block.height,
        });

        process_events.set(block.height, ProcessEvent {
            sequence: current_mailbox.process_count,
            id,
        });
        current_mailbox.process_count += 1;
        mailbox.set(true, current_mailbox);
    }

    /// Dispatch
    /// Creates a new message based on given inputs and dispatch it
    /// - hook_allowance: mapping from hook_address -> allowed credits to spent. This is used to correctly initialize credit transfers in the `post_dispatch` hooks
    async transition dispatch(destination_domain: u32, recipient_address: [u8; 32], message_body: [u128; 8], message_sender: address) -> Future {
        // Make sure that dispatch is called by the dispatch proxy and no one else
        return finalize_dispatch(
            destination_domain,
            recipient_address,
            message_body,
            message_sender,
            self.caller
        );
    }

    async function finalize_dispatch(destination_domain: u32, recipient_address: [u8; 32], message_body: [u128; 8], message_sender: address, caller: address) {
        assert(mailbox.contains(true));
        let current_mailbox: Mailbox = mailbox.get(true);

        assert_eq(caller, current_mailbox.dispatch_proxy);

        let sender = address_to_bytes_raw(message_sender);
        let message = Message {
            version: MAILBOX_VERSION,
            nonce: current_mailbox.nonce,
            origin_domain: current_mailbox.local_domain,
            sender,
            destination_domain,
            recipient: recipient_address,
            body: message_body,
        };
        let id = static_message_id(message);

        dispatch_events.set(current_mailbox.nonce, message);
        dispatch_id_events.set(current_mailbox.nonce, id);

        current_mailbox.nonce += 1;

        mailbox.set(true, current_mailbox);
    }

    inline address_to_bytes_raw(a: address) -> [u8; 32] {
        let bits = Serialize::to_bits_raw(a);
        let padded_bits = [false; 256];
        for i in 0u8..253u8 {
            padded_bits[i] = bits[i];
        }
        return Deserialize::from_bits_raw::[[u8; 32]](padded_bits);
    }

    /// Returns the message id based on the static sized message
    inline static_message_id(message: Message) -> [u128; 2] {
        let message_raw = message_to_raw(message);
        let hash = Keccak256::hash_native_raw(message_raw);
        return Deserialize::from_bits_raw::[[u128; 2]](hash);
    }

    /// Calcualtes the message id based on a dynamic message length
    ///
    /// The message id is the keccak of the raw bytes of that message, this ID changes with the length of the bytes.
    /// Other Hyperlane implementations might have dynamic message lengths, something that we can't depitc in the AVM.
    /// We resolve this by having the caller provide the message length and copy the bytes into a fixed length array before hashing.
    /// Note: This approach comes with following limitations:
    /// - The maximum message length is 205 bytes (the full message size)
    /// - The minimum message length is 77 bytes (the static part of the message without body)
    /// - The message length has to be of the form 77 + n*8 bytes, where n is a natural number (0,1,2,...16)
    /// - This results in only 17 possible message lengths
    inline dynamic_message_id(static_message: Message, message_length: u32) -> [u128; 2] {
        assert(message_length >= 77);
        assert((message_length - 77) % 8 == 0);
        let id = [0u128; 2];
        let message_raw = message_to_raw(static_message);
        // Note: This is the best solution possible, other solutions result in more op-codes generated for the same logic.
        // It is also important to note, that there exists no branching logic in Aleo, branches are resolved with a ternary assignment.
        // This means, even if we were to implement some high level optimizations like binary search here, the generated Aleo code would still execute every statement.
        if message_length == 77u32 {
            let message = [0u8; 77];
            for i in 0u32..77u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 85u32 {
            let message = [0u8; 85];
            for i in 0u32..85u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 93u32 {
            let message = [0u8; 93];
            for i in 0u32..93u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 101u32 {
            let message = [0u8; 101];
            for i in 0u32..101u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 109u32 {
            let message = [0u8; 109];
            for i in 0u32..109u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 117u32 {
            let message = [0u8; 117];
            for i in 0u32..117u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 125u32 {
            let message = [0u8; 125];
            for i in 0u32..125u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 133u32 {
            let message = [0u8; 133];
            for i in 0u32..133u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 141u32 {
            let message = [0u8; 141];
            for i in 0u32..141u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 149u32 {
            let message = [0u8; 149];
            for i in 0u32..149u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 157u32 {
            let message = [0u8; 157];
            for i in 0u32..157u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 165u32 {
            let message = [0u8; 165];
            for i in 0u32..165u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 173u32 {
            let message = [0u8; 173];
            for i in 0u32..173u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 181u32 {
            let message = [0u8; 181];
            for i in 0u32..181u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 189u32 {
            let message = [0u8; 189];
            for i in 0u32..189u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 197u32 {
            let message = [0u8; 197];
            for i in 0u32..197u32 { message[i] = message_raw[i]; }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 205u32 {
            let hash = Keccak256::hash_native_raw(message_raw);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        }

        return id;
    }

    // Converts a message into its raw byte form
    inline message_to_raw(message: Message) -> [u8; 205] {
        // Byte layout of message:
        // [0]         - version (1 byte)
        // [1-4]       - message nonce (4 bytes)
        // [5-8]       - origin domain (4 bytes)
        // [9-40]      - sender address (32 bytes)
        // [41-44]     - destination domain (4 bytes)
        // [45-76]     - recipient address (32 bytes)
        // [77-205]    - message body (128 bytes)
        let raw = [0u8; 205];
        raw[0] = message.version;

        let nonce = u32_to_bytes(message.nonce);
        let origin_domain = u32_to_bytes(message.origin_domain);
        let destination_domain = u32_to_bytes(message.destination_domain);

        for i in 0u8..4u8 {
            raw[i + 1] = nonce[i];
            raw[i + 5] = origin_domain[i];
            raw[i + 41] = destination_domain[i];
        }

        for i in 0u8..32u8 {
            raw[i + 9] = message.sender[i];
            raw[i + 45] = message.recipient[i];
        }

        for i in 0u8..8u8 {
            let bytes = u128_to_bytes(message.body[i]);
            for k in 0u8..16u8 {
                raw[77 + i * 16 + k] = bytes[k];
            }
        }

        return raw;
    }

    inline u32_to_bytes(value: u32) -> [u8; 4] {
        let b3: u8 = (value >> 24u32) as u8;
        let b2: u8 = ((value >> 16u32) % 256u32) as u8;
        let b1: u8 = ((value >> 8u32) % 256u32) as u8;
        let b0: u8 = (value % 256u32) as u8;
        return [b3, b2, b1, b0];
    }

    inline u128_to_bytes(value: u128) -> [u8; 16] {
        let bits = Serialize::to_bits_raw(value);
        return Deserialize::from_bits_raw::[[u8; 16]](bits);
    }
}
