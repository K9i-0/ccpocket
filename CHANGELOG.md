# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.23.0] - 2026-02-25

### Changed
- Session list filters unified into a single SessionFilterBar with active filter highlighting
- Filtering and search now handled server-side for better performance and consistent pagination
- Added 300ms debounce for search input and skeleton loading on filter switch

## [1.22.0] - 2026-02-24

### Added
- Session list filters: filter by provider (Claude/Codex) and named/unnamed sessions, with name search
- Shorebird update track switching: change between stable and staging tracks via hidden debug screen

### Changed
- Shorebird auto_update disabled; app now manually controls update checks with track selection

### Fixed
- Update app name and subtitle metadata for App Store resubmission

## [1.21.2] - 2026-02-24

### Changed
- Recommend `npx @ccpocket/bridge@latest` in setup guide and tutorials to ensure users always run the latest Bridge Server

## [1.21.1] - 2026-02-24

### Fixed
- Android 16KB page size compliance: use 16KB-aligned irondash fork for Google Play
- Remove brand names from subtitle for App Store guideline 4.1

## [1.21.0] - 2026-02-24

### Added
- Session archive: hide historical sessions from the session list via long-press menu
- Push notification privacy mode: hides project names, session names, and message content
- Session name displayed in push notification titles

### Fixed
- Duplicate submit button on single multi-select AskUserQuestion

## [1.20.0] - 2026-02-23

### Added
- GitHub repository link and changelog page in About section
- Setup guide updated to recommend `npx @ccpocket/bridge`

### Fixed
- Rename result message no longer triggers false error display
- Session name chip color adjusted for dark theme
- Elapsed time right-aligned in session cards
- Plan approval header layout and tap target improved

### Changed
- Redesigned session cards with compact inline session name and project badge
- Refined session name and project badge to use cohesive rounded chip styles

## [1.19.0] - 2026-02-23

### Added
- Session rename support for Claude Code and Codex (rename from chat AppBar or session list)
- Codex plan approval UI optimization with dedicated mock scenarios

### Changed
- Redesigned session cards: compact layout with inline session name and project badge
- Refined session name chip and elapsed time alignment in session cards
- Improved plan approval header layout and tap targets

### Fixed
- Rename result no longer shows false error bubble in chat (handle rename_result message)
- Codex session chat input now restores text draft correctly
- Plan approval button text no longer clipped
- Claude OAuth token refresh for usage API
- Session name chip color adjusted for dark theme

## [1.18.0] - 2026-02-22

### Added
- Codex app-server native collaboration_mode API integration (Plan mode)
- Codex plan approval flow: streaming plan text, approve/reject with feedback
- Codex AskUserQuestion routing for multi-question and single-question flows
- Talker logging for Bridge service errors and session state transitions
- Collaboration mode logging in Codex startup and turn/start

### Changed
- Bridge Server 1.0.0: Codex process rewritten for app-server protocol
- Unified permission/sandbox mode system across Claude and Codex sessions
- Replaced custom plan gate with native collaboration_mode in turn/start

### Fixed
- Permission mode preserved when re-entering Codex sessions from session list
- AskUserQuestion correctly routed in Codex history replay (no longer shows as generic approval)
- Plan Accept now transitions server out of Plan mode (collaborationMode always sent)
- Zombie approval dialogs no longer resurrect on history replay (synthetic tool_result)
- Plan approval race condition: queued input when inputResolve not ready

## [1.16.1] - 2026-02-22

### Added
- Push notification i18n: per-device locale support (English/Japanese) with Bridge-side translation
- ExitPlanMode push notification shows "Plan ready" / "プラン完成" instead of raw tool name
- "Update notification language" button in settings
- Plan approval enhancements: inline plan editing, feedback text field, approve-with-clear-context
- Multiple image attachments per message with draft persistence
- Multi-question AskUserQuestion: summary page, step indicators, improved PageView UX
- Prompt history backup & restore via Bridge Server
- Usage section: in-memory cache and animated gauge
- Markdown code block highlight and copy UX improvements
- `BRIDGE_HIDE_IP` option to mask IP addresses in Bridge Server

### Changed
- Redesigned Session List UI cards and filter chips
- Redesigned running session cards and New Session sheet (Graphite & Ember aesthetic)
- Refined theme: crisp monochrome base with vibrant provider accents
- Connection screen: unified new connections via MachineEditSheet (removed text fields)
- Debug bundle button moved to status indicator long press
- Removed swipe queue prototype

### Fixed
- Clear-context session switch and routing stability
- Hardcoded Japanese strings replaced with AppLocalizations
- Splash screen background set to black for neon icon visibility
- Segmented toggle and ChoiceChip contrast with onPrimaryContainer

## [1.14.0] - 2025-06-19

### Added
- iOS PrivacyInfo.xcprivacy for App Store compliance
- Android adaptive icon and dedicated notification icon
- Push notification enhancements: per-server settings, enriched content, auto-clear on launch

### Changed
- Migrated FCM auth from shared secret to Firebase Anonymous Auth
- Hardened Firebase security rules for store release

### Fixed
- Android heads-up notifications via FCM priority and channel settings

## [1.13.0]

### Added
- Inline diff display in ToolUseTile for Edit/Write/MultiEdit tools
- Base64 image extraction from tool_result content blocks
- Image attachment indicator on restored session messages

### Fixed
- History snapshot no longer overwrites live messages on idle/resume
- Session status and lastMessage propagate to session list in real-time

## [1.12.0]

### Added
- Message image viewer screen with session ID resolution
- Message history with jump support for Codex sessions
- Permission mode switching UI with color badges
- Quick approve/reject from session list cards
- Pending permission display in session_list with split approval UI by tool name

### Fixed
- Restored permissionMode/sandboxMode when re-entering running sessions
- Diff screen file name display improvements

## [1.9.0]

### Added
- i18n support with language selection in settings
- Slash command XML tags formatted as CLI-style display
- Skeleton loading for recent sessions

### Fixed
- History JSONL lookup for worktree sessions
- firstPrompt/lastPrompt extraction from JSONL for all recordings

## [1.8.0]

### Added
- Session recording and replay mode
- ReplayBridgeService for offline playback
- ChatTestScenario DSL for testing
- Debug screen with talker logging
- Message history redesigned as scrollable sheet with scroll-to support
- Recording metadata with session summary

### Fixed
- Replay stuck on starting state
- User message UUID backfill for rewind support

## [1.6.0]

### Added
- Setup guide for first-time users
- Image cache with extended_image
- Prompt history improvements
- Swipe queue approval screen prototype

### Fixed
- multiSelect single question submit button
- Duplicate messages when history received multiple times

## [1.4.0]

### Added
- Usage monitoring for Claude Code and Codex
- Prompt history with sqflite persistence
- Horizontal scroll sync across diff hunk lines
- Plan approval layout improvements
- Skill name display instead of full prompt in chat
- Session deep link (`ccpocket://session/<sessionId>`)

### Fixed
- Preserved original timestamps in restored session history
- Content parsing hardened against string format
- String content handling in JSONL user messages after interrupt

## [1.0.0]

### Added
- Initial release
- Real-time chat with Claude Code via WebSocket bridge
- Multi-session management (create, switch, resume, history)
- Tool approval/rejection from mobile
- Multiple connection methods: saved machines, QR code, mDNS auto-discovery, manual input, deep link
- Diff viewer with syntax highlighting
- Gallery for session images and screenshots
- Voice input
- Machine management with SSH remote start/stop/update
- Permission modes: Accept Edits, Plan Only, Bypass All, Don't Ask, Delegate
- AskUserQuestion with multi-question batch support
- Session-scoped tool approval rules
- Bridge Server with multi-session support and stdio ↔ WebSocket translation
