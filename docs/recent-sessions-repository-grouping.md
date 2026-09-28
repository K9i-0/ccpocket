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

- One git process per distinct session cwd, run with concurrency 8. Positive
  results are cached for the Bridge process lifetime (a path's main repository
  does not change); negative results expire after 5 minutes.
- Measured on a machine with ~300 recent sessions: first listing +0.7 s,
  later listings unchanged. Groups went from 132 to 25.

## Project-filtered listings

- Codex files are always parsed in full, so the project filter is applied to
  Codex entries after grouping.
- Claude project dirs are pre-filtered by slug for speed. Sibling worktree dirs
  have unrelated slugs, so they are included via a slug → repository map learned
  during earlier listings. The app loads the unfiltered list first, so the map is
  populated before any per-project "Show more". A filtered listing on a freshly
  started Bridge can miss those dirs until the first unfiltered listing.
