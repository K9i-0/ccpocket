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
      child: DuoStripKeyboardInset(
        inset: mediaQuery.viewInsets.bottom,
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

/// The keyboard height of the window, kept apart from [DuoStripScope] so that
/// only the strip controls rebuild while the keyboard animates.
///
/// On the iPhone Duo cover display the keyboard spans the strip too, so the
/// bottom controls ride above it.
class DuoStripKeyboardInset extends InheritedWidget {
  const DuoStripKeyboardInset({
    super.key,
    required this.inset,
    required super.child,
  });

  final double inset;

  static double of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DuoStripKeyboardInset>()
          ?.inset ??
      0;

  @override
  bool updateShouldNotify(DuoStripKeyboardInset oldWidget) =>
      inset != oldWidget.inset;
}

/// Vertical metrics of the strip controls.
abstract final class DuoStripMetrics {
  /// Height of each control in the top group.
  static const itemExtent = 52.0;

  /// Height of the slot of the bottom (primary) controls.
  static const primaryExtent = 64.0;

  /// Room the top group leaves for a [DuoStripBottomSlot]: a secondary
  /// control above the primary one.
  static const reservedSlotExtent = primaryExtent + itemExtent;

  static const _bottomGap = 8.0;

  /// Distance from the bottom of the window to the bottom of the controls:
  /// above the home indicator, an occlusion, or the keyboard.
  static double bottomEdge({
    required FoldStrip strip,
    required double bottomInset,
    required double keyboardInset,
  }) =>
      math.max(math.max(strip.bottomClearance, bottomInset), keyboardInset) +
      _bottomGap;
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

  /// Makes [token] the most recently activated screen, if it is active.
  void touch(Object token) {
    if (!_activations.containsKey(token)) return;
    _activations[token] = ++_sequence;
    if (identical(token, _owner)) return;
    _owner = token;
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

/// Hands the strip to the screens inside [child] when the user touches it.
///
/// Wrap each pane of a multi-pane layout, so the strip follows the pane the
/// user works in: the chat's tools and send button after touching the chat,
/// search and New after touching the session list.
class DuoStripTouchRegion extends StatefulWidget {
  const DuoStripTouchRegion({super.key, required this.child});

  final Widget child;

  @override
  State<DuoStripTouchRegion> createState() => _DuoStripTouchRegionState();
}

class _DuoStripTouchRegionState extends State<DuoStripTouchRegion> {
  var _touches = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => setState(() => _touches++),
      child: _DuoStripTouches(touches: _touches, child: widget.child),
    );
  }
}

class _DuoStripTouches extends InheritedWidget {
  const _DuoStripTouches({required this.touches, required super.child});

  final int touches;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DuoStripTouches>()?.touches ??
      0;

  @override
  bool updateShouldNotify(_DuoStripTouches oldWidget) =>
      touches != oldWidget.touches;
}

/// Puts the controls of a screen into the control strip while the screen is
/// the frontmost one.
///
/// The strip has two roles, top to bottom:
///
/// * [top]: tools the screen wants at hand (Git, Explorer, search). They
///   scroll if they do not fit, since Live Activities can grow the status
///   cluster and the keyboard can cover the lower part of the strip.
/// * [bottom]: the one primary action under the thumb (New, back, send). It
///   is pinned above the home indicator or the keyboard.
///
/// A descendant can place its own primary action with [DuoStripBottomSlot]
/// (the chat composer does this for send / stop / voice); set
/// [reserveBottomSlot] so that the top group leaves room for it.
///
/// The controls are built in this widget's context, so they can read the
/// providers of the screen. The screen counts as frontmost while [enabled],
/// its route is not covered by an opaque route (tickers enabled), and it is
/// the most recently activated or touched (see [DuoStripTouchRegion]) such
/// screen. Controls stay visible but ignore
/// taps while a popup route (menu, dialog, sheet) is above the screen.
class DuoStripActions extends StatefulWidget {
  const DuoStripActions({
    super.key,
    required this.enabled,
    this.stripMode,
    this.top = const [],
    this.bottom = const [],
    this.reserveBottomSlot = false,
    required this.child,
  });

  final bool enabled;

  /// Whether this screen has handed its controls to the strip, for
  /// [DuoStripBottomSlot.isStripMode]. Defaults to [enabled] when the window
  /// has a strip.
  final bool? stripMode;

  final List<Widget> top;
  final List<Widget> bottom;
  final bool reserveBottomSlot;
  final Widget child;

  @override
  State<DuoStripActions> createState() => _DuoStripActionsState();
}

class _DuoStripActionsState extends State<DuoStripActions> {
  final _portal = OverlayPortalController()..show();
  DuoStripController? _controller;
  int? _touches;

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
    final touches = _DuoStripTouches.of(context);
    if (_touches != null && touches != _touches) controller.touch(this);
    _touches = touches;

    return _DuoStripRegion(
      owner: this,
      controller: controller,
      strip: strip,
      bottomInset: scope.bottomInset,
      active: active,
      interactive: interactive,
      stripMode: strip != null && (widget.stripMode ?? widget.enabled),
      child: OverlayPortal(
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
                  keyboardInset: DuoStripKeyboardInset.of(context),
                  top: widget.top,
                  bottom: widget.bottom,
                  reservedBottomExtent: widget.reserveBottomSlot
                      ? DuoStripMetrics.reservedSlotExtent
                      : 0,
                ),
              ),
            );
          },
        ),
        child: widget.child,
      ),
    );
  }
}

class _DuoStripRegion extends InheritedWidget {
  const _DuoStripRegion({
    required this.owner,
    required this.controller,
    required this.strip,
    required this.bottomInset,
    required this.active,
    required this.interactive,
    required this.stripMode,
    required super.child,
  });

  final Object owner;
  final DuoStripController controller;
  final FoldStrip? strip;
  final double bottomInset;
  final bool active;
  final bool interactive;
  final bool stripMode;

  static _DuoStripRegion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DuoStripRegion>();

  @override
  bool updateShouldNotify(_DuoStripRegion oldWidget) =>
      !identical(owner, oldWidget.owner) ||
      controller != oldWidget.controller ||
      strip != oldWidget.strip ||
      bottomInset != oldWidget.bottomInset ||
      active != oldWidget.active ||
      interactive != oldWidget.interactive ||
      stripMode != oldWidget.stripMode;
}

/// Shows [child] at the bottom of the strip, on behalf of the enclosing
/// [DuoStripActions], while that screen owns the strip. [child] sizes itself
/// (up to [DuoStripMetrics.reservedSlotExtent] tall, e.g. a secondary control
/// above the primary one); use [DuoStripSlotItem] for each control.
///
/// Builds nothing in place. Use [isStripMode] to decide whether to render the
/// action inline instead.
class DuoStripBottomSlot extends StatefulWidget {
  const DuoStripBottomSlot({super.key, required this.child});

  final Widget child;

  /// Whether the enclosing screen has handed its controls to the strip.
  static bool isStripMode(BuildContext context) =>
      _DuoStripRegion.maybeOf(context)?.stripMode ?? false;

  @override
  State<DuoStripBottomSlot> createState() => _DuoStripBottomSlotState();
}

class _DuoStripBottomSlotState extends State<DuoStripBottomSlot> {
  final _portal = OverlayPortalController()..show();

  @override
  Widget build(BuildContext context) {
    final region = _DuoStripRegion.maybeOf(context);
    final strip = region?.strip;
    if (region == null || strip == null) return const SizedBox.shrink();

    return OverlayPortal(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) => ListenableBuilder(
        listenable: region.controller,
        builder: (context, _) {
          if (!region.active ||
              !identical(region.controller.owner, region.owner)) {
            return const SizedBox.shrink();
          }
          return Positioned(
            key: const ValueKey('duo_strip_bottom_slot'),
            left: strip.rect.left,
            width: strip.width,
            bottom: DuoStripMetrics.bottomEdge(
              strip: strip,
              bottomInset: region.bottomInset,
              keyboardInset: DuoStripKeyboardInset.of(context),
            ),
            child: IgnorePointer(
              ignoring: !region.interactive,
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
          );
        },
      ),
      child: const SizedBox.shrink(),
    );
  }
}

/// One control of a [DuoStripBottomSlot], centered in the strip at the height
/// of a primary ([primary]) or a top-group control.
class DuoStripSlotItem extends StatelessWidget {
  const DuoStripSlotItem({
    super.key,
    this.primary = false,
    required this.child,
  });

  final bool primary;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: primary
        ? DuoStripMetrics.primaryExtent
        : DuoStripMetrics.itemExtent,
    child: Center(child: child),
  );
}

/// Lays out strip controls: [top] below the status cluster, [bottom] pinned
/// above the home indicator or the keyboard.
class DuoStripColumn extends StatelessWidget {
  const DuoStripColumn({
    super.key,
    required this.strip,
    required this.bottomInset,
    this.keyboardInset = 0,
    required this.top,
    required this.bottom,
    this.reservedBottomExtent = 0,
  });

  final FoldStrip strip;
  final double bottomInset;
  final double keyboardInset;
  final List<Widget> top;
  final List<Widget> bottom;

  /// Empty room below [top] for controls placed by [DuoStripBottomSlot].
  final double reservedBottomExtent;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('duo_control_strip'),
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(
          top: strip.topClearance,
          bottom: DuoStripMetrics.bottomEdge(
            strip: strip,
            bottomInset: bottomInset,
            keyboardInset: keyboardInset,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final child in top)
                      SizedBox(
                        height: DuoStripMetrics.itemExtent,
                        child: Center(child: child),
                      ),
                  ],
                ),
              ),
            ),
            for (final child in bottom)
              SizedBox(
                height: DuoStripMetrics.primaryExtent,
                child: Center(child: child),
              ),
            SizedBox(height: reservedBottomExtent),
          ],
        ),
      ),
    );
  }
}

/// The large round button of the strip's primary slot.
class DuoStripPrimaryButton extends StatelessWidget {
  const DuoStripPrimaryButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.backgroundColor,
    this.foregroundColor,
  });

  static const size = 56.0;

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: backgroundColor ?? cs.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            onLongPress: enabled ? onLongPress : null,
            child: SizedBox.square(
              dimension: size,
              child: IconTheme.merge(
                data: IconThemeData(
                  color: foregroundColor ?? cs.onPrimary,
                  size: 26,
                ),
                child: Center(child: icon),
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
/// In strip mode the app bar's actions go to the top of the strip, its
/// leading widget to the slim header (unless [leadingInHeader] is false), and
/// [primary] to the bottom of the strip. The body keeps its place in the tree
/// in every pose, so switching between the app bar and the strip does not
/// rebuild the screen's content.
class DuoAdaptiveScaffold extends StatelessWidget {
  const DuoAdaptiveScaffold({
    super.key,
    required this.appBar,
    required this.body,
    this.wrapAppBar,
    this.useStrip = true,
    this.publish = true,
    this.primary,
    this.leadingInHeader = true,
    this.reserveBottomSlot = false,
    this.extendBodyBehindAppBar = false,
    this.bottomNavigationBar,
    this.stripTools = const [],
  });

  final AppBar appBar;

  /// Tools shown in the strip before the app bar's actions, only in strip
  /// mode (e.g. New in a chat, which has no app bar counterpart).
  final Widget? body;

  /// Applied to [appBar] when it is shown as an app bar.
  final PreferredSizeWidget Function(AppBar appBar)? wrapAppBar;

  /// Whether this screen fills the window, so it may trade its app bar for the
  /// strip. False for panes of a multi-pane layout.
  final bool useStrip;

  /// Whether this screen is the frontmost one and should own the strip.
  final bool publish;

  /// The primary action at the bottom of the strip.
  final Widget? primary;

  /// Whether [AppBar.leading] stays in the slim header in strip mode.
  final bool leadingInHeader;

  /// See [DuoStripActions.reserveBottomSlot].
  final bool reserveBottomSlot;

  final bool extendBodyBehindAppBar;
  final Widget? bottomNavigationBar;
  final List<Widget> stripTools;

  @override
  Widget build(BuildContext context) {
    final stripMode = useStrip && DuoStripScope.hasStrip(context);
    final primary = this.primary;

    return DuoStripActions(
      enabled: stripMode && publish,
      stripMode: stripMode,
      top: [...stripTools, ...?appBar.actions],
      bottom: [?primary],
      reserveBottomSlot: reserveBottomSlot,
      child: Scaffold(
        extendBodyBehindAppBar: !stripMode && extendBodyBehindAppBar,
        appBar: stripMode ? null : (wrapAppBar?.call(appBar) ?? appBar),
        bottomNavigationBar: bottomNavigationBar,
        body: Column(
          children: [
            if (stripMode)
              DuoSlimHeader(
                leading: leadingInHeader ? appBar.leading : null,
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
  const DuoSlimHeader({
    super.key,
    this.leading,
    this.title,
    this.flexibleSpace,
    this.trailing,
  });

  static const height = 40.0;

  /// Room above the header: the inner display has no top inset, but its
  /// corners are rounded and the status cluster sits beside the header.
  static const topSpacing = 10.0;

  final Widget? leading;
  final Widget? title;
  final Widget? flexibleSpace;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = this.leading;
    final title = this.title;
    final flexibleSpace = this.flexibleSpace;
    final trailing = this.trailing;
    if (leading == null && title == null && trailing == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      key: const ValueKey('duo_slim_header'),
      bottom: false,
      minimum: const EdgeInsets.only(top: topSpacing),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (flexibleSpace != null) Positioned.fill(child: flexibleSpace),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: leading == null ? 16 : 0,
                end: 8,
              ),
              child: Row(
                children: [
                  if (leading != null)
                    SizedBox.square(
                      dimension: height,
                      child: IconButtonTheme(
                        data: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size.square(height),
                          ),
                        ),
                        child: Center(child: leading),
                      ),
                    ),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title ?? const SizedBox.shrink(),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
