from __future__ import annotations

import errno
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

import omajabra_gnp as gnp  # noqa: E402


PC = 0
HEADSET1 = 4
CONFIG = 0x13
ACK = 0xFF
REPLY = 0xC0
READ = 0x40
WRITE = 0x80
DSP_SIDETONE = 0x7C


def frame(packet_id: int, command: int, subcommand: int, data: bytes = b"") -> bytes:
    length = 6 + len(data)
    return bytes((PC, HEADSET1, packet_id, REPLY | length, command, subcommand)) + data


class FakeDevice:
    """Minimal in-memory GNP peer for the sidetone register."""

    def __init__(self, sidetone: bytes = b"\x01\x04") -> None:
        self.registers = {DSP_SIDETONE: sidetone}
        self.writes: list[tuple[int, bytes]] = []
        self._pending = bytearray()

    def settimeout(self, _value: float) -> None:
        pass

    def sendall(self, payload: bytes) -> None:
        packet_id = payload[2]
        packet_type = payload[3] & 0xC0
        subcommand = payload[5]
        data = payload[6:]
        if packet_type == WRITE:
            self.registers[subcommand] = bytes(data)
            self.writes.append((subcommand, bytes(data)))
            self._pending += frame(packet_id, ACK, subcommand)
        else:
            self._pending += frame(packet_id, CONFIG, subcommand, self.registers[subcommand])

    def recv(self, size: int) -> bytes:
        chunk = bytes(self._pending[:size])
        del self._pending[:size]
        return chunk

    def close(self) -> None:
        pass


def connector_for(device: FakeDevice):
    return lambda address, channel, timeout: device


class GnpTest(unittest.TestCase):
    def test_encodes_public_api_read_example(self) -> None:
        self.assertEqual(
            gnp.encode_packet(0x4C, READ, 0x87),
            bytes.fromhex("04 00 4c 46 13 87"),
        )

    def test_decodes_sidetone_state(self) -> None:
        # config[0] == 0 means unmuted (enabled); config[1] is a signed dB level.
        self.assertEqual(gnp.decode_sidetone(b"\x00\x04"), {"enabled": True, "levelDb": 4})
        self.assertEqual(gnp.decode_sidetone(b"\x01\xfa"), {"enabled": False, "levelDb": -6})

    def test_enable_sidetone_writes_unmuted_and_preserves_level(self) -> None:
        device = FakeDevice(sidetone=b"\x01\x04")  # starts muted at 4 dB
        result = gnp.enable_sidetone("50:C2:ED:F6:DA:BB", connector=connector_for(device))
        self.assertTrue(result["enabled"])
        self.assertIn((DSP_SIDETONE, b"\x00\x04"), device.writes)

    def test_only_the_validated_elite_75t_supports_sidetone(self) -> None:
        self.assertTrue(gnp.model_supports_sidetone("bluetooth:v0067p24A7d0200"))
        # Same Jabra vendor, a different (unvalidated) product must be refused.
        self.assertFalse(gnp.model_supports_sidetone("bluetooth:v0067p9999d0200"))
        self.assertFalse(gnp.model_supports_sidetone(""))

    def test_connect_retries_on_ebusy(self) -> None:
        device = FakeDevice()
        attempts = {"count": 0}

        def flaky(address, channel, timeout):
            attempts["count"] += 1
            if attempts["count"] < 3:
                raise OSError(errno.EBUSY, "Device or resource busy")
            return device

        gnp.enable_sidetone(
            "50:C2:ED:F6:DA:BB", connector=flaky, sleeper=lambda _seconds: None
        )
        self.assertEqual(attempts["count"], 3)


if __name__ == "__main__":
    unittest.main()
