import 'dart:math' as math;

import 'package:duo_kit/duo_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Reserves the control strip of an iPhone Duo window and lets the frontmost
/// screen put its own controls there.
///
/// iOS reports the strip only as a one-sided view padding (84pt on the right,
/// or on the left on the cover display in landscape with the camera on the
/// left). The app below this widget is laid out beside the strip, with that
/// padding removed, so no screen, dialog or sheet can draw under it. Screens
/// publish their controls into the strip with [DuoStripActions].
///
/// Without a strip (every other device, Android, the inner display in
/// portrait) the child gets the whole window and nothing changes. The widget
/// tree has the same shape in every pose, so folding keeps all state below.
///
/// See docs/design/iphone-duo-support.md.
class DuoStripHost extends StatefulWidget {
  const DuoStripHost({super.key, required this.child, this.detectStrip});

  final Widget child;

  /// Passed to [FoldGeometry.fromMediaQuery]. Defaults to iOS only.
  final bool? detectStrip;

  @override
  State<DuoStripHost> createState() => _DuoStripHostState();
}

class _DuoStripHostState extends State<DuoStripHost> {
  final _controller = DuoStripController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final strip = FoldGeometry.fromMediaQuery(
      mediaQuery,
      detectStrip: widget.detectStrip,
    ).strip;
    final side = strip?.side;
    final stripWidth = strip?.width ?? 0;
    final childData = mediaQuery
        .removePadding(
          removeLeft: side == FoldStripSide.left,
          removeRight: side == FoldStripSide.right,
        )
        .copyWith(
          size: Size(
            math.max(0, mediaQuery.size.width - stripWidth),
            mediaQuery.size.height,
          ),
        );

    return DuoStripScope(
      strip: strip,
      bottomInset: mediaQuery.viewPadding.bottom,
      controller: _controller,
      child: Overlay.wrap(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: side == FoldStripSide.left ? stripWidth : 0,
              right: side == FoldStripSide.right ? stripWidth : 0,
              child: MediaQuery(data: childData, child: widget.child),
            ),
            Positioned(
              key: const ValueKey('duo_control_strip_background'),
              top: 0,
              bottom: 0,
              width: stripWidth,
              left: side == FoldStripSide.left ? 0 : null,
              right: side == FoldStripSide.left ? null : 0,
              child: ColoredBox(color: Theme.of(context).colorScheme.surface),
            ),
          ],
        ),
      ),
    );
  }
}

/// The strip of the window, as seen by [DuoStripHost].
class DuoStripScope extends InheritedWidget {
  const DuoStripScope({
    super.key,
    required this.strip,
    required this.bottomInset,
    required this.controller,
    required super.child,
  });

  /// The control strip, in window coordinates, or null when there is none.
  final FoldStrip? strip;

  /// The bottom view padding of the window (home indicator).
  final double bottomInset;

  final DuoStripController controller;

  static DuoStripScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuoStripScope>();

  /// Whether the window has a control strip that screens should use instead
  /// of their app bar actions.
  static bool hasStrip(BuildContext context) => maybeOf(context)?.strip != null;

  @override
  bool updateShouldNotify(DuoStripScope oldWidget) =>
      strip != oldWidget.strip ||
      bottomInset != oldWidget.bottomInset ||
      controller != oldWidget.controller;
}

/// Decides which [DuoStripActions] owns the strip: the one that became active
/// most recently among those still active.
class DuoStripController extends ChangeNotifier {
  int _sequence = 0;
  final Map<Object, int> _activations = {};
  Object? _owner;
  bool _notifyScheduled = false;
  bool _disposed = false;

  Object? get owner => _owner;

  /// Safe to call during build: listeners are notified after the frame.
  void setActive(Object token, bool active) {
    if (active) {
      _activations.putIfAbsent(token, () => ++_sequence);
    } else {
      _activations.remove(token);
    }
    Object? next;
    var latest = -1;
    for (final MapEntry(:key, :value) in _activations.entries) {
      if (value > latest) {
        latest = value;
        next = key;
      }
    }
    if (identical(next, _owner)) return;
    _owner = next;
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Puts [top] and [bottom] into the control strip while this screen is the
/// frontmost one, as UIKit does with toolbar items on iPhone Duo: items from
/// the top bar go to the top of the strip, bottom actions to its bottom.
///
/// The controls are built in this widget's context, so they can read the
/// providers of the screen. The screen counts as frontmost while [enabled],
/// its route is not covered by an opaque route (tickers enabled), and it is
/// the most recently activated such screen. Controls stay visible but ignore
/// taps while a popup route (menu, dialog, sheet) is above the screen.
class DuoStripActions extends StatefulWidget {
  const DuoStripActions({
    super.key,
    required this.enabled,
    this.top = const [],
    this.bottom = const [],
    required this.child,
  });

  final bool enabled;
  final List<Widget> top;
  final List<Widget> bottom;
  final Widget child;

  @override
  State<DuoStripActions> createState() => _DuoStripActionsState();
}

class _DuoStripActionsState extends State<DuoStripActions> {
  final _portal = OverlayPortalController()..show();
  DuoStripController? _controller;

  @override
  void dispose() {
    _controller?.setActive(this, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = DuoStripScope.maybeOf(context);
    final controller = scope?.controller;
    if (!identical(controller, _controller)) {
      _controller?.setActive(this, false);
      _controller = controller;
    }
    if (scope == null || controller == null) return widget.child;

    final route = ModalRoute.of(context);
    final strip = scope.strip;
    final active =
        widget.enabled &&
        strip != null &&
        TickerMode.valuesOf(context).enabled &&
        (route?.isActive ?? true);
    final interactive = route?.isCurrent ?? true;
    controller.setActive(this, active);

    return OverlayPortal(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          if (!active || !identical(controller.owner, this)) {
            return const SizedBox.shrink();
          }
          return Positioned.fromRect(
            rect: strip.rect,
            child: IgnorePointer(
              ignoring: !interactive,
              child: DuoStripColumn(
                strip: strip,
                bottomInset: scope.bottomInset,
                top: widget.top,
                bottom: widget.bottom,
              ),
            ),
          );
        },
      ),
      child: widget.child,
    );
  }
}

/// Lays out strip controls: [top] below the status cluster, [bottom] above
/// the home indicator. Scrolls if the controls do not fit, since Live
/// Activities can grow the status cluster.
class DuoStripColumn extends StatelessWidget {
  const DuoStripColumn({
    super.key,
    required this.strip,
    required this.bottomInset,
    required this.top,
    required this.bottom,
  });

  /// Height reserved for each control.
  static const itemExtent = 52.0;

  final FoldStrip strip;
  final double bottomInset;
  final List<Widget> top;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    Widget item(Widget child) => SizedBox(
      height: itemExtent,
      child: Center(child: child),
    );

    return Material(
      key: const ValueKey('duo_control_strip'),
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(
          top: strip.topClearance,
          bottom: math.max(strip.bottomClearance, bottomInset) + 8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    for (final child in top) item(child),
                    const Spacer(),
                    for (final child in bottom) item(child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A [Scaffold] whose [appBar] turns into a slim title line plus strip
/// controls when the window has a control strip and [useStrip] is true.
///
/// The app bar's leading widget and actions move to the top of the strip.
/// The body keeps its place in the tree in every pose, so switching between
/// the app bar and the strip does not rebuild the screen's content.
class DuoAdaptiveScaffold extends StatelessWidget {
  const DuoAdaptiveScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.wrapAppBar,
    this.useStrip = true,
    this.publish = true,
  });

  final AppBar appBar;
  final Widget? body;

  /// Applied to [appBar] when it is shown as an app bar.
  final PreferredSizeWidget Function(AppBar appBar)? wrapAppBar;

  /// Whether this screen fills the window, so it may trade its app bar for the
  /// strip. False for panes of a multi-pane layout.
  final bool useStrip;

  /// Whether this screen is the frontmost one and should own the strip.
  final bool publish;

  @override
  Widget build(BuildContext context) {
    final stripMode = useStrip && DuoStripScope.hasStrip(context);
    final leading = appBar.leading;

    return DuoStripActions(
      enabled: stripMode && publish,
      top: [?leading, ...?appBar.actions],
      child: Scaffold(
        appBar: stripMode ? null : (wrapAppBar?.call(appBar) ?? appBar),
        body: Column(
          children: [
            if (stripMode)
              DuoSlimHeader(
                title: appBar.title,
                flexibleSpace: appBar.flexibleSpace,
              )
            else
              const SizedBox.shrink(),
            Expanded(child: body ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// The title line that replaces an app bar next to a control strip.
class DuoSlimHeader extends StatelessWidget {
  const DuoSlimHeader({super.key, this.title, this.flexibleSpace});

  static const height = 40.0;

  final Widget? title;
  final Widget? flexibleSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    final flexibleSpace = this.flexibleSpace;
    return SafeArea(
      key: const ValueKey('duo_slim_header'),
      bottom: false,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            if (flexibleSpace != null) Positioned.fill(child: flexibleSpace),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: title ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
