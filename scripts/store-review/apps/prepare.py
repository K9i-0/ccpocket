#!/usr/bin/env python3
"""Validate dispatch data without loading code from the application repositories."""
import json
import os
from pathlib import Path
import re

APPS = {
    "T2QR": ("com.kotahayashi.t2qr", "MANUAL"),
    "Bookmark-Safe": ("com.k9i.b72", "AFTER_APPROVAL"),
}


def validate(env):
    app = env["TARGET_APP"]
    bundle, release_type = APPS[app]
    operation = env["OPERATION"]
    platform = env["PLATFORM"]
    assert operation in ("inspect", "submit"), "Invalid operation"
    assert platform in ("ios", "android", "both"), "Invalid platform"
    assert re.fullmatch(r"[0-9a-f]{40}", env["EXPECTED_REF_SHA"]), "Invalid workflow SHA"
    assert env["GITHUB_SHA"] == env["EXPECTED_REF_SHA"], "Workflow ref moved"
    notes = {}
    if operation == "submit":
        version, build = env["VERSION"], env["BUILD_NUMBER"]
        assert re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version), "Invalid version"
        assert re.fullmatch(r"[1-9][0-9]*", build), "Invalid build"
        assert re.fullmatch(r"[0-9a-f]{40}", env["CANDIDATE_SHA"]), "Invalid candidate SHA"
        assert env["CONFIRMATION"] == f"SUBMIT {app} {version}+{build}", "Confirmation mismatch"
        notes = json.loads(env["RELEASE_NOTES_JSON"])
        targets = ("ios", "android") if platform == "both" else (platform,)
        assert set(notes) == set(targets), "Notes must match selected platforms"
        for target in targets:
            locales = {"en-US", "ja" if target == "ios" else "ja-JP"}
            assert isinstance(notes[target], dict) and set(notes[target]) == locales, "Expected English/Japanese notes"
            for value in notes[target].values():
                assert isinstance(value, str) and value.strip(), "Empty notes"
                assert len(value) <= (4000 if target == "ios" else 500), "Notes too long"
                assert "\x00" not in value, "Invalid note character"
    return bundle, release_type, notes


def main():
    bundle, release_type, notes = validate(os.environ)
    root = Path(os.environ["RUNNER_TEMP"]) / "store-review"
    root.mkdir(parents=True, exist_ok=True)
    (root / "ios-notes.json").write_text(json.dumps(notes.get("ios", {}), ensure_ascii=False))
    for locale, value in notes.get("android", {}).items():
        path = root / "android" / locale / "changelogs" / (os.environ["BUILD_NUMBER"] + ".txt")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write(f"ASC_BUNDLE_ID={bundle}\nSTORE_BUNDLE_ID={bundle}\n")
        output.write(f"STORE_RELEASE_TYPE={release_type}\nSTORE_ANDROID_METADATA={root / 'android'}\n")
        output.write(f"STORE_IOS_NOTES={root / 'ios-notes.json'}\n")


if __name__ == "__main__":
    main()
