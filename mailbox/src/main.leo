import hook_manager.aleo;
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
    // Owner
    mapping mailbox_owner: bool => address;

    struct Mailbox {
        local_domain: u32,
        nonce: u32,
        process_count: u32,
        default_ism: address,
        default_hook: address,
        required_hook: address,
    }

    struct Message {
        version: u8,
        nonce: u32,
        origin_domain: u32,
        sender: [u8; 32],
        destination_domain: u32,
        recipient: [u8; 32],
        body: [u8; 179],
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

    async transition instantiate(local_domain: u32) -> Future {
        return finalize_instantiate(local_domain, self.caller);
    }

    async function finalize_instantiate(local_domain: u32, caller: address) {
        mailbox.set(true, Mailbox {
            local_domain,
            nonce: 0u32,
            process_count: 0u32,
            default_ism: NULL_ADDRESS,
            default_hook: NULL_ADDRESS,
            required_hook: NULL_ADDRESS,
        });
        mailbox_owner.set(true, caller);
    }

    async transition process(ism: address, message: [u8; 256], message_length: u32, metadata: [u8; 512]) -> Future {
        let processor = self.caller;
        let id = dynamic_message_id(message, message_length);
        let verify_future = ism_manager.aleo/verify(ism, message, id, metadata);
        return finalize_process(ism, message, id, processor, verify_future);
    }

    async function finalize_process(ism: address, message: [u8; 256], id: [u128; 2], processor: address, verify_future: Future) {
        assert(mailbox.contains(true));

        let current_mailbox: Mailbox = mailbox.get(true);
        verify_future.await();
        let processor_bytes = address_to_bytes_raw(processor);
        assert_eq(message_recipient(message), processor_bytes);
        assert_eq(message_version(message), MAILBOX_VERSION);
        assert_eq(message_destination_domain(message), current_mailbox.local_domain);

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
    }

    /// Dispatch
    /// Creates a new message based on given inputs and dispatch it
    /// - passed_mailbox: Is the current mailbox state, this is necessary to initialize `post_dispatch` futures
    /// - hook_allowance: mapping from hook_address -> allowed credits to spent. This is used to correctly initialize credit transfers in the `post_dispatch` hooks
    async transition dispatch(passed_mailbox: Mailbox, destination_domain: u32, recipient_address: [u8; 32], message_body: [u8; 179], metadata: [u8; 256], hook_allowance: [CreditAllowance; 4]) -> Future {
        assert_neq(passed_mailbox.default_hook, NULL_ADDRESS);
        assert_neq(passed_mailbox.required_hook, NULL_ADDRESS);

        let sender = address_to_bytes_raw(self.caller);

        let message = Message {
            version: MAILBOX_VERSION,
            nonce: passed_mailbox.nonce,
            origin_domain: passed_mailbox.local_domain,
            sender,
            destination_domain,
            recipient: recipient_address,
            body: message_body,
        };
        let raw = raw_message(message);
        let id = static_message_id(raw);
        // initialize futures for the post_dispatch hook assuming all of the passed arguments are correct.
        let default_hook = hook_manager.aleo/post_dispatch(passed_mailbox.default_hook, metadata, raw, hook_allowance);
        let required_hook = hook_manager.aleo/post_dispatch(passed_mailbox.required_hook, metadata, raw, hook_allowance);

        return finalize_dispatch(
            passed_mailbox,
            message,
            id,
            default_hook,
            required_hook,
        );
    }

    async function finalize_dispatch(passed_mailbox: Mailbox, message: Message, id: [u128; 2], default_hook: Future, required_hook: Future) {
        assert(mailbox.contains(true));

        let current_mailbox: Mailbox = mailbox.get(true);
        assert_eq(passed_mailbox, current_mailbox);

        default_hook.await();
        required_hook.await();

        dispatch_events.set(current_mailbox.nonce, message);
        dispatch_id_events.set(current_mailbox.nonce, id);

        current_mailbox.nonce += 1;

        mailbox.set(true, current_mailbox);
    }

    inline raw_message(message: Message) -> [u8; 256] {
        // Byte layout of message:
        // [0]         - version (1 byte)
        // [1-4]       - message nonce (4 bytes)
        // [5-8]       - origin domain (4 bytes)
        // [9-40]      - sender address (32 bytes)
        // [41-44]     - destination domain (4 bytes)
        // [45-76]     - recipient address (32 bytes)
        // [77-255]    - message body (179 bytes)
        let raw = [0u8; 256];
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

        for i in 0u8..179u8 {
            raw[i + 77] = message.body[i];
        }

        return raw;
    }

    inline address_to_bytes_raw(a: address) -> [u8; 32] {
        let bits = Serialize::to_bits_raw(a);
        let padded_bits = [false; 256];
        for i in 0u8..253u8 {
            padded_bits[i] = bits[i];
        }
        return Deserialize::from_bits_raw::[[u8; 32]](padded_bits);
    }

    inline u32_to_bytes(value: u32) -> [u8; 4] {
        let b3: u8 = (value >> 24u32) as u8;
        let b2: u8 = ((value >> 16u32) % 256u32) as u8;
        let b1: u8 = ((value >> 8u32) % 256u32) as u8;
        let b0: u8 = (value % 256u32) as u8;
        return [b3, b2, b1, b0];
    }

    /// Returns the MessageId (hash of the message) based on the length that is provided.
    /// Hash changes with respect to the input size and we can only have static sized arrays in Aleo
    /// This function manually matches all possible input sizes, copies the respective bytes into the correctly sized arrays and calculates the hash
    inline dynamic_message_id(message_raw: [u8; 256], message_length: u32) -> [u128; 2] {
        assert(message_length >= 77);
        let id = [0u128; 2];
        // Note: This is the best solution possible, other solutions result in more op-codes generated for the same logic.
        // It is also important to note, that there exists no branching logic in Aleo, branches are resolved with a ternary assignment.
        // This means, even if we were to implement some high level optimizations like binary search here, the generated Aleo code would still execute every statement.
        if message_length == 77u32 {
            let message = [0u8; 77];
            for i in 0u32..77u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 85u32 {
            let message = [0u8; 85];
            for i in 0u32..85u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 93u32 {
            let message = [0u8; 93];
            for i in 0u32..93u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 101u32 {
            let message = [0u8; 101];
            for i in 0u32..101u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 109u32 {
            let message = [0u8; 109];
            for i in 0u32..109u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 117u32 {
            let message = [0u8; 117];
            for i in 0u32..117u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 125u32 {
            let message = [0u8; 125];
            for i in 0u32..125u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 133u32 {
            let message = [0u8; 133];
            for i in 0u32..133u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 141u32 {
            let message = [0u8; 141];
            for i in 0u32..141u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 149u32 {
            let message = [0u8; 149];
            for i in 0u32..149u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 157u32 {
            let message = [0u8; 157];
            for i in 0u32..157u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 165u32 {
            let message = [0u8; 165];
            for i in 0u32..165u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 173u32 {
            let message = [0u8; 173];
            for i in 0u32..173u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 181u32 {
            let message = [0u8; 181];
            for i in 0u32..181u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 189u32 {
            let message = [0u8; 189];
            for i in 0u32..189u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 197u32 {
            let message = [0u8; 197];
            for i in 0u32..197u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 205u32 {
            let message = [0u8; 205];
            for i in 0u32..205u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 213u32 {
            let message = [0u8; 213];
            for i in 0u32..213u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 221u32 {
            let message = [0u8; 221];
            for i in 0u32..221u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 229u32 {
            let message = [0u8; 229];
            for i in 0u32..229u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 237u32 {
            let message = [0u8; 237];
            for i in 0u32..237u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 245u32 {
            let message = [0u8; 245];
            for i in 0u32..245u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        } else if message_length == 253u32 {
            let message = [0u8; 253];
            for i in 0u32..253u32 {
                message[i] = message_raw[i];
            }
            let hash = Keccak256::hash_native_raw(message);
            id = Deserialize::from_bits_raw::[[u128; 2]](hash);
        }

        return id;
    }

    /// Returns the message id based on the static sized message
    inline static_message_id(message: [u8; 256]) -> [u128; 2] {
        let hash = Keccak256::hash_native_raw(message);
        return Deserialize::from_bits_raw::[[u128; 2]](hash);
    }

    inline message_version(message: [u8; 256]) -> u8 {
        // [0]         - version (1 byte)
        return message[0];
    }

    inline message_destination_domain(message: [u8; 256]) -> u32 {
        // [41-44]     - destination domain (4 bytes)
        let destination_domain = 0u32;
        for i in 0u8..4u8 {
            destination_domain = destination_domain << 1u32 + message[41 + i] as u32;
        }
        return destination_domain;
    }

    inline message_recipient(message: [u8; 256]) -> [u8; 32] {
        // [45-76]     - recipient address (32 bytes)
        let recipient_raw = [0u8; 32];
        for i in 0u8..32u8 {
            recipient_raw[i] = message[i + 45];
        }
        return recipient_raw;
    }
}
