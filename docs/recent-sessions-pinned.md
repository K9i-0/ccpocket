# Recent Sessions: keeping pinned sessions visible

Pinned sessions are stored only in the app (SharedPreferences
`session_list_pinned_session_keys_v1`, key `provider\nprojectPath\nsessionId`).
The list used to pin-sort only the sessions already loaded, so a pinned session
outside the first page disappeared after every filter change (provider, named
only, search, project), each of which re-fetches page 0.

The Bridge now returns the requested pinned sessions with the first list page,
independent of pagination.

## Protocol (additive)

Client `list_recent_sessions` gains:

```ts
pinnedSessions?: Array<{ provider: "claude" | "codex"; sessionId: string }>;
```

The app sends it only for `requestScope: "list"` requests at offset 0
(initial load, refresh, filter switch). Up to 1000 entries; malformed entries
reject the message like other malformed fields.

Server `recent_sessions` gains:

```ts
pinnedSessions?: RecentSession[];
```

- Resolved only when the request is not project scoped, `offset` is 0 and the
  request carried a non-empty `pinnedSessions`. It is `[]` when nothing matches.
- Entries must pass the same filters as the page: `provider`, `namedOnly`,
  `searchQuery`, `projectPath` / `projectId` / `workspaceKind`, and archived
  sessions are excluded. Only `offset` / `limit` are ignored.
- Entries go through the same post-processing as page entries (workspace info,
  names, Claude `lastPrompt` supplement) and may also appear in `sessions`.
- The pinned list is part of the Bridge's in-flight coalescing key.

## Where the entries come from

- Claude and all-provider listings: `getAllRecentSessions` already loads and
  filters every entry before slicing, so pinned entries are selected from the
  filtered, unsliced list (`pinnedSessionKeys` option). No extra scan.
- Codex-only listings backed by app-server `thread/list`: `getPinnedCodexSessions`
  walks `~/.codex/sessions` once and parses only the rollout files whose names
  contain a pinned thread ID (the same targeted lookup the page already uses for
  rollout metadata). Filters are applied locally; search uses the local
  name / first prompt / last prompt / summary match rather than the app-server
  `searchTerm`, so results can differ slightly for edge cases.
- When `thread/list` fails, the rollout fallback listing selects pinned entries
  from the same `getAllRecentSessions` call.
- Codex entries are returned in the `thread/list` shape (`projectPath` is the
  raw thread cwd), because the app pin key includes `projectPath` and page
  Codex entries normally come from `thread/list`. Known gap: when `thread/list`
  fails in an all-provider listing, page Codex entries fall back to the
  repository-grouped shape, so a pinned worktree/subdirectory thread outside
  the page may show without its pin mark until `thread/list` recovers.

## App behavior

- `SessionListCubit` pushes the pinned (provider, sessionId) list to
  `BridgeService` after loading preferences and on every toggle. If the first
  page was already requested without pins, it re-requests the first page once.
- `BridgeService` publishes `page sessions + pinned sessions not already in the
  page` (deduped by provider + sessionId). Pinned extras survive `loadMore`
  appends and project-scoped merges and are replaced by the next first-page
  response. Pagination offsets count page sessions only.
- Unpinning needs no request: the extra is dropped on the next list update
  (not immediately, to avoid replaying the last response, which would reset
  expanded project groups). Pinning a visible session needs no request either.
- Pins are matched by `provider:sessionId` (see
  [recent-sessions-filters.md](recent-sessions-filters.md)), which closes the
  known gap above: a pinned worktree/subdirectory thread is recognized even when
  its listed `projectPath` differs from the stored key.

## Compatibility

- New app + old Bridge: the old `list_recent_sessions` validator checks known
  fields only and ignores unknown ones, so the request is accepted. The
  response has no `pinnedSessions` and the list behaves as before.
- Old app + new Bridge: no `pinnedSessions` in the request, so nothing is
  resolved and the response is unchanged.
