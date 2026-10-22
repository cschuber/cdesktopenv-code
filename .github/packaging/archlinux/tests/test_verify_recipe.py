import importlib.util
import unittest
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "ci-verify-recipe.py"
spec = importlib.util.spec_from_file_location("verify_recipe", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

ORIGINAL = b"pkgver=1\npkgrel=4\ndepends=(mksh)\nbuild() { make; }\n"


class RecipeIntegrityTests(unittest.TestCase):
    def test_native_version_refresh_is_allowed(self):
        module.verify(ORIGINAL, ORIGINAL.replace(b"pkgver=1", b"pkgver=2.5.3.140.gabc")
                      .replace(b"pkgrel=4", b"pkgrel=1"))

    def test_compiler_override_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL.replace(b"make;", b"make CFLAGS=-w;"))

    def test_dependency_substitution_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL.replace(b"mksh", b"ksh"))

    def test_added_prepare_patch_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL + b"prepare() { patch -p1 < fix.patch; }\n")

    def test_auxiliary_line_change_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL + b"source=(replacement)\n")

    def test_trailing_shell_commands_are_rejected(self):
        for key in (b"pkgver=1", b"pkgrel=4"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                module.verify(ORIGINAL, ORIGINAL.replace(key, key + b"; export CFLAGS=-w"))

    def test_command_expansion_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL.replace(b"pkgver=1", b"pkgver=$(echo 1)"))

    def test_literal_quoted_versions_are_allowed(self):
        module.verify(ORIGINAL, ORIGINAL.replace(b"pkgver=1", b'pkgver="2.5.3"')
                      .replace(b"pkgrel=4", b"pkgrel='1.1'"))

    def test_duplicate_version_assignment_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL + b"pkgver=1\n")

    def test_changes_outside_version_assignments_are_rejected(self):
        with self.assertRaises(ValueError):
            module.verify(ORIGINAL, ORIGINAL.replace(b"pkgver=1\n", b"pkgver=1\nexport CFLAGS=-w\n"))
