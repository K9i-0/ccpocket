# T2QR / Bookmark-Safe store submission

`companion-store-review.yml` runs read-only inspection or submits an already
uploaded exact version/build. T2QR and Bookmark-Safe invoke it from their
`scripts/store-review/dispatch.py` helpers. No browser or local keychain is
needed for submission. Binary signing/upload remains the release workflow's
responsibility; missing binaries are not rebuilt by submission.

Credentials remain in ccpocket's existing GitHub Secrets and `store-review`
environment. The workflow does not create keys, grant permissions, or copy
credentials to the other repositories. Existing Apple/Google app permissions
must cover the selected app; inspection verifies that before submission.

The allowlist fixes bundle IDs and existing release policies:

| App | Bundle/package | iOS policy | Android |
| --- | --- | --- | --- |
| T2QR | com.kotahayashi.t2qr | MANUAL | completed (100%) |
| Bookmark-Safe | com.k9i.b72 | AFTER_APPROVAL | completed (100%) |

Managed publishing, countries, pricing, privacy and IAP configuration are not
changed. Google production track status is not evidence of review/publication
state under Managed Publishing. Inspection explicitly reports those as unknown.

## Trust boundary

Both application repositories are private. The local helper verifies clean main,
remote main/tag SHA, tag pubspec version and the candidate's successful Test run
using the caller's existing `gh` authentication. It sends only version/build,
candidate SHA and bounded English/Japanese notes. The hub does not have access
to source or independently attest that candidate SHA. The invoking agent must
also verify signed release/upload evidence and the cumulative release notes;
do not bypass the helper to submit an unverified candidate.

Hub input is data only: no shell interpolation, dynamic repository, action, file
path, arbitrary locale or executable source. The hub checks its own immutable
workflow SHA before any credential-bearing step. Run identity includes app,
operation, platform and version; the caller additionally checks headSha and
dispatch time. Per-app serialization preserves other ongoing operations.

## Mutations and retry

iOS reuses the ccpocket submission implementation with an optional notes hook.
The hook is absent for ccpocket's existing workflow. Companion submissions update
only existing en-US/ja What's New fields after checking build identity and
already-submitted state. A ready submission with differing notes fails without
cancelling review. Missing metadata/agreements remain explicit blockers.

Android promotes only a single exact internal versionCode, uploads only its
changelogs and commits with `ERROR_IF_IN_REVIEW`. A production version already
present fails without mutation, requiring verification of the previous run.
This avoids claiming idempotent success when Google's API cannot prove review
submission. No fallback silently changes `changes_not_sent_for_review`.

## Validation

Run `actionlint .github/workflows/companion-store-review.yml`, the Python tests
and `ruby scripts/store-review/apps/test_commit.rb`. Use operation `inspect`
against both apps to verify credentials; it never uploads metadata or submits.
Application-facing skill changes require no Flutter rebuild.
