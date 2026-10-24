#!/usr/bin/env python3
"""Update only what's-new; refuse missing locales or locked-version differences."""
import json
import os
import subprocess
import sys

version_id, state = sys.argv[1:]
notes = json.load(open(os.environ["STORE_IOS_NOTES"], encoding="utf-8"))
result = json.loads(subprocess.check_output([
    "asc", "localizations", "list", "--version", version_id, "--paginate", "--output", "json"
]))
items = result["data"] if isinstance(result, dict) else result
by_locale = {item["attributes"]["locale"]: item for item in items}
if not set(notes).issubset(by_locale):
    raise SystemExit("Missing existing English/Japanese localization; complete store metadata first")
changes = [(locale, text) for locale, text in notes.items()
           if by_locale[locale]["attributes"].get("whatsNew", "") != text]
if changes and state == "READY_FOR_REVIEW":
    raise SystemExit("Ready review has different notes; refusing to alter or cancel the submission")
for locale, text in changes:
    subprocess.run(["asc", "localizations", "update", "--version", version_id,
                    "--locale", locale, "--whats-new", text, "--output", "table"], check=True)
