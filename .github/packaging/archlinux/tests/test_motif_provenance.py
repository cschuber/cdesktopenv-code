import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / "ci-motif-provenance.py"
spec = importlib.util.spec_from_file_location("motif_provenance", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MotifVersionTests(unittest.TestCase):
    def test_full_release_is_preserved(self):
        self.assertEqual(module.version_parts("2.3.8-4"),
                         {"full_version": "2.3.8-4", "epoch": "0",
                          "upstream_version": "2.3.8", "package_release": "4"})

    def test_epoch_and_fractional_release_are_preserved(self):
        self.assertEqual(module.version_parts("1:2.3.8-4.1"),
                         {"full_version": "1:2.3.8-4.1", "epoch": "1",
                          "upstream_version": "2.3.8", "package_release": "4.1"})

    def test_missing_release_is_not_guessed(self):
        with self.assertRaises(ValueError):
            module.version_parts("2.3.8")
