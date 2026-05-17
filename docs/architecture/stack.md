# CC Pocket Technical Stack

This document is the agent-readable version of the CC Pocket architecture page.
Human-readable HTML is available at `https://k9i-0.github.io/ccpocket/architecture/`.

## Product Shape

CC Pocket is an MIT-licensed client framework for controlling local Codex and
Claude agent sessions from mobile and desktop surfaces.

The project is designed around self-hosting:

```text
CC Pocket app
  <-> JSON WebSocket protocol
Bridge Server on the user's machine
  <-> local agent tools, shell, git repository, filesystem
Codex / Claude
```

The Bridge Server runs on the machine that has access to the project. The app is
the control surface for starting sessions, sending prompts, approving actions,
answering agent questions, browsing files, reviewing diffs, and managing git
operations.

## Repository Layout

```text
ccpocket/
├── apps/mobile/        # Flutter app for iOS, iPadOS, Android, macOS, Linux
├── packages/bridge/    # TypeScript Bridge Server published as @ccpocket/bridge
├── docs/               # GitHub Pages site and design notes
├── scripts/            # Release, development, and asset automation
├── functions/          # Firebase Cloud Functions for push relay support
└── package.json        # npm workspace root
```

## Bridge Server

Location: `packages/bridge/`

Core stack:

- Runtime: Node.js 18+
- Language: TypeScript, ESM, strict mode
- Module resolution: NodeNext
- WebSocket server: `ws`
- Claude integration: `@anthropic-ai/claude-agent-sdk`
- Codex integration: local Codex CLI / shared app-server transport
- Local discovery: `bonjour-service` mDNS
- Proxy support: `undici` global dispatcher and `socks`
- Tests: Vitest
- Development runner: `tsx`

Key responsibilities:

- Expose a JSON WebSocket protocol to CC Pocket clients.
- Manage concurrent agent sessions.
- Start, resume, stop, and reconnect sessions.
- Route streaming assistant output and status changes to clients.
- Handle approval requests, user questions, and unsupported-message fallbacks.
- Preserve compatibility with local agent session history.
- Provide git operations: diff, stage, unstage, commit, push, branch operations,
  worktree support, and dirty-state summaries.
- Provide project utilities: file browsing, prompt history, image gallery,
  screenshot serving, usage metadata, and session indexes.
- Support host setup: launchd on macOS, systemd on Linux.
- Support remote access via QR code, mDNS, manual WebSocket URLs, and Tailscale.

Important files:

- `src/index.ts`: server entry point
- `src/cli.ts`: `ccpocket-bridge` CLI
- `src/websocket.ts`: WebSocket server and message routing
- `src/session.ts`: session lifecycle and multi-session coordination
- `src/parser.ts`: protocol types and message parsing
- `src/sdk-process.ts`: shared SDK process primitives
- `src/codex-process.ts`: Codex process/session integration
- `src/codex-transport.ts`: Codex transport abstraction
- `src/git-operations.ts`: git command wrappers
- `src/worktree.ts`: git worktree operations
- `src/prompt-history-store.ts`: Bridge-managed prompt history
- `src/gallery-store.ts`: image gallery persistence
- `src/setup-launchd.ts`: macOS service setup
- `src/setup-systemd.ts`: Linux service setup

## Flutter App

Location: `apps/mobile/`

Core stack:

- Framework: Flutter
- Language: Dart
- Platforms: iOS, iPadOS, Android, macOS, Linux
- State management: `flutter_bloc` / Cubit, `provider`, `flutter_hooks`
- Routing: `auto_route`
- Data models: `freezed`, `json_serializable`
- WebSocket client: `web_socket_channel`
- Local storage: `shared_preferences`, `sqflite`, `flutter_secure_storage`
- Markdown and code rendering: `flutter_markdown`, `markdown`, `highlight`,
  `syntax_highlight`
- File/image UX: `image_picker`, `extended_image`, `super_clipboard`,
  `super_drag_and_drop`
- Discovery and onboarding: `bonjour-service` counterpart via `bonsoir`,
  QR scanning via `mobile_scanner`, deep links via `app_links`
- SSH host management: `dartssh2`
- Push notifications: Firebase Messaging
- Purchases/supporter flow: RevenueCat `purchases_flutter`
- OTA updates: Shorebird Code Push
- UI automation hooks: `marionette_flutter`
- Tests: `flutter_test`, `bloc_test`, Patrol finders, widget tests

Feature-first directories:

- `features/chat_session/`: shared chat state, widgets, message handling
- `features/claude_session/`: Claude session screen
- `features/codex_session/`: Codex session screen
- `features/session_list/`: home screen, machines, recent/running sessions
- `features/git/`: diff viewer and git operations UI
- `features/explore/`: file explorer
- `features/file_peek/`: inline file preview from messages
- `features/gallery/`: image gallery
- `features/message_images/`: image viewer
- `features/prompt_history/`: prompt history UI
- `features/settings/`: app settings and supporter surfaces
- `features/setup_guide/`: connection and setup guidance
- `features/debug/`: debug and diagnostics surfaces

## Protocol Boundary

The app and Bridge communicate over a JSON WebSocket protocol.

Common client-to-server messages:

- `start`: start a new Codex or Claude session
- `input`: send user text or attachments
- `approve` / `reject`: answer permission requests
- `answer`: answer agent questions
- `list_sessions`: fetch running/recent sessions
- `stop_session`: stop a session
- `get_history`: restore session history
- `get_diff`: fetch git diff data

Common server-to-client messages:

- `system`: init and session lifecycle events
- `assistant`: assistant messages
- `stream_delta`: streaming text deltas
- `tool_result`: tool result summaries and payloads
- `permission_request`: approval prompts
- `status`: running/idle/waiting approval status
- `history`: restored messages
- `session_list`: recent and running sessions
- `diff_result`: git diff response
- `error`: recoverable protocol/runtime errors

When adding a new feature, prefer adding an explicit protocol message and a
graceful unsupported-message fallback so newer clients can communicate with
older Bridge versions.

## Persistence and Sync

CC Pocket does not move the user's project into a hosted IDE.

State is split by responsibility:

- Agent history remains compatible with local agent tools.
- Bridge keeps session indexes, prompt history, gallery metadata, worktree
  metadata, and runtime state needed for reconnection.
- The app keeps UI preferences, machines, local caches, and secure credentials.
- Git state remains in the user's repository and worktrees.

This split is what allows mobile and desktop clients to reconnect to the same
host machine and continue work without replacing local CLI workflows.

## Extension Points for Forks

Good places to fork or customize:

- Add a first-class Jira, Linear, GitHub, or internal ticket UI.
- Add private REST API panels that turn daily workflow state into GUI controls.
- Remove app surfaces that are not needed for a focused internal tool.
- Add organization-specific approval policies or command presets.
- Add new Bridge protocol messages for workflow-specific data.
- Add custom prompt history, project templates, or issue-to-session flows.
- Extend desktop support. macOS and Linux are supported today. Windows support is
  technically feasible with relatively low effort, but not official because the
  project does not have a stable Windows verification environment.

Recommended implementation pattern:

1. Add Bridge-side data access or operation in `packages/bridge/src/`.
2. Add protocol types in `parser.ts` and routing in `websocket.ts`.
3. Add a Flutter service stream or request method in `apps/mobile/lib/services/`.
4. Add feature UI under `apps/mobile/lib/features/<feature>/`.
5. Add focused tests for protocol parsing, Bridge behavior, and Flutter state.

## Development Commands

Bridge:

```bash
npm run bridge
npm run bridge:build
npm run test:bridge
npx tsc --noEmit -p packages/bridge/tsconfig.json
```

Flutter:

```bash
cd apps/mobile && flutter pub get
cd apps/mobile && dart analyze
cd apps/mobile && flutter test
```

Combined development:

```bash
npm run dev
npm run dev -- <device-id>
```

## Licensing

CC Pocket is MIT licensed. Forks can reuse, modify, and specialize both the app
and Bridge Server, subject to the MIT license notice requirements and any
third-party service terms that apply to the fork's integrations.
