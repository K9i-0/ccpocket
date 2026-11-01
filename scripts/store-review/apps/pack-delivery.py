#!/usr/bin/env python3
"""Package local verified artifacts; never read signing credentials.

The application dispatch dry-run verifies main, remote release tags and Test CI.
The generated ZIP is staged as a draft release in the credential-owning hub.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--platform", choices=("ios", "android"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    validated = json.loads(subprocess.check_output([
        "python3", "scripts/store-review/dispatch.py", "submit", "--platform", args.platform, "--dry-run"
    ], cwd=root))['inputs']
    app = validated["app"]
    assert app in ("T2QR", "Bookmark-Safe")
    if args.platform == "ios":
        artifact = root / "build/ios/ipa" / ("T2QR.ipa" if app == "T2QR" else "Bookmark Safe.ipa")
        files = {"app.ipa": artifact}
        suffix = "png" if app == "T2QR" else "jpg"
        for locale in ("en-US", "ja"):
            for display in ("inner", "cover"):
                images = sorted((root / "store/screenshots/ios/duo" / locale).glob(f"{display}-*.{suffix}"))
                assert len(images) == 3
                for index, image in enumerate(images, 1):
                    dimensions, channels, *_ = subprocess.check_output([
                        "magick", "identify", "-format", "%wx%h %[channels]", str(image)
                    ], text=True).split()
                    assert dimensions in ({"2007x2853", "2853x2007"} if display == "inner" else {"1398x2034", "2034x1398"})
                    assert "a" not in channels.lower(), "Alpha channel is not accepted by App Store Connect"
                    files[f"screenshots/{locale}/{display}-{index:02}.{suffix}"] = image
    else:
        files = {"app.aab": root / "build/app/outputs/bundle/release/app-release.aab"}
    manifest = dict(app=app, platform=args.platform, version=validated["version"],
                    build=validated["build_number"], candidate=validated["candidate_sha"],
                    files={name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in files.items()})
    with zipfile.ZipFile(args.output, "x", compression=zipfile.ZIP_STORED) as archive:
        archive.writestr("manifest.json", json.dumps(manifest))
        for name, path in files.items():
            archive.write(path, name)
    print(json.dumps(dict(manifest=manifest, payload_sha256=hashlib.sha256(args.output.read_bytes()).hexdigest()), indent=2))


if __name__ == "__main__":
    main()
