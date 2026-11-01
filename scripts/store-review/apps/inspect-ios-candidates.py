#!/usr/bin/env python3
"""Extend the public-version snapshot with all uploaded builds and draft versions."""
import json
import os
from pathlib import Path
import subprocess
import sys


def asc(*args):
    return json.loads(subprocess.check_output(["asc", *args, "--output", "json"]))


def rows(value):
    return value["data"] if isinstance(value, dict) else value


def main():
    bundle = os.environ["ASC_BUNDLE_ID"]
    apps = [a for a in rows(asc("apps", "list", "--bundle-id", bundle, "--paginate"))
            if a["attributes"]["bundleId"] == bundle]
    assert len(apps) == 1, "Expected exactly one app"
    app = apps[0]["id"]
    builds = rows(asc("builds", "list", "--app", app, "--platform", "IOS",
                      "--processing-state", "all", "--paginate"))
    uploads = rows(asc("builds", "uploads", "list", "--app", app,
                       "--platform", "IOS", "--paginate"))
    versions = rows(asc("versions", "list", "--app", app, "--platform", "IOS", "--paginate"))
    path = Path(sys.argv[1])
    state = json.loads(path.read_text())
    state.update(appId=app,
                 builds=[dict(id=b["id"], buildNumber=b["attributes"]["version"],
                              processingState=b["attributes"].get("processingState")) for b in builds],
                 uploads=[dict(id=u["id"], **u["attributes"]) for u in uploads],
                 versions=[dict(id=v["id"], version=v["attributes"]["versionString"],
                                state=v["attributes"].get("appVersionState") or v["attributes"].get("appStoreState")) for v in versions])
    path.write_text(json.dumps(state, indent=2) + "\n")


if __name__ == "__main__":
    main()
