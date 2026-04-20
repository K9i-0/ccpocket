import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kWorkspaceMacOSToolbarHeight = 52.0;
const kWorkspaceMacOSLeadingInset = 88.0;
const kWorkspaceMacOSToolbarButtonExtent = 32.0;
const kWorkspaceMacOSToolbarLeadingSlotWidth = 44.0;
const kWorkspaceMacOSSinglePaneTopInset = 28.0;
const kWorkspacePaneHorizontalPadding = 12.0;
const kWorkspacePaneVerticalPadding = 10.0;
const kWorkspacePaneActionGap = 4.0;
const _windowChromeChannelName = 'ccpocket/window_chrome';

enum WorkspacePaneSlot { left, center, right }

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

  PreferredSizeWidget wrapAppBar(PreferredSizeWidget appBar) {
    if (topInset == 0) return appBar;
    return PreferredSize(
      preferredSize: Size.fromHeight(appBar.preferredSize.height + topInset),
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: appBar,
      ),
    );
  }

  Widget wrapTitle(Widget title) {
    if (!useMacOSAdaptiveChrome) return title;
    return MacOSWindowDragHandle(child: title);
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
