#!/usr/bin/env python3
"""Validate and unpack a hash-pinned delivery from a private draft release.

No application source or executable from the payload is run in the secret job.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import zipfile

from prepare import APPS


def validate_manifest(manifest, env):
    for key, variable in [("app", "TARGET_APP"), ("version", "VERSION"),
                          ("build", "BUILD_NUMBER"), ("candidate", "CANDIDATE_SHA"),
                          ("platform", "PLATFORM")]:
        if manifest.get(key) != env[variable]:
            raise ValueError(f"Payload {key} mismatch")
    expected = {"app.ipa"} if env["PLATFORM"] == "ios" else {"app.aab"}
    if env["PLATFORM"] == "ios":
        suffix = "png" if env["TARGET_APP"] == "T2QR" else "jpg"
        for locale in ("en-US", "ja"):
            for display in ("inner", "cover"):
                for index in range(1, 4):
                    expected.add(f"screenshots/{locale}/{display}-{index:02}.{suffix}")
    files = manifest.get("files", {})
    if set(files) != expected or any(not re.fullmatch(r"[0-9a-f]{64}", v) for v in files.values()):
        raise ValueError("Unexpected payload files or hashes")
    return expected


def extract(archive, destination, env):
    with zipfile.ZipFile(archive) as payload:
        names = payload.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP paths")
        manifest = json.loads(payload.read("manifest.json"))
        expected = validate_manifest(manifest, env)
        if set(names) != expected | {"manifest.json"}:
            raise ValueError("Unexpected ZIP members")
        if any(i.file_size > 1024**3 or (i.external_attr >> 16) & 0o170000 == 0o120000 for i in payload.infolist()):
            raise ValueError("Oversized file or symlink")
        destination.mkdir(parents=True, exist_ok=False)
        for name in sorted(expected):
            content = payload.read(name)
            if hashlib.sha256(content).hexdigest() != manifest["files"][name]:
                raise ValueError(f"File hash mismatch: {name}")
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
    if env["PLATFORM"] == "ios":
        with zipfile.ZipFile(destination / "app.ipa") as ipa:
            plists = [n for n in ipa.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info.plist", n)]
            if len(plists) != 1:
                raise ValueError("Expected one IPA application")
            info = plistlib.loads(ipa.read(plists[0]))
            if (info.get("CFBundleIdentifier"), info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")) != (APPS[env["TARGET_APP"]][0], env["VERSION"], env["BUILD_NUMBER"]):
                raise ValueError("IPA identity mismatch")
    return manifest


def main():
    env = os.environ
    assert env["TARGET_APP"] in APPS
    assert env["PLATFORM"] in ("ios", "android")
    assert env["DELIVERY_OPERATION"] in ("upload", "screenshots")
    assert env["PLATFORM"] == "ios" or env["DELIVERY_OPERATION"] == "upload"
    assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", env["VERSION"])
    assert re.fullmatch(r"[1-9][0-9]*", env["BUILD_NUMBER"])
    assert re.fullmatch(r"[0-9a-f]{40}", env["CANDIDATE_SHA"])
    assert re.fullmatch(r"[0-9a-f]{40}", env["EXPECTED_REF_SHA"])
    assert env["GITHUB_SHA"] == env["EXPECTED_REF_SHA"], "Workflow ref moved"
    assert re.fullmatch(r"[1-9][0-9]*", env["PAYLOAD_RELEASE_ID"])
    assert re.fullmatch(r"[0-9a-f]{64}", env["PAYLOAD_SHA256"])
    repo = env["GITHUB_REPOSITORY"]
    release = json.loads(subprocess.check_output(["gh", "api", f"repos/{repo}/releases/{env['PAYLOAD_RELEASE_ID']}"]))
    tag = f"companion-staging/{env['TARGET_APP']}/{env['VERSION']}+{env['BUILD_NUMBER']}/{env['CANDIDATE_SHA'][:12]}/{env['PLATFORM']}"
    assert release["draft"] and release["tag_name"] == tag, "Expected matching private draft release"
    assets = [a for a in release["assets"] if a["name"] == "delivery.zip"]
    assert len(assets) == 1 and assets[0]["size"] <= 1024**3, "Expected one bounded delivery asset"
    archive = Path(env["RUNNER_TEMP"]) / "delivery.zip"
    with archive.open("wb") as output:
        subprocess.run(["gh", "api", f"repos/{repo}/releases/assets/{assets[0]['id']}",
                        "-H", "Accept: application/octet-stream"], stdout=output, check=True)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == env["PAYLOAD_SHA256"], "Payload hash mismatch"
    destination = Path(env["RUNNER_TEMP"]) / "companion-delivery"
    extract(archive, destination, env)
    with open(env["GITHUB_ENV"], "a") as output:
        output.write(f"STORE_DELIVERY={destination}\nASC_BUNDLE_ID={APPS[env['TARGET_APP']][0]}\n")
        output.write(f"STORE_BUNDLE_ID={APPS[env['TARGET_APP']][0]}\nSTORE_RELEASE_TYPE={APPS[env['TARGET_APP']][1]}\n")


if __name__ == "__main__":
    main()
