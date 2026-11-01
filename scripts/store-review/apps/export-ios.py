#!/usr/bin/env python3
"""Export an unsigned archive using only preexisting CI signing resources."""
import datetime
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile


def main():
    root = Path(os.environ["STORE_DELIVERY"])
    archive = root / "Runner.xcarchive"
    apps = list((archive / "Products/Applications").glob("*.app"))
    assert len(apps) == 1
    bundles = [apps[0], *apps[0].glob("PlugIns/*.appex")]
    expected_extension = {"T2QR": "com.kotahayashi.t2qr.Share-Extension", "Bookmark-Safe": "com.k9i.b72.MyShareExtension"}[os.environ["TARGET_APP"]]
    identities = {plistlib.loads((b / "Info.plist").read_bytes())["CFBundleIdentifier"] for b in bundles}
    assert identities == {os.environ["STORE_BUNDLE_ID"], expected_extension}, "Unexpected app/extension identity"
    profiles = []
    profile_dir = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
    for path in profile_dir.glob("*.mobileprovision"):
        data = plistlib.loads(subprocess.check_output(["security", "cms", "-D", "-i", str(path)], stderr=subprocess.DEVNULL))
        if data["ExpirationDate"] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None) and not data.get("ProvisionedDevices") and not data["Entitlements"].get("get-task-allow", False):
            profiles.append(data)
    mapping, teams = {}, set()
    for bundle in identities:
        matching = [p for p in profiles if p["Entitlements"].get("application-identifier") == p["TeamIdentifier"][0] + "." + bundle]
        assert matching, f"No existing App Store profile for {bundle} matching the CI certificate"
        profile = max(matching, key=lambda p: p["ExpirationDate"])
        mapping[bundle] = profile["UUID"]
        teams.add(profile["TeamIdentifier"][0])
    assert len(teams) == 1
    options = dict(method="app-store-connect", signingStyle="manual", teamID=teams.pop(),
                   signingCertificate="Apple Distribution", provisioningProfiles=mapping,
                   manageAppVersionAndBuildNumber=False, uploadSymbols=True, stripSwiftSymbols=True)
    options_path = root / "ExportOptions.plist"
    options_path.write_bytes(plistlib.dumps(options))
    subprocess.run(["xcodebuild", "-exportArchive", "-archivePath", str(archive),
                    "-exportPath", str(root / "export"), "-exportOptionsPlist", str(options_path)], check=True)
    ipas = list((root / "export").glob("*.ipa"))
    assert len(ipas) == 1
    shutil.copyfile(ipas[0], root / "app.ipa")
    with zipfile.ZipFile(root / "app.ipa") as ipa:
        ipa.extractall(root / "signed")
    signed_app = next((root / "signed/Payload").glob("*.app"))
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(signed_app)], check=True)
    for bundle in [signed_app, *signed_app.glob("PlugIns/*.appex")]:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        assert info["CFBundleIdentifier"] in identities
        assert info["CFBundleShortVersionString"] == os.environ["VERSION"]
        assert info["CFBundleVersion"] == os.environ["BUILD_NUMBER"]
    print("Exported and verified signed IPA and share extension")


if __name__ == "__main__":
    main()
