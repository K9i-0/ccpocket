# iPhone Duo support (proposal)

Updated: 2026-11-02 · Status: phase 1 implemented, phase 2 proposed

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
- **Inner landscape:** the workspace shell already sizes panes from the width
  without horizontal padding (867), but the right-most pane receives the 84pt
  inset and its content ignores it: the empty state is centered on 951, not
  867, and actions can sit under the status cluster.
- `workspaceMultiPaneBreakpoint = 862`. 867 stays multi-pane, but only just:
  left 260 + center min 360 leaves ~245 for the tool pane.

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

## Design

### Rule

`strip != null` → no AppBar row for the frontmost compact screen; its actions go
into the strip; the body loses that side's inset. `strip == null` (inner
portrait, every non-Duo device, Android) → current UI unchanged.

### Implementation (phase 1)

All in [duo_control_strip.dart](../../apps/mobile/lib/widgets/duo/duo_control_strip.dart):

- **`DuoStripHost`** wraps the whole app in `MaterialApp.builder`. It detects the
  strip with `FoldGeometry.fromMediaQuery` and lays the app (Navigator, dialogs,
  sheets included) out beside it with that padding removed and `size` reduced.
  This fixes the overlap for every screen at once, adapted or not. It also adds
  an `Overlay` above the app, which becomes the root overlay. The tree has the
  same shape in every pose. `FoldScaffold` is not used, because it would have to
  wrap each screen, and screens inside workspace panes do not touch the window
  edge.
- **`DuoStripActions`** lets a screen publish `top` / `bottom` controls. They are
  rendered through an `OverlayPortal` into the host's overlay, so they are built
  in the screen's context and can read its providers. The controls are shown
  while the screen is `enabled`, its tickers are on (not under an opaque route,
  not a covered compact layer), and its route is active. The most recently
  activated screen wins (`DuoStripController`). Under a popup route (menu,
  dialog, sheet), the controls stay visible but ignore taps.
- **`DuoAdaptiveScaffold`** (Claude/Codex chat) takes the screen's `AppBar`. In
  strip mode it hides the bar, renders `DuoSlimHeader` (40pt: title +
  `flexibleSpace` status line), and moves `leading` + `actions` to the strip.
  The body stays at the same tree position, so folding keeps composer and
  scroll state.
- **`WorkspacePaneScope`** (in `WorkspacePaneNavigator`) exposes `compact` /
  `active` to pane content. Chat uses `useStrip: isSinglePane` and
  `publish: pane.active`.

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
| Session list | settings (update badge), gallery, disconnect | **New** (56pt filled circle, key `new_session_fab`; replaces the extended FAB) | title + bridge label as a 48pt floating sliver app bar without actions (scrolls away) |
| Claude / Codex chat | back, explore, changes (git badge), the app bar's other actions, overflow menu | — (composer keeps send) | session name + status line in a 40pt slim header |
| Git / Explore / Gallery / Settings / demo / debug | — (strip empty) | | keep their own AppBar; the host keeps them clear of the strip |
| Sheets (new session, slash commands) | unchanged | | laid out beside the strip by the host |

Strip items keep the `ValueKey`s of the app bar buttons they replace.

Plan-mode chip and `StatusLineFlexibleSpace` lose their AppBar home; keep them
visible in the slim header, never only in the strip.

### Inner landscape (workspace multi-pane)

The strip belongs to the window, so it sits right of the right-most pane. Panes
get `width − 84`. The per-pane headers stay (vertical space is not the problem
here); only the **global** actions (settings, gallery, disconnect, New) leave the
left pane header for the strip, so there is one home for them. Chat panes keep
their app bars (`useStrip: false` in multi-pane).

### Half-open

Phase 2, needs `foldable`. Use `FoldAnchor.content` for dialogs we open, and
consider `FoldSplitView` for list | chat when folded like a book. Do not turn on
`bridgeMode: full` until every bottom sheet has been checked against the fold.

## Phasing

1. **Phase 1 – duo_kit only, no native dependency (done).** Host-level strip
   reservation, session list and chat actions + New in the strip, slim headers.
   Android and non-Duo iOS unchanged by construction.
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

Phase 1 coverage: `test/duo_control_strip_test.dart` (cover, cover
landscape-left, inner portrait, plain iPhone; strip ownership across routes;
inert under a dialog; app bar ↔ slim header; body state across fold/unfold).
Simulator (2026-11-02, iOS 27.2): inner landscape with global actions + New in
the strip; cover session list; cover chat (mock preview) with back / explore /
changes / overflow in the strip, the overflow menu opening beside it, and back
returning to a screen whose strip is empty.

## Decisions and open items

- Chat title/status on the cover: slim header line (decided).
- Inner landscape: global actions only in the strip (decided).
- Known gaps: empty-state copy still says "New in the left pane"; strip
  clearance uses the 170pt fallback on inner landscape (cluster is 120pt);
  half-open pose not checked (needs the phase 2 bridge for the fold).
- Cover keyboard (checked): it spans the full width including the strip, so
  strip controls are top-aligned and New is hidden while the keyboard is up.
  Text selection toolbars land in the content area despite the root overlay.
- Open: take `foldable` now or wait for `duo_kit_ios` (phase 2).
