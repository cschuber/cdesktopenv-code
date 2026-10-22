#!/usr/bin/env python3
"""Check that PKGBUILD changes are limited to pkgver/pkgrel."""
import re
import sys
from pathlib import Path

ASSIGNMENT = re.compile(rb"^(pkgver|pkgrel)=(.*)$", re.M)
VALUES = {
    b"pkgver": re.compile(rb"[A-Za-z0-9._+~]+"),
    b"pkgrel": re.compile(rb"[0-9]+(?:\.[0-9]+)?"),
}


def normalize(data: bytes) -> bytes:
    seen = {key: 0 for key in VALUES}

    def assignment(match: re.Match[bytes]) -> bytes:
        key, value = match.groups()
        seen[key] += 1
        # Allow literal quotes, but reject shell expansion and commands.
        if len(value) >= 2 and value[:1] in (b"'", b'"') and value[-1:] == value[:1]:
            value = value[1:-1]
        if VALUES[key].fullmatch(value) is None:
            raise ValueError(f"Nonliteral {key.decode()} assignment in AUR recipe")
        return key + b"=<native-makepkg-version>"

    result = ASSIGNMENT.sub(assignment, data)
    if any(count != 1 for count in seen.values()):
        raise ValueError("Expected exactly one plain pkgver and pkgrel assignment")
    return result


def verify(original: bytes, working: bytes) -> None:
    if normalize(original) != normalize(working):
        raise ValueError("AUR recipe changed beyond native pkgver/pkgrel metadata")


if __name__ == "__main__":
    try:
        verify(*(Path(p).read_bytes() for p in sys.argv[1:]))
    except (OSError, ValueError, TypeError) as error:
        raise SystemExit(f"FATAL: {error}")
