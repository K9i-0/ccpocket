import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'selection_controller.dart';
import 'selection_model.dart';

/// Identifies which selection handle is being rendered or dragged.
enum MarkdownSelectionHandleType { start, end }

/// Custom visual builder for a selection handle.
///
/// The returned widget is rendered inside an opaque 44x44+ hit target anchored
/// to the selection endpoint's `LeaderLayer`.
typedef MarkdownSelectionHandleBuilder =
    Widget Function(
      BuildContext context,
      MarkdownSelectionHandleType type,
      double lineHeight,
      Color color,
    );

/// Custom builder for the touch selection magnifier loupe.
typedef MarkdownMagnifierBuilder =
    Widget Function(
      BuildContext context,
      Offset globalFocalPoint,
      double lineHeight,
    );

/// Callback fired when a handle drag starts.
typedef MarkdownHandleDragStartCallback =
    void Function(MarkdownSelectionHandleType type, Offset globalPosition);

/// Callback fired as a handle is dragged.
typedef MarkdownHandleDragUpdateCallback =
    void Function(MarkdownSelectionHandleType type, Offset globalPosition);

/// Callback fired when a handle drag ends or is cancelled.
typedef MarkdownHandleDragEndCallback =
    void Function(MarkdownSelectionHandleType type);

/// Minimum logical hit-target dimension for touch selection handles.
const double kMarkdownHandleMinHitSize = 44.0;

/// Key of the start selection handle, for finding it in widget tests.
const Key kMarkdownStartHandleKey =
    MarkdownSelectionHandleOverlay.startHandleKey;

/// Key of the end selection handle, for finding it in widget tests.
const Key kMarkdownEndHandleKey = MarkdownSelectionHandleOverlay.endHandleKey;

/// Low drag threshold (in logical pixels) used for selection handles so drags
/// initiate immediately without losing the gesture arena to scrollables.
const double kMarkdownHandleTouchSlop = 2.0;

/// Default selection handle color when none is configured.
const Color kDefaultMarkdownHandleColor = Color(0xFF007AFF);

/// Custom `OverlayEntry`-based overlay managing opaque, low-slop selection
/// handles, a touch magnifier loupe, and an optional context menu toolbar.
///
/// Unlike Flutter's built-in `_SelectionHandleOverlay` (which uses
/// `HitTestBehavior.translucent` and `2 * kTouchSlop`), each handle here is
/// wrapped in `Listener(behavior: HitTestBehavior.opaque)` and a
/// `RawGestureDetector(behavior: HitTestBehavior.opaque)` with a `2.0` lp
/// `touchSlop` over a minimum 44x44 hit box. Touches on a handle therefore
/// never penetrate to underlying `ListView`s, horizontal scrollables, or
/// navigation back-swipe gestures.
class MarkdownSelectionHandleOverlay {
  MarkdownSelectionHandleOverlay({
    required this.context,
    this.handleBuilder,
    this.magnifierBuilder,
    this.isSurfaceMounted,
    this.onHandleDragStart,
    this.onHandleDragUpdate,
    this.onHandleDragEnd,
    this.onHandleDragCancel,
  });

  /// Test & semantics key for the start handle hit container.
  static const Key startHandleKey = ValueKey<String>(
    'markdown_selection_start_handle',
  );

  /// Test & semantics key for the end handle hit container.
  static const Key endHandleKey = ValueKey<String>(
    'markdown_selection_end_handle',
  );

  /// Test & semantics key for the active magnifier widget.
  static const Key magnifierKey = ValueKey<String>(
    'markdown_selection_magnifier',
  );

  /// Test & semantics key for the context menu toolbar wrapper.
  static const Key toolbarKey = ValueKey<String>('markdown_selection_toolbar');

  /// Build context inside which the enclosing [Overlay] is resolved.
  final BuildContext context;

  /// Optional custom handle visual builder.
  final MarkdownSelectionHandleBuilder? handleBuilder;

  /// Optional custom magnifier visual builder.
  final MarkdownMagnifierBuilder? magnifierBuilder;

  /// Optional predicate checking whether a previously linked surface is still
  /// mounted before clearing its handle layers during teardown.
  final bool Function(MarkdownSelectionSurface surface)? isSurfaceMounted;

  final MarkdownHandleDragStartCallback? onHandleDragStart;
  final MarkdownHandleDragUpdateCallback? onHandleDragUpdate;
  final MarkdownHandleDragEndCallback? onHandleDragEnd;
  final MarkdownHandleDragEndCallback? onHandleDragCancel;

  /// Leader/follower link tracking the start handle anchor (`caretRect.bottomLeft`).
  final LayerLink startHandleLayerLink = LayerLink();

  /// Leader/follower link tracking the end handle anchor (`caretRect.bottomLeft`).
  final LayerLink endHandleLayerLink = LayerLink();

  OverlayEntry? _startHandleEntry;
  OverlayEntry? _endHandleEntry;
  OverlayEntry? _magnifierEntry;
  OverlayEntry? _toolbarEntry;

  MarkdownSelectionSurface? _linkedStartSurface;
  MarkdownSelectionSurface? _linkedEndSurface;

  double _startLineHeight = 20.0;
  double _endLineHeight = 20.0;
  Color _handleColor = kDefaultMarkdownHandleColor;

  Offset? _magnifierFocalPoint;
  double _magnifierLineHeight = 20.0;

  WidgetBuilder? _toolbarBuilder;
  MarkdownSelectionHandleType? _activeDragHandle;
  bool _disposed = false;

  /// Whether at least one handle overlay entry is currently mounted.
  bool get handlesVisible =>
      _startHandleEntry != null || _endHandleEntry != null;

  /// Whether the context menu toolbar overlay entry is currently mounted.
  bool get toolbarVisible => _toolbarEntry != null;

  /// Whether the magnifier loupe overlay entry is currently mounted.
  bool get magnifierVisible => _magnifierEntry != null;

  /// The handle currently capturing an active drag gesture, if any.
  MarkdownSelectionHandleType? get activeDragHandle => _activeDragHandle;

  /// Synchronizes handle layer links and overlay entries with [endpoints].
  ///
  /// [showStartHandle] and [showEndHandle] allow independent suppression of
  /// endpoints that have scrolled outside the visible viewport clip (for
  /// example into a `ListView`'s `cacheExtent` behind a floating composer).
  ///
  /// If a handle is currently being dragged and its endpoint scrolls off-screen
  /// (for instance after flipping handles during edge autoscroll), its
  /// [OverlayEntry] stays mounted (visually hidden via unlinked
  /// `CompositedTransformFollower`) so the active `PanGestureRecognizer` is not
  /// cancelled mid-gesture.
  void updateHandles({
    required MarkdownHandleEndpoints? endpoints,
    required bool visible,
    bool showStartHandle = true,
    bool showEndHandle = true,
    Color? handleColor,
  }) {
    if (_disposed) return;
    final nextColor = handleColor ?? kDefaultMarkdownHandleColor;
    final colorChanged = nextColor != _handleColor;
    _handleColor = nextColor;

    final effectiveShowStart =
        visible && showStartHandle && endpoints != null && endpoints.hasStart;
    final effectiveShowEnd =
        visible && showEndHandle && endpoints != null && endpoints.hasEnd;

    if (!effectiveShowStart && !effectiveShowEnd) {
      _unlinkHandleLayers();
      if (_activeDragHandle != MarkdownSelectionHandleType.start) {
        _removeStartHandleEntry();
      }
      if (_activeDragHandle != MarkdownSelectionHandleType.end) {
        _removeEndHandleEntry();
      }
      return;
    }

    _linkHandleLayers(
      endpoints,
      linkStart: effectiveShowStart,
      linkEnd: effectiveShowEnd,
    );

    if (effectiveShowStart) {
      final nextHeight = (endpoints.startLineHeight ?? 20.0).clamp(8.0, 200.0);
      final heightChanged = nextHeight != _startLineHeight;
      _startLineHeight = nextHeight;
      _ensureStartHandleEntry(needsRebuild: colorChanged || heightChanged);
    } else if (_activeDragHandle != MarkdownSelectionHandleType.start) {
      _removeStartHandleEntry();
    }

    if (effectiveShowEnd) {
      final nextHeight = (endpoints.endLineHeight ?? 20.0).clamp(8.0, 200.0);
      final heightChanged = nextHeight != _endLineHeight;
      _endLineHeight = nextHeight;
      _ensureEndHandleEntry(needsRebuild: colorChanged || heightChanged);
    } else if (_activeDragHandle != MarkdownSelectionHandleType.end) {
      _removeEndHandleEntry();
    }
  }

  /// Displays or moves the touch magnifier loupe at [globalFocalPoint].
  void showMagnifier({
    required Offset globalFocalPoint,
    required double lineHeight,
  }) {
    if (_disposed) return;
    _magnifierFocalPoint = globalFocalPoint;
    _magnifierLineHeight = lineHeight.clamp(8.0, 200.0);

    final overlay = _resolveOverlay();
    if (overlay == null) return;

    if (_magnifierEntry == null) {
      _magnifierEntry = OverlayEntry(builder: _buildMagnifier);
      overlay.insert(_magnifierEntry!);
    } else {
      _markEntryNeedsBuild(_magnifierEntry!);
    }
  }

  /// Hides the touch magnifier loupe.
  void hideMagnifier() {
    _magnifierFocalPoint = null;
    _magnifierEntry?.remove();
    _magnifierEntry?.dispose();
    _magnifierEntry = null;
  }

  /// Shows, updates, or hides the selection context menu toolbar.
  void updateToolbar({required bool visible, required WidgetBuilder? builder}) {
    if (_disposed) return;
    if (!visible || builder == null) {
      _toolbarBuilder = null;
      _toolbarEntry?.remove();
      _toolbarEntry?.dispose();
      _toolbarEntry = null;
      return;
    }

    _toolbarBuilder = builder;
    final overlay = _resolveOverlay();
    if (overlay == null) return;

    if (_toolbarEntry == null) {
      _toolbarEntry = OverlayEntry(builder: _buildToolbar);
      overlay.insert(_toolbarEntry!);
    } else {
      _markEntryNeedsBuild(_toolbarEntry!);
    }
  }

  /// Removes all overlay entries and unlinks handle layer leaders.
  void hideAll() {
    _activeDragHandle = null;
    _unlinkHandleLayers();
    _removeStartHandleEntry();
    _removeEndHandleEntry();
    hideMagnifier();
    updateToolbar(visible: false, builder: null);
  }

  /// Disposes all overlay resources permanently.
  void dispose() {
    if (_disposed) return;
    hideAll();
    _disposed = true;
  }

  OverlayState? _resolveOverlay() {
    if (!context.mounted) return null;
    return Overlay.maybeOf(context) ??
        Overlay.maybeOf(context, rootOverlay: true);
  }

  bool _canUpdateSurface(MarkdownSelectionSurface surface) {
    if (isSurfaceMounted != null && !isSurfaceMounted!(surface)) {
      return false;
    }
    return surface.globalBounds != null;
  }

  void _linkHandleLayers(
    MarkdownHandleEndpoints endpoints, {
    required bool linkStart,
    required bool linkEnd,
  }) {
    final nextStartSurface = linkStart && endpoints.hasStart
        ? endpoints.startSurface
        : null;
    final nextEndSurface = linkEnd && endpoints.hasEnd
        ? endpoints.endSurface
        : null;

    if (_linkedStartSurface != null &&
        _linkedStartSurface != nextStartSurface &&
        _canUpdateSurface(_linkedStartSurface!)) {
      _linkedStartSurface!.clearSelectionHandleLayersIfLinked(
        startHandleLayerLink: startHandleLayerLink,
      );
    }
    if (_linkedEndSurface != null &&
        _linkedEndSurface != nextEndSurface &&
        _canUpdateSurface(_linkedEndSurface!)) {
      _linkedEndSurface!.clearSelectionHandleLayersIfLinked(
        endHandleLayerLink: endHandleLayerLink,
      );
    }

    if (nextStartSurface != null && nextStartSurface == nextEndSurface) {
      if (_canUpdateSurface(nextStartSurface)) {
        nextStartSurface.setSelectionHandleLayers(
          startHandleLayerLink: startHandleLayerLink,
          startHandleLocalOffset: endpoints.startLocalOffset,
          endHandleLayerLink: endHandleLayerLink,
          endHandleLocalOffset: endpoints.endLocalOffset,
        );
      }
    } else {
      if (nextStartSurface != null && _canUpdateSurface(nextStartSurface)) {
        nextStartSurface.setSelectionHandleLayers(
          startHandleLayerLink: startHandleLayerLink,
          startHandleLocalOffset: endpoints.startLocalOffset,
        );
      }
      if (nextEndSurface != null && _canUpdateSurface(nextEndSurface)) {
        nextEndSurface.setSelectionHandleLayers(
          endHandleLayerLink: endHandleLayerLink,
          endHandleLocalOffset: endpoints.endLocalOffset,
        );
      }
    }

    _linkedStartSurface = nextStartSurface;
    _linkedEndSurface = nextEndSurface;
  }

  void _unlinkHandleLayers() {
    if (_linkedStartSurface != null &&
        _canUpdateSurface(_linkedStartSurface!)) {
      _linkedStartSurface!.clearSelectionHandleLayersIfLinked(
        startHandleLayerLink: startHandleLayerLink,
        endHandleLayerLink: _linkedStartSurface == _linkedEndSurface
            ? endHandleLayerLink
            : null,
      );
    }
    if (_linkedEndSurface != null &&
        _linkedEndSurface != _linkedStartSurface &&
        _canUpdateSurface(_linkedEndSurface!)) {
      _linkedEndSurface!.clearSelectionHandleLayersIfLinked(
        endHandleLayerLink: endHandleLayerLink,
      );
    }
    _linkedStartSurface = null;
    _linkedEndSurface = null;
  }

  void _ensureStartHandleEntry({bool needsRebuild = true}) {
    final overlay = _resolveOverlay();
    if (overlay == null) return;
    if (_startHandleEntry == null) {
      _startHandleEntry = OverlayEntry(
        builder: (ctx) => _buildHandleOverlayEntry(
          ctx,
          type: MarkdownSelectionHandleType.start,
        ),
      );
      overlay.insert(
        _startHandleEntry!,
        below: _magnifierEntry ?? _toolbarEntry,
      );
    } else if (needsRebuild) {
      _markEntryNeedsBuild(_startHandleEntry!);
    }
  }

  void _ensureEndHandleEntry({bool needsRebuild = true}) {
    final overlay = _resolveOverlay();
    if (overlay == null) return;
    if (_endHandleEntry == null) {
      _endHandleEntry = OverlayEntry(
        builder: (ctx) => _buildHandleOverlayEntry(
          ctx,
          type: MarkdownSelectionHandleType.end,
        ),
      );
      overlay.insert(_endHandleEntry!, below: _magnifierEntry ?? _toolbarEntry);
    } else if (needsRebuild) {
      _markEntryNeedsBuild(_endHandleEntry!);
    }
  }

  void _removeStartHandleEntry() {
    _startHandleEntry?.remove();
    _startHandleEntry?.dispose();
    _startHandleEntry = null;
  }

  void _removeEndHandleEntry() {
    _endHandleEntry?.remove();
    _endHandleEntry?.dispose();
    _endHandleEntry = null;
  }

  void _markEntryNeedsBuild(OverlayEntry entry) {
    if (!entry.mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && entry.mounted) {
          entry.markNeedsBuild();
        }
      });
    } else {
      entry.markNeedsBuild();
    }
  }

  Widget _buildHandleOverlayEntry(
    BuildContext overlayContext, {
    required MarkdownSelectionHandleType type,
  }) {
    final isStart = type == MarkdownSelectionHandleType.start;
    final lineHeight = isStart ? _startLineHeight : _endLineHeight;
    final layerLink = isStart ? startHandleLayerLink : endHandleLayerLink;
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    // LeaderLayer sits at `caretRect.bottomLeft` (`(0, 0)` in follower space).
    final Offset followerOffset;
    if (isApple) {
      followerOffset = isStart
          // Centered over the top pin head above the caret line.
          ? Offset(
              -kMarkdownHandleMinHitSize / 2,
              -lineHeight - kMarkdownHandleMinHitSize + 14.0,
            )
          // Centered over the bottom pin head below the caret baseline.
          : const Offset(-kMarkdownHandleMinHitSize / 2, -6.0);
    } else {
      followerOffset = isStart
          // Left-hanging teardrop below baseline.
          ? const Offset(-kMarkdownHandleMinHitSize * 0.75, -6.0)
          // Right-hanging teardrop below baseline.
          : const Offset(-kMarkdownHandleMinHitSize * 0.25, -6.0);
    }

    final handleVisual =
        handleBuilder?.call(overlayContext, type, lineHeight, _handleColor) ??
        _DefaultMarkdownSelectionHandle(
          type: type,
          lineHeight: lineHeight,
          color: _handleColor,
          isAppleStyle: isApple,
        );

    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: followerOffset,
        child: _OpaqueSelectionHandleTarget(
          key: isStart ? startHandleKey : endHandleKey,
          type: type,
          onDragStart: _dispatchHandleDragStart,
          onDragUpdate: _dispatchHandleDragUpdate,
          onDragEnd: _dispatchHandleDragEnd,
          onDragCancel: _dispatchHandleDragCancel,
          child: handleVisual,
        ),
      ),
    );
  }

  void _dispatchHandleDragStart(
    MarkdownSelectionHandleType type,
    Offset globalPosition,
  ) {
    _activeDragHandle = type;
    onHandleDragStart?.call(type, globalPosition);
  }

  void _dispatchHandleDragUpdate(
    MarkdownSelectionHandleType type,
    Offset globalPosition,
  ) {
    onHandleDragUpdate?.call(type, globalPosition);
  }

  void _dispatchHandleDragEnd(MarkdownSelectionHandleType type) {
    if (_activeDragHandle == type) {
      _activeDragHandle = null;
    }
    onHandleDragEnd?.call(type);
  }

  void _dispatchHandleDragCancel(MarkdownSelectionHandleType type) {
    if (_activeDragHandle == type) {
      _activeDragHandle = null;
    }
    onHandleDragCancel?.call(type);
  }

  Widget _buildMagnifier(BuildContext overlayContext) {
    final focalPoint = _magnifierFocalPoint;
    if (focalPoint == null) {
      return const SizedBox.shrink();
    }

    final custom = magnifierBuilder?.call(
      overlayContext,
      focalPoint,
      _magnifierLineHeight,
    );
    if (custom != null) {
      return KeyedSubtree(key: magnifierKey, child: custom);
    }

    return _DefaultMarkdownMagnifier(
      key: magnifierKey,
      globalFocalPoint: focalPoint,
      lineHeight: _magnifierLineHeight,
    );
  }

  Widget _buildToolbar(BuildContext overlayContext) {
    final builder = _toolbarBuilder;
    if (builder == null) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(key: toolbarKey, child: builder(overlayContext));
  }
}

/// Opaque 44x44+ hit target with a low-slop (`2.0` lp) `PanGestureRecognizer`.
///
/// The `Listener(behavior: HitTestBehavior.opaque)` guarantees that Flutter's
/// `Overlay` stops hit-testing inside this box, completely shielding drags
/// from underlying scrollables and route gestures.
class _OpaqueSelectionHandleTarget extends StatelessWidget {
  const _OpaqueSelectionHandleTarget({
    super.key,
    required this.type,
    required this.child,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
  });

  final MarkdownSelectionHandleType type;
  final Widget child;
  final MarkdownHandleDragStartCallback? onDragStart;
  final MarkdownHandleDragUpdateCallback? onDragUpdate;
  final MarkdownHandleDragEndCallback? onDragEnd;
  final MarkdownHandleDragEndCallback? onDragCancel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kMarkdownHandleMinHitSize,
      height: kMarkdownHandleMinHitSize,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          // Opaque hit-test absorber: prevents Overlay hit-testing from
          // reaching underlying ListView or horizontal scroll containers.
        },
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            PanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                  () => PanGestureRecognizer(
                    debugOwner: this,
                    supportedDevices: const <PointerDeviceKind>{
                      PointerDeviceKind.touch,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.invertedStylus,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  (PanGestureRecognizer instance) {
                    instance
                      ..gestureSettings = const DeviceGestureSettings(
                        touchSlop: kMarkdownHandleTouchSlop,
                      )
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = (DragStartDetails details) {
                        onDragStart?.call(type, details.globalPosition);
                      }
                      ..onUpdate = (DragUpdateDetails details) {
                        onDragUpdate?.call(type, details.globalPosition);
                      }
                      ..onEnd = (_) {
                        onDragEnd?.call(type);
                      }
                      ..onCancel = () {
                        onDragCancel?.call(type);
                      };
                  },
                ),
          },
          child: child,
        ),
      ),
    );
  }
}

/// Default `widgets.dart`-only visual painter for selection handles.
///
/// Renders an iOS-style vertical stem + pin ball on Apple platforms, and a
/// classic teardrop handle on Android and other platforms.
class _DefaultMarkdownSelectionHandle extends StatelessWidget {
  const _DefaultMarkdownSelectionHandle({
    required this.type,
    required this.lineHeight,
    required this.color,
    required this.isAppleStyle,
  });

  final MarkdownSelectionHandleType type;
  final double lineHeight;
  final Color color;
  final bool isAppleStyle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(kMarkdownHandleMinHitSize, kMarkdownHandleMinHitSize),
      painter: isAppleStyle
          ? _ApplePinHandlePainter(
              type: type,
              lineHeight: lineHeight,
              color: color,
            )
          : _TeardropHandlePainter(type: type, color: color),
    );
  }
}

class _ApplePinHandlePainter extends CustomPainter {
  const _ApplePinHandlePainter({
    required this.type,
    required this.lineHeight,
    required this.color,
  });

  final MarkdownSelectionHandleType type;
  final double lineHeight;
  final Color color;

  static const double _ballRadius = 5.5;
  static const double _stemWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;

    if (type == MarkdownSelectionHandleType.start) {
      // Follower offset places caret top at `size.height - 14.0`.
      final caretTopY = size.height - 14.0;
      final caretBottomY = caretTopY + lineHeight;
      final ballCenterY = caretTopY - _ballRadius;

      canvas.drawRect(
        Rect.fromLTRB(
          cx - _stemWidth / 2,
          caretTopY,
          cx + _stemWidth / 2,
          caretBottomY,
        ),
        paint,
      );
      canvas.drawCircle(Offset(cx, ballCenterY), _ballRadius, paint);
    } else {
      // Follower offset places caret baseline at `y = 6.0`.
      const caretBottomY = 6.0;
      final caretTopY = caretBottomY - lineHeight;
      final ballCenterY = caretBottomY + _ballRadius;

      canvas.drawRect(
        Rect.fromLTRB(
          cx - _stemWidth / 2,
          caretTopY,
          cx + _stemWidth / 2,
          caretBottomY,
        ),
        paint,
      );
      canvas.drawCircle(Offset(cx, ballCenterY), _ballRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_ApplePinHandlePainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.color != color;
  }
}

class _TeardropHandlePainter extends CustomPainter {
  const _TeardropHandlePainter({required this.type, required this.color});

  final MarkdownSelectionHandleType type;
  final Color color;

  static const double _radius = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Tip aligns with the caret baseline anchor inside the 44x44 box.
    final isStart = type == MarkdownSelectionHandleType.start;
    final tipX = isStart ? size.width * 0.75 : size.width * 0.25;
    const tipY = 6.0;

    final centerX = isStart ? tipX - _radius : tipX + _radius;
    const centerY = tipY + _radius;

    final path = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: _radius),
      );

    // Pointed corner connecting circle smoothly up to the caret baseline tip.
    if (isStart) {
      path.addRect(Rect.fromLTWH(centerX, tipY, _radius, _radius));
    } else {
      path.addRect(Rect.fromLTWH(tipX, tipY, _radius, _radius));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TeardropHandlePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

/// Default `widgets.dart`-only rounded pill magnifier loupe.
class _DefaultMarkdownMagnifier extends StatelessWidget {
  const _DefaultMarkdownMagnifier({
    super.key,
    required this.globalFocalPoint,
    required this.lineHeight,
  });

  final Offset globalFocalPoint;
  final double lineHeight;

  static const Size _magnifierSize = Size(92.0, 44.0);
  static const double _verticalClearance = 44.0;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.maybeSizeOf(context) ?? const Size(400, 800);
    final left = (globalFocalPoint.dx - _magnifierSize.width / 2)
        .clamp(8.0, math.max(8.0, mediaSize.width - _magnifierSize.width - 8.0))
        .toDouble();
    final rawTop =
        globalFocalPoint.dy - _magnifierSize.height - _verticalClearance;
    final top = rawTop
        .clamp(
          8.0,
          math.max(8.0, mediaSize.height - _magnifierSize.height - 8.0),
        )
        .toDouble();

    final magnifierCenter = Offset(
      left + _magnifierSize.width / 2,
      top + _magnifierSize.height / 2,
    );
    final focalOffset = globalFocalPoint - magnifierCenter;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22.0),
                border: Border.all(color: const Color(0x33000000), width: 1.0),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x28000000),
                    blurRadius: 12.0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: RawMagnifier(
                size: _magnifierSize,
                magnificationScale: 1.25,
                focalPointOffset: focalOffset,
                decoration: const MagnifierDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22.0)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
