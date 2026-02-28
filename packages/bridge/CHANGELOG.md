# Changelog

All notable changes to `@ccpocket/bridge` will be documented in this file.

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
