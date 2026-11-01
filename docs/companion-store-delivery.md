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
   Android uses `--platform android`. Inspect the artifact signature locally first. If the local keychain is unavailable, build with `flutter build ipa --no-codesign` (and the app's usual release/flavor flags), then package using `--unsigned-archive`. The macOS delivery job exports the archive using the hub's existing signing key and certificate, reusing or creating the required profiles and verifies the signed app and extension before upload. It never creates keys, certificates or bundle IDs, and never revokes signing resources.
4. Create a **draft** GitHub release in `K9i-0/ccpocket` with the tag name
   `companion-staging/<app>/<version>+<build>/<candidate-sha-first-12>/<platform>`
   and upload `delivery.zip`. Keep it draft; never publish this transport release.
   Only the signed binary (or unsigned archive for CI signing), final Duo screenshots and a manifest are transferred.
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

CI signing uses pinned codemagic-cli-tools 0.70.2 through `fetch-signing.py`. It allows creation of missing App Store profiles but explicitly disables certificate and bundle-ID creation. A missing certificate matching the existing CI key is a blocker; credentials are never sent back to the Mac. Archive extraction rejects symlinks, traversal and oversized payloads. Only binaries and metadata are accepted, and app code is not executed by the signing job.

## Lessons verified on 2026-11-01

- Draft release downloads require `contents: write`; `contents: read` returned 403 even though the job only downloaded the asset. Keep the existing delivery permission and pass the token only to the validating download step. Checkout must retain `persist-credentials: false`; do not publish the draft or introduce a PAT to work around this.
- Local keychain identities being visible does not prove codesign can use them. T2QR hit `errSecInternalComponent`; unsigned archives exported and verified successfully on macos-26 with the hub's existing signing key. Preserve each app's release/flavor flags when building unsigned archives.
- A matching existing CI certificate can lack matching app/extension profiles. `fetch-signing.py` permits missing profile creation, blocks certificate/bundle-ID creation, and verifies the exact app/extension identifier set before mutation. Do not replace it with unrestricted `fetch-signing-files --create` or delete stale profiles as a retry.
- asc 6.3 returns nested `versions view` data; shared inspection/submission scripts retain compatibility with older flattened data. `review submit --build` was removed in 5.0: companion review sets `ASC_REVIEW_BUILD_FLAG=--build-id`, while legacy callers retain their default. When changing asc pins, inspect command help and response shapes for both inspection and mutation paths; an inspection-only test misses submission flag changes.
- Duo uses one `APP_IPHONE_DUO` set per locale, including cover and inner images. T2QR PNGs needed opaque output (`-background white -alpha remove -alpha off`). Verify final images, not only generator inputs; the uploader checks filenames, checksums, order and COMPLETE state.
- Google bundle upload uses the authenticated API client directly; calling Supply helpers without initialized `Supply.config` failed. Retain the direct upload path and verify the resulting internal draft before submission.
- Both successful iOS deliveries took several minutes in upload/processing/image verification. Inspect the active step and completion rather than canceling or redispatching a pending run. After a partial failure, retry only the unfinished stage with the original candidate/payload; never treat an existing build number as proof of identical binary content.

Verified submissions: [T2QR iOS](https://github.com/K9i-0/ccpocket/actions/runs/41273125006), [T2QR Android](https://github.com/K9i-0/ccpocket/actions/runs/41272105800), [Bookmark Safe both platforms](https://github.com/K9i-0/ccpocket/actions/runs/41273136582). Both iOS runs confirmed WAITING_FOR_REVIEW; Android runs committed production changes for review. These are historical results, not current store status.
