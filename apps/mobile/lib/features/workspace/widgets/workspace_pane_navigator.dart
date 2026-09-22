import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A permanent navigation surface. Resizing changes its geometry, never its
/// routes or their owners. The empty first page reveals the sibling pane during
/// an interactive back gesture in compact layouts.
class WorkspacePaneNavigator extends StatefulWidget {
  const WorkspacePaneNavigator({
    super.key,
    required this.navigatorKey,
    required this.pages,
    required this.compact,
    required this.active,
    required this.onDidRemovePage,
    this.onInteraction,
    this.handlesBack = true,
    this.visible = true,
    this.background = const SizedBox.expand(),
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final List<WorkspacePanePage> pages;
  final bool compact;
  final bool active;
  final bool handlesBack;
  final bool visible;
  final VoidCallback? onInteraction;
  final void Function(Page<Object?>) onDidRemovePage;
  final Widget background;

  @override
  State<WorkspacePaneNavigator> createState() => _WorkspacePaneNavigatorState();
}

class _WorkspacePaneNavigatorState extends State<WorkspacePaneNavigator> {
  final _heroController = HeroController();
  final _focusScope = FocusScopeNode(debugLabel: 'workspace pane');
  FocusNode? _lastFocusedNode;

  @override
  void didUpdateWidget(covariant WorkspacePaneNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && _focusScope.hasFocus) {
      _lastFocusedNode = FocusManager.instance.primaryFocus;
    } else if (!oldWidget.active && widget.active && widget.handlesBack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.active || !widget.handlesBack) return;
        final node = _lastFocusedNode;
        if (node?.context != null && node!.canRequestFocus) node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _heroController.dispose();
    _focusScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _focusScope,
      onFocusChange: (focused) {
        if (focused && widget.active) widget.onInteraction?.call();
      },
      child: Listener(
        onPointerDown: widget.active
            ? (_) => widget.onInteraction?.call()
            : null,
        child: Opacity(
          opacity: widget.visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !widget.active,
            child: ExcludeSemantics(
              excluding: !widget.active,
              child: ExcludeFocus(
                excluding: !widget.active,
                child: HeroControllerScope(
                  controller: _heroController,
                  child: NavigatorPopHandler<Object?>(
                    enabled: widget.handlesBack && widget.active,
                    onPopWithResult: (result) =>
                        widget.navigatorKey.currentState?.pop(result),
                    child: Navigator(
                      key: widget.navigatorKey,
                      // The sibling list must retain focus when no page is selected.
                      requestFocus: widget.active && widget.handlesBack,
                      pages: [
                        WorkspacePanePage(
                          key: const ValueKey('pane_root'),
                          compact: widget.compact,
                          child: widget.background,
                        ),
                        ...widget.pages,
                      ],
                      onDidRemovePage: widget.onDidRemovePage,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspacePanePage extends Page<Object?> {
  const WorkspacePanePage({
    required super.key,
    required this.child,
    required this.compact,
  });

  final Widget child;
  final bool compact;

  @override
  Route<Object?> createRoute(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS
      ? _WorkspacePaneRoute(this)
      : _WorkspaceMaterialPaneRoute(this);
}

class _WorkspacePaneRoute extends CupertinoPageRoute<Object?> {
  _WorkspacePaneRoute(WorkspacePanePage page)
    : super(settings: page, builder: (_) => page.child);

  WorkspacePanePage get page => settings as WorkspacePanePage;

  @override
  bool get popGestureEnabled => page.compact && super.popGestureEnabled;

  @override
  Duration get transitionDuration =>
      page.compact ? super.transitionDuration : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      page.compact ? super.reverseTransitionDuration : Duration.zero;

  @override
  void changedInternalState() {
    super.changedInternalState();
    controller?.duration = transitionDuration;
    controller?.reverseDuration = reverseTransitionDuration;
  }

  // Page updates (including compact chrome) must not be captured by the
  // createRoute closure. Flutter retains this route for the same Page key.
  @override
  Widget buildContent(BuildContext context) => page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => page.compact
      ? super.buildTransitions(context, animation, secondaryAnimation, child)
      : child;
}

/// Keep Material/predictive-back behavior on Android and themed desktop
/// transitions. Platform is stable for a route; width only updates its page.
class _WorkspaceMaterialPaneRoute extends MaterialPageRoute<Object?> {
  _WorkspaceMaterialPaneRoute(WorkspacePanePage page)
    : super(settings: page, builder: (_) => page.child);

  WorkspacePanePage get page => settings as WorkspacePanePage;

  @override
  Duration get transitionDuration =>
      page.compact ? super.transitionDuration : Duration.zero;
  @override
  Duration get reverseTransitionDuration =>
      page.compact ? super.reverseTransitionDuration : Duration.zero;
  @override
  void changedInternalState() {
    super.changedInternalState();
    controller?.duration = transitionDuration;
    controller?.reverseDuration = reverseTransitionDuration;
  }

  @override
  Widget buildContent(BuildContext context) => page.child;
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => page.compact
      ? super.buildTransitions(context, animation, secondaryAnimation, child)
      : child;
}
