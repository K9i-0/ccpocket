# iPhone Duo support (proposal)

Updated: 2026-11-02 · Status: proposal, not implemented

## Goal

On iPhone Duo the system reserves an 84pt **control strip** along the side of the
window. Content must stay out of it, and the app's own controls (AppBar actions,
the New FAB) should live in it, as UIKit apps get automatically. The cover display
is short (678pt, keyboard takes about half), so dropping the AppBar there is the
main win.

This is a presentation change only. The contract in
[adaptive-workspace-layout.md](adaptive-workspace-layout.md) still holds: a pose
change must not rebuild sessions, composers or tools. There is no device-model
navigation tree; the trigger is "the window has a strip", not "this is a Duo".

## Measured geometry

Measured on the iPhone Duo simulator (iOS 27.2, Xcode 27.2) through the running
app's `FlutterView`, and matching `duo_kit`'s `FoldTestPose` (iOS 27.1):

| Pose | Window (pt) | viewPadding | Strip | Notes |
| --- | --- | --- | --- | --- |
| Closed, cover portrait | 466 × 678 | R84 B34 | right | status cluster occupies strip top 170pt. Usable content width 382 |
| Closed, cover landscape | 678 × 466 | L84 or R84, B34 | follows camera | status cluster 82pt tall |
| Open, inner landscape | 951 × 669 | R84 B34 | right (both rotations) | status cluster occupies strip top 120pt |
| Open, inner portrait | 669 × 951 | T82 B34 | **none** | horizontal bars are kept (Apple) |
| Half-open | as above | as above | as above | fold at 455.5–495.5 (40pt) on the long axis |

`MediaQuery.displayFeatures` is **empty** on iOS. The strip is visible to Flutter
only as a one-sided `viewPadding`; fold and occlusions need a native bridge.

## Current behaviour (defects)

Screenshots on the simulator, 2026-11-02:

- **Cover:** `AppBar` respects the right inset (settings icon ends at ~357pt), but
  the body does not. Cards and the "Add Machine" button extend to ~440pt, i.e.
  ~58pt under the strip, below the status cluster. `endFloat` FAB placement uses
  the inset, so the New FAB lands left of the strip and wastes a row of height.
- **Inner landscape:** the workspace shell lays out panes over the full 951pt. The
  center/right pane runs under the strip and its status cluster (center pane's
  empty state is centered on 951, not 867).
- `workspaceMultiPaneBreakpoint = 862`. Inner landscape is 951 wide, 867 without
  the strip, so it stays multi-pane either way, but only just: left 260 + center
  min 360 leaves ~245 for the tool pane. Keep the breakpoint, but compute it from
  the width without the strip so the decision is honest.

## Reference behaviour

Apple's "Design for iPhone Duo" tech talk (111466) and "Prepare your app for
iPhone Duo" (111461):

- Cover display: top toolbar items move to the **top** of the side column,
  bottom toolbar items to the **bottom**, tab bar stays bottom-aligned, back
  button moves to the column. Wide items (text buttons, segmented controls) stay
  in the nav bar. The column is shared with the status cluster and Live
  Activities; when it overflows, UIKit collapses items into an overflow menu.
- Content aligns to horizontal safe-area insets. Full-bleed backgrounds may run
  under the column; interactive elements must not.
- Inner portrait is the only pose with horizontal bars. Inner display favours
  split views / two columns (Slack: conversations | messages; Music; Health
  sidebar). Same hierarchy and features in every pose.
- Half-open: interactive elements leave the curve; scrolling content need not.
  Sheets slide to one side of the fold.

Reviews list ChatGPT, Claude, Slack and Notion as handling the Duo well, but
public material gives no layout detail for ChatGPT/Claude. Confirm by installing
them on a real device or the simulator (App Store sign-in required) before
copying any specific pattern.

## Packages

- **`duo_kit` 0.1.2** (LeanCode, Apache-2.0, depends only on Flutter).
  `FoldGeometry.of(context).strip` detects the strip from the one-sided
  `viewPadding` on iOS, so **it works without a bridge**. `FoldScaffold` lays out
  `body` + a navigation widget built for `left / right / bottom`, keeps the same
  children across poses (state survives folding), and gives the strip child a
  `MediaQuery` padded by the status-cluster clearance. `FoldAnchor` gives a
  dialog `anchorPoint` on one side of the fold. `FoldTestPose` provides all
  poses for widget tests. Without occlusion data the strip's top clearance falls
  back to 170pt (correct on cover, 50pt too conservative on inner landscape).
- **`foldable` 1.0.5** (medialyra). Bridges `UIHinge` and reserved regions into
  `displayFeatures` (`DisplayFeatureBridgeMode.full`). Needed for the fold and
  exact occlusions. Caveats: publishes nothing while closed (duo_kit's example
  adds `ClosedFoldOcclusions`), `full` mode makes every dialog/bottom sheet split
  to one side of the fold, Xcode 27.1 Podfile/`ARCHS` workarounds, simulator-only
  testing so far. `duo_kit_ios` (in development) would replace it.

Prerequisites already met: Xcode 27.2 SDK, `UIApplicationSceneManifest`
(UIScene), no `UIRequiresFullScreen`, portrait + landscape allowed on iPhone,
deployment target 15.0.

## Proposed design

### Rule

`strip != null` → no AppBar row for the frontmost compact screen; its actions go
into a vertical `DuoControlStrip` occupying the strip; the body loses that side's
inset. `strip == null` (inner portrait, every non-Duo device, Android) → current
UI unchanged. `FoldScaffold` is used only for its strip placement; its `bottom`
placement maps to our existing layout (no new bottom bar).

### Strip budget

84pt wide. Usable height = window height − top clearance − max(bottom clearance, 34):
cover ≈ 678 − 170 − 34 = **474pt**, inner landscape ≈ 669 − 120 − 34 = 515pt
(445 with the 170 fallback). At 48pt per target that is ~8–9 slots; plan for 5–6
plus a `more` button, because Live Activities can grow the cluster and Flutter has
no automatic overflow. Each item: 48×48 icon button, badge support, tooltip,
same `ValueKey` as today's AppBar button (keeps E2E selectors stable).

### Item mapping

Top group (from the top AppBar), bottom group (bottom actions / FAB):

| Screen | Strip top | Strip bottom | Stays in content |
| --- | --- | --- | --- |
| Session list | settings (update badge), gallery, disconnect | **New** (icon-only, filled tonal circle; replaces the extended FAB) | bridge title → a slim header inside the scrolling list (scrolls away) |
| Claude / Codex chat | back, explore, changes (git badge), history, `more` (existing overflow menu; Codex join button moves into it) | — (composer keeps send) | session name + status line → 28–32pt line above the message list, or a status dot in the strip (decision below) |
| Git / Explore / Gallery / Settings (pushed) | back, screen actions | — | screen title in a slim inline header |
| Sheets (new session, slash commands) | unchanged in phase 1 | | |

Plan-mode chip and `StatusLineFlexibleSpace` lose their AppBar home; keep them
visible in the slim header, never only in the strip.

### Inner landscape (workspace multi-pane)

The strip belongs to the window, so it sits right of the right-most pane. Panes
get `width − 84`. Phase 1: keep the per-pane headers (vertical space is not the
problem here), move only the **global** actions (settings, gallery, disconnect,
New) from the left pane header into the strip so there is one home for them.
Moving the active session's actions too is phase 2, gated on user feedback.

### Half-open

Phase 2, needs `foldable`. Use `FoldAnchor.content` for dialogs we open, and
consider `FoldSplitView` for list | chat when folded like a book. Do not turn on
`bridgeMode: full` until every bottom sheet has been checked against the fold.

## Phasing

1. **Phase 1 – duo_kit only, no native dependency.** Fix the overlaps (body and
   workspace shell honour the strip inset), add `DuoControlStrip`, move session
   list and chat AppBar actions + New into it on strip poses, slim inline
   headers. Android and non-Duo iOS unchanged by construction.
2. **Phase 2 – `foldable` bridge.** Exact occlusion clearances, fold awareness,
   dialog anchoring, optional book-mode split.
3. Duo-specific store screenshots already exist
   ([companion-store-delivery.md](../companion-store-delivery.md)); refresh them
   after phase 1.

## Verification plan

- Unit/widget: `package:duo_kit/testing.dart` `FoldTestPose.duoCover`,
  `duoCoverLandscapeLeft`, `duoInnerLandscape`, `duoInnerPortrait`,
  `duoHalfOpenedLandscape`, plus a plain iPhone `MediaQueryData`. Assert: strip
  shown only with a strip; no interactive widget's rect intersects the strip;
  AppBar absent on cover, present on inner portrait/iPhone; actions keep their
  `ValueKey`s; session screen state survives a pose change (same element).
- `dart analyze`, `dart format`, existing workspace shell tests.
- Simulator: `mise exec -- agent-device fold closed|open|half-open --session <s>`,
  screenshots with `xcrun simctl io <udid> screenshot --display=1` (cover) /
  `--display=3` (inner), Marionette taps on strip buttons, keyboard open on the
  cover with the composer focused (does the keyboard span the strip?).
- Regression: plain iPhone and iPad simulators, Android phone.

## Open decisions

- Chat title/status on the cover: slim header line vs. status dot in the strip.
- Inner landscape: global actions only (proposed) vs. all session actions in the
  strip.
- Whether to take `foldable` now or wait for `duo_kit_ios`.
