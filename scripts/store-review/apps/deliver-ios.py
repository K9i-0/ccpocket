#!/usr/bin/env python3
"""Upload the exact IPA and add only the requested Duo screenshot set."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


def asc(*args):
    return json.loads(subprocess.check_output(["asc", *args, "--output", "json"]))


def rows(value):
    return value["data"] if isinstance(value, dict) else value


def screenshot_set(localization):
    result = asc("screenshots", "list", "--version-localization", localization)
    sets = [s for s in result.get("sets", [])
            if s["set"]["attributes"]["screenshotDisplayType"] == "APP_IPHONE_DUO"]
    assert len(sets) <= 1, "Duplicate Duo sets"
    if not sets:
        return []
    return rows(asc("screenshots", "list", "--set-id", sets[0]["set"]["id"], "--paginate"))


def verify_screenshots(remote, files, complete=False):
    expected = [(f.name, hashlib.md5(f.read_bytes()).hexdigest()) for f in files]
    actual = [(r["attributes"]["fileName"], r["attributes"].get("sourceFileChecksum", "")) for r in remote]
    if len(actual) > len(expected) or any(name != expected[index][0] or (checksum and checksum != expected[index][1])
                                        for index, (name, checksum) in enumerate(actual)):
        raise ValueError("Existing Duo screenshots differ in content or order; refusing to replace them")
    if any(r["attributes"].get("assetDeliveryState", {}).get("state") == "FAILED" for r in remote):
        raise ValueError("Duo upload reservation failed; inspect asc screenshots resume before retrying")
    if complete:
        return actual == expected and all(r["attributes"].get("assetDeliveryState", {}).get("state") == "COMPLETE" for r in remote)
    return True


def main():
    env = os.environ
    root = Path(env["STORE_DELIVERY"])
    version, build = env["VERSION"], env["BUILD_NUMBER"]
    apps = [a for a in rows(asc("apps", "list", "--bundle-id", env["ASC_BUNDLE_ID"], "--paginate"))
            if a["attributes"]["bundleId"] == env["ASC_BUNDLE_ID"]]
    assert len(apps) == 1
    app = apps[0]["id"]
    existing = rows(asc("builds", "list", "--app", app, "--version", version,
                        "--build-number", build, "--platform", "IOS", "--processing-state", "all", "--paginate"))
    # Never silently reuse an existing number: use screenshots-only after verifying
    # the successful upload run if retrying a partially completed delivery.
    if env["DELIVERY_OPERATION"] == "upload":
        assert not existing, "Build already exists; verify previous upload before screenshots-only retry"
        asc("builds", "upload", "--app", app, "--ipa", str(root / "app.ipa"),
            "--version", version, "--build-number", build, "--wait")
        existing = rows(asc("builds", "list", "--app", app, "--version", version,
                            "--build-number", build, "--platform", "IOS", "--processing-state", "all", "--paginate"))
    else:
        assert len(existing) == 1 and existing[0]["attributes"]["processingState"] == "VALID", "Exact processed build required"
    assert len(existing) == 1 and existing[0]["attributes"]["processingState"] == "VALID", "Upload did not produce exact valid build"
    versions = rows(asc("versions", "list", "--app", app, "--version", version, "--platform", "IOS", "--paginate"))
    if not versions:
        created = asc("versions", "create", "--app", app, "--version", version,
                      "--platform", "IOS", "--release-type", env["STORE_RELEASE_TYPE"])
        version_id = created.get("id") or created["data"]["id"]
    else:
        assert len(versions) == 1
        version_id = versions[0]["id"]
    detail = asc("versions", "view", "--version-id", version_id, "--include-build")
    attrs = detail.get("data", {}).get("attributes", {})
    state = detail.get("state") or attrs.get("appVersionState") or attrs.get("appStoreState")
    attached = detail.get("buildId") or detail.get("data", {}).get("relationships", {}).get("build", {}).get("data")
    if isinstance(attached, dict):
        attached = attached.get("id")
    assert not attached or attached == existing[0]["id"], "Different build already attached"
    assert state in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"), "Version is not editable"
    localizations = {x["attributes"]["locale"]: x["id"] for x in rows(asc("localizations", "list", "--version", version_id, "--paginate"))}
    assert {"ja", "en-US"} <= set(localizations), "Missing existing localized metadata"
    for locale in ("en-US", "ja"):
        files = sorted((root / "screenshots" / locale).iterdir())
        for attempt in range(30):
            remote = screenshot_set(localizations[locale])
            verify_screenshots(remote, files)
            if all(r["attributes"].get("sourceFileChecksum") and r["attributes"].get("assetDeliveryState", {}).get("state") == "COMPLETE" for r in remote):
                break
            time.sleep(10)
        else:
            raise TimeoutError("Existing Duo reservations are still pending; inspect/resume the prior upload")
        asc("screenshots", "upload", "--version-localization", localizations[locale],
            "--path", str(root / "screenshots" / locale), "--device-type", "APP_IPHONE_DUO", "--skip-existing")
        for attempt in range(30):
            remote = screenshot_set(localizations[locale])
            if verify_screenshots(remote, files, complete=True):
                break
            if any(r["attributes"].get("assetDeliveryState", {}).get("state") == "FAILED" for r in remote):
                raise ValueError("Screenshot processing failed")
            time.sleep(10)
        else:
            raise TimeoutError("Duo screenshot processing did not complete")
        print(f"Verified {locale}: six Duo screenshots, ordered checksums match, COMPLETE")
    with open(env["GITHUB_STEP_SUMMARY"], "a") as output:
        output.write(f"\nIPA: {version}+{build}\n\nDuo: en-US and ja, six images each, hashes/order/COMPLETE verified.\n\nNo review submitted.\n")


if __name__ == "__main__":
    main()
