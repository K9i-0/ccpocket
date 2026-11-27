#!/usr/bin/env python3
"""Validate a release tag before running checks or requesting publish credentials."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

PACKAGES = {'markdown_kit': '.'}


def validate(tag):
    package, separator, version = tag.rpartition("-v")
    if not separator or package not in PACKAGES:
        raise ValueError("Expected a package-v<version> tag for this repository")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)*", version):
        raise ValueError("Invalid release version")
    directory = Path(PACKAGES[package])
    match = re.search(r"^version:\s*([^\s#]+)", (directory / "pubspec.yaml").read_text(), re.M)
    actual = match.group(1).strip("\"'") if match else None
    if actual != version:
        raise ValueError(f"Tag version {version} differs from pubspec version {actual}")
    changelog = (directory / "CHANGELOG.md").read_text()
    if not re.search(r"^## " + re.escape(version) + r"\s*$", changelog, re.M):
        raise ValueError(f"CHANGELOG.md needs a '## {version}' section")
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", "HEAD", "origin/main"],
        check=False,
    )
    if result.returncode != 0:
        raise ValueError("The tagged commit must already be on origin/main")
    return {"package": package, "version": version, "dir": str(directory)}


if __name__ == "__main__":
    try:
        result = validate(sys.argv[1] if len(sys.argv) == 2 else os.environ["TAG"])
    except (KeyError, OSError, ValueError) as error:
        sys.exit(str(error))
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a", encoding="utf-8") as file:
            for key, value in result.items():
                file.write(f"{key}={value}\n")
    print(json.dumps(result))
