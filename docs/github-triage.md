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

New client messages. `requestId` is required; the Bridge echoes `requestId`
and `projectPath` on success and on failure (see `request-correlation.md`).
Only open items are listed (up to 100, newest first).

```ts
// client → Bridge
{ type: "github_list"; projectPath: string; kind: "pr" | "issue"; requestId: string }
{ type: "github_item"; projectPath: string; kind: "pr" | "issue"; number: number; requestId: string }

// Bridge → client
{ type: "github_list_result"; requestId: string; projectPath: string; kind: "pr" | "issue";
  repository?: string;            // "owner/name"
  items?: GitHubItemSummary[];
  error?: GitHubError }
{ type: "github_item_result"; requestId: string; projectPath: string; kind: "pr" | "issue";
  number: number;
  item?: GitHubItemDetail;
  error?: GitHubError }

interface GitHubAuthor { login: string; isBot: boolean } // "app/" prefix stripped
interface GitHubItemSummary {
  number: number;
  title: string;
  url: string;
  author: GitHubAuthor;
  labels: string[];
  createdAt: string;              // ISO 8601
  updatedAt: string;
  isDraft?: boolean;              // PR only
  checks?: "success" | "failure" | "pending" | "none"; // PR only, from statusCheckRollup
}
interface GitHubItemDetail extends GitHubItemSummary {
  body: string;
  comments: { author: GitHubAuthor; body: string; createdAt: string }[]; // latest 20, oldest first
}
interface GitHubError {
  code: "gh_missing" | "gh_unauthenticated" | "not_github" | "failed";
  message: string;
}
```

A dependabot item is `author.isBot && author.login.startsWith("dependabot")`.

Bridge implementation notes (`packages/bridge/src/github-cli.ts`):

- A `projectPath` outside the allowed directories answers with `failed`.
- An item that does not exist, a timeout, and an unparseable `gh` response
  answer with `failed` and a one-line message.
- `gh` returns no `is_bot` for comment authors, so `comments[].author.isBot`
  is true only for an `app/` or `[bot]` login. The item author is reliable.

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

### Entry from an empty chat

The chat screen also shows an "Issues / PRs" button for the session's project,
only while the user has sent no message in that session.

- Hidden as soon as a user message exists, including a queued or pending one.
  Assistant-only or system entries do not hide it.
- Shown for both Claude and Codex sessions. A non-GitHub project or an older
  Bridge is handled inside the screen, so the button does not call the Bridge.
- Opened from a chat, the request sheet sends `/triage ...` as the first
  message of that session instead of starting a new one. Provider and effort
  are not shown because the session already fixes them.
- On wide layouts it opens as a workspace tool pane like Git.

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
