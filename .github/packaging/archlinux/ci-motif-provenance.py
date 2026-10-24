#!/usr/bin/env python3
"""Report installed Motif package and library versions."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


def command(*args: str) -> str:
    return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT,
                          env=dict(os.environ, LC_ALL="C")).stdout


def version_parts(version: str) -> dict[str, str]:
    upstream, separator, release = version.rpartition("-")
    if not separator or not upstream or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", release):
        raise ValueError(f"Unrecognized Arch package version: {version}")
    epoch, colon, upstream_version = upstream.partition(":")
    if not colon:
        epoch, upstream_version = "0", upstream
    elif not epoch.isdigit() or not upstream_version:
        raise ValueError(f"Unrecognized Arch package epoch: {version}")
    return {"full_version": version, "epoch": epoch,
            "upstream_version": upstream_version, "package_release": release}


def identify(path: Path) -> dict:
    owner = command("pacman", "-Qoq", str(path)).strip()
    if not owner or len(owner.splitlines()) != 1:
        raise ValueError(f"Expected one package owner for {path}: {owner!r}")
    name, version = command("pacman", "-Q", owner).strip().split(maxsplit=1)
    return {"name": name, **version_parts(version),
            "metadata": command("pacman", "-Qi", owner)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=("build", "install"), required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--aur-revision", required=True)
    parser.add_argument("--build-report", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    header = Path("/usr/include/Xm/Xm.h")
    linkage = ""
    if args.phase == "install":
        linkage = command("ldd", "/usr/dt/bin/dtwm")
        match = re.search(r"^\s*libXm\.so\S*\s+=>\s+(/\S+)", linkage, re.M)
        if match is None:
            raise ValueError("dtwm has no resolved libXm dependency")
        library = Path(match.group(1)).resolve(strict=True)
        linkage = match.group(0).strip() + "\n"
    else:
        library = Path("/usr/lib/libXm.so").resolve(strict=True)
    provider = identify(library)
    report = {"phase": args.phase, "library": str(library),
              "provider": provider, "cdesktopenv_aur_revision": args.aur_revision}
    if header.is_file():
        report["header"] = str(header)
        report["header_provider"] = identify(header)
        report["header_version_macros"] = "\n".join(
            line for line in header.read_text(errors="replace").splitlines()
            if re.match(r"^#\s*define\s+Xm(?:VERSION|REVISION|UPDATE_LEVEL|VERSION_STRING)\s", line))
    build_provider = None
    if args.build_report:
        build_provider = json.loads(args.build_report.read_text())["provider"]
        report["build_provider"] = build_provider
    label = "Build" if args.phase == "build" else "Installed"
    rows = [
        ("Motif package", provider["name"]),
        ("Package version", provider["full_version"]),
        ("Epoch", provider["epoch"]),
        ("Motif version", provider["upstream_version"]),
        ("Package release", provider["package_release"]),
        ("Library", str(library)),
        ("CDE AUR revision", args.aur_revision),
    ]
    if "header_provider" in report:
        hp = report["header_provider"]
        rows.append(("Header package", hp["name"] + " " + hp["full_version"]))
    if build_provider:
        rows.append(("Build package",
                     build_provider["name"] + " " + build_provider["full_version"]))
        same = all(provider[key] == build_provider[key] for key in ("name", "full_version"))
        rows.append(("Matches build", "yes" if same else "no"))
    markdown = f"### Motif: {label}\n\n| Field | Value |\n|---|---|\n"
    markdown += "".join(f"| {key} | {value} |\n" for key, value in rows)
    markdown += (
        "\n<details>\n<summary>Package details</summary>\n\n"
        "~~~text\n" + provider["metadata"])
    if "header_version_macros" in report:
        markdown += "\nXm.h version:\n" + report["header_version_macros"] + "\n"
    if linkage:
        markdown += "\ndtwm libXm:\n" + linkage
    markdown += "~~~\n\n</details>\n"
    text_report = f"Motif: {label}\n\n"
    text_report += "".join(f"{key}: {value}\n" for key, value in rows)
    text_report += "\n" + provider["metadata"]
    if "header_provider" in report:
        if any(report["header_provider"][key] != provider[key]
               for key in ("name", "full_version")):
            text_report += "\nHeader package metadata:\n" + report["header_provider"]["metadata"]
        text_report += "\nXm.h version:\n" + report["header_version_macros"] + "\n"
    if linkage:
        text_report += "\ndtwm libXm:\n" + linkage
    stem = args.output_dir / ("motif-" + args.phase)
    stem.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
    stem.with_suffix(".txt").write_text(text_report)
    stem.with_suffix(".md").write_text(markdown)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
            summary.write(markdown + "\n")
    print(text_report)


if __name__ == "__main__":
    main()
