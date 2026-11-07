/// Pane widths and the user-adjustable split threshold of the adaptive
/// workspace. See `docs/design/adaptive-workspace-layout.md`.
library;

/// Session list width below 1024 logical pixels of usable width.
const double kWorkspaceMinListPaneWidth = 260;

/// Narrowest center pane the workspace lays out.
const double kWorkspaceMinCenterPaneWidth = 360;

/// Narrowest tool pane the workspace lays out by default.
const double kWorkspaceMinToolPaneWidth = 240;

/// Width of the hairline between adjacent panes.
const double kWorkspacePaneDividerWidth = 1;

/// Usable width at which list, center and tool panes fit side by side.
/// Below it, an open tool pane covers the list instead (see
/// [kWorkspaceMinMultiPaneBreakpoint]).
const double kWorkspaceThreePaneMinWidth =
    kWorkspaceMinListPaneWidth +
    kWorkspaceMinCenterPaneWidth +
    kWorkspaceMinToolPaneWidth +
    2 * kWorkspacePaneDividerWidth;

/// Default usable width at which the workspace splits into panes.
const double kWorkspaceDefaultMultiPaneBreakpoint = kWorkspaceThreePaneMinWidth;

/// Lowest user-selectable split threshold. Keeps list + center at their
/// minimum widths (621) with some headroom.
const double kWorkspaceMinMultiPaneBreakpoint = 640;

/// Highest user-selectable split threshold.
const double kWorkspaceMaxMultiPaneBreakpoint = 1200;

/// Slider granularity, in logical pixels.
const double kWorkspaceMultiPaneBreakpointStep = 2;

/// Clamps and snaps [value] to a selectable split threshold.
double normalizeWorkspaceMultiPaneBreakpoint(double value) {
  if (!value.isFinite) return kWorkspaceDefaultMultiPaneBreakpoint;
  final clamped = value.clamp(
    kWorkspaceMinMultiPaneBreakpoint,
    kWorkspaceMaxMultiPaneBreakpoint,
  );
  final steps =
      ((clamped - kWorkspaceMinMultiPaneBreakpoint) /
              kWorkspaceMultiPaneBreakpointStep)
          .round();
  return kWorkspaceMinMultiPaneBreakpoint +
      steps * kWorkspaceMultiPaneBreakpointStep;
}
