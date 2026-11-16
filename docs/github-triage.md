# GitHub Triage in ccpocket

Status: implemented on main (not yet released)

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
| Entry point | A screen bound to a session, opened from an empty chat or from a project (which starts a session first) | The picked items are a draft of that session's next message |
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
- Only git's "not a git repository" and "No such remote" map to `not_github`;
  other git failures (dubious ownership, a missing directory) are `failed`.
- `--repo` is pinned to `github.com/owner/name`, so `GH_HOST` is ignored.
- `checks`: `ACTION_REQUIRED`, `STALE`, and unknown states count as `pending`.
- `body` and each comment body are cut at 20,000 characters with a
  `… (truncated)` marker.
- `gh` returns no `is_bot` for comment authors, so `comments[].author.isBot`
  is true only for an `app/` or `[bot]` login. The item author is reliable.

Compatibility: an older Bridge answers `unsupported_message`. The GitHub screen
waits for these responses directly, so it shows the Bridge update guidance
inside the screen (not through chat `_unsupportedActions`).

## App

The model follows media feedback (`MediaFeedbackCubit`): what the user picks is
a per-session draft that is shown above the composer and added to the next
message.

- Tabs: Issues / PRs. Results are cached per project like
  `git_view_cache_service`, with pull-to-refresh.
- PR row: number, title, author, Draft badge, dependabot marker, CI state.
- Issue row: number, title, labels, created time.
- Filters: hide drafts, dependabot only, label.
- There is no selection mode. Each row has a leading selection circle that
  toggles the item (a long press does the same); tapping the rest of the row
  shows the detail, which offers opening it on GitHub and the same
  select / deselect toggle.
- The app bar shows the selected count and has "select all" and "clear
  selection". "Select all" adds the visible items of the current tab and skips
  drafts; drafts can still be selected one by one. A notice says so only while
  something is selected and the current tab shows drafts.
- The screen always works for one session. The selection is that session's
  draft in `GitHubSelectionCubit` (owned by `DraftService`): persisted in
  SharedPreferences per session, migrated with the session id
  (`pending_*` → real id, session switches), and kept until sent or removed.
  It is not pruned when an item leaves the open list.
- Selecting or deselecting is reflected at once as cards above that
  session's composer (`#331 title`, with × to deselect). The cards stay
  visible after the screen is closed and after the chat has messages.
- On send, the URLs of the selected items are appended to the message, one
  per line, after the user's text, so a leading `/skill` or `$skill` stays at
  the start. The app does not know any skill: the user types the instruction
  and any skill name in the normal composer, so skill completion, `/` ↔ `$`
  conversion, and attachments work as usual. With no text the message is just
  the URLs (media feedback allows the same). The selection is cleared only
  after the send is accepted; a rejected send keeps it. Nothing is ever sent
  by the screen itself. (2026-11-16: replaced the earlier triage-specific
  presets; ccpocket's `/triage` is a repository skill, not a product
  feature.)
- Opened from a project (recent-session menu item / group header icon): the
  app opens `NewSessionSheet` with the project locked and starts the session
  with no message. Once the new chat is ready it opens the Issues / PRs
  screen bound to that session by itself (`GitHubSelectionCubit.requestOpen`,
  consumed by the empty chat entry). If the start is queued while offline, no
  chat opens and the request is dropped.

### Entry from an empty chat

While the user has sent no message in the session, the empty chat shows a
centered "Open Issues / PRs" button with the GitHub mark.

- Hidden as soon as a user message exists, including a queued or pending one,
  or older history exists outside the loaded window. Assistant-only or system
  entries do not hide it.
- Shown for both Claude and Codex sessions. A non-GitHub project or an older
  Bridge is handled inside the screen, so the button does not call the Bridge.
- The screen it opens is bound to this session.
- On wide layouts the screen opens as a workspace tool pane like Git.

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
- UI: Marionette runs of list → select → cards above the composer from both
  entry points, checking that nothing is sent until the user sends.
