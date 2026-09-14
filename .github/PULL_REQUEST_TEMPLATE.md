## Summary

<!-- What does this PR do? Keep it brief and describe the user-visible outcome. -->

## Why This Is A PR

<!--
For non-trivial changes, open a Prompt Request or Issue first.
Write "None — <reason>" only for a small, self-contained change.
Maintainer-authored PRs up to 50 files may instead document their scope decision here.
-->

- Related Issue / Prompt Request: <!-- Link or "None — <reason>" -->
- Why this is ready for PR review:

## Changes

<!-- List only changes needed for the primary goal. Omit unrelated refactors and speculative additions. -->

-

## Scope Check

<!-- One user-visible goal per PR. PRs over 150 changed files are closed. -->

- Single primary goal:
- Intentionally out of scope:
- Split plan or why this cannot be split:

## Test Evidence

<!--
Run the checks for each changed area before submitting:
https://github.com/K9i-0/ccpocket/blob/main/docs/development-testing.md#before-opening-a-pr
Bridge changes need the full Bridge test suite, type check, and build; a targeted
test alone is not sufficient. Name any checks not run and explain why.
Include exact commands and actual results. Bug fixes need a regression test or
reproducible before/after validation when automation is impractical.
Write "N/A — <reason>" when validation does not apply.
For <=10-file low-risk PRs, supporting context and manual/platform fields are
advisory; UI and OS-dependent changes still require their relevant evidence.
-->

- Automated tests (command and result):
- Manual validation:
- Target platform and version:

## Risk and Rollback

<!-- Select exactly one risk level. -->

- [ ] Low
- [ ] Medium
- [ ] High
- Main risks:
- Rollback plan:

## UI Evidence

<!--
Select exactly one option.
Text-only changes may use automated UI test evidence instead of an image. Include
a backticked `flutter test ...` command and its explicit successful result.
For visual or interaction changes, upload images directly to GitHub. An After
image or recording is required. Before may be "N/A — <reason>" only for a new UI.
-->

- [ ] No user-visible UI change
- [ ] User-visible text-only change
- [ ] Visual or interaction UI change
- No-visual-change reason:
- Before:
- After:
- Device / platform:

## Author Checklist

<!--
Address CI and CodeRabbit findings before requesting maintainer review.
After handoff, maintainers may finish bounded fixes themselves and merge with
attribution, or decline if the integration cost outweighs the value.
-->

- [ ] I reviewed the complete diff and can explain and maintain this change.
- [ ] This PR contains no unrelated changes.
- [ ] User-facing or breaking changes are documented, or documentation is not applicable.
