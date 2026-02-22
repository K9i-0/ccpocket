# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.16.1] - 2025-06-22

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
