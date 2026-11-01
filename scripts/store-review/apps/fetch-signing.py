#!/usr/bin/env python3
"""Fetch signing resources, allowing profiles but never new keys/certificates/IDs."""
import os
from codemagic.tools import AppStoreConnect


def forbid_creation(*args, **kwargs):
    raise RuntimeError("Existing bundle IDs and signing certificate are required; creation is disabled")


AppStoreConnect.create_certificate = forbid_creation
AppStoreConnect.create_bundle_id = forbid_creation
original_bundle_lookup = AppStoreConnect._get_or_create_bundle_ids


def checked_bundle_lookup(self, *args, **kwargs):
    bundles = original_bundle_lookup(self, *args, **kwargs)
    expected = {
        "T2QR": {"com.kotahayashi.t2qr", "com.kotahayashi.t2qr.Share-Extension"},
        "Bookmark-Safe": {"com.k9i.b72", "com.k9i.b72.MyShareExtension"},
    }[os.environ["TARGET_APP"]]
    if {b.attributes.identifier for b in bundles} != expected:
        raise RuntimeError("Bundle lookup must match exactly the expected app and extension")
    return bundles


AppStoreConnect._get_or_create_bundle_ids = checked_bundle_lookup

if __name__ == "__main__":
    AppStoreConnect.invoke_cli()
