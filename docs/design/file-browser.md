# Unified file browsing

Explorer, chat paths (files and directories), and Git previews share one browser.
The browser is read-only; upload remains an explicit action and chat references
are inserted into the originating draft without sending it.

## Presentation and navigation

- Phones: full safe-area screen, a top toolbar for Close / Back / Parent / Add to chat.
- Adaptive workspace: a separate browser layer covers center and right, retaining
  the session list and all underlying chat/tool state. Wide browsers optionally
  show a directory/search list beside the preview. Narrow browsers drill down.
- Back traverses browsing history; Parent changes filesystem hierarchy; Close
  leaves the entire browsing session. Esc closes. Close is always the leading header action; Back is disabled at the start of history;
  content gestures remain available to scrolling, zooming, and 3D interaction.
- Each history location retains directory, query, selected file, and scroll
  position. A file opened from search returns to the same results. Width changes
  do not recreate the browser. Changing sessions or disconnecting closes it.
- Workspace background navigators cannot consume focus/back while browsing.

## Data and compatibility

Project file index powers multi-term, case-insensitive filename/path search.
Directory contents use list_directory(includeFiles: true, includeHidden: true)
so empty/unindexed/ignored directories are accessible. Its optional `files`
response field preserves existing directory-picker clients. An absent files
field or legacy unsupported_message produces an explicit update notice and
indexed fallback, never a false claim that a directory is empty. Requests have
unique IDs, timeout/retry, and late responses cannot replace a newer location.
The existing lexical + canonical allowed-root checks and symlink exclusion
apply equally to files. Browser hierarchy is bounded by the current project;
explicit absolute file links outside it can still be previewed through the
existing authorized read API but cannot traverse outside the browsing root.

Recent files are shared per Bridge instance/connection URL and project/worktree.
Navigation and search history belong to a browser instance, not a global list.
Search reports a truncated index rather than claiming complete results.

## Chat references

Capture a callback to the originating composer when opening the browser. Shell
bindings are session-scoped. Preserve existing draft and cursor; insert a quoted
@path for spaces, recognize that token as a reference, and never auto-send.
No callback means the Add to chat action is unavailable (e.g. standalone demo).

## Validation

Cover actual directory entries/permissions, backwards compatibility, stale and
missing responses, path resolution and directory links, search/history/scroll,
shared-history isolation, draft insertion, compact/wide layout, shell close/back
and session changes. Run targeted Flutter and Bridge tests, static analysis,
independent review, and runtime layout/interaction checks on a test instance.

## Verification record (2026-09-22)

- Bridge directory/parser tests: 185 passed; TypeScript type check passed.
- A temporary real WebSocket server on test port 8766 verified directory/file
  responses, empty and hidden entries, paths containing spaces, old request
  format, file probes, reads, and allowed-root rejection. Server and fixtures
  were removed; production Bridge was untouched.
- Full Flutter suite: 1,885 passed, 4 skipped, 1 unrelated existing failure:
  `macos_app_bar_chrome_test.dart` constructs `FullScreenImageViewer` without
  localization delegates required by its unchanged `MediaExportActions`.
- Final focused runs: browser/Explorer 39 passed; shell/browser/Explorer 73
  passed before the final keyboard-height refinement; lifecycle/file-link
  regressions 30 passed. New cases cover an incomplete search index while
  restoring a directory, 236 px panes, deep paths, and the software keyboard.
- Static analysis: no errors or warnings; existing informational lints remain.
- Independent reviews covered protocol compatibility, lifecycle, stale requests,
  draft binding, navigation and position restoration; findings were addressed.
- iPhone simulator: fullscreen Markdown preview, search-to-preview, bottom
  controls, and reference insertion into the unsent draft verified. Wide browser
  and center+right shell geometry/back/session switching are widget-tested.
  A forced narrow mock workspace additionally exposed breadcrumb/control sizing
  issues, which were fixed and regression-tested.
- Runtime limitations: macOS launch is blocked by the existing CocoaPods lock
  mismatch (PurchasesHybridCommon 17.55.1 vs required 18.14.1); fresh iPad startup
  awaits a native notification prompt that the available UI tooling could not
  dismiss. No claim of completed macOS/iPad runtime verification is made.

Close-control follow-up: moved Close to the top-left header in every layout and
removed header swipe dismissal. Browser and workspace tests: 55 passed, including
close-button placement and explicit dismissal after a header drag.

Toolbar follow-up: browsing controls now share the top header with no bottom bar.
Recent files and upload live in its overflow menu; narrow panes also put Parent
there. Preview/source stays beside the filename, while copy/share/photo saving
use the file-specific overflow menu.
Validation: 85 targeted tests passed across browser, Explorer, workspace and media
preview suites; static analysis of changed UI/test files reported no issues.
