# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.106.2] - 2026-07-18

### Changed
- Require Bridge 1.67.3 for the latest Codex goal history replay behavior.

### Fixed
- Open Markdown file links in File Peek, and show a copyable error when a link cannot be opened or is unsupported.

## [1.106.1] - 2026-07-16

### Changed
- Refresh app store screenshots.
- Require Bridge 1.67.1 to suppress all approved Codex auto-review notifications consistently.

### Fixed
- Keep running-session pin actions aligned to the right edge when status details are shown.

## [1.106.0] - 2026-07-16

### Added
- Add persistent pinning for sessions and projects, with pinned items prioritized in session lists.

### Changed
- Preserve the current reading position while new message content streams into an active session.
- Reduce unnecessary background refresh work and handle hidden app lifecycle transitions consistently.
- Require Bridge 1.67.0 for the latest session resource lifecycle and Codex history fixes.

### Fixed
- Restore the compact pin control layout on session cards and project headers.

## [1.105.2] - 2026-07-16

### Fixed
- Prevent repeated Codex settings metadata chips from appearing when reopening a session.

## [1.105.1] - 2026-07-16

### Changed
- Require Bridge 1.66.2 for the latest Codex app-server dialog, warning, review, and typed form handling.

### Fixed
- Handle Codex tool suggestion dialogs consistently in active chats and session cards, including installation and authentication flows.
- Preserve typed Codex and MCP question responses, optional fields, multi-select values, and label/value mappings across chat and session-card answers.
- Classify Codex usage windows by duration so weekly-only limits are displayed correctly.

## [1.105.0] - 2026-07-16

### Added
- Add Codex Effort and Speed controls to active sessions and the new-session flow, including slider-based Effort selection and a Fast mode toggle.
- Add compact and advanced Codex settings layouts with animated transitions and current Model, Effort, and Speed context.

### Changed
- Keep frequent Effort and Speed controls prominent while moving model selection into the advanced Codex settings flow.
- Require Bridge 1.66.0 for live Codex Speed changes and settings synchronization.

### Fixed
- Correct Fast mode availability and refine the compact settings layout, advanced selector, and Effort presentation.
- Remove Android-specific wording from iOS store descriptions.

## [1.104.1] - 2026-07-14

### Fixed
- Increase the machine menu touch target to the platform minimum interactive size.
- Refine supporter plan ordering, labels, and responsive text layout.

## [1.104.0] - 2026-07-14

### Added
- Add persisted Codex Goals with `/goal` completion and compact controls to edit, pause, resume, and clear the active goal.

### Changed
- Require Bridge 1.65.0 for Codex Goal state synchronization.

## [1.103.0] - 2026-07-12

### Added
- Add GPT-5.6 Max and Ultra reasoning options with localized descriptions.

### Changed
- Require Bridge 1.64.0 for the latest Codex app-server reasoning metadata.
- Preserve model-advertised reasoning effort values so future levels remain selectable.

## [1.102.0] - 2026-07-12

### Added
- Add lower-priced $2.99 monthly and one-time Snack Support options.

## [1.101.4] - 2026-07-11

### Changed
- Require Bridge 1.63.6 for the latest streaming, connection metadata, permission, and input reliability improvements.

### Fixed
- Show a localized, accessible fallback when part of the interface fails to render in a release build without exposing error details.
- Handle IPv6 Bridge endpoints consistently across connection and display flows.
- Handle malformed AskUserQuestion payloads without breaking the active session UI.
- Prevent answered approvals from reappearing after session state is restored.
- Show Codex permission settings derived from the active runtime configuration.

## [1.101.3] - 2026-06-11

### Changed
- Refresh store release notes.

### Fixed
- Apply the Chinese system font fallback only when the app or device locale is Chinese.
- Use the bundled Fastlane executable for store metadata upload in release automation.

## [1.101.2] - 2026-06-06

### Changed
- Require Bridge 1.63.4 for the latest persistent service compatibility fixes.
- Add an Agents setting to show Codex only, Claude only, or both providers in new sessions and session filters.
- Add a list display mode for Recent Sessions alongside project grouping.

### Fixed
- Keep Settings working on Flutter Web by avoiding direct `dart:io` platform access.
- Avoid showing the Claude login card for non-Claude authentication errors.
- Preserve factual Codex recent-session settings instead of overlaying saved defaults.

## [1.101.1] - 2026-05-29

### Fixed
- Show the effective Codex reasoning effort in the session mode bar when using the default effort.

## [1.101.0] - 2026-05-29

### Added
- Support switching Codex models from an existing session.

### Changed
- Require Bridge 1.63.0 for Codex runtime model switching.
- Compact the Codex session mode bar and use neutral model chip styling.
- Refresh store release notes.

### Fixed
- Show a Bridge update hint when older Bridge versions do not support session model switching.

## [1.100.1] - 2026-05-27

### Changed
- Require Bridge 1.62.1 for Codex permission mode preservation when toggling Plan mode.

### Fixed
- Preserve Codex Auto Review when switching a running session into Plan mode.

## [1.100.0] - 2026-05-27

### Added
- Group recent sessions by project with per-project collapse state and incremental history loading.

### Changed
- Require Bridge 1.62.0 for project-scoped recent session pagination.

## [1.99.4] - 2026-05-26

### Fixed
- Preserve standard desktop `Ctrl+V` text paste while still probing the clipboard for pasted images.
- Handle Windows-style project paths when displaying project names.

## [1.99.3] - 2026-05-26

### Changed
- Upgrade the app toolchain to Flutter 3.44.0 and Dart 3.12.0.
- Pin Shorebird 1.6.105 through mise for release and patch builds.

### Fixed
- Keep iOS and macOS plugin integration on CocoaPods so Darwin builds work with current plugin manifests.

## [1.99.2] - 2026-05-22

### Fixed
- Support macOS dictation tools that paste through native AppKit shortcuts, including Wispr Flow.
- Allow image paste shortcuts to work when Caps Lock is remapped to Control on macOS.

## [1.99.1] - 2026-05-20

### Changed
- Require Bridge 1.61.1 for Codex model reasoning capability metadata.

### Fixed
- Allow Codex sessions to select `none` reasoning effort while hiding unsupported `minimal` effort.
- Preserve the visible default Codex model when starting a session without manually reselecting it.

## [1.99.0] - 2026-05-18

### Added
- Load Claude effort capabilities from the installed SDK through Bridge so session options match the available CLI capabilities.

### Changed
- Require Bridge 1.61.0 for SDK-driven Claude effort capability metadata.
- Refresh store release notes and screenshots.

### Fixed
- Wait for machine manager initialization before auto-connecting to the default machine.

## [1.98.2] - 2026-05-17

### Changed
- Require Bridge 1.59.3 for clearer Codex CLI setup errors.

### Fixed
- Show a clearer setup error when the Codex CLI is unavailable.
- Improve markdown emphasis styling in chat messages.

## [1.98.1] - 2026-05-16

### Changed
- Require Bridge 1.59.2 for multi-client user message synchronization.

### Fixed
- Display user messages received from another connected client or promoted from a Codex queued steer.

## [1.98.0] - 2026-05-15

### Added
- Add official Codex permissions modes, including Auto-review, Full access, and config-driven Custom.

### Changed
- Require Bridge 1.59.0 for Codex permissions mode synchronization.

## [1.97.0] - 2026-05-13

### Added
- Add experimental Linux desktop release support.
- Add an in-app action to copy the Codex CLI command for joining the current session.

### Changed
- Require Bridge 1.58.0 for experimental Codex shared app-server co-presence.
- Refresh store release notes.

### Fixed
- Keep copied Codex join commands scoped to the current session.
- Hide the Codex join command until the session can be resumed from Codex CLI.
- Keep Linux release cargokit precompiled binary overrides scoped to release builds.

## [1.96.1] - 2026-05-12

### Fixed
- Preserve saved SSH private keys when editing machines.
- Preserve jump host password and private key credentials when editing machines.
- Show saved private key status in the machine editor and localize related copy.
- Avoid keyboard overlap in bottom sheets with text fields.

## [1.96.0] - 2026-05-09

### Added
- Support mentioning directories from file mention completions.

### Changed
- Improve file mention filtering so path-based fuzzy queries can match full paths.
- Require Bridge 1.57.0 for directory mention candidates.

## [1.95.0] - 2026-05-09

### Added
- Add command completion scoring in the composer.
- Add configurable code font settings.

### Changed
- Refresh store release notes.

### Fixed
- Reduce jank when rendering long markdown history.

## [1.94.0] - 2026-05-08

### Added
- Add a focus mode for reviewing Git diffs.

### Changed
- Require Bridge 1.56.2 for the latest Bridge documentation and compatibility metadata.

### Fixed
- Tunnel Bridge WebSocket connections through SSH jump hosts.
- Avoid false project path error inference in session output.

## [1.93.0] - 2026-05-07

### Added
- Show the connected Bridge name in the session list.

### Changed
- Require Bridge 1.56.1 for the latest Git diff compatibility fixes.

### Fixed
- Clear stale Bridge connection state when switching machines.
- Support Bridge actions that use SSH private keys.
- Pass jump host passwords in the SSH smoke test.
- Handle non-ASCII untracked file paths in diff views.

## [1.92.0] - 2026-05-06

### Added
- Add SSH jump host credential support for remote machine connections.

### Fixed
- Keep Codex approval defaults separate from Claude approval defaults.

## [1.91.2] - 2026-05-05

### Fixed
- Use Sparkle's probe API for macOS update checks.
- Localize remaining mobile UI strings.

## [1.91.1] - 2026-05-05

### Changed
- Require Bridge 1.55.1 for Explorer file listings in non-Git projects.
- Localize Git unavailable tip copy across supported languages.

### Fixed
- Update Explorer empty state copy now that non-Git file listings are supported.

## [1.91.0] - 2026-05-05

### Added
- Add SSH jump host support for remote machine connections.
- Add a Google search action to the text selection menu.
- Render Codex plan updates as structured todo lists.

### Changed
- Require Bridge 1.55.0 for Codex plan update rendering.

### Fixed
- Clear stale pending session cards after session state changes.

## [1.90.0] - 2026-05-04

### Added
- Show queued user input on session cards.

### Changed
- Require Bridge 1.53.2 for restored image history and Codex resume compatibility.
- Refresh store release notes.

### Fixed
- Restore user images when loading session history.

## [1.89.2] - 2026-05-03

### Changed
- Require Bridge 1.53.1 for the latest Bridge compatibility fixes.

### Fixed
- Preserve existing prompt text when using voice input.

## [1.89.1] - 2026-05-03

### Fixed
- Prevent duplicate review prompts from appearing.

## [1.89.0] - 2026-05-03

### Added
- Surface Message History directly in the workspace session toolbar.

## [1.88.0] - 2026-05-02

### Added
- Add Codex conversation rewind and fork session recovery.

### Changed
- Require Bridge 1.53.0 for Codex rewind and fork session recovery.
- Show Codex rewind as a confirmation dialog and limit fork actions to the final Codex response.

### Fixed
- Localize Rewind and Fork UI copy across supported languages.

## [1.87.0] - 2026-05-02

### Added
- Add Codex conversation rewind support.
- Add image file previews from file peek actions.

### Changed
- Require Bridge 1.52.0 for conversation rewind and image file preview support.

### Fixed
- Restore session project actions from history.

## [1.86.1] - 2026-05-02

### Changed
- Refresh store release notes and screenshots for the latest mobile release.

### Fixed
- Localize queued message and reconnect copy across supported languages.
- Merge prompt history entries that share the same display text.
- Expand the workspace resize handle hit target.

## [1.86.0] - 2026-05-02

### Added
- Add session badges for Git dirty status and unsynced branches.
- Add a file peek action to the diff menu.
- Add separate Auto Rename settings for Claude and Codex sessions.

### Changed
- Require Bridge 1.51.0 for Git session badge metadata.
- Enable Auto Rename by default for new settings.

### Fixed
- Refresh the latest Bridge version after user actions.
- Improve the disconnect flow when a Bridge update is available.
- Prevent session name labels from overflowing.

## [1.85.0] - 2026-05-02

### Added
- Add an Auto Rename setting that names new sessions after the first agent response.

### Changed
- Require Bridge 1.50.0 for automatic session renaming.

### Fixed
- Keep add-directory suggestions above the keyboard.

## [1.84.0] - 2026-05-01

### Added
- Add Bridge-managed Prompt History with multi-Bridge sync, favorites, deletion, usage counts, and persistent filters.
- Add Prompt History migration controls for replacing Bridge history from old-format local history.
- Add sync status details that group registered machine names and endpoints by Bridge identity.

### Changed
- Require Bridge 1.49.0 for Prompt History sync.
- Remove Prompt History search and project chips in favor of persistent filter controls.
- Remove the old app-database backup and restore controls now that Bridge owns Prompt History.

### Fixed
- Record project paths for newly created prompt history entries.
- Hide project labels in prompt history rows.

## [1.83.2] - 2026-05-01

### Changed
- Keep the saved machine primary action focused on connecting, with Bridge updates available from the machine menu.
- Let Bridge update checks use the latest published npm Bridge version in addition to the app's minimum recommended version.
- Show current and latest Bridge versions in connection settings, including retry states when the latest version check fails.

### Fixed
- Refresh machine health and version status after failed Bridge update attempts so stale connection state is not left on screen.

## [1.83.1] - 2026-04-30

### Changed
- Put the App Icon entry first in General settings and keep language-related controls grouped together.
- Point Korean public links and store metadata at the localized documentation pages.

### Fixed
- Clarify the App Icon settings subtitle with the current device type instead of showing the Supporter perk message in the settings list.

## [1.83.0] - 2026-04-30

### Added
- Add Korean app localization, authentication help, store metadata, and store screenshots.

### Changed
- Require Bridge 1.48.0 for Korean push notification localization.

## [1.82.0] - 2026-04-30

### Added
- Add a compact text density setting that can reduce in-app text scale while preserving the system text scale.
- Add Simplified Chinese App Store metadata and screenshots.

### Fixed
- Make single Ask User Question prompts scrollable when their content is long.

## [1.81.1] - 2026-04-30

### Fixed
- Show the Bridge version normally when update setup is unavailable but the connected Bridge is already current.
- Report missing remote `npx` during Bridge start instead of waiting for the start health check to time out.

## [1.81.0] - 2026-04-30

### Added
- Let the Bridge update banner open connection settings directly.
- Show setup guidance for Bridge updates when SSH or auto-start setup is missing.

### Changed
- Require Bridge 1.47.2 and label it as the recommended Bridge version.
- Improve machine card Bridge version wrapping in workspace layouts.

### Fixed
- Shorten Bridge start health checks while keeping update waits tolerant of npm startup time.

## [1.80.0] - 2026-04-30

### Added
- Add setup-based Bridge update actions from the machine card and connection settings
- Show Bridge version status in connection settings, including update availability and setup requirements

### Changed
- Require Bridge 1.47.1 so setup service restarts use non-interactive `npx --yes`
- Hide Bridge update actions unless the connected machine is online, SSH-configured, and running an older Bridge version

### Fixed
- Hide the server stop action when the Bridge server is not running
- Verify health and refreshed version after remote Bridge start or update before reporting success

## [1.79.2] - 2026-04-29

### Fixed
- Restore the first sent Codex message when reopening a session after cached history sequence gaps.

## [1.79.1] - 2026-04-29

### Fixed
- Use production APNs entitlements for iOS release builds and verify the signed IPA before TestFlight upload.

## [1.79.0] - 2026-04-28

### Added
- Add runtime session state caching so active sessions can reopen without refetching full history
- Add delta-based session history refresh for lower-bandwidth session screen entry
- Add offline pending actions for starting and resuming sessions
- Add offline Codex chat input queuing with base sequence conflict protection
- Add a scroll-first Git diff view mode

### Changed
- Require Bridge 1.47.0 for history delta sync and strict input acknowledgement support
- Improve offline pending session and queued input UX across Running and session screens

### Fixed
- Keep pending delivery input visible across session screen recreation and Running list refreshes
- Separate pending delivery input handling from the Bridge-managed Codex conversation queue
- Restore delivered pending input bubbles after reconnect acknowledgements or assistant responses
- Dedupe restored chat history entries

## [1.78.0] - 2026-04-27

### Added
- Add keyboard shortcuts for completion navigation in the chat composer
- Add keyboard shortcuts for prompt editing in the chat composer

### Fixed
- Pad macOS workspace pane actions so controls do not overlap window chrome
- Remove the empty native toolbar from the macOS app window

## [1.77.0] - 2026-04-27

### Added
- Add desktop context menus for session cards, user messages, and Git diff actions

### Fixed
- Clear the workspace session pane after stopping a session

## [1.76.0] - 2026-04-27

### Added
- Add Codex plugin completions to the `@` mention overlay and send selected plugins as `plugin://...` mentions
- Add Codex plugin metadata parsing and composer highlighting for plugin mentions

### Changed
- Require Bridge 1.46.0 for Codex plugin completion support
- Keep Codex apps under `$` and plugins under `@`, with updated input helper tooltips
- Relax review appeal eligibility and improve appeal action ordering

### Fixed
- Handle Codex plugin metadata whose starter prompts arrive as arrays without showing parse errors
- Restore Codex image generation history rendering

## [1.75.0] - 2026-04-25

### Added
- Recommend the macOS native app when the iOS app is running on Mac
- Add a settings link to the macOS GitHub Releases download page for iOS-on-Mac users

### Changed
- Promote the macOS desktop app out of beta in README documentation

## [1.74.0] - 2026-04-25

### Added
- Add a usage display mode toggle for switching how usage limits are shown

### Changed
- Improve completion keyboard navigation in the chat composer

### Fixed
- Enable Android voice input by declaring the required speech recognition permissions and service query
- Avoid macOS app bar overlap with window controls

## [1.73.0] - 2026-04-25

### Added
- Add a dedicated Codex image generation UI that keeps generated images visible by default

### Changed
- Require Bridge 1.45.0 for Codex app-server image generation result support

## [1.72.1] - 2026-04-25

### Fixed
- Prevent older apps from showing unknown-message errors when connected to a Bridge with Codex queue support

### Changed
- Require Bridge 1.44.1 for Codex conversation queue compatibility handling

## [1.72.0] - 2026-04-25

### Added
- Add Codex conversation queue support while a Codex turn is running
- Add queued Codex message steering, editing back into the composer, and cancellation controls

### Changed
- Require Bridge 1.44.0 for synchronized Codex conversation queue support
- Remove Codex failed-message tap retry behavior in favor of the Bridge-managed queue flow

## [1.71.1] - 2026-04-25

### Fixed
- Keep the workspace right pane synced with the selected center session and restore each session's last tool pane when returning to it

## [1.71.0] - 2026-04-25

### Added
- Add Codex additional writable directories to new sessions so another project can be available alongside the selected project
- Remember manually added directories and show them as suggestions next time

### Changed
- Compact the Codex additional directory controls and move explanatory text into the info tooltip
- Require Bridge 1.43.1 for Codex additional writable directory support and latest Codex approval mode handling

### Fixed
- Keep Codex approval mode consistent when resuming recent sessions by using the latest new-session defaults
- Hide Codex approval mode on Recent Sessions cards while keeping it visible for running sessions

## [1.70.3] - 2026-04-24

### Fixed
- Enable Sparkle's sandboxed installer launcher so macOS self-updates can complete installation and relaunch
- Preserve the full Sparkle appcast URL in macOS release builds

### Changed
- Add more detailed macOS Sparkle update diagnostics and local validation scripts

## [1.70.2] - 2026-04-24

### Fixed
- Constrain modal bottom sheet height on macOS so sheets no longer extend past the workspace toolbar

## [1.70.1] - 2026-04-24

### Fixed
- Use Sparkle's native update flow for macOS update actions when the signed appcast is configured

### Changed
- Add Sparkle update diagnostics to help identify why native update probes fall back to GitHub Releases

## [1.70.0] - 2026-04-24

### Added
- Add Codex Auto Review as an approval option in the new session flow

### Changed
- Update Codex approval display to show Auto Review consistently in session status
- Require Bridge 1.42.0 for the latest Codex Auto Review session handling

## [1.69.0] - 2026-04-24

### Added
- Add Sparkle-based in-app updates for macOS releases
- Publish signed Sparkle appcasts to GitHub Pages from the macOS release workflow

## [1.68.2] - 2026-04-21

### Changed
- Refine the iPad App Store screenshot messaging to better emphasize the tablet-optimized, IDE-like workspace experience

### Fixed
- Localize the new workspace empty states and left-pane actions in Japanese and Simplified Chinese

## [1.68.1] - 2026-04-21

### Changed
- Refresh the iPad App Store screenshots to match the latest workspace flows and orientations

### Fixed
- Avoid highlighting the running session in the narrow mobile layout when opening a session
- Show the Hide sessions button in the mock iPad workspace preview scenarios
- Increase the top clearance for macOS single-pane layouts so the window controls no longer crowd the session chrome

## [1.68.0] - 2026-04-20

### Added
- Add center-pane overlay navigation and right-pane session gallery support for the adaptive workspace on iPad and macOS
- Add native-feeling macOS workspace chrome that integrates the transparent titlebar with pane headers and session toolbars

### Changed
- Move narrow macOS layouts to render app chrome below the window controls while keeping adaptive workspace controls aligned in the titlebar zone

### Fixed
- Keep macOS window dragging limited to explicit top chrome drag areas so text selection and copy interactions work normally
- Refine macOS pane spacing, button grouping, and toolbar alignment to avoid overlap with the traffic lights in both wide and narrow layouts

## [1.67.0] - 2026-04-20

### Added
- Add an adaptive workspace layout that expands into 2-pane and 3-pane views on iPad and macOS
- Add dedicated iPad App Store screenshot scenarios for the workspace, approval context, and dark workspace flows

### Changed
- Split narrow mobile navigation from the multi-pane workspace shell so phone and tablet layouts behave independently
- Refresh the iPad screenshot capture workflow to target landscape layouts and keep the generated store assets aligned with the new workspace scenarios

### Fixed
- Improve pane headers, session highlighting, and tool-pane resizing so the multi-pane workspace is stable in daily use
- Prevent Tab indentation from firing during Japanese IME composition in the message composer

## [1.66.2] - 2026-04-20

### Fixed
- Preserve provisioning-derived entitlements when re-signing the macOS release app so GitHub Release builds can still save API keys in secure storage

## [1.66.1] - 2026-04-19

### Changed
- Update the macOS release workflow to provision Developer ID signing assets through App Store Connect before packaging the app

### Fixed
- Restore GitHub Release macOS builds by embedding the required provisioning profile in the signed app bundle
- Re-sign the released macOS app with hardened runtime and a secure timestamp so notarization succeeds

## [1.66.0] - 2026-04-17

### Added
- Add Claude Auto mode to the app's permission mode selection UI

### Changed
- Reorder Claude permission modes to Default, Accept Edits, Plan, Auto, and Bypass All

### Fixed
- Fall back to Default mode and resync the UI when Claude Auto mode is unavailable in the current environment

## [1.65.0] - 2026-04-17

### Added
- Add Codex profile selection to the New Session sheet

### Changed
- Refine the Codex profile precedence note copy and spacing so it reads as help text for the Profile field

### Fixed
- Keep Explorer history available until the session is explicitly stopped
- Preserve Explorer history when reopening an existing session

## [1.64.1] - 2026-04-17

### Fixed
- Prevent File Peek from crashing on TypeScript files when syntax highlighting hits missing upstream documentation comment grammars
- Show a clearer error when File Peek opens a symbolic link that points to a directory

## [1.64.0] - 2026-04-17

### Added
- Add Claude Opus 4.7 to the available model list when starting a new session

### Changed
- Improve Explorer navigation by keeping file history focused on recent open files
- Open file peek automatically after jumping to a file selected from Explorer history

## [1.63.0] - 2026-04-16

### Added
- Add a diff file list sheet and direct navigation between changed files
- Keep diff file actions available while git content is still loading

### Changed
- Remove in-app plan approval editing from the plan review flow

### Fixed
- Show structured MCP approval details and route question-style MCP approvals through the approval UI

## [1.62.0] - 2026-04-16

### Added
- Add a home support banner that can promote the Support entry point for eligible users

### Changed
- Route the home support banner through Settings, auto-scroll to the Support section, and highlight the in-app entry point
- Add a debug toggle to force-show the home support banner for UI verification

### Fixed
- Lazy-initialize FCM handlers to avoid startup issues in the mobile app

## [1.61.4] - 2026-04-15

### Changed
- Update public-facing Claude branding across docs, store metadata, and generated marketing assets while keeping Claude Code references where CLI compatibility matters

### Fixed
- Remove the remaining Claude usage OAuth path from the Bridge-backed mobile flow and keep Claude billing and usage links pointed at official pages
- Add Privacy Policy and Apple Standard EULA links to the Support purchase flow and metadata
- Restore the Support section position so it appears just above Spread in Settings
- Keep Support and App Icon settings visible without an active Bridge connection

## [1.61.3] - 2026-04-15

### Fixed
- Add Privacy Policy and Apple Standard EULA links to the Support purchase flow and metadata

## [1.61.2] - 2026-04-15

### Fixed
- Restore the Support section position so it appears just above Spread in Settings

## [1.61.1] - 2026-04-15

### Fixed
- Keep Support and App Icon settings visible without an active Bridge connection

## [1.61.0] - 2026-04-14

### Added
- Add Supporter purchases with one-time and monthly support flows via RevenueCat
- Add a dedicated Support screen with purchase actions, restore, and support history summaries
- Add alternate app icon selection as a Monthly Supporter perk on iOS and Android
- Add localized supporter documentation and Apple review checklist for purchase submission

### Changed
- Refine supporter copy, labels, and package presentation across settings and purchase flows
- Update support wording from Coffee to Drink to match the current product presentation

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
