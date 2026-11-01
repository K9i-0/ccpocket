# T2QR / Bookmark Safe delivery

App repositories retain their source, local signing inputs and release tags. The
ccpocket hub retains its existing App Store Connect and Google Play credentials.
No private-repository token or signing key is copied to another repository.

1. Run the app's `scripts/store-review/dispatch.py inspect --platform both`.
   Inspection includes all iOS builds/upload attempts and Android uploaded codes
   and tracks, as well as the published version. Choose a larger build number.
2. Run the app's release skill: update notes/version, test, commit, build and
   verify signed artifacts, push main and the release tag, and confirm Test CI.
3. Run `scripts/store-review/apps/pack-delivery.py <app-root> --platform ios
   --output /tmp/delivery.zip` from the hub. The app's submit dry-run verifies
   clean main, remote tag/version and successful candidate CI; it does not submit.
   Android uses `--platform android`. Inspect the artifact signature locally first.
4. Create a **draft** GitHub release in `K9i-0/ccpocket` with the tag name
   `companion-staging/<app>/<version>+<build>/<candidate-sha-first-12>/<platform>`
   and upload `delivery.zip`. Keep it draft; never publish this transport release.
   Only the signed binary, final Duo screenshots and a manifest are transferred.
5. Dispatch `companion-store-delivery.yml` with app, platform, operation `upload`,
   version, build_number, candidate_sha, expected_ref_sha (hub main SHA),
   payload_release_id and payload_sha256. The hub validates the draft identity,
   archive SHA-256, exact file allowlist, per-file hashes and IPA identity before
   exposing store credentials to the upload step. Payload files are never executed.
6. Verify the run's inputs, workflow SHA, completion and summary. iOS uploads the
   exact IPA and checks processing; it creates the exact App Store version if
   absent, then adds six images to `APP_IPHONE_DUO` for each of en-US and ja.
   The order is cover 01–03 then inner 01–03. Filename, MD5, order and `COMPLETE`
   state are reread from Apple. Other display sets are unchanged. Android uploads
   only to internal as a draft and rereads the version code and draft state.
7. Submit using the application's existing `dispatch.py submit` after delivery
   success. T2QR iOS remains manual release; Bookmark Safe remains after approval.
   Production promotion/review is deliberately separate from delivery.

## Failure and compatibility

- Both workflows share per-app concurrency so inspect/delivery/submission do not
  overlap. A separate app can proceed independently.
- An existing build number stops upload; never assume an existing binary matches
  local bytes. If IPA upload succeeded but screenshots failed, verify the prior
  upload result and retry the same pinned payload with operation `screenshots`.
- Existing Duo images must be an exact ordered prefix of the requested images.
  Different content stops the run; no automatic deletion or replacement occurs.
- `asc` is pinned to 6.3.0 for companion operations because 4.9.2 lacks Duo.
  API uses a single `APP_IPHONE_DUO` set containing both cover and inner images.
- Google API cannot establish actual review/publication state or Managed
  publishing. Inspection continues to label those fields unknown. Internal
  delivery and production submission use `ERROR_IF_IN_REVIEW`.
- The hub cannot read the private app repositories. The local packer establishes
  candidate provenance; the hash-pinned manifest carries it across that boundary.
- Draft payload releases remain private transport records and are not app release
  announcements. Remove them only after completion when no retry needs them.
