"""Test command and logger failures."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "ci-log.sh"


class LogCaptureTests(unittest.TestCase):
    def test_command_failure_is_preserved_with_complete_log(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "capture.txt"
            result = subprocess.run(["bash", str(SCRIPT), str(log), "bash", "-c",
                                     "echo before; echo failure >&2; exit 7"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 7)
            self.assertEqual(log.read_text(), "before\nfailure\n")
            self.assertEqual(Path(str(log) + ".command-exit-status.txt").read_text(), "7\n")
            self.assertEqual(Path(str(log) + ".logger-exit-status.txt").read_text(), "0\n")

    def test_logger_failure_cannot_report_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tee = root / "tee"
            tee.write_text('#!/bin/bash\ncat > "$1"\nexit 9\n')
            tee.chmod(0o755)
            log = root / "capture.txt"
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"])
            result = subprocess.run(["bash", str(SCRIPT), str(log), "bash", "-c", "echo complete"],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(log.read_text(), "complete\n")
            self.assertEqual(Path(str(log) + ".logger-exit-status.txt").read_text(), "9\n")
