# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.60.0] - 2026-04-11

### Added
- Support always-allow approvals for MCP tool requests in Codex sessions

### Fixed
- Avoid async `BuildContext` access warnings in Claude and Codex session screens

## [1.59.0] - 2026-04-11

### Added
- Link Claude usage settings to the official billing and subscription pages from Settings

### Changed
- Upgrade Marionette Flutter integration to 0.5.0

### Fixed
- Deduplicate Codex approval "why" copy in the mobile UI

## [1.58.0] - 2026-04-08

### Added
- Align Codex approval UI with CLI (plan/apply mode labels and actions)

### Fixed
- Soften Codex plan continue label

## [1.57.1] - 2026-04-08

### Fixed
- Fix file peek detection not working on session screens (context.read → context.watch for FileListCubit)
- Add bare file path detection without backticks (BareFilePathSyntax)
- Refresh file list on tool results and pending session resolution

## [1.57.0] - 2026-04-08

### Added
- Enhance approval UI with permission details and push notifications

### Fixed
- Route McpElicitation through permission path for proper approval UI in Codex sessions
- Simplify approval bar UI
- Remove deprecated gpt-5.2-codex model from Codex model list

## [1.56.1] - 2026-04-08

### Fixed
- Preserve composer token highlight during IME composing

## [1.56.0] - 2026-04-07

### Added
- Token highlighting and Codex skill completion in composer
- Split slash and dollar completions for Codex

### Changed
- Tune token highlight colors in composer

### Fixed
- Preserve MCP elicitation approval type in Codex sessions

## [1.55.0] - 2026-04-04

### Changed
- Improve file peek detection using project file list

## [1.54.0] - 2026-04-02

### Added
- Explore file browser for navigating project files

## [1.53.0] - 2026-04-02

### Added
- Codex approval policy display in session cards and environment summary

### Fixed
- Preserve initial approval policy in Codex session UI
- Show "Changes" instead of project name in git diff mock AppBar

## [1.52.0] - 2026-04-01

### Changed
- Polish git diff screen: redesigned project header, swipe action backgrounds, and view mode segment control
- Refactored git screen layout for improved readability and usability

## [1.51.1] - 2026-03-31

### Fixed
- Enable Apple Keychain storage for API keys on iOS and macOS
- Support secure Bridge connections via `wss://` and `https://`

## [1.51.0] - 2026-03-30

### Added
- Git Operations UI: stage/unstage, commit, branch checkout, fetch/pull/push from the app
- Swipe-to-stage/unstage and swipe-to-revert (discard) on file headers
- Long-press context menu on file headers with Request Change flow
- Branch indicator chip with branch selector in Git Screen
- Remote status display with fetch/pull/push in bottom bar
- Revert (discard changes) support via swipe and bridge handler

### Changed
- Rename DiffScreen → GitScreen to reflect expanded scope
- Wrapped diff is now the default view
- Auto-refresh UI after push/commit operations

### Fixed
- Dismissible assertion error on Staged tab
- Mock loading, bottom bar layout, single line numbers, swipe control
- Clarify request change diff preview
- Unify hunk long-press actions

## [1.50.0] - 2026-03-29

### Added
- File Peek: tap file paths in assistant messages to preview file contents in a bottom sheet
- Partial path resolution: automatically resolve shortened paths (e.g. `lib/main.dart`) against the project file list, with a picker for ambiguous matches
- Syntax highlighting in File Peek matching the chat code block style
- Markdown raw/preview toggle (Tt button) in File Peek
- Copy @path button for pasting file references into chat input

### Changed
- Remove unused list_dir/DirListing infrastructure (directory browsing handled client-side)

## [1.49.0] - 2026-03-27

### Added
- Native localization for iOS and Android (en, ja, zh-Hans) — localized permission dialogs and OS-level UI
- Improve @mention file list with untracked files and relevance scoring
- Improve resume command copy for worktree and permission modes

### Changed
- Refactor new session sheet with dynamic tabs and provider-colored project tiles

## [1.48.1] - 2026-03-27

### Changed
- Upgrade Flutter SDK from 3.41.4 to 3.41.5 (Dart 3.11.3)
- Upgrade Shorebird from 1.6.88 to 1.6.91
- Update marionette_flutter to ^0.4.0 and remove git dependency override

## [1.48.0] - 2026-03-24

### Added
- Hide bridge-dependent settings sections when disconnected
- Hide AppBar on scroll with floating SliverAppBar in session list

### Changed
- Swap default Claude model order: opus 4.6 before opus 4.6[1m]
- Update expected Bridge Server version to 1.28.0

## [1.47.3] - 2026-03-22

### Changed
- Replace AnimatedList with reverse ListView.builder for chat message rendering

### Fixed
- Server entries in chat history now inherit timestamp from user messages
- Flaky unseen sessions test using future date far enough from buffer

## [1.47.2] - 2026-03-21

### Fixed
- Approval buttons styling and localization refinements
- Plan mode glow effect unified for Codex to match Claude
- iPad screenshots retaken with correct themes

## [1.47.1] - 2026-03-21

### Fixed
- Approval button overflow and split Claude/Codex labels

## [1.47.0] - 2026-03-21

### Added
- BottomSheet pattern for all mode selectors (Approval, Sandbox, Model, Effort/Reasoning) with localized descriptions
- Category subtitles in BottomSheets explaining each setting's purpose
- Provider-specific Sandbox descriptions (Codex defaults on, Claude defaults off)
- Localized effort/reasoning level descriptions (en, ja, zh)

### Changed
- Removed "Default" option from Model, Effort, and Reasoning selectors for clarity
- Model pre-selects first available model; Effort defaults to Medium; Reasoning defaults to High
- Claude Effort selector only appears when an Opus model is selected
- Unified branding to CC Pocket in store metadata

## [1.46.0] - 2026-03-21

### Added
- Mode descriptions displayed in new session sheet for better discoverability
- Simplified Codex session metadata and new session mode selection
- Plan mode toggle without restart when Codex session is idle

### Changed
- Localized mode descriptions and restored Claude mode grouping

### Fixed
- Cleared plan mode immediately after approval to prevent stale state
- Ignored placeholder model name on Codex session resume
- Fixed 14 failing tests from mode bar and session sheet changes

## [1.45.0] - 2026-03-20

### Added
- Redesigned session modes around Codex-style Execution and Plan controls
- Clarified approval dialog labels with explicit "Allow Once" and session-scoped approval wording

### Fixed
- Rolled back session mode changes locally when a Bridge mode update fails

## [1.44.1] - 2026-03-20

### Added
- Unified segmented button selection color styling in settings

### Fixed
- Safely displayed resolved Codex environment details on init
- Corrected macOS app update download URL resolution from GitHub Releases assets

## [1.44.0] - 2026-03-19

### Added
- Simplified Chinese (简体中文) language support
- Copy resume command from recent sessions for quick continuation
- Surface primary session settings (model, permission mode) in session view
- Codex approval amendment details display
- Codex sub-agent session metadata display
- Dedicated API key required error card with clear guidance
- Codex as the default entry point
- "More" button positioned inline at bottom-right with gradient fade

### Changed
- Reverted Flutter to 3.41.4 (Shorebird compatibility)
- Softened scroll-to-bottom button appearance
- Improved worktree section layout in new session sheet
- Removed prefixIcon from model dropdowns in new session sheet
- Removed copy button from API key required card
- Hidden terminal integration behind feature flag

### Fixed
- Chat scroll adjustment when keyboard appears
- Unseen session buffering stabilization
- Restart drafts preserved across session switch
- MCP images restored in Codex session history
- Codex app-server approval protocol alignment

## [1.43.0] - 2026-03-19

### Added
- Expandable summary text for long approval commands — tap "more"/"less" to toggle full command display
- gpt-5.4-mini model option for Codex sessions

### Fixed
- Unified tool approval button order and color semantics across Claude/Codex
- Reduced unnecessary rebuilds triggered by Android notification shade
- Prevented false auth error on long assistant messages
- Renamed "Experimental" label to "Preview" for App Store review safety

## [1.42.0] - 2026-03-18

### Added
- Graceful degradation for unsupported Bridge messages (older Bridge versions show update hint instead of errors)

### Changed
- Simplified auth error troubleshooting — clearer guidance with `claude` / `/login` instead of raw CLI commands
- Reframed remote login troubleshooting documentation
- Updated store screenshots to light theme with iOS app icon
- Updated feature graphic to light theme

### Fixed
- Store screenshots regenerated with correct bold font weight
- Suppressed "Invalid message format" error from older Bridge versions

## [1.41.2] - 2026-03-17

### Fixed
- "Invalid message format" error when opening a session screen (missing `refresh_branch` parser case)

### Changed
- License changed from MIT to FSL-1.1-MIT

## [1.41.1] - 2026-03-17

### Fixed
- Japanese IME composing Enter no longer sends message (was triggering send during kanji conversion)
- macOS app name changed from "ccpocket" to "CC Pocket" (Dock, menu bar, title bar)
- macOS app icon replaced from Flutter default to CC Pocket icon
- Keep planning input field on session card now correctly allows newlines on desktop
- Git branch display not refreshing when opening session or tapping branch chip

## [1.41.0] - 2026-03-17

### Added
- Keyboard shortcuts for macOS desktop (Cmd+N: new session, Cmd+K: search, Tab: toggle provider, Cmd+Enter: start/approve, Cmd+Shift+P: permission mode, Tab/Shift+Tab: indent/dedent)
- Auto-update check via GitHub Releases on macOS

## [1.40.0] - 2026-03-16

### Added
- macOS desktop support
- Desktop keyboard shortcuts (Enter to send, Shift+Enter for newline)
- Drag & drop image attachment on desktop
- Cmd/Ctrl+V clipboard image paste (with text paste fallback)
- macOS release workflow (Developer ID signing + notarization + DMG)

### Changed
- Disabled mobile-only features on desktop (QR scan, voice input, Shorebird OTA, store review)

## [1.39.0] - 2026-03-15

### Added
- Auth help screen with troubleshooting guide for authentication errors
- Graceful handling of non-git projects

### Fixed
- Dismiss keyboard on approval UI header tap and scroll
- Approval overlay scroll support (SingleChildScrollView)
- Content padding overflow prevention
- Chat content clipping above approval overlay
- Approval overlay keyboard layout refinement
- Bottom overlay height sync improvement

### Changed
- Refactored to unified BottomOverlayLayout for approval/question overlays

## [1.38.0] - 2026-03-13

### Added
- Bridge update banner when server version is outdated

### Changed
- Removed stop button from running session card

## [1.37.1] - 2026-03-13

### Changed
- Unified swipe actions to Slidable circular button style

## [1.37.0] - 2026-03-13

### Added
- iOS-style swipe actions with Slidable (replacing Dismissible)
- Dynamic line-number column width in diff view
- Line-number width test mock scenario

## [1.36.0] - 2026-03-13

### Added
- Codex Skills (Prompts) support with rich metadata and SkillUserInput
- Multi-image selection with 5-image limit for attachments
- Diff toggle compare mode with reversed slider direction
- 3-state expandable UI for tool use commands
- Tap-to-zoom for attached image thumbnails

### Changed
- Removed Claude auth login feature

### Fixed
- Sandbox state decoupled between Claude and Codex in new session sheet
- Provider-aware sandbox defaults and UI presentation
- Diff slider hint and overlay controls repositioned above mode selector

## [1.35.0] - 2026-03-11

### Added
- Unseen indicator for idle sessions with new activity (bold text + glow dot)
- Expandable project history in new session sheet (show more/less toggle)

### Fixed
- White screen crash caused by BlocProvider context mismatch in unseen sessions
- False-positive unseen indicators when sending messages or creating new sessions

## [1.34.0] - 2026-03-08

### Added
- Codex approval mock scenarios with improved section organization in mock preview

### Changed
- Codex MCP tool approval now displays as ApprovalBar instead of AskUserQuestion dialog

### Fixed
- Model label clipping in new session advanced section
- FAB hidden when keyboard is visible on session list
- Duplicate screen on session restart and rewind (sourceSessionId-based matching)
- Usage API auto-refresh cooldown to prevent excessive requests
- Codex permissionMode tracked as mutable state, updating correctly on restart
- Codex permissionMode forwarded on session resume for proper mode persistence
- Claude auth status flow improvements

## [1.33.0] - 2026-03-08

### Added
- Claude authentication flow in settings for API key management
- Extended FAB with "New" label and raised position for better accessibility

### Changed
- Improved error messages with errorCode and structured UI display

### Fixed
- Upgraded Flutter 3.41.2 → 3.41.4 to fix iOS launch crash
- Reset plan mode state after exit approval

## [1.32.0] - 2026-03-07

### Added
- In-app review eligibility tracking based on session completion

### Fixed
- Android autofill popup fully disabled with null autofillHints (empty list was insufficient)

## [1.31.0] - 2026-03-07

### Added
- In-app review prompts for user feedback
- Swipe gesture to switch between Claude and Codex in new session sheet
- Swipe-to-archive with confirmation dialog for recent sessions
- Dynamic model list delivery from Bridge Server

### Changed
- Model lists updated to latest available versions

### Fixed
- Image MIME type detection using magic bytes instead of file extension
- Android autofill on prompt input field
- App Store compliance: removed Apple trademark and OpenAI references from metadata

## [1.30.0] - 2026-03-03

### Added
- Project path validation with `BRIDGE_ALLOWED_DIRS` whitelist support
- Allowed directories display in New Session sheet for path input assistance
- API key SecureStorage migration (from SharedPreferences plaintext to FlutterSecureStorage)
- Dismissible swipe-to-delete for recent projects with confirmation dialog

### Changed
- Reactive project list: projects appear immediately on connect (fixed broadcast stream race condition)
- Project removal UI changed from long-press to swipe gesture

### Fixed
- Recent projects not appearing in New Session sheet on first connect (broadcast stream timing)

## [1.29.0] - 2026-03-02

### Added
- Claude model name display on session cards

### Changed
- Improved session card layout with better date/time alignment
- Improved bottom sheet visibility in dark mode
- Consolidated store screenshots from 8 to 7 scenarios

### Fixed
- Date/time alignment in session card meta row
- Bottom sheet background contrast in dark mode

## [1.28.0] - 2026-03-01

### Added
- Plan mode rotating light animation on session mode bar border
- Orbiting green light on session card status dot during Plan mode
- Slash command button in chat input (replaces dedent when input is empty)
- @ mention button in chat input bar
- New mock scenarios for store screenshots (Coding Session, Task Planning)

### Changed
- Redesigned session card UI with unified status colors and compact header
- Plan mode visuals: removed Plan text badge, orbit indicator limited to active states (Working/Needs You)
- Updated all store screenshots with latest UI

### Fixed
- Codex sandbox mode switching now works correctly
- Store screenshot extension error codes (valid range 0-16)
- Session card status dot clipping and Plan border padding

## [1.27.0] - 2026-02-28

### Added
- Full-screen image comparison viewer for diff screen
- Lazy loading, combined requests, and image caching for diff view

### Fixed
- Prevent app freeze when opening diffs with many images
- Handle session creation failure gracefully instead of hanging on loading screen

## [1.26.0] - 2026-02-28

### Added
- Floating SessionModeBar with transparency over chat list
- Glowing StatusLine indicator replacing dot-based StatusIndicator
- Indent settings for markdown bullet lists in chat input
- Image change support for git diff screen (auto-display up to 1MB, max 5MB)
- Display main repo branch name in worktree list
- Ask user free-text submit flow improvements
- Granular upload controls (screenshots/metadata/images) in metadata workflow

### Changed
- Reorganized session UI buttons and consolidated into overflow menu
- Compact header layout with updated icons for Message History and attach image
- Permission mode colors/order aligned with Claude Code CLI
- Compose script always syncs ja screenshots from en-US source
- Store screenshots updated with new session UI layout

### Fixed
- SessionModeBar horizontal centering and content width fitting
- BranchChip tap restored with Rename added to overflow menu
- Diff background color fill to full viewport width for short lines
- Recent sessions loading and archive UX improvements

## [1.25.0] - 2026-02-26

### Added
- 8 new store screenshot mock scenarios (approval list, multi-question, markdown input, named sessions, image attach, git diff, new session)
- Framed screenshots for iPhone/iPad in EN/JA with updated compose script

### Changed
- Store descriptions and README features rewritten to highlight mobile-first capabilities
- Store subtitle updated to "Coding AI in Your Pocket"

### Fixed
- File path display in diff screen
- StoreDiffWrapper resource leak (converted to StatefulWidget for proper disposal)

## [1.24.0] - 2026-02-25

### Added
- Show compacting status during auto compact
- Tooltips on filter bar and chat input buttons
- Screenshot banner for README

### Changed
- Rename session filter label from "All Providers" to "All AI Tools"

### Fixed
- Preserve user message images and timestamps across history refresh
- Serve user images via HTTP for session re-entry (images no longer disappear when returning to a running session)
- Persist Claude session settings across resumes
- Resume existing session on "Edit settings then start"
- Preserve queued input ordering

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
