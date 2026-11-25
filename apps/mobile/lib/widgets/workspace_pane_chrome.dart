import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

const kWorkspaceMacOSToolbarHeight = 52.0;
const kWorkspaceMacOSLeadingInset = 88.0;
const kWorkspaceMacOSToolbarButtonExtent = 32.0;
const kWorkspaceMacOSToolbarLeadingSlotWidth = 44.0;
const kWorkspaceSidebarToggleSlotWidth = 36.0;
// Single-pane macOS windows still render traffic lights above the content.
// Keep a slightly larger clearance so the session status line does not sit
// under the window controls when the app collapses to the mobile layout.
const kWorkspaceMacOSSinglePaneTopInset = 36.0;
const kWorkspacePaneHorizontalPadding = 12.0;
const kWorkspacePaneVerticalPadding = 10.0;
const kWorkspacePaneActionGap = 4.0;
const _windowChromeChannelName = 'ccpocket/window_chrome';

/// Publishes collapsed-sidebar expansion controls to center-pane headers
/// wrapped by [WorkspacePaneChrome.wrapAppBar].
class WorkspaceSidebarChromeScope extends InheritedWidget {
  const WorkspaceSidebarChromeScope({
    super.key,
    required this.showExpandSidebarButton,
    required this.onExpandSidebar,
    this.tooltip,
    required super.child,
  });

  final bool showExpandSidebarButton;
  final VoidCallback? onExpandSidebar;
  final String? tooltip;

  static WorkspaceSidebarChromeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceSidebarChromeScope>();

  @override
  bool updateShouldNotify(WorkspaceSidebarChromeScope oldWidget) =>
      showExpandSidebarButton != oldWidget.showExpandSidebarButton ||
      onExpandSidebar != oldWidget.onExpandSidebar ||
      tooltip != oldWidget.tooltip;
}

enum WorkspacePaneSlot { left, center, right }

BoxConstraints? macOSModalBottomSheetConstraints(
  BuildContext context, {
  double? maxHeight,
}) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
    return maxHeight == null ? null : BoxConstraints(maxHeight: maxHeight);
  }

  final screenHeight = MediaQuery.sizeOf(context).height;
  const reservedTopHeight = kToolbarHeight;
  final macOSMaxHeight = (screenHeight - reservedTopHeight)
      .clamp(0.0, screenHeight)
      .toDouble();
  final effectiveMaxHeight = maxHeight == null || maxHeight > macOSMaxHeight
      ? macOSMaxHeight
      : maxHeight;
  return BoxConstraints(maxHeight: effectiveMaxHeight);
}

class _WindowChromeGateway {
  const _WindowChromeGateway();

  static const _channel = MethodChannel(_windowChromeChannelName);

  Future<void> beginWindowDrag() {
    return _channel.invokeMethod<void>('beginWindowDrag');
  }
}

class MacOSWindowDragHandle extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const MacOSWindowDragHandle({
    super.key,
    required this.child,
    this.enabled = true,
  });

  static const _gateway = _WindowChromeGateway();

  @override
  Widget build(BuildContext context) {
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        if ((event.buttons & kPrimaryMouseButton) == 0) return;
        unawaited(_gateway.beginWindowDrag());
      },
      child: child,
    );
  }
}

class WorkspacePaneChrome {
  final bool useMacOSAdaptiveChrome;
  final bool ownsWindowControls;
  final double toolbarHeight;
  final double topInset;

  const WorkspacePaneChrome({
    required this.useMacOSAdaptiveChrome,
    required this.ownsWindowControls,
    required this.toolbarHeight,
    this.topInset = 0,
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

  List<Widget> padActions(List<Widget> actions) {
    if (actions.isEmpty || !useMacOSAdaptiveChrome) return actions;
    return [...actions, const SizedBox(width: kWorkspacePaneHorizontalPadding)];
  }

  PreferredSizeWidget wrapAppBar(PreferredSizeWidget appBar) {
    final baseHeight = appBar.preferredSize.height + topInset;
    return PreferredSize(
      preferredSize: Size.fromHeight(baseHeight),
      child: _WorkspacePaneChromeAppBar(
        chrome: this,
        topInset: topInset,
        appBar: appBar,
      ),
    );
  }

  Widget wrapTitle(Widget title) {
    if (!useMacOSAdaptiveChrome) return title;
    return MacOSWindowDragHandle(child: title);
  }
}

class _WorkspacePaneChromeAppBar extends StatelessWidget {
  const _WorkspacePaneChromeAppBar({
    required this.chrome,
    required this.topInset,
    required this.appBar,
  });

  final WorkspacePaneChrome chrome;
  final double topInset;
  final PreferredSizeWidget appBar;

  @override
  Widget build(BuildContext context) {
    final sidebarScope = WorkspaceSidebarChromeScope.maybeOf(context);
    final showExpandButton =
        sidebarScope != null &&
        sidebarScope.showExpandSidebarButton &&
        sidebarScope.onExpandSidebar != null;

    Widget child = appBar;
    if (showExpandButton) {
      final mediaQuery = MediaQuery.of(context);
      final slotWidth = chrome.useMacOSAdaptiveChrome
          ? kWorkspaceSidebarToggleSlotWidth
          : kWorkspaceMacOSToolbarLeadingSlotWidth;
      final buttonLeft =
          mediaQuery.padding.left +
          (chrome.ownsWindowControls
              ? kWorkspaceMacOSLeadingInset
              : kWorkspacePaneHorizontalPadding);
      child = Stack(
        children: [
          MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(
                left: mediaQuery.padding.left + slotWidth,
              ),
            ),
            child: appBar,
          ),
          Positioned(
            left: buttonLeft,
            top: mediaQuery.padding.top,
            bottom: 0,
            child: Center(
              child: IconButton(
                key: const ValueKey('center_sidebar_toggle_button'),
                iconSize: chrome.useMacOSAdaptiveChrome ? 18 : 20,
                color: chrome.useMacOSAdaptiveChrome
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
                style: chrome.useMacOSAdaptiveChrome
                    ? chrome.compactButtonStyle()
                    : null,
                onPressed: sidebarScope.onExpandSidebar,
                tooltip: sidebarScope.tooltip,
                icon: const Icon(Icons.view_sidebar_outlined),
              ),
            ),
          ),
        ],
      );
    }

    if (topInset == 0) return child;
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: child,
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
    if (platform == TargetPlatform.macOS && !isAdaptiveWorkspace) {
      return const WorkspacePaneChrome(
        useMacOSAdaptiveChrome: false,
        ownsWindowControls: false,
        toolbarHeight: kToolbarHeight,
        topInset: kWorkspaceMacOSSinglePaneTopInset,
      );
    }
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

WorkspacePaneChrome resolveStandalonePaneChrome(BuildContext context) {
  return resolveWorkspacePaneChrome(
    platform: Theme.of(context).platform,
    isAdaptiveWorkspace: false,
    isLeftPaneVisible: false,
    slot: WorkspacePaneSlot.center,
  );
}
