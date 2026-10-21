# Pages and Sparkle publishing

The docs and macOS release workflows share the `pages` concurrency group. Both
use `.github/actions/deploy-pages` and keep the lock until the public appcast
matches the uploaded bytes.

Each upload is named with the workflow run ID and attempt. Deployment uses the
upload's artifact ID directly and `artifact-<id>` as `pages_build_version`.
Do not replace this with a commit SHA: docs and macOS releases can publish
different artifacts from the same commit. GitHub can report success for a reused
deployment ID while continuing to serve the earlier content
([upstream issue](https://github.com/actions/deploy-pages/issues/383)).

The macOS release stores its signed `appcast.xml` as a GitHub Release asset before
publishing Pages. Docs deployments preserve the feed from the highest-build
published macOS release, not from the Pages CDN. A missing release asset fails
the docs deployment rather than silently restoring an older feed. The repository
copy is retained only if its build is newer than the release asset. For equal
build numbers, the release asset wins so a rebuilt DMG keeps its current signature.

After the Pages API succeeds, the shared action compares the public appcast with
the uploaded file for up to ten minutes. Failure remains a workflow failure.
The existing macOS release check also confirms the expected app version/build.

Regression coverage runs via `npm run test:release-tools` in the repository CI
job: distinct artifacts from the same commit, terminal deployment failures,
timeouts, stale public content, and network failures.

For 1.145.4+276, the signed feed was recovered from the original macOS workflow
artifact and published unchanged. No app rebuild or re-signing was needed.
