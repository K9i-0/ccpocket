import 'package:flutter/material.dart';

const kWorkspaceMacOSToolbarHeight = 52.0;
const kWorkspaceMacOSLeadingInset = 88.0;
const kWorkspaceMacOSToolbarButtonExtent = 32.0;
const kWorkspaceMacOSToolbarLeadingSlotWidth = 44.0;
const kWorkspacePaneHorizontalPadding = 12.0;
const kWorkspacePaneVerticalPadding = 10.0;
const kWorkspacePaneActionGap = 4.0;

enum WorkspacePaneSlot { left, center, right }

class WorkspacePaneChrome {
  final bool useMacOSAdaptiveChrome;
  final bool ownsWindowControls;
  final double toolbarHeight;

  const WorkspacePaneChrome({
    required this.useMacOSAdaptiveChrome,
    required this.ownsWindowControls,
    required this.toolbarHeight,
  });

  double get leadingInset =>
      ownsWindowControls ? kWorkspaceMacOSLeadingInset : 0;

  EdgeInsets headerPadding({
    double trailing = 8,
    double vertical = kWorkspacePaneVerticalPadding,
  }) {
    return EdgeInsets.fromLTRB(
      useMacOSAdaptiveChrome
          ? leadingInset + kWorkspacePaneHorizontalPadding
          : kWorkspacePaneHorizontalPadding,
      vertical,
      trailing,
      vertical,
    );
  }

  Widget? wrapLeading(Widget? leading) {
    if (leading == null || leadingInset == 0) return leading;
    return Padding(
      padding: EdgeInsets.only(left: leadingInset),
      child: Align(alignment: Alignment.centerLeft, child: leading),
    );
  }

  double? resolveLeadingWidth({
    required bool hasLeading,
    double baseWidth = kToolbarHeight,
  }) {
    if (!hasLeading) return null;
    return baseWidth + leadingInset;
  }

  double resolveTitleSpacing({
    required bool hasLeading,
    double fallback = NavigationToolbar.kMiddleSpacing,
  }) {
    if (hasLeading) {
      return useMacOSAdaptiveChrome ? 8 : fallback;
    }
    if (leadingInset == 0) return fallback;
    return leadingInset + kWorkspacePaneHorizontalPadding;
  }

  ButtonStyle compactButtonStyle() {
    return IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(kWorkspaceMacOSToolbarButtonExtent),
      maximumSize: const Size.square(kWorkspaceMacOSToolbarButtonExtent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

WorkspacePaneChrome resolveWorkspacePaneChrome({
  required TargetPlatform platform,
  required bool isAdaptiveWorkspace,
  required bool isLeftPaneVisible,
  required WorkspacePaneSlot slot,
}) {
  final useMacOSAdaptiveChrome =
      platform == TargetPlatform.macOS && isAdaptiveWorkspace;

  if (!useMacOSAdaptiveChrome) {
    return const WorkspacePaneChrome(
      useMacOSAdaptiveChrome: false,
      ownsWindowControls: false,
      toolbarHeight: kToolbarHeight,
    );
  }

  final ownsWindowControls = switch (slot) {
    WorkspacePaneSlot.left => isLeftPaneVisible,
    WorkspacePaneSlot.center => !isLeftPaneVisible,
    WorkspacePaneSlot.right => false,
  };

  return WorkspacePaneChrome(
    useMacOSAdaptiveChrome: true,
    ownsWindowControls: ownsWindowControls,
    toolbarHeight: kWorkspaceMacOSToolbarHeight,
  );
}
