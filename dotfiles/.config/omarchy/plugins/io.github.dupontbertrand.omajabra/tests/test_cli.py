from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "omajabra"
MAC = "50:C2:ED:F6:DA:BB"


class OmajabraCliTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.log = self.root / "commands.log"
        self.write_fake_bluetoothctl()
        self.write_fake_wpctl()
        self.write_fake_pw_cli()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_tool(self, name: str, body: str) -> None:
        path = self.bin_dir / name
        path.write_text("#!/bin/sh\nset -eu\n" + body, encoding="utf-8")
        path.chmod(0o755)

    def write_fake_bluetoothctl(self) -> None:
        self.write_tool(
            "bluetoothctl",
            r'''
case "$*" in
  list)
    if [ "${FAKE_ADAPTER:-1}" = "1" ]; then
      echo "Controller 10:02:B5:C4:17:F5 test [default]"
    fi
    ;;
  show)
    echo "Controller 10:02:B5:C4:17:F5 (public)"
    echo "  Powered: ${FAKE_POWERED:-yes}"
    ;;
  "devices Paired")
    if [ "${FAKE_PAIRED:-1}" = "1" ]; then
      echo "Device 50:C2:ED:F6:DA:BB Jabra Elite 75t"
    fi
    ;;
  "devices Connected")
    if [ "${FAKE_CONNECTED:-1}" = "1" ]; then
      echo "Device 50:C2:ED:F6:DA:BB Jabra Elite 75t"
    fi
    ;;
  info*)
    echo "Device 50:C2:ED:F6:DA:BB (public)"
    echo "  Name: Jabra Elite 75t"
    echo "  Alias: Jabra Elite 75t"
    echo "  Paired: yes"
    if [ "${FAKE_CONNECTED:-1}" = "1" ]; then
      echo "  Connected: yes"
      echo "  Battery Percentage: 0x57 (87)"
    else
      echo "  Connected: no"
    fi
    echo "  Modalias: ${FAKE_MODALIAS:-bluetooth:v0067p24A7d0200}"
    ;;
  connect*|disconnect*)
    printf '%s\n' "bluetoothctl $*" >> "$FAKE_LOG"
    echo "Connection successful"
    ;;
esac
''',
        )

    def write_fake_wpctl(self) -> None:
        self.write_tool(
            "wpctl",
            r'''
case "$1 ${2:-}" in
  "status -n")
    cat <<'EOF'
Audio
 ├─ Sinks:
 │  *   67. bluez_output.50_C2_ED_F6_DA_BB.1 [vol: 0.46]
 ├─ Sources:
 │  *   69. bluez_input.50:C2:ED:F6:DA:BB [Audio/Source]
EOF
    ;;
  "inspect 67")
    echo 'api.bluez5.address = "50:C2:ED:F6:DA:BB"'
    echo 'api.bluez5.codec = "aac"'
    echo "api.bluez5.profile = \"${FAKE_PROFILE:-a2dp-sink}\""
    echo 'node.name = "bluez_output.50_C2_ED_F6_DA_BB.1"'
    echo 'device.id = "66"'
    ;;
  "inspect @DEFAULT_AUDIO_SINK@")
    if [ "${FAKE_ACTIVE:-1}" = "1" ]; then
      echo 'api.bluez5.address = "50:C2:ED:F6:DA:BB"'
      echo 'node.name = "bluez_output.50_C2_ED_F6_DA_BB.1"'
    else
      echo 'node.name = "alsa_output.pci-0000_00_1f.3.analog-stereo"'
    fi
    ;;
  "get-volume 67")
    if [ "${FAKE_MUTED:-0}" = "1" ]; then
      echo 'Volume: 0.46 [MUTED]'
    else
      echo 'Volume: 0.46'
    fi
    ;;
  "set-default 67"|"set-volume 67"|"set-mute 67"|"set-profile 66")
    printf '%s\n' "wpctl $*" >> "$FAKE_LOG"
    ;;
esac
''',
        )

    def write_fake_pw_cli(self) -> None:
        self.write_tool(
            "pw-cli",
            r'''
cat <<'EOF'
Object: profile
  Prop: key Param:Profile:index
    Int 131076
  Prop: key Param:Profile:name
    String "a2dp-sink"
  Prop: key Param:Profile:description
    String "High Fidelity Playback (A2DP Sink, codec AAC)"
  Prop: key Param:Profile:available
    Id 2
  Prop: key Param:Profile:priority
    Int 133
Object: profile
  Prop: key Param:Profile:index
    Int 196864
  Prop: key Param:Profile:name
    String "headset-head-unit-cvsd"
  Prop: key Param:Profile:description
    String "Headset Head Unit (HSP/HFP, codec CVSD)"
  Prop: key Param:Profile:available
    Id 2
  Prop: key Param:Profile:priority
    Int 5
Object: profile
  Prop: key Param:Profile:index
    Int 196865
  Prop: key Param:Profile:name
    String "headset-head-unit"
  Prop: key Param:Profile:description
    String "Headset Head Unit (HSP/HFP, codec MSBC)"
  Prop: key Param:Profile:available
    Id 2
  Prop: key Param:Profile:priority
    Int 6
EOF
''',
        )

    def environment(self, **values: str) -> dict[str, str]:
        environment = os.environ.copy()
        # Keep the suite hermetic: a default GNP mock stands in for the headset
        # so `profile calls` never reaches real Bluetooth. Tests override it.
        environment["OMAJABRA_GNP_MOCK_FILE"] = str(self.root / "gnp-default.json")
        environment.update(values)
        environment["PATH"] = f"{self.bin_dir}:{os.environ.get('PATH', '')}"
        environment["FAKE_LOG"] = str(self.log)
        environment["HOME"] = str(self.root)
        # Pin XDG_CONFIG_HOME under the temp root so the config-fallback mock
        # resolves deterministically and never leaks the CI runner's value.
        environment["XDG_CONFIG_HOME"] = str(self.root / ".config")
        return environment

    def run_cli(
        self, *arguments: str, check: bool = True, **environment: str
    ) -> subprocess.CompletedProcess[str]:
        completed = subprocess.run(
            [sys.executable, str(CLI), *arguments],
            capture_output=True,
            text=True,
            env=self.environment(**environment),
            check=False,
        )
        if check and completed.returncode != 0:
            self.fail(f"CLI failed: {completed.stdout}\n{completed.stderr}")
        return completed

    def status(self, **environment: str) -> dict[str, object]:
        return json.loads(self.run_cli("status", **environment).stdout)

    def test_connected_device_exposes_battery_audio_and_microphone(self) -> None:
        status = self.status()
        self.assertTrue(status["adapterAvailable"])
        self.assertTrue(status["connected"])
        self.assertTrue(status["activeOutput"])
        self.assertEqual(status["name"], "Jabra Elite 75t")
        self.assertEqual(status["battery"], 87)
        self.assertEqual(status["volume"], 46)
        self.assertEqual(status["codec"], "AAC")
        self.assertEqual(status["profile"], "a2dp-sink")
        self.assertFalse(status["microphoneAvailable"])
        self.assertEqual(status["profileMode"], "music")
        self.assertEqual(status["profiles"]["music"]["index"], 131076)
        self.assertEqual(status["profiles"]["calls"]["index"], 196865)

    def test_calls_profile_exposes_the_real_headset_microphone(self) -> None:
        status = self.status(FAKE_PROFILE="headset-head-unit")
        self.assertEqual(status["profileMode"], "calls")
        self.assertTrue(status["microphoneAvailable"])

    def test_paired_disconnected_device_remains_available(self) -> None:
        status = self.status(FAKE_CONNECTED="0")
        self.assertTrue(status["paired"])
        self.assertFalse(status["connected"])
        self.assertIsNone(status["battery"])
        self.assertIsNone(status["sinkId"])
        self.assertEqual(status["message"], "Ready to connect")

    def test_missing_adapter_is_reported_cleanly(self) -> None:
        status = self.status(FAKE_ADAPTER="0")
        self.assertFalse(status["adapterAvailable"])
        self.assertFalse(status["connected"])
        self.assertEqual(status["message"], "No Bluetooth adapter")

    def test_missing_jabra_is_not_an_error(self) -> None:
        status = self.status(FAKE_CONNECTED="0", FAKE_PAIRED="0")
        self.assertFalse(status["paired"])
        self.assertEqual(status["name"], "Jabra")
        self.assertEqual(status["message"], "No paired Jabra device")

    def test_mock_file_drives_visual_testing(self) -> None:
        mock = self.root / "mock.json"
        mock.write_text(
            json.dumps(
                {
                    "connected": True,
                    "paired": True,
                    "name": "Jabra demo",
                    "battery": 63,
                    "volume": 42,
                }
            ),
            encoding="utf-8",
        )
        status = self.status(OMAJABRA_MOCK_FILE=str(mock))
        self.assertEqual(status["name"], "Jabra demo")
        self.assertEqual(status["battery"], 63)
        self.assertIn("checkedAt", status)

    def test_config_mock_is_an_explicit_visual_testing_fallback(self) -> None:
        mock = self.root / ".config" / "omajabra" / "mock.json"
        mock.parent.mkdir(parents=True)
        mock.write_text(
            json.dumps({"connected": False, "name": "Offline Jabra demo"}),
            encoding="utf-8",
        )
        status = self.status()
        self.assertEqual(status["name"], "Offline Jabra demo")
        self.assertFalse(status["connected"])

    def test_activate_and_volume_use_the_discovered_sink(self) -> None:
        self.run_cli("activate")
        self.run_cli("volume", "125")
        self.run_cli("volume-step", "-5")
        self.run_cli("mute", "toggle")
        self.run_cli("profile", "calls")
        commands = self.log.read_text(encoding="utf-8").splitlines()
        self.assertIn("wpctl set-default 67", commands)
        self.assertIn("wpctl set-volume 67 100%", commands)
        self.assertIn("wpctl set-volume 67 5%-", commands)
        self.assertIn("wpctl set-mute 67 toggle", commands)
        self.assertIn("wpctl set-profile 66 196865", commands)

    def test_connect_uses_only_the_validated_device_address(self) -> None:
        self.run_cli("connect", FAKE_CONNECTED="0")
        self.assertIn(
            f"bluetoothctl connect {MAC}", self.log.read_text(encoding="utf-8")
        )

    def test_calls_profile_enables_sidetone_by_default(self) -> None:
        mock = self.root / "gnp.json"
        mock.write_text(json.dumps({"sidetone": {"enabled": False}}), encoding="utf-8")
        result = json.loads(
            self.run_cli("profile", "calls", OMAJABRA_GNP_MOCK_FILE=str(mock)).stdout
        )
        self.assertTrue(json.loads(mock.read_text())["sidetone"]["enabled"])
        self.assertIn("sidetone", result["message"].lower())

    def test_music_profile_leaves_sidetone_untouched(self) -> None:
        mock = self.root / "gnp.json"
        mock.write_text(json.dumps({"sidetone": {"enabled": False}}), encoding="utf-8")
        self.run_cli("profile", "music", OMAJABRA_GNP_MOCK_FILE=str(mock))
        self.assertFalse(json.loads(mock.read_text())["sidetone"]["enabled"])

    def test_optout_wins_even_when_a_mock_is_present(self) -> None:
        mock = self.root / "gnp.json"
        mock.write_text(json.dumps({"sidetone": {"enabled": False}}), encoding="utf-8")
        result = json.loads(
            self.run_cli(
                "profile",
                "calls",
                OMAJABRA_GNP_MOCK_FILE=str(mock),
                OMAJABRA_SIDETONE_IN_CALLS="0",
            ).stdout
        )
        self.assertTrue(result["ok"])
        self.assertFalse(json.loads(mock.read_text())["sidetone"]["enabled"])
        self.assertNotIn("sidetone", result["message"].lower())

    def test_unvalidated_model_is_left_untouched(self) -> None:
        mock = self.root / "gnp.json"
        mock.write_text(json.dumps({"sidetone": {"enabled": False}}), encoding="utf-8")
        result = json.loads(
            self.run_cli(
                "profile",
                "calls",
                OMAJABRA_GNP_MOCK_FILE=str(mock),
                FAKE_MODALIAS="bluetooth:v0067p9999d0200",
            ).stdout
        )
        self.assertTrue(result["ok"])
        self.assertFalse(json.loads(mock.read_text())["sidetone"]["enabled"])
        self.assertIn("wpctl set-profile 66 196865", self.log.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
