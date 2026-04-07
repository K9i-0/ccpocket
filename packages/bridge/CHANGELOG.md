# Changelog

All notable changes to `@ccpocket/bridge` will be documented in this file.

## [1.34.0] - 2026-04-07

### Added
- Token highlighting and Codex skill completion in composer
- Split slash and dollar completions for Codex

### Fixed
- Preserve MCP elicitation approval type in Codex sessions

## [1.33.3] - 2026-04-05

### Fixed
- Handle `Revert All` and hunk/file revert actions correctly when the git diff includes untracked files
- Allow hunk stage/revert operations to build patches for untracked files shown in the diff view

## [1.33.2] - 2026-04-05

### Changed
- Clarify Bridge redistribution terms for unofficial Windows, WSL, proxy, and other hard-to-validate environment-specific distributions
- Align package license metadata and README guidance with the Bridge redistribution exception

## [1.33.1] - 2026-04-04

### Changed
- Add Bridge test/typecheck/build to the regular Ubuntu CI workflow
- Require Windows smoke verification for Bridge releases and support manual Windows smoke runs

### Fixed
- Handle Windows allowed-directory and `resume_session` path normalization correctly, including `\\?\` extended paths
- Launch Codex app-server on Windows via a compatible `cmd.exe` spawn path

## [1.33.0] - 2026-04-02

### Added
- `BRIDGE_DISABLE_MDNS` environment variable and `--no-mdns` CLI flag to disable mDNS auto-discovery advertisement (#34)

## [1.32.0] - 2026-04-02

### Added
- Codex `approvalPolicy` values (`untrusted`, `on-request`, `on-failure`, `never`) in the Bridge client protocol

### Changed
- Preserve Codex approval policy directly across start, resume, and mode-change flows instead of mapping everything through legacy execution presets

## [1.31.1] - 2026-04-01

### Fixed
- Support public startup deep links and QR codes for reverse proxy / ngrok setups via `BRIDGE_PUBLIC_WS_URL` or `--public-ws-url`

## [1.31.0] - 2026-03-30

### Added
- Auto-generate staged commit messages via the active Claude/Codex session provider

### Changed
- `git_commit` now requires `sessionId` when `autoGenerate=true`

### Fixed
- Use Codex Mini for commit message auto-generation
- Support current Codex exec CLI interface

### Removed
- Unused post-1.30.0 git API surface: `git_status`, `git_status_result`, `git_branches.query`, `git_push.forceLease`, `git_push_result.remote`, `git_push_result.branch`

## [1.30.0] - 2026-03-29

### Added
- File Peek: `read_file` handler for viewing file contents from the mobile app

### Removed
- Unused `list_dir` handler (directory browsing handled client-side via file list)

## [1.29.1] - 2026-03-27

### Fixed
- Include agent message in Codex completion notification

## [1.29.0] - 2026-03-27

### Added
- Improve @mention file list with untracked files and relevance scoring
- Improve resume command copy for worktree and permission modes

## [1.28.0] - 2026-03-24

### Added
- Emit acceptEdits mode when file-edit tool is always-approved
- Propagate SDK permission mode changes to connected clients

### Changed
- Swap default Claude model order: opus 4.6 before opus 4.6[1m]

### Fixed
- Return updatedPermissions in approveAlways for mode transition
- Add runtime guard to reject OAuth auth source

## [1.27.0] - 2026-03-21

### Added
- Codex plan mode toggle without restart when idle
- Redesigned modes for Codex execution and plan

### Fixed
- Ignore placeholder model name on Codex session resume
- Show resolved environment on Codex init
- Rollback mode changes on bridge error

## [1.26.0] - 2026-03-19

### Added
- Codex approval protocol support (catch up app-server approval flow)
- Codex sub-agent session metadata display
- Codex dynamic tool call normalization
- Codex thread list for recent sessions (stored threads without active sessions)
- Simplified Chinese (zh-CN) localization support

### Changed
- Deprecated all npm package versions older than `1.25.0` for new installs due to potential Anthropic policy concerns around OAuth-based usage

### Fixed
- Restore MCP images in Codex session history
- Preserve Codex sandbox mode on session resume
- Restore Codex recent session settings correctly

## [1.25.0] - 2026-03-19

### Changed
- Subscription-based (OAuth) authentication is temporarily disabled pending Anthropic policy clarification. API key (`ANTHROPIC_API_KEY`) is now required

### Fixed
- Prevent false auth error detection on long assistant messages containing auth-related keywords

## [1.24.0] - 2026-03-19

### Changed
- Claude usage tracking is now opt-in (set `BRIDGE_ENABLE_USAGE=1` to enable). No direct Anthropic API calls by default

## [1.23.0] - 2026-03-18

### Added
- Add `gpt-5.4-mini` to available Codex model list
- Graceful degradation for unsupported Bridge message types with per-action client fallback handling

### Changed
- Doctor check no longer requires unused `codex-sdk`, and skips `systemd` checks on macOS

## [1.22.1] - 2026-03-17

### Fixed
- "Invalid message format" error when app sends `refresh_branch` message (missing parser case)

## [1.22.0] - 2026-03-17

### Added
- HTTP/SOCKS5 proxy support for outgoing fetch requests via `HTTPS_PROXY` env var (#16)

### Fixed
- Refresh git branch display when opening session or tapping branch chip

## [1.21.2] - 2026-03-15

### Changed
- Session recording is now opt-in via `BRIDGE_RECORDING` env var (disabled by default)

## [1.21.1] - 2026-03-15

### Fixed
- Read customTitle from JSONL for pipe-created sessions (`claude -p -n`)

## [1.21.0] - 2026-03-15

### Added
- Auth help screen and improved auth error UX

### Fixed
- Restore claude sessions with original cwd

## [1.20.2] - 2026-03-15

### Fixed
- `ANTHROPIC_AUTH_TOKEN` 環境変数による認証をサポート (#12)

## [1.20.1] - 2026-03-15

### Fixed
- `ccpocket-bridge setup` が生成する launchd plist で `RunAtLoad` / `KeepAlive` が `false` になっていた問題を修正 (#13)

## [1.20.0] - 2026-03-14

### Added
- Gentle tip message when project has no git repository (persisted in session history)
- Categorized `errorCode` for git-related diff errors (`git_not_available`)

### Changed
- Non-git projects return empty file list instead of error on `list_files`
- Diff errors for non-git projects use user-friendly message instead of raw git error

## [1.19.0] - 2026-03-14

### Added
- Add `claude-opus-4-6[1m]` (1M context) to available Claude model list

## [1.18.0] - 2026-03-13

### Added
- Include `bridgeVersion` in `session_list` messages for client-side version checks

### Fixed
- Send skill descriptions from Claude Code `supportedCommands()` — previously only skill names were forwarded, causing the mobile app to display directory names instead of descriptions

### Changed
- Update `@anthropic-ai/claude-agent-sdk` to 0.2.74

## [1.17.1] - 2026-03-12

### Changed
- Sandbox configuration now delegated to Claude Code native `.claude/settings.json` — Bridge passes only `enabled: true/false`
- Worktree configuration uses `.gtrconfig` only (removed `.ccpocket.toml` priority logic)

### Removed
- `.ccpocket.toml` support and `smol-toml` dependency — sandbox settings should be configured via `.claude/settings.json`

## [1.17.0] - 2026-03-12

### Added
- Auto-enable `loginctl enable-linger` on systemd setup to keep the Bridge Server running after logout (SSH disconnect etc.)
  - Idempotent: skips if linger is already enabled
  - Graceful fallback: prints manual command if `loginctl` fails

### Removed
- Unused `@openai/codex-sdk` dependency

## [1.16.0] - 2026-03-12

### Added
- Linux (systemd) support for `setup` / `setup --uninstall` commands — auto-detects OS and registers appropriate service (launchd on macOS, systemd on Linux)
- `checkSystemdService` in `doctor` command for Linux service health check
- Resolves full `npx` path at setup time so nvm/mise/volta-managed Node.js works under systemd

### Changed
- `setup` command now uses dynamic imports with `platform()` branching instead of static launchd import
- Unsupported platforms (e.g. Windows) get a clear error message

### Removed
- `claude auth login` feature removed (refactor: remove claude auth login feature)

## [1.15.0] - 2026-03-12

### Added
- Claude Code sandbox support — pass sandbox enabled/disabled state from mobile client to Claude SDK via `query()` options
- Claude sandbox mode toggle — changing sandbox restarts the session with the new setting (sandbox is a query-level config)
- `.ccpocket.toml` configuration file support with `[worktree]` section, prioritized over legacy `.gtrconfig`
- `smol-toml` dependency for TOML parsing

### Changed
- Simplified permission/sandbox mode forwarding — both Claude and Codex sessions now use unified message handling

## [1.14.0] - 2026-03-11

### Added
- Codex Skills (Prompts) support — fetch full skill metadata (description, defaultPrompt, brandColor) via `skills/list` RPC and forward to Flutter client as `skillMetadata`
- Send `SkillUserInput` (`{ type: "skill", name, path }`) when a Codex skill is selected, enabling proper skill loading and execution
- Handle `skills/changed` notification for automatic skill re-fetching
- Cache skill metadata alongside slash commands for session restore

## [1.13.2] - 2026-03-11

### Fixed
- Remove misleading WARNING log when BRIDGE_API_KEY is not set — API key authentication is optional (Tailscale handles security)

## [1.13.1] - 2026-03-08

### Fixed
- Rewind session_created messages now include `sourceSessionId`, preventing duplicate session screens on restart and rewind
- Codex permission mode changes trigger a session restart (matching sandbox mode behavior) with confirmation dialog
- Codex session_created response now includes `permissionMode`, ensuring restored sessions retain their permission setting

## [1.13.0] - 2026-03-08

### Added
- Claude OAuth authentication status endpoint — settings screen can display login state and trigger re-authentication without leaving the app (experimental)

### Fixed
- Usage API returning persistent 429 errors — refresh OAuth token on rate-limit responses (not just on 401), resolving stale-token rate limits
- Auth status check no longer probes the upstream API, eliminating redundant requests that could trigger rate limits when opening the settings screen

## [1.12.0] - 2026-03-08

### Added
- `errorCode` field on error messages for structured client-side display (`auth_login_required`, `auth_token_expired`, `auth_api_error`, `path_not_allowed`)

### Changed
- Auth and path-not-allowed error messages now include clear problem descriptions and remedy instructions (e.g. `claude auth login`) so users can self-resolve without checking server logs
- Dev script unsets `CLAUDECODE` env var to allow E2E testing inside a Claude Code session

## [1.11.1] - 2026-03-07

### Fixed
- Fall back to macOS Keychain for Claude OAuth credentials when `~/.claude/.credentials.json` does not exist (e.g. login performed on older Claude Code version that stored creds in Keychain)

## [1.11.0] - 2026-03-06

### Added
- Deliver available model lists (Claude / Codex) in `session_list` message so clients can display dynamic dropdowns instead of hardcoded values

### Changed
- Update model lists to latest versions: Claude 4.6 series (opus, sonnet, haiku), Codex gpt-5.4 default

## [1.10.1] - 2026-03-04

### Fixed
- Restore slash commands on `get_history` after history eviction — long sessions (100+ messages) lost `init`/`supported_commands` from in-memory history, causing slash completion to fall back to 4 built-in commands when re-entering the session
- Protect `system` messages from history eviction alongside `user_input`

## [1.10.0] - 2026-03-03

### Added
- `BRIDGE_ALLOWED_DIRS` environment variable for project path whitelist (defaults to `$HOME`)
- Path validation on `start`, `resume_session`, `get_diff`, `get_diff_image`, `list_files`, `list_worktrees`, `remove_worktree` — rejects paths outside allowed directories
- Include `allowedDirs` in `session_list` message for client-side path input assistance
- Send `project_history` on WebSocket connect so clients receive history immediately

## [1.9.7] - 2026-03-02

### Fixed
- Auto-refresh expired OAuth access token before starting SDK session (prevents auth errors when token expires between CLI sessions)

## [1.9.6] - 2026-03-02

### Fixed
- Skip system-injected messages (`<local-command-caveat>`, `<local-command-stderr>`, etc.) when extracting firstPrompt/lastPrompt from JSONL scan
- Add streaming fallback for sessions with large user messages (embedded images) that exceed the 16KB head-read buffer
- Supplement missing lastPrompt for Claude sessions via tail-read with growing window (8KB→128KB), enabling distinct Last display mode in session list (+3-5ms overhead)

## [1.9.5] - 2026-03-02

### Fixed
- Replace `claude auth status` process spawn with lightweight file read for auth pre-check (reduces memory pressure)
- Preserve extra credential fields (scopes, subscriptionType, rateLimitTier) when refreshing OAuth tokens

## [1.9.4] - 2026-03-02

### Fixed
- Read Claude OAuth credentials from disk (`~/.claude/.credentials.json`) instead of macOS Keychain, eliminating iCloudHelper keychain dialog
- Replace keychain-based doctor check with file-based credential check

## [1.9.3] - 2026-03-02

### Fixed
- Pre-check Claude auth before starting SDK session to prevent macOS keychain access dialog
- Remove password read (-w flag) from doctor's keychain check to avoid triggering keychain dialog
- Preserve original user text when merging SDK echo (avoid overwriting with translated text)

## [1.9.2] - 2026-03-01

### Added
- Include Claude Code model name in session list response (stored from system/init message)

## [1.9.1] - 2026-03-01

### Fixed
- Make Codex sandbox mode switching actually work (destroy + resume with new sandbox parameter)
- Fix 0-message session sandbox switch causing "no rollout found" error
- Always use last turn_context for codex session settings after sandbox mode changes
- Send sandbox mode in external format ("on"/"off") to clients instead of internal format
- Pass sandboxMode to navigation when resuming Codex sessions from session list

## [1.9.0] - 2026-02-28

### Added
- Add macOS Screen Recording permission check to doctor command
- Add macOS Keychain access check to doctor command
- Add Health Check section to README

## [1.8.0] - 2026-02-28

### Added
- Lazy loading, combined requests, and image caching for diff view

### Fixed
- Prevent server crash when starting a session with an invalid or inaccessible project path
- Prevent zombie session entries when session creation fails

## [1.7.0] - 2026-02-28

### Added
- Add doctor command for environment health checks
- Add image change support for git diff screen
- Display main repo branch name in worktree list

### Changed
- Relax diff image thresholds to 1MB auto-display / 5MB max and add env var config (`DIFF_IMAGE_AUTO_DISPLAY_KB`, `DIFF_IMAGE_MAX_SIZE_MB`)

## [1.6.1] - 2026-02-25

### Fixed
- Add timestamp to `user_input` history entries so client displays original send time
- Register uploaded images in imageStore and include image URLs in `user_input` history for session re-entry
- Remove flaky persist-and-reload test

## [1.6.0] - 2026-02-25

### Added
- Forward SDK `compact_boundary` events as `compacting` process status for auto compact visibility

## [1.5.3] - 2026-02-25

### Changed
- Optimize JSONL session parsing with head+tail partial file reads (16KB+8KB) and regex-based field extraction (6.6x speedup: 2507ms → 382ms)
- Optimize namedOnly session path to skip unnamed sessions early
- Parallelize Claude + Codex session loading with Promise.all
- Remove messageCount from session index entries to eliminate full-file scanning

## [1.5.2] - 2026-02-25

### Fixed
- Stabilize busy-path queue handling by deriving `input_ack.queued` and interrupt behavior from actual enqueue results
- Ensure busy-path logs are emitted consistently when input is queued and interrupted
- Resolve tool-result image paths relative to project root when CLI outputs project-relative absolute-like paths (e.g. `/images/...`)
- Fix gallery/image persistence failures caused by unresolved screenshot paths

## [1.5.1] - 2026-02-25

### Fixed
- Replace single-slot `pendingInput` with FIFO array queue to prevent message loss when multiple inputs arrive while the agent is busy
- Auto-interrupt the current agent turn when a new message is queued, so queued messages are picked up promptly instead of waiting for the turn to finish
- Add `queued` flag to `input_ack` response so the client can show a "queued" indicator
- Preserve queued messages across `interrupt()` calls instead of clearing them

## [1.5.0] - 2026-02-25

### Added
- Server-side filtering for `list_recent_sessions`: `provider`, `namedOnly`, and `searchQuery` parameters
- Search matches against session name, first/last prompt, and summary

## [1.4.1] - 2026-02-24

### Changed
- Recommend `npx @ccpocket/bridge@latest` to ensure users always run the latest version
- Updated launchd plist template, README, and in-app setup guide

## [1.4.0] - 2026-02-24

### Changed
- Replace `BRIDGE_HIDE_IP` with `BRIDGE_DEMO_MODE`: hides Tailscale IPs and omits API key from QR code deep links for safe video recording

## [1.3.0] - 2026-02-24

### Added
- Session archive functionality: hide historical sessions from the session list
- Archive store persists archived session IDs in `~/.ccpocket/archived-sessions.json`
- Codex `thread/archive` RPC called best-effort when archiving Codex sessions
- New WebSocket message: `archive_session` (client→server) / `archive_result` (server→client)

## [1.2.0] - 2026-02-24

### Added
- Privacy mode for push notifications: hides project names, session names, tool names, and message content
- Session name (rename) displayed in notification titles, with project name fallback
- Notification title format: `セッション名 (プロジェクト名)` when both are available

## [1.1.1] - 2026-02-23

### Fixed
- Persist renamed session name after CLI overwrites sessions-index.json on session end

## [1.1.0] - 2026-02-23

### Added
- Session rename support for Claude Code and Codex
- Fetch and display skills for Codex sessions
- Collaboration mode logging for Codex startup
- Tag-driven npm publish workflow via GitHub Actions (Trusted Publishing)

### Changed
- Unified mode system — removed ApprovalPolicy, simplified SandboxMode
- Codex: use native ApprovalPolicy and collaboration_mode API
- Extracted permission/sandbox mode mapping helpers

### Fixed
- Refresh Claude OAuth token for usage API
- Correctly map bypassPermissions in Codex session list
- Expose Codex collaborationMode as permissionMode in session list
- Emit synthetic tool_result after Codex approve/reject/answer
- Plan approval race condition

## [0.2.0] - 2026-02-22

### Added
- Prompt history backup & restore via Bridge Server
- `BRIDGE_HIDE_IP` option to mask IP addresses in QR code and logs
- Multiple image attachments per message support
- i18n push notifications with per-device locale (English/Japanese)
- ExitPlanMode special handling for push notifications
- Session-targeted push notification improvements with markdown code blocks

### Fixed
- Clear-context session switch and routing stability

### Changed
- Updated `@anthropic-ai/claude-agent-sdk` 0.2.29 → 0.2.50
- Updated `@openai/codex-sdk` 0.101.0 → 0.104.0

## [0.1.1] - 2025-06-17

### Changed
- Prepared metadata for public release and npm publish

## [0.1.0] - 2025-06-17

### Added
- Initial release
- WebSocket bridge between Claude Code CLI / Codex CLI and mobile devices
- Multi-session management
- Tool approval/rejection routing
- QR code connection with mDNS auto-discovery
- Push notifications via Firebase Cloud Messaging
- API key authentication support
