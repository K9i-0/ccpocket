# Recent Sessions: grouping worktree sessions by repository

Issue: [#256](https://github.com/K9i-0/ccpocket/issues/256)

The app groups Recent Sessions by `projectPath`. The Bridge reports the main
repository as `projectPath` for sessions that ran in a worktree and keeps the
worktree directory as `resumeCwd`, so resume still targets the worktree. No
protocol field was added; older apps get the grouped `projectPath` as is.

## How a session's repository is resolved

Implemented in `packages/bridge/src/sessions-index.ts` (`groupEntriesByRepository`)
and `packages/bridge/src/repository-root.ts`.

1. **Path patterns** (`normalizeWorktreePath`), no I/O:
   - `<project>-worktrees/<branch>` (CC Pocket worktrees)
   - `<repo>/.claude/worktrees/<name>` (Claude Code desktop / `claude --worktree`)
2. **git**, when the cwd still exists: `git rev-parse --show-toplevel --git-common-dir`.
   Only a checkout's top level is regrouped; a linked worktree maps to its main
   worktree. Subdirectories of a checkout are left alone, so monorepo package
   sessions keep their own group as before.
3. **Codex repository URL**, when the cwd was deleted (e.g. `codex exec review`
   in a throwaway sibling worktree): Codex records
   `session_meta.payload.git.repository_url`. It is matched against the `origin`
   of repositories resolved in step 2. When several local checkouts share the
   origin, nothing is guessed and the session keeps its own group.

A name-prefix heuristic (`app-feature` → `app`) is deliberately not used:
unrelated repositories often share a prefix (`roomphoto` and `roomphoto-lp-stats`).

## Cost and caching

- Git resolutions run with concurrency 8. Concurrent requests for the same path
  share one pending lookup. Origin lookups also reuse pending results and do not
  fan out a process per candidate repository.
- Both successful and unsuccessful results expire after 5 minutes, so reused
  worktree paths and changed origins can be discovered without restarting Bridge.
- The original PR measured ~300 sessions: first listing +0.7 s, later listings
  unchanged; groups went from 132 to 25. These are the author's measurements,
  not a benchmark of the subsequent filtering/cache fixes.

## Project-filtered listings

Both providers are loaded and grouped before filtering by repository. Claude
project directories cannot be pre-filtered by slug: a sibling worktree's name
need not resemble its repository. The first filtered request therefore includes
those sessions even without an earlier unfiltered listing, at the cost of reading
all Claude project directories for a project-filtered request. Existing named-only
loading optimizations still apply.

URL fallback is restricted to missing cwd paths (ENOENT/ENOTDIR). Existing
monorepo subdirectories and paths that cannot be inspected are left unchanged.
The candidate set consists of repository roots found in the loaded sessions;
no match or multiple matches leave the deleted session in its original group.
