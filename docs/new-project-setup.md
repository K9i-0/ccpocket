# New project setup

## User flow

The session-list + button opens the session sheet directly. Its Project header
provides Create and Multi actions. The selected project card opens a separate
folder picker with browsing and direct path input; recent projects remain
selectable below it. “Multi-project” is the display name of the existing
WorkspaceProject grouping; persisted IDs, `create_project`, and `workspaceKind:
"project"` remain unchanged.

New project setup asks for a folder name, parent folder, optional first request,
Git initialization (on by default), and an optional AI-settings source. The
parent folder is remembered per Bridge URL. Creation never merges into an
existing destination. After creation the app returns to the session sheet with the new folder selected.
The user can review model and permission settings before starting. The initial
request (including AI-settings adaptation) is held only for that created folder
while the sheet is open and submitted through the ordinary input handler on
Start. Choosing another folder or a multi-project never sends that request.
The initial request is not persisted in session defaults. No initial commit is manufactured.

## AI settings inheritance

`project-bootstrap.ts` defines an explicit list of project instructions, shared
agent configuration, skills, agents, commands, and hooks. These are copied into
`.ccpocket-bootstrap/`, which is excluded by the new `.gitignore`. They are not
installed as active settings before adaptation. The source is not added to the
session's writable roots.

Symlinks, local Claude settings, .env files, and named credential/auth/secret
files are excluded. This is not a general secret-content scanner: selected
configuration files can contain inline values. Canonical source and destination
paths must stay in Bridge's allowed directories. Copying is capped at 500 files
and 8 MiB. A setup failure rolls back only the exclusively created destination;
existing destinations are never removed. A directory without supported settings
is reported rather than silently claiming inheritance succeeded.

The first AI request asks it to remove source-specific paths, architecture and
release instructions, retain useful rules, and obtain confirmation before
activating executable configuration. Trust is a separate opt-in, with the path
and effect explained. Copying does not itself grant trust.

## Protocol and compatibility

- `bootstrap_project`: `parentPath`, `name`, `initializeGit`, optional
  `sourcePath`, required `requestId`.
- `initialize_git`: `projectPath`, `requestId`; a repository already containing
  the path is retained rather than creating a nested repository.
- `trust_project`: `projectPath`, `requestId`, optional active `sessionId`.
- `project_setup_result`: matching `requestId`, `projectPath` and optional
  `copiedFiles`, or `error`.
- `start.initialPrompt`: optional bounded initial request, dispatched after
  `session_created` through the ordinary input/queue/history path. Claude also
  receives its user-message echo because there is no optimistic client entry.
- Successful `diff_result` can carry `hasCommits`. Older clients ignore this;
  new clients retain their previous empty-state behavior when it is absent.

The dedicated setup UI correlates responses and handles old Bridges'
`unsupported_message`, disconnects and timeouts. Mutating setup requests are
not queued offline. A timeout does not prove that creation failed: the error
explains that an existing folder can be opened normally. Retrying the same name
never overwrites it. If trust fails after folder creation, retry reuses the
created path, or trust can be deselected to continue.

## Codex trust

Trust is persisted with the official `config/value/write` RPC, using a quoted
path segment. Overrides are reported as errors. The default private app-server
mode reloads an idle session by restarting only its transport and resuming the
same thread ID with the current model, permissions, and launch options. Incoming
input queues during reload and drains on the new `input_ready` event. Busy
sessions and sessions already holding queued input cannot begin reload.

Shared/externally managed app-server sessions are explicitly rejected for live
trust reload before mutation: reconnecting does not guarantee unloading a shared
thread, and restarting a shared server could interrupt other sessions. Trust at
new-project creation, before starting the thread, remains available.

Sources:
- https://learn.chatgpt.com/docs/config-file/config-reference
- https://learn.chatgpt.com/docs/app-server

## Git state

Branch lookup uses symbolic HEAD, with detached-HEAD fallback, so an unborn
repository is not mistaken for a missing repository. Aggregate diff compares
against an empty tree before the first commit. Unstaging preserves working files
even if they were edited after staging. Successful refreshes clear old errors;
initialization refreshes the open Git view without restarting the AI session.

## Validation

Regression coverage exercises exclusive creation/rollback, canonical allowed-root
checks, copying drafts without symlinks/local settings, unborn branch/diff and
unstage behavior, request correlation/old Bridge fallback, phone-sized form
layout, automatic Claude input echo, and same-thread Codex reload with input
blocked on the old transport. A separate local Codex initialization with a
throwaway CODEX_HOME verifies the quoted trust key written by the real RPC.
