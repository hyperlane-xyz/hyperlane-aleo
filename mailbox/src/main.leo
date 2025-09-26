import hook_manager.aleo;
import ism_manager.aleo;

// The 'mailbox' program.
program mailbox.aleo {
    struct Mailbox {
        local_domain: u32,
        nonce: u32,
        process_count: u32,
        latest_dispatch_id: Bytes32,
        default_ism: address,
        default_hook: address,
        required_hook: address,
    }

    struct Bytes32 {
        bytes: [u8; 32]
    }

    struct Metadata {
        bytes: [Bytes32; 32]
    }

    struct Message {
        version: u8,
        nonce: u32,
        origin_domain: u32,
        sender: Bytes32,
        destination_domain: u32,
        recipient: Bytes32,
        body: [u8; 179],
    }

    // Mapping of message ID to delivery context that processed the message.
    struct Delivery {
        processor: address,
        block_number: u32,
    }

    struct ProcessEvent {
        sequence: u32,
        id: Bytes32,
    }

    // messageId => Delivery
    mapping deliveries: Bytes32 => Delivery;
    // TODO: multiple events per block height
    // dispatches events map from blockheight => message
    mapping dispatch_events: u32 => Message;
    // dispatches id events map from blockheight => message
    mapping dispatch_id_events: u32 => Bytes32;
    // delivery events map from blockheight => message id
    mapping process_events: u32 => ProcessEvent;
    // Mailbox state
    mapping mailbox: bool => Mailbox;
    // Owner
    mapping mailbox_owner: bool => address;

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
            latest_dispatch_id: new_bytes32([0u8; 32]),
            default_ism: NULL_ADDRESS,
            default_hook: NULL_ADDRESS,
            required_hook: NULL_ADDRESS
        });
        mailbox_owner.set(true, caller);
    }

    async transition process(message: Message, metadata: Metadata) -> Future {
        let processor = self.caller;
        return finalize_process(message, metadata, processor);
    }

    async function finalize_process(message: Message, metadata: Metadata, processor: address) {
        let current_mailbox: Mailbox = mailbox.get(true);

        assert_eq(message.version, MAILBOX_VERSION);
        assert_eq(message.destination_domain, current_mailbox.local_domain);

        let id = message_id(message);

        let delivered: bool = deliveries.contains(id);
        assert(!delivered);

        deliveries.set(id, Delivery {
            processor,
            block_number: block.height,
        });
        
        process_events.set(block.height, ProcessEvent {
            sequence: current_mailbox.process_count,
            id,
        });
        current_mailbox.process_count += 1; 
    }

    async transition dispatch(passed_mailbox: Mailbox, destination_domain: u32, recipient_address: Bytes32, message_body: [u8; 179], credits_amount: u64) -> Future  {
        let sender = self.caller;

        assert_neq(passed_mailbox.default_hook, NULL_ADDRESS);
        assert_neq(passed_mailbox.required_hook, NULL_ADDRESS);

        let message = Message {
            version: MAILBOX_VERSION,
            nonce: passed_mailbox.nonce,
            origin_domain: passed_mailbox.local_domain,
            sender: zero_bytes(), 
            destination_domain,
            recipient: recipient_address,
            body: message_body
        };
        let raw = raw_message(message);
        let metadata = [0u8; 256];
        // initialize futures for the post_dispatch hook assuming all of the passed arugments are correct.
        // TODO: create correct hook_metadata
        let default_hook = hook_manager.aleo/post_dispatch(passed_mailbox.default_hook, metadata, raw, credits_amount);
        let required_hook = hook_manager.aleo/post_dispatch(passed_mailbox.required_hook, metadata, raw, 0u64); // TODO: we need a way to make this dynamic

        return finalize_dispatch(
                passed_mailbox,
                message,
                default_hook,
                required_hook
            );
    }

    async function finalize_dispatch(passed_mailbox: Mailbox, message: Message, default_hook: Future, required_hook: Future) {
        let current_mailbox: Mailbox = mailbox.get(true);
        assert_eq(passed_mailbox, current_mailbox);

        default_hook.await();
        required_hook.await();

        let id = message_id(message);

        current_mailbox.nonce += 1;
        current_mailbox.latest_dispatch_id = id;

        dispatch_events.set(block.height, message);
        dispatch_id_events.set(block.height, id);

        mailbox.set(true, current_mailbox);
    }

    inline new_bytes32(bytes: [u8; 32]) ->  Bytes32 {
        return Bytes32 {
            bytes,
        };
    }

    inline zero_bytes() ->  Bytes32 {
        return Bytes32 {
            bytes: [0u8; 32],
        };
    }

    inline message_id(message: Message) -> Bytes32 {
        return zero_bytes();
    }

    inline raw_message(message: Message) -> [u8; 256] {
        // TODO:
        return [0u8; 256];
    }
}
