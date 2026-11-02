#!/usr/bin/env python3
"""Upload the iPhone Duo screenshot set (APP_IPHONE_DUO) for one App Store version.

fastlane deliver does not know the iPhone Duo sizes, so the Duo cards live in
apps/mobile/fastlane/screenshots/store_duo/<locale>/ and are uploaded with asc.

For each locale directory, the remote APP_IPHONE_DUO set is compared with the
local files by file name, MD5 and order. An identical, fully processed set is
left alone; anything else is replaced (asc --replace --confirm) and then reread
until Apple reports every image COMPLETE with matching names and checksums.

Environment: ASC_ISSUER_ID / ASC_KEY_ID / ASC_PRIVATE_KEY (asc auth),
VERSION (X.Y.Z), optional ASC_BUNDLE_ID, DUO_SCREENSHOTS_DIR, DRY_RUN=true.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

DISPLAY_TYPE = "APP_IPHONE_DUO"
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIR = REPO_ROOT / "apps/mobile/fastlane/screenshots/store_duo"


def asc(*args):
    return json.loads(subprocess.check_output(["asc", *args, "--output", "json"]))


def rows(value):
    return value["data"] if isinstance(value, dict) else value


def local_files(directory):
    files = sorted(p for p in directory.iterdir() if p.suffix == ".png" and not p.name.startswith("."))
    if not files:
        raise SystemExit(f"No Duo screenshots in {directory}")
    return files


def expected(files):
    return [(f.name, hashlib.md5(f.read_bytes()).hexdigest()) for f in files]


def remote_set(localization_id):
    result = asc("screenshots", "list", "--version-localization", localization_id)
    sets = [s for s in result.get("sets", [])
            if s["set"]["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE]
    if len(sets) > 1:
        raise SystemExit(f"Duplicate {DISPLAY_TYPE} sets for localization {localization_id}")
    if not sets:
        return []
    return rows(asc("screenshots", "list", "--set-id", sets[0]["set"]["id"], "--paginate"))


def state(item):
    return item["attributes"].get("assetDeliveryState", {}).get("state")


def matches(remote, wanted, require_complete):
    actual = [(r["attributes"]["fileName"], r["attributes"].get("sourceFileChecksum") or "") for r in remote]
    if [name for name, _ in actual] != [name for name, _ in wanted]:
        return False
    if any(checksum and checksum != md5 for (_, checksum), (_, md5) in zip(actual, wanted)):
        return False
    if require_complete:
        return all(state(r) == "COMPLETE" and r["attributes"].get("sourceFileChecksum") for r in remote)
    return True


def main():
    env = os.environ
    version = env.get("VERSION", "")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise SystemExit("VERSION must use X.Y.Z")
    bundle_id = env.get("ASC_BUNDLE_ID", "com.k9i.ccpocket")
    root = Path(env.get("DUO_SCREENSHOTS_DIR", DEFAULT_DIR))
    dry_run = env.get("DRY_RUN") == "true"
    locales = sorted(p.name for p in root.iterdir() if p.is_dir())
    if not locales:
        raise SystemExit(f"No locale directories in {root}")

    apps = [a for a in rows(asc("apps", "list", "--bundle-id", bundle_id, "--paginate"))
            if a["attributes"]["bundleId"] == bundle_id]
    if len(apps) != 1:
        raise SystemExit(f"Expected exactly one app for {bundle_id}, found {len(apps)}")
    app_id = apps[0]["id"]
    versions = [v for v in rows(asc("versions", "list", "--app", app_id, "--version", version,
                                    "--platform", "IOS", "--paginate"))
                if v["attributes"].get("versionString") == version]
    if len(versions) != 1:
        raise SystemExit(f"Expected exactly one iOS App Store version {version}, found {len(versions)}")
    version_id = versions[0]["id"]
    localizations = {x["attributes"]["locale"]: x["id"]
                     for x in rows(asc("localizations", "list", "--version", version_id, "--paginate"))}
    missing = [locale for locale in locales if locale not in localizations]
    if missing:
        raise SystemExit(f"Version {version} has no localization for {', '.join(missing)}")

    summary = []
    for locale in locales:
        files = local_files(root / locale)
        wanted = expected(files)
        localization_id = localizations[locale]
        if matches(remote_set(localization_id), wanted, require_complete=True):
            print(f"{locale}: {len(files)} Duo screenshots already match; unchanged")
            summary.append(f"{locale}: unchanged ({len(files)})")
            continue
        if dry_run:
            print(f"{locale}: would replace the {DISPLAY_TYPE} set with {len(files)} screenshots")
            summary.append(f"{locale}: would replace ({len(files)})")
            continue
        print(f"{locale}: replacing the {DISPLAY_TYPE} set with {len(files)} screenshots")
        subprocess.check_call(["asc", "screenshots", "upload", "--version-localization", localization_id,
                               "--path", str(root / locale), "--device-type", DISPLAY_TYPE,
                               "--replace", "--confirm", "--output", "json"], stdout=subprocess.DEVNULL)
        for _ in range(60):
            remote = remote_set(localization_id)
            if any(state(r) == "FAILED" for r in remote):
                raise SystemExit(f"{locale}: Apple reported a failed Duo screenshot; inspect before retrying")
            if matches(remote, wanted, require_complete=True):
                break
            time.sleep(10)
        else:
            raise SystemExit(f"{locale}: Duo screenshots did not finish processing")
        print(f"{locale}: verified {len(files)} Duo screenshots (order, checksums, COMPLETE)")
        summary.append(f"{locale}: replaced ({len(files)})")

    if env.get("GITHUB_STEP_SUMMARY"):
        with open(env["GITHUB_STEP_SUMMARY"], "a") as output:
            output.write(f"\n### iPhone Duo screenshots ({version})\n\n")
            output.writelines(f"- {line}\n" for line in summary)


if __name__ == "__main__":
    sys.exit(main())
