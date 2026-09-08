from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

# bin/omajabra has no .py extension, so load it through an explicit loader.
_loader = SourceFileLoader("omajabra_cli", str(ROOT / "bin" / "omajabra"))
_spec = importlib.util.spec_from_loader("omajabra_cli", _loader)
cli = importlib.util.module_from_spec(_spec)
_loader.exec_module(cli)


class RunBoundedTest(unittest.TestCase):
    def test_returns_normal_command_output(self) -> None:
        result = cli.run_bounded([sys.executable, "-c", "print('hello')"], timeout=5)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "hello")

    def test_caps_oversized_output_instead_of_buffering_it_all(self) -> None:
        with self.assertRaises(cli.CommandOutputLimitExceeded):
            cli.run_bounded(
                [sys.executable, "-c", "import sys; sys.stdout.write('x' * 400000)"],
                timeout=5,
                output_limit=1000,
            )

    def test_times_out_a_slow_command(self) -> None:
        with self.assertRaises(subprocess.TimeoutExpired):
            cli.run_bounded([sys.executable, "-c", "import time; time.sleep(5)"], timeout=0.4)


class ReadJsonFileTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def test_reads_a_regular_owned_json_file(self) -> None:
        path = self.dir / "ok.json"
        path.write_text('{"connected": true}', encoding="utf-8")
        self.assertEqual(cli.read_json_file(path), {"connected": True})

    def test_refuses_a_symlink(self) -> None:
        target = self.dir / "target.json"
        target.write_text('{"a": 1}', encoding="utf-8")
        link = self.dir / "link.json"
        link.symlink_to(target)
        with self.assertRaises(ValueError):
            cli.read_json_file(link)

    def test_refuses_a_non_regular_file(self) -> None:
        with self.assertRaises(ValueError):
            cli.read_json_file(self.dir)  # a directory is not a regular file

    def test_refuses_an_oversized_file(self) -> None:
        path = self.dir / "big.json"
        path.write_bytes(b"x" * (cli.MAX_JSON_BYTES + 1))
        with self.assertRaises(ValueError):
            cli.read_json_file(path)

    def test_missing_file_raises_file_not_found(self) -> None:
        with self.assertRaises(FileNotFoundError):
            cli.read_json_file(self.dir / "absent.json")


if __name__ == "__main__":
    unittest.main()
