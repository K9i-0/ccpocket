# Pages and Sparkle publishing

Only `pages.yml` deploys the site, using the `pages` concurrency group. The macOS
release dispatches that workflow on main and waits for its exact correlated run.
The shared action keeps the Pages lock until the public appcast matches the
uploaded bytes. The dispatching macOS job must not hold the Pages lock.

Each upload is named with the workflow run ID and attempt; the official deploy
action receives that exact name. Never deploy directly from the macOS tag job:
GitHub can report success while continuing to serve earlier content. Dispatching
the main-branch workflow is the upstream workaround
([issue and reproductions](https://github.com/actions/deploy-pages/issues/383)).
The API also rejects arbitrary `pages_build_version` strings with 404, so we use
the official deployment action instead of replacing the build version.

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
job: exact dispatch correlation, failed/cancelled/skipped publications, missing
runs, stale public content, and network failures.

For 1.145.4+276, the signed feed was recovered from the original macOS workflow
artifact and published unchanged. No app rebuild or re-signing was needed.
