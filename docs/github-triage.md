# GitHub Triage in ccpocket

Status: design (not implemented)

## Goal

Finish the `/triage` loop inside ccpocket instead of opening github.com to
look up Issue / PR numbers.

Observed usage of `/triage` (2026-11) always follows one loop:

1. pick items (`/triage 327`, "今日来たIssueをチェック", "dependabotのPR全部")
2. hand them to an agent with an intent (merge, review only, close resolved)
3. optionally continue to a release ("リリースして", "そのままリリースもして")

ccpocket covers that loop only. It is not a general GitHub client.

## Decisions

| Topic | Decision | Reason |
|---|---|---|
| Data source | `gh` CLI on the Bridge host | Already authenticated for the triage skill; no token in the app |
| Entry point | Separate project-level screen next to the Git screen | Usable without an open session |
| Write actions | None from the app | Merge, comment, close, and label changes are done by the agent under the triage skill rules |

## Bridge

- Repository: `rootPaths[0]` of the workspace project → `git remote get-url origin`
  → normalized with `repository-root.ts`. A non-GitHub remote returns a
  `not_github` state.
- Read-only `gh` calls with `--json`:
  - PRs: `number,title,author,isDraft,labels,createdAt,updatedAt,statusCheckRollup,url`
  - Issues: `number,title,author,labels,createdAt,updatedAt,url`
  - Detail: body plus the latest comments
- `doctor`: checks that `gh` exists and `gh auth status` succeeds.
- Errors are typed (`gh_missing`, `gh_unauthenticated`, `not_github`, `failed`)
  so the app can show actionable guidance.

### Protocol

New client messages, both answered with a request-correlated response:

- `github_list { projectPath, kind: "pr" | "issue", state: "open" }`
- `github_item { projectPath, kind, number }`

Compatibility: an older Bridge answers `unsupported_message`. The GitHub screen
waits for these responses directly, so it shows the Bridge update guidance
inside the screen (not through chat `_unsupportedActions`).

## App

- Tabs: Issues / PRs. Results are cached per project like
  `git_view_cache_service`, with pull-to-refresh.
- PR row: number, title, author, Draft badge, dependabot marker, CI state.
- Issue row: number, title, labels, created time.
- Filters: hide drafts, dependabot only, label.
- Tapping a row shows the detail and offers opening it on GitHub.
- Long press starts multi-select. "Select all" skips drafts by default; drafts
  can still be selected one by one.
- "Request triage" opens a sheet with presets plus free text, provider, and
  effort:
  - investigate and merge (skill default for PRs)
  - handle and release
  - content only / review only
  - check if resolved, comment, and close
- Sending starts a new session in the project through `NewSessionSheet`'s
  `initialPrompt`, for example `/triage 327 332 対応してリリースまで`.
  `skill_invocation.dart` rewrites it to `$triage` for Codex
  (`.agents/skills` links to `.claude/skills`).

## Triage skill change

Accept several numbers explicitly (`/triage 327 332 ...`) and process them one
by one under the existing per-item rules, then report a combined result.

## Non-goals

Notifications or badges for new items, review comments, closed-item history,
external repository search, and write actions from the app.

## Verification

- Bridge: vitest for the `gh` wrapper using fixture JSON (no network), error
  mapping, and the request validation in `parser.ts`.
- App: cubit unit tests, an `unsupported_message` test, `dart analyze`,
  `dart format`, and a mock scenario in `mock_scenarios.dart`.
- UI: one Marionette run of list → multi-select → preset → the session starts
  with the expected first message.
