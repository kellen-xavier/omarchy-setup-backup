"""Minimal GNP client used to enable DSP sidetone on a Jabra headset.

Sidetone (hearing your own voice on calls) is not reachable through BlueZ on
the Elite line, so Omajabra sets it through GNP, an unofficial serial protocol
reverse-engineered from black-box observation of an Elite 75t. This module does
exactly one thing on demand — enable sidetone — as a best-effort side effect of
switching to Calls mode. It talks to no Jabra binary, SDK, or cloud service.

The transport is injectable (``connector``) so the protocol is tested against an
in-memory device rather than real hardware.
"""

from __future__ import annotations

import contextlib
import errno
import re
import secrets
import socket
import time
from dataclasses import dataclass
from typing import Callable


HEADSET1 = 4
PC = 0
CONFIG = 0x13
ACK = 0xFF
NACK = 0xFE
READ = 0x40
WRITE = 0x80
REPLY = 0xC0

DSP_SIDETONE = 0x7C

DEFAULT_CHANNEL = 3
DEFAULT_TIMEOUT = 3.0
EBUSY_RETRIES = 3
EBUSY_BACKOFF = 0.4

Connector = Callable[[str, int, float], "socket.socket"]

# (vendor, product) Bluetooth IDs whose GNP channel-3 sidetone is validated.
# On any other model that RFCOMM channel may serve a different purpose, so we
# never write to it. Keep this list to devices actually tested on hardware.
SIDETONE_MODELS = {("0067", "24a7")}  # Jabra Elite 75t
_MODALIAS_RE = re.compile(r"v([0-9a-f]{4})p([0-9a-f]{4})", re.IGNORECASE)


def model_supports_sidetone(modalias: str) -> bool:
    match = _MODALIAS_RE.search(modalias or "")
    if not match:
        return False
    return (match.group(1).lower(), match.group(2).lower()) in SIDETONE_MODELS


class ProtocolError(RuntimeError):
    """A malformed, rejected, or unexpected GNP frame."""


@dataclass(frozen=True)
class Packet:
    packet_id: int
    packet_type: int
    command: int
    subcommand: int
    data: bytes


def encode_packet(packet_id: int, packet_type: int, subcommand: int, data: bytes = b"") -> bytes:
    length = 6 + len(data)
    if not 6 <= length <= 63:
        raise ValueError("GNP packet length must be between 6 and 63 bytes")
    if packet_type not in (READ, WRITE):
        raise ValueError("only read and write requests are supported")
    return bytes((HEADSET1, PC, packet_id, packet_type | length, CONFIG, subcommand)) + data


def decode_packet(raw: bytes) -> Packet:
    if len(raw) < 6:
        raise ProtocolError("short GNP packet")
    declared_length = raw[3] & 0x3F
    if declared_length != len(raw):
        raise ProtocolError(
            f"GNP length mismatch: declared {declared_length}, received {len(raw)}"
        )
    return Packet(
        packet_id=raw[2],
        packet_type=raw[3] & 0xC0,
        command=raw[4],
        subcommand=raw[5],
        data=raw[6:],
    )


def signed_byte(value: int) -> int:
    return int.from_bytes(bytes((value,)), "little", signed=True)


def decode_sidetone(configuration: bytes) -> dict[str, object]:
    if len(configuration) != 2:
        raise ProtocolError("unexpected sidetone payload")
    return {"enabled": configuration[0] == 0, "levelDb": signed_byte(configuration[1])}


def _default_connector(address: str, channel: int, timeout: float) -> "socket.socket":
    client = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
    client.settimeout(timeout)
    client.connect((address, channel))
    return client


class GnpClient:
    def __init__(
        self,
        address: str,
        channel: int = DEFAULT_CHANNEL,
        timeout: float = DEFAULT_TIMEOUT,
        connector: Connector | None = None,
        sleeper: Callable[[float], None] = time.sleep,
    ) -> None:
        self.address = address
        self.channel = channel
        self.timeout = timeout
        self.connector = connector or _default_connector
        self.sleeper = sleeper
        self.socket: "socket.socket | None" = None
        self.packet_id = secrets.randbelow(256)

    def __enter__(self) -> "GnpClient":
        # The Elite 75t transiently refuses a reconnect with EBUSY; retry briefly.
        for attempt in range(EBUSY_RETRIES):
            try:
                self.socket = self.connector(self.address, self.channel, self.timeout)
                return self
            except OSError as error:
                if error.errno == errno.EBUSY and attempt < EBUSY_RETRIES - 1:
                    self.sleeper(EBUSY_BACKOFF)
                    continue
                raise
        return self

    def __exit__(self, *_: object) -> None:
        if self.socket is not None:
            with contextlib.suppress(OSError):
                self.socket.close()
            self.socket = None

    def _next_packet_id(self) -> int:
        self.packet_id = (self.packet_id + 1) & 0xFF
        return self.packet_id

    def _receive(self) -> bytes:
        if self.socket is None:
            raise ProtocolError("client is not connected")
        raw = bytearray()
        while len(raw) < 4:
            chunk = self.socket.recv(64)
            if not chunk:
                raise ProtocolError("RFCOMM peer closed the connection")
            raw.extend(chunk)
        expected = raw[3] & 0x3F
        while len(raw) < expected:
            chunk = self.socket.recv(expected - len(raw))
            if not chunk:
                raise ProtocolError("RFCOMM peer closed during a packet")
            raw.extend(chunk)
        if len(raw) != expected:
            raise ProtocolError("multiple GNP packets arrived in one read")
        return bytes(raw)

    def _exchange(self, packet_type: int, subcommand: int, data: bytes = b"") -> Packet:
        if self.socket is None:
            raise ProtocolError("client is not connected")
        packet_id = self._next_packet_id()
        self.socket.sendall(encode_packet(packet_id, packet_type, subcommand, data))
        reply = decode_packet(self._receive())
        if reply.packet_id != packet_id:
            raise ProtocolError("reply packet ID does not match the request")
        if reply.packet_type != REPLY:
            raise ProtocolError(f"unexpected packet type 0x{reply.packet_type:02x}")
        if reply.command == NACK:
            raise ProtocolError(f"device rejected command 0x{subcommand:02x}")
        return reply

    def read(self, subcommand: int) -> bytes:
        reply = self._exchange(READ, subcommand)
        if reply.command != CONFIG or reply.subcommand != subcommand:
            raise ProtocolError("unexpected read response")
        return reply.data

    def write(self, subcommand: int, data: bytes) -> None:
        reply = self._exchange(WRITE, subcommand, data)
        if reply.command != ACK:
            raise ProtocolError("write was not acknowledged")

    def set_sidetone(self, enabled: bool) -> dict[str, object]:
        current = self.read(DSP_SIDETONE)
        if len(current) != 2:
            raise ProtocolError("unexpected sidetone payload")
        mute_state = 0 if enabled else 1
        self.write(DSP_SIDETONE, bytes((mute_state, current[1])))
        verified = decode_sidetone(self.read(DSP_SIDETONE))
        if verified["enabled"] is not enabled:
            raise ProtocolError("sidetone verification failed")
        return verified


def enable_sidetone(
    address: str,
    *,
    connector: Connector | None = None,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, object]:
    """Enable DSP sidetone on the headset. Raises on any transport or protocol
    failure; callers treat it as best-effort and ignore failures."""
    with GnpClient(address, connector=connector, sleeper=sleeper) as client:
        return client.set_sidetone(True)
