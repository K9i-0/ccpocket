# ccpocket Projects

## Goal

Provide one ccpocket-owned workspace model that works with both Claude and
Codex, restores the same folder access when a session is resumed, and groups
recent sessions independently of the provider-reported working directory.

ccpocket does not write Codex Desktop's private `~/.codex` project state.
Importing that state may be added later as a read-only migration feature.

## Persistent model

The Bridge is the source of truth and stores versioned state in
`~/.ccpocket/workspaces-v1.json`.

For isolated development and tests, `BRIDGE_WORKSPACE_FILE` overrides the
state file.

```ts
interface WorkspaceProject {
  id: string;
  name: string;
  // Ordered. Index 0 is the primary root.
  rootPaths: string[];
  createdAt: string;
  updatedAt: string;
}

interface SessionWorkspaceAssignment {
  provider: "claude" | "codex";
  providerSessionId: string;
  kind: "project";
  projectId?: string;
  // Snapshot used to restore the original execution environment even if the
  // project is later edited or removed.
  rootPaths: string[];
  assignedAt: string;
}

interface WorkspaceStateV1 {
  version: 1;
  projects: WorkspaceProject[];
  assignments: Record<string, SessionWorkspaceAssignment>;
}
```

Assignment keys are `${provider}:${providerSessionId}` so Claude and Codex IDs
cannot collide.

## Execution mapping

| ccpocket workspace | Claude Agent SDK | Codex App Server |
| --- | --- | --- |
| primary root | `cwd` | `cwd` |
| secondary roots | `additionalDirectories` | workspace-write writable roots |

The primary root remains the base for Git, worktrees, project instructions,
skills, and provider configuration discovery. Secondary roots provide file
access only.

## Session lifecycle

1. A start request identifies a Project or a legacy folder-only session.
2. The Bridge resolves and validates every root against `BRIDGE_ALLOWED_DIRS`.
3. The runtime session temporarily carries the resolved workspace.
4. When Claude or Codex reports its durable provider session ID, the Bridge
   persists the assignment.
5. Recent-session responses are enriched from the assignment store.
6. Resume uses the assignment's root snapshot. A recorded worktree `cwd` still
   wins as the primary execution directory; legacy sessions use provider
   transcript paths as their fallback.

## Recent-session classification

Recent sessions use a workspace key rather than `projectPath`:

- `project:<projectId>`: display the ccpocket Project name.
- `<primaryPath>`: legacy or externally-created provider sessions retain the
  existing path key for backward-compatible collapse and pin state.

Project identity is based only on an explicit session assignment. A legacy or
externally-created session stays Unassigned even when its `cwd` matches a
Project's primary root. This keeps ordinary folder sessions distinct from
sessions that were actually started through a ccpocket Project.

Project-scoped filtering and pagination happen after provider results are
enriched, so two Projects sharing one primary root do not leak sessions into
each other's groups.

The Recent Sessions project filter lists the Bridge's complete Project catalog,
including Projects with no session in the currently loaded page. Each Project's
primary folder is also listed as a folder filter. Selecting the named Project
matches only its explicit assignments; selecting its primary folder matches
both ordinary sessions at that path and sessions assigned to any Project whose
primary root is that folder.

The New Session sheet follows the same identity split. It lists both the named
Project and its primary folder. Selecting the named Project starts with all of
its roots, while selecting the primary folder starts an ordinary single-root
session without the Project identity or secondary roots.

## Compatibility and migration

- Existing `projectPath` and `additionalWritableRoots` fields remain accepted.
- New clients send Project identity in addition to the legacy primary path.
- Old Bridges return `unsupported_message`; the app keeps the existing
  folder-based new-session and Recent Sessions behavior.
- Existing `~/.ccpocket/project-history.json` paths remain folder suggestions.
  They are not silently converted into named Projects.
- Codex/Claude sessions without ccpocket assignments remain accessible as
  Unassigned sessions.

## First implementation boundary

The first release includes Bridge-owned Project CRUD, session assignment,
provider root mapping, Recent Sessions enrichment, and mobile Project
management/selection. Read-only Codex Desktop import and manual reassignment
of historical ambiguous sessions are follow-up features.
