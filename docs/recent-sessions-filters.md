# Recent Sessions: quick filters and advanced search

The recent session list separates three layers:

1. **Display settings** (rarely changed): List / Grouped, first / last prompt /
   summary. Moved behind a settings button in the section header.
2. **Quick filters** (chip row, most used first): pinned only, projects
   (multi-select, favorites first), AI tool, period.
3. **Advanced search** (full-screen sheet): text query, content (transcript)
   search, custom date range, created vs. modified, named only, plus the quick
   filters.

"Favorite projects" are the existing pinned projects
(`session_list_pinned_project_paths_v1`). A favorite project is pinned to the
top in grouped mode, its sessions are prioritized in list mode, and it is shown
first in the project picker.

## Protocol (additive, capability `recent_sessions_filters_v1`)

Client `list_recent_sessions` gains optional fields:

```ts
type RecentProjectFilter = {
  projectPath?: string;          // folder path (repository root after grouping)
  projectId?: string;            // workspace Project id
  workspaceKind?: "project" | "unassigned";
};

projectFilters?: RecentProjectFilter[]; // OR across entries, max 100
modifiedAfter?: string;   // ISO 8601, inclusive
modifiedBefore?: string;  // ISO 8601, exclusive
dateField?: "modified" | "created"; // field compared by the range, default "modified"
pinnedOnly?: boolean;     // only pinnedSessions + sessions of pinnedProjects
pinnedProjects?: RecentProjectFilter[]; // max 100, used by pinnedOnly
searchContent?: boolean;  // also search transcript text (slow path)
```

- `projectFilters` is used when two or more projects are selected. A single
  selection keeps using `projectPath` / `projectId` / `workspaceKind`, so the
  common case is unchanged for old Bridges.
- Each `RecentProjectFilter` matches like the single-project fields do today:
  `projectId` matches `workspace.projectId`; `projectPath` matches the session
  `projectPath` (repository root) or a Project whose primary root is that path.
- `pinnedOnly` matches a session when its `provider:sessionId` is in
  `pinnedSessions`, or it matches any `pinnedProjects` entry. `pinnedSessions`
  is still sent with first pages; with `pinnedOnly` the page itself already
  contains every pinned session, so `pinnedSessions` in the response may be
  omitted or empty.
- All filters combine with AND, and also apply to `recent_sessions.pinnedSessions`.
- Project-scoped requests (`requestScope: "project"`, Grouped mode "show more")
  carry every new field too, except `projectFilters` (the scope's own
  `projectPath` / `projectId` replaces it). When `pinnedOnly` is set, the app
  sends `pinnedSessions` / `pinnedProjects` on every request regardless of scope
  or offset, because they define the result set.
- Validation: unknown/malformed values reject the message like other fields
  (non-string dates, unparseable dates, arrays over 100, non-boolean flags).

Server `recent_sessions` entries (page and `pinnedSessions`) gain, only when a
`searchQuery` was sent:

```ts
searchMatch?: {
  field: "name" | "firstPrompt" | "lastPrompt" | "summary" | "project" | "branch" | "content";
  snippet?: string; // ~120 chars around the first content hit (content only)
};
```

### Search fields

`searchQuery` (case-insensitive substring) now also matches the project folder
name (basename of `projectPath`) and `gitBranch`, in this priority:
name → firstPrompt → lastPrompt → summary → project → branch. The first
matching field is reported in `searchMatch.field`.

With `searchContent: true`, sessions that do not match on metadata are checked
against their transcript (Claude JSONL under `~/.claude/projects`, Codex
rollout JSONL under `~/.codex/sessions`). Only user / assistant message text is
searched, not tool input or output. The scan walks the filtered sessions newest
first and stops once `offset + limit + 1` matches are found, so cost grows with
how deep the user pages. Codex app-server `thread/list` is bypassed for content
search; the rollout index is used for both providers.

## Bridge routing

`listRecentSessions` already has a predicate-based path for workspace filters
(`matchesWorkspace`). Any of the new filters routes the request through that
path with an extended predicate (projects OR, date range, pinned only). The
Codex `thread/list` probe passed to the predicate includes `modified` / `created`
converted with `threadTimestampToIso`, and the scan stops early once the
converted `modified` falls below `modifiedAfter` when `dateField` is
`modified` (the list is sorted by `updated_at` desc). The coalescing key
includes every new field.

Content search is bounded: at most 400 transcript files are read per request
(newest first, after the metadata filters) and the scan stops after a 4 s
budget. When a bound is hit before enough matches are found, the response
returns the matches so far with `hasMore: true`, and the next page continues
from the requested offset (the scan restarts from the newest session, so
deeper pages cost more; acceptable for an explicit opt-in search).

Implementation notes (Bridge):

- Routing: the predicate path is used when `projectFilters` (non-empty, list
  scope), `modifiedAfter`, `modifiedBefore`, `pinnedOnly`, or `searchContent`
  with a non-blank `searchQuery` is present. `dateField` alone,
  `pinnedProjects` without `pinnedOnly`, and `searchContent` without a query
  keep the previous fast path. `projectFilters` is ignored on project-scoped
  requests.
- Dates: a session whose compared field is missing or unparseable is excluded
  while a date bound is set.
- `pinnedOnly`: pinned keys come from `pinnedSessions` (filtered by
  `provider`) on every request. The `pinnedSessions` extras are not resolved;
  a first list page (offset 0) that sent pins answers `pinnedSessions: []`,
  other pages omit it. With no pins and no `pinnedProjects` the response is
  empty without a scan.
- Path-based project filters compare `projectPath` exactly. Index entries
  carry the repository root; Codex `thread/list` probes carry the raw thread
  cwd (same as the existing single-project workspace path).
- Content search uses the filesystem index for both providers, so Codex page
  entries come in the repository-grouped index shape (as in the `thread/list`
  failure fallback, see `recent-sessions-pinned.md`); pinned extras keep the
  `thread/list` shape. Every rollout segment of a Codex thread (and every
  worktree copy of a Claude transcript) is searched; each file counts toward
  the 400-file bound. Pinned extras are content-searched separately with the
  same bounds. Excluded from content search: tool use / tool results,
  reasoning, Claude `isMeta` and command/system-injected user text, and Codex
  injected user context (AGENTS.md, environment context, ...).
- `searchMatch` on `thread/list` results is computed locally from the mapped
  entry; when only the app-server matched (e.g. on text not exposed in the
  entry), `searchMatch` is omitted.
- Search helpers live in `packages/bridge/src/recent-session-search.ts`.

## Compatibility

- New app + old Bridge: the old validator ignores unknown fields, so a request
  with `projectFilters` / dates / `pinnedOnly` / `searchContent` would silently
  return unfiltered results. The app therefore only sends these fields when the
  Bridge advertises `recent_sessions_filters_v1`. Without it, the project picker
  stays single-select and the pinned-only, period and content-search controls
  are disabled with a Bridge update hint. Extended search fields (project,
  branch) and `searchMatch` simply do not appear.
- Old app + new Bridge: none of the new fields are sent; responses only gain the
  optional `searchMatch`, which old apps ignore.

## App behavior

- The app request de-duplication key (`queryKey`) includes every new field.
- Pinned sessions are matched by `provider:sessionId` (not the full pin key that
  also contains `projectPath`), so a session pinned while running in a worktree,
  or a Codex thread whose `projectPath` differs between listing shapes, is still
  recognized as pinned and sorted to the top. Toggling removes every stored
  key with the same `provider:sessionId`, so a duplicate key is never added.
- Favorite (pinned) project groups stay visible in Grouped mode even when the
  loaded pages contain none of their sessions; the header's "show more" loads
  that project with a project-scoped request.
- List mode shows a "Pinned" section first, then the remaining sessions under
  date headers (Today / Yesterday / date).
- Period presets: Today, Yesterday, Day before yesterday, Last 7 days, Last 30
  days, Custom range. Presets are computed on the device in local time and sent
  as ISO instants.
- Project filter keys keep the existing encoding (`project:<id>` or a path).
