import requests, json, yaml
from Crypto.Hash import keccak
import click
from typing import Literal


def decode_into_big_endian(value: str|list, endianness: Literal["big", "little"] = 'big'):
    if isinstance(value, list):
        return b''.join([decode_into_big_endian(x, endianness) for x in value])
    if value.endswith("u8"):
        return int(value[:-2]).to_bytes(1, endianness)
    if value.endswith("u32"):
        return int(value[:-3]).to_bytes(4, endianness)
    if value.endswith("u128"):
        return int(value[:-4]).to_bytes(16, endianness)
    raise ValueError("Suffix not supported: ", value)


class Message:
    def __init__(self,version: int, nonce: int, origin_domain: int, sender: bytes, destination_domain: int, recipient: bytes, body: bytes):
        self.version = version
        self.nonce = nonce
        self.origin_domain = origin_domain
        self.sender = sender
        self.destination_domain = destination_domain
        self.recipient = recipient
        self.message_body = body

    @classmethod
    def from_message_bytes(cls, message_bytes: bytes) -> "Message":
        return cls(
            int.from_bytes(message_bytes[0:1], byteorder='big'),
            int.from_bytes(message_bytes[1:5], byteorder='big'),
            int.from_bytes(message_bytes[5:9], byteorder='big'),
            message_bytes[9:41],
            int.from_bytes(message_bytes[41:45], byteorder='big'),
            message_bytes[45:77],
            message_bytes[77:]
        )

    @classmethod
    def from_aleo_event(cls, aleo_event_yaml: str) -> "Message":
        message = yaml.safe_load(json.loads(aleo_event_yaml))
        message_bytes = [
            decode_into_big_endian(message["version"]),
            decode_into_big_endian(message["nonce"]),
            decode_into_big_endian(message["origin_domain"]),
            decode_into_big_endian(message["sender"]),
            decode_into_big_endian(message["destination_domain"]),
            decode_into_big_endian(message["recipient"]),
            decode_into_big_endian(message["body"], 'little'),
        ]
        return Message.from_message_bytes(b''.join(message_bytes))

    def get_message_bytes(self):
        return b''.join([
            self.version.to_bytes(1, 'big'),
            self.nonce.to_bytes(4, 'big'),
            self.origin_domain.to_bytes(4, 'big'),
            self.sender,
            self.destination_domain.to_bytes(4, 'big'),
            self.recipient,
            self.message_body,
        ])

    def message_id(self):
        keccak_hash = keccak.new(digest_bits=256)
        keccak_hash.update(self.get_message_bytes())
        return bytes.fromhex(keccak_hash.hexdigest())

    def get_length(self):
        return 77 + len(self.message_body)

    def get_aleo_struct(self):
        sender = "[" + ", ".join([str(int(x)) + "u8" for x in self.sender]) + "]"
        recipient = "[" + ", ".join([str(int(x)) + "u8" for x in self.recipient]) + "]"

        if len(self.message_body) > 128:
            raise ValueError("Message body too large for Aleo.")

        aleo_body = self.message_body
        if len(self.message_body) < 256:
            aleo_body = aleo_body + b'\x00' * (256 - len(self.message_body))

        aleo_body_u128 = [int.from_bytes(aleo_body[i:i + 16], byteorder='little') for i in range(0, 256, 16)]
        aleo_body_u128 = "[" + ", ".join([str(x) + "u128" for x in aleo_body_u128]) + "]"

        return f"{{version: {self.version}u8, nonce: {self.nonce}u32, origin_domain: {self.origin_domain}u32, sender: {sender}, destination_domain: {self.destination_domain}u32, recipient: {recipient}, body: {aleo_body_u128} }}"

    def get_aleo_message_id(self):
        msg_id = self.message_id()
        part1 = int.from_bytes(msg_id[0:16], byteorder='little')
        part2 = int.from_bytes(msg_id[16:32], byteorder='little')
        return f"[{part1}u128, {part2}u128]"


@click.group()
def cli():
    """Hypertools for Aleo"""
    pass


@cli.command()
@click.option("--nonce", type=int, help="Use a custom nonce", default=1)
@click.option("--origin", type=int, help="The origin where the message comes from", default=1)
@click.option("--sender", type=str, help="The sender (hex) address from the origin", default="0102010201020102010201020102010201020102010201020102010201020102")
@click.option("--destination", type=int, help="Should equal the mailbox id", default=12)
@click.option("--recipient", type=str, help="Should equal the recipient contract", default="eb6b26cfd0ae2dbb2230f3f2d3c58db7672d871c4173d29a9876e136dde11807")
@click.option("--warp_recipient", type=str, help="Should equal the user recipient", default="eb6b26cfd0ae2dbb2230f3f2d3c58db7672d871c4173d29a9876e136dde11807")
@click.option("--warp_amount", type=int, help="The amount that is being sent", default=1000000)
def process_warp(nonce, origin, sender, destination, recipient, warp_recipient, warp_amount):
    warp_body = bytes.fromhex(warp_recipient.zfill(32)) + (int(warp_amount).to_bytes(32, 'big'))
    m = Message(
        3,
        nonce,
        origin,
        bytes.fromhex(sender.removeprefix("0x")),
        destination,
        bytes.fromhex(recipient.removeprefix("0x")),
        warp_body)
    print("message struct (aleo):\n" + m.get_aleo_struct())
    print("raw-message (hex):\n" + m.get_message_bytes().hex())
    print("message-id (aleo):\t", m.get_aleo_message_id())
    print("message-id (hex):\t", m.message_id().hex())


@cli.command()
@click.argument("event_id", type=int)
def fetch(event_id):
    r = requests.get(f"http://localhost:3030/testnet/program/mailbox.aleo/mapping/dispatch_events/{event_id}u32")
    dispatch = Message.from_aleo_event(r.text)
    print("raw-message (hex):\n" + dispatch.get_message_bytes().hex())
    print("message-id (aleo):\t", dispatch.get_aleo_message_id())
    print("message-id (hex):\t", dispatch.message_id().hex())


@cli.command()
@click.argument("u128", type=int)
def decode_ascii(u128):
    print(int(u128).to_bytes(16, 'big').decode('ascii'))

if __name__ == "__main__":
    cli()
