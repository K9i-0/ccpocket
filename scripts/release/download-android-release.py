"""Download an existing Shorebird AAB without rebuilding its release baseline."""

import hashlib
import json
import os
from pathlib import Path
import re
import urllib.request


def main():
    version = os.environ["RELEASE_VERSION"]
    if not re.fullmatch(r"\d+\.\d+\.\d+\+\d+", version):
        raise SystemExit("Expected release version X.Y.Z+N")
    config = Path("apps/mobile/shorebird.yaml").read_text()
    app_id = re.search(r"^app_id: ([a-f0-9-]+)$", config, re.M).group(1)
    base = f"https://api.shorebird.dev/api/v1/apps/{app_id}/releases"

    def api(url):
        request = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {os.environ['SHOREBIRD_TOKEN']}"}
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)

    releases = [r for r in api(base)["releases"] if r["version"] == version]
    if len(releases) != 1:
        raise SystemExit("Expected exactly one matching Shorebird release")
    release_id = releases[0]["id"]
    artifacts = api(f"{base}/{release_id}/artifacts?arch=aab&platform=android")["artifacts"]
    if len(artifacts) != 1:
        raise SystemExit("Expected exactly one Android AAB")
    artifact = artifacts[0]
    if not artifact["url"].startswith("https://"):
        raise SystemExit("Artifact URL must use HTTPS")
    # The signed storage URL does not receive the Shorebird credential.
    output = Path("app-release.aab")
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(artifact["url"], timeout=120) as source, output.open("wb") as target:
        while chunk := source.read(1024 * 1024):
            target.write(chunk)
            digest.update(chunk)
            size += len(chunk)
    if size != artifact["size"] or digest.hexdigest() != artifact["hash"]:
        output.unlink()
        raise SystemExit("AAB checksum or size mismatch")
    print(f"Verified original AAB for {version}: {size} bytes")


if __name__ == "__main__":
    main()
