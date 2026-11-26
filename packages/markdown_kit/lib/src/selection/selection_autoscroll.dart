import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Resolves a custom [MarkdownAutoscrollTarget] for a selection drag gesture.
typedef MarkdownAutoscrollTargetResolver = MarkdownAutoscrollTarget? Function(
  BuildContext context,
  Offset globalPointer,
);

/// Configuration for edge autoscrolling during touch/mouse selection drags.
@immutable
class MarkdownSelectionAutoscrollConfig {
  /// Creates an autoscroll configuration.
  const MarkdownSelectionAutoscrollConfig({
    this.enabled = true,
    this.edgeZone = 48.0,
    this.maxVelocity = 600.0,
    this.topPad = 0.0,
    this.bottomPad = 0.0,
    this.useMediaQueryPadding = true,
    this.useHostUnionGate = true,
    this.targetResolver,
  }) : assert(edgeZone >= 0),
       assert(maxVelocity >= 0),
       assert(topPad >= 0),
       assert(bottomPad >= 0);

  /// Whether edge autoscroll is active.
  final bool enabled;

  /// Thickness (in logical pixels) of the top and bottom trigger bands.
  final double edgeZone;

  /// Peak scroll speed in logical pixels per second at the outer edge.
  final double maxVelocity;

  /// Additional inset from the top of the scroll viewport (e.g. floating app bar).
  final double topPad;

  /// Additional inset from the bottom of the scroll viewport (e.g. composer bar).
  final double bottomPad;

  /// Whether to account for overlapping `MediaQuery.padding` safe-area insets.
  final bool useMediaQueryPadding;

  /// When true, prevents autoscrolling past edges where the selectable host
  /// content does not extend into the trigger band.
  final bool useHostUnionGate;

  /// Optional override that resolves the scrollable target to drive.
  final MarkdownAutoscrollTargetResolver? targetResolver;

  /// Returns a copy of this configuration with the given fields replaced.
  MarkdownSelectionAutoscrollConfig copyWith({
    bool? enabled,
    double? edgeZone,
    double? maxVelocity,
    double? topPad,
    double? bottomPad,
    bool? useMediaQueryPadding,
    bool? useHostUnionGate,
    MarkdownAutoscrollTargetResolver? targetResolver,
  }) {
    return MarkdownSelectionAutoscrollConfig(
      enabled: enabled ?? this.enabled,
      edgeZone: edgeZone ?? this.edgeZone,
      maxVelocity: maxVelocity ?? this.maxVelocity,
      topPad: topPad ?? this.topPad,
      bottomPad: bottomPad ?? this.bottomPad,
      useMediaQueryPadding: useMediaQueryPadding ?? this.useMediaQueryPadding,
      useHostUnionGate: useHostUnionGate ?? this.useHostUnionGate,
      targetResolver: targetResolver ?? this.targetResolver,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownSelectionAutoscrollConfig &&
        other.enabled == enabled &&
        other.edgeZone == edgeZone &&
        other.maxVelocity == maxVelocity &&
        other.topPad == topPad &&
        other.bottomPad == bottomPad &&
        other.useMediaQueryPadding == useMediaQueryPadding &&
        other.useHostUnionGate == useHostUnionGate &&
        other.targetResolver == targetResolver;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    edgeZone,
    maxVelocity,
    topPad,
    bottomPad,
    useMediaQueryPadding,
    useHostUnionGate,
    targetResolver,
  );
}

/// Global-coordinate viewport geometry used for edge-band hit calculations.
@immutable
class MarkdownAutoscrollViewport {
  /// Creates viewport geometry for [rect].
  const MarkdownAutoscrollViewport({
    required this.rect,
    this.topInset = 0.0,
    this.bottomInset = 0.0,
    this.axis = Axis.vertical,
  }) : assert(topInset >= 0),
       assert(bottomInset >= 0);

  /// Global bounding rectangle of the scrollable viewport.
  final Rect rect;

  /// Effective top inset inside [rect].
  final double topInset;

  /// Effective bottom inset inside [rect].
  final double bottomInset;

  /// Scroll axis of the target.
  final Axis axis;

  /// Effective top trigger boundary in global coordinates.
  double get effectiveTop => rect.top + topInset;

  /// Effective bottom trigger boundary in global coordinates.
  double get effectiveBottom => rect.bottom - bottomInset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownAutoscrollViewport &&
        other.rect == rect &&
        other.topInset == topInset &&
        other.bottomInset == bottomInset &&
        other.axis == axis;
  }

  @override
  int get hashCode => Object.hash(rect, topInset, bottomInset, axis);
}

/// Abstract scrollable target driven by [applyMarkdownSelectionAutoscroll].
///
/// All scroll deltas are expressed in **screen-space visual coordinates**:
/// - Negative `visualDy` reveals content **above** the viewport (scrolls up).
/// - Positive `visualDy` reveals content **below** the viewport (scrolls down).
abstract interface class MarkdownAutoscrollTarget {
  /// Returns the target's current viewport in global coordinates, or `null` if
  /// unmounted / not laid out.
  MarkdownAutoscrollViewport? viewport();

  /// Whether more content can be revealed above the top edge.
  bool canScrollUp();

  /// Whether more content can be revealed below the bottom edge.
  bool canScrollDown();

  /// Applies a screen-space vertical scroll delta and returns the actual
  /// visual delta applied (`0.0` if clamped at a scroll boundary).
  double scrollByVisualDelta(double visualDy);
}

/// Callback-backed [MarkdownAutoscrollTarget] for custom scroll containers
/// and deterministic unit testing.
class MarkdownCallbackAutoscrollTarget implements MarkdownAutoscrollTarget {
  /// Creates a target that forwards every call to the given callbacks.
  const MarkdownCallbackAutoscrollTarget({
    required this.viewportProvider,
    required this.canScrollUpCallback,
    required this.canScrollDownCallback,
    required this.onScrollVisualDelta,
  });

  /// Returns the viewport's current geometry, or null when it is not available.
  /// Backs [viewport].
  final MarkdownAutoscrollViewport? Function() viewportProvider;

  /// Returns whether more content can be revealed above. Backs [canScrollUp].
  final bool Function() canScrollUpCallback;

  /// Returns whether more content can be revealed below. Backs [canScrollDown].
  final bool Function() canScrollDownCallback;

  /// Scrolls by the given screen-space delta and returns the delta actually
  /// applied. Backs [scrollByVisualDelta].
  final double Function(double visualDy) onScrollVisualDelta;

  @override
  MarkdownAutoscrollViewport? viewport() => viewportProvider();

  @override
  bool canScrollUp() => canScrollUpCallback();

  @override
  bool canScrollDown() => canScrollDownCallback();

  @override
  double scrollByVisualDelta(double visualDy) => onScrollVisualDelta(visualDy);
}

/// [MarkdownAutoscrollTarget] backed by a Flutter vertical [ScrollableState].
///
/// Explicitly handles both [AxisDirection.down] (standard `ListView`) and
/// [AxisDirection.up] (`ListView(reverse: true)`), inverting pixel deltas when
/// the scroll axis grows upward so screen-space edge scrolling always moves
/// toward the pointer's edge.
class MarkdownScrollableAutoscrollTarget implements MarkdownAutoscrollTarget {
  /// Creates a target that scrolls [scrollable].
  MarkdownScrollableAutoscrollTarget({
    required this.scrollable,
    this.topPad = 0.0,
    this.bottomPad = 0.0,
    this.useMediaQueryPadding = true,
  });

  /// Resolves the nearest vertical [ScrollableState] from [context], or uses
  /// the `targetResolver` of [config] when provided.
  static MarkdownAutoscrollTarget? resolve(
    BuildContext context, {
    required Offset globalPointer,
    MarkdownSelectionAutoscrollConfig config =
        const MarkdownSelectionAutoscrollConfig(),
  }) {
    if (config.targetResolver != null) {
      return config.targetResolver!(context, globalPointer);
    }

    final scrollable = _findVerticalScrollable(context);
    if (scrollable == null) return null;

    return MarkdownScrollableAutoscrollTarget(
      scrollable: scrollable,
      topPad: config.topPad,
      bottomPad: config.bottomPad,
      useMediaQueryPadding: config.useMediaQueryPadding,
    );
  }

  /// The scrollable that is scrolled.
  final ScrollableState scrollable;

  /// Extra inset, in logical pixels, from the top of the viewport before the
  /// top trigger band starts.
  final double topPad;

  /// Extra inset, in logical pixels, from the bottom of the viewport before the
  /// bottom trigger band starts.
  final double bottomPad;

  /// Whether the part of the viewport covered by the `MediaQuery.padding` safe
  /// area is added to the insets.
  final bool useMediaQueryPadding;

  bool get _isReversed => scrollable.axisDirection == AxisDirection.up;

  bool get _isReady =>
      scrollable.mounted &&
      scrollable.position.hasPixels &&
      scrollable.position.hasContentDimensions;

  @override
  MarkdownAutoscrollViewport? viewport() {
    if (!scrollable.mounted) return null;
    final renderObject = scrollable.context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;

    var resolvedTopInset = topPad;
    var resolvedBottomInset = bottomPad;

    if (useMediaQueryPadding) {
      final mediaQuery = MediaQuery.maybeOf(scrollable.context);
      if (mediaQuery != null) {
        final topOverlap = math.max(0.0, mediaQuery.padding.top - rect.top);
        final screenBottom = mediaQuery.size.height;
        final bottomOverlap = math.max(
          0.0,
          mediaQuery.padding.bottom - (screenBottom - rect.bottom),
        );
        resolvedTopInset += topOverlap;
        resolvedBottomInset += bottomOverlap;
      }
    }

    return MarkdownAutoscrollViewport(
      rect: rect,
      topInset: resolvedTopInset,
      bottomInset: resolvedBottomInset,
    );
  }

  @override
  bool canScrollUp() {
    if (!_isReady) return false;
    final position = scrollable.position;
    // On AxisDirection.up (reverse: true), higher pixels reveal content above.
    if (_isReversed) {
      return position.pixels < position.maxScrollExtent - 1e-3;
    }
    return position.pixels > position.minScrollExtent + 1e-3;
  }

  @override
  bool canScrollDown() {
    if (!_isReady) return false;
    final position = scrollable.position;
    // On AxisDirection.up (reverse: true), lower pixels reveal content below.
    if (_isReversed) {
      return position.pixels > position.minScrollExtent + 1e-3;
    }
    return position.pixels < position.maxScrollExtent - 1e-3;
  }

  @override
  double scrollByVisualDelta(double visualDy) {
    if (!_isReady || visualDy == 0.0) return 0.0;
    final position = scrollable.position;
    final before = position.pixels;
    final pixelDelta = _isReversed ? -visualDy : visualDy;
    final nextPixels = (before + pixelDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((nextPixels - before).abs() < 1e-6) {
      return 0.0;
    }
    position.jumpTo(nextPixels);
    final appliedPixelDelta = position.pixels - before;
    return _isReversed ? -appliedPixelDelta : appliedPixelDelta;
  }

  static ScrollableState? _findVerticalScrollable(BuildContext context) {
    final direct = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (direct != null) return direct;

    // Also search immediate descendants if the selection scope wraps a ListView.
    ScrollableState? descendant;
    void visit(Element element) {
      if (descendant != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final candidate = element.state as ScrollableState;
        if (candidate.axisDirection == AxisDirection.down ||
            candidate.axisDirection == AxisDirection.up) {
          descendant = candidate;
          return;
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return descendant;
  }
}

/// Per-drag autoscroll state that tracks per-direction hard-stop disarming.
///
/// Once a direction reaches its scroll boundary, it is disarmed until the
/// pointer leaves that edge band so autoscroll does not spin against an
/// immovable edge.
class MarkdownAutoscrollSession {
  bool _upDisarmed = false;
  bool _downDisarmed = false;

  /// Whether upward autoscroll is currently disarmed after hitting a stop.
  bool get isUpDisarmed => _upDisarmed;

  /// Whether downward autoscroll is currently disarmed after hitting a stop.
  bool get isDownDisarmed => _downDisarmed;

  /// Resets both directions to armed (typically at drag start or end).
  void reset() {
    _upDisarmed = false;
    _downDisarmed = false;
  }

  void _disarmUp() => _upDisarmed = true;

  void _armUp() => _upDisarmed = false;

  void _disarmDown() => _downDisarmed = true;

  void _armDown() => _downDisarmed = false;
}

/// Evaluates pointer position against [target]'s viewport edge bands and
/// applies one tick of smooth velocity-ramped autoscroll.
///
/// Returns the actual screen-space visual delta scrolled (`< 0` for up,
/// `> 0` for down, `0.0` when idle, gated, or disarmed).
double applyMarkdownSelectionAutoscroll({
  required MarkdownAutoscrollTarget target,
  required MarkdownAutoscrollSession session,
  required Offset globalPointer,
  required Duration dt,
  MarkdownSelectionAutoscrollConfig config =
      const MarkdownSelectionAutoscrollConfig(),
  Rect? hostBounds,
}) {
  if (!config.enabled || dt <= Duration.zero || config.edgeZone <= 0) {
    return 0.0;
  }

  final viewport = target.viewport();
  if (viewport == null || viewport.rect.isEmpty) {
    return 0.0;
  }

  final topBound = viewport.effectiveTop;
  final bottomBound = viewport.effectiveBottom;
  if (bottomBound <= topBound) {
    return 0.0;
  }

  final effectiveZone = math.min(config.edgeZone, (bottomBound - topBound) / 2);
  if (effectiveZone <= 0) {
    return 0.0;
  }

  final topTriggerY = topBound + effectiveZone;
  final bottomTriggerY = bottomBound - effectiveZone;

  final inTopBand = globalPointer.dy < topTriggerY;
  final inBottomBand = globalPointer.dy > bottomTriggerY;

  if (!inTopBand) {
    session._armUp();
  }
  if (!inBottomBand) {
    session._armDown();
  }

  final dtSeconds = math.min(dt.inMicroseconds / 1e6, 0.1);
  if (dtSeconds <= 0) return 0.0;

  if (inTopBand) {
    if (session.isUpDisarmed) return 0.0;
    if (config.useHostUnionGate &&
        hostBounds != null &&
        hostBounds.top >= topTriggerY) {
      return 0.0;
    }
    if (!target.canScrollUp()) {
      session._disarmUp();
      return 0.0;
    }

    final ratio = ((topTriggerY - globalPointer.dy) / effectiveZone).clamp(
      0.0,
      1.0,
    );
    final velocity = config.maxVelocity * ratio * (0.5 + 0.5 * ratio);
    final desiredDy = -velocity * dtSeconds;
    if (desiredDy == 0.0) return 0.0;

    final applied = target.scrollByVisualDelta(desiredDy);
    if (applied.abs() < 1e-6 || !target.canScrollUp()) {
      session._disarmUp();
    }
    return applied;
  }

  if (inBottomBand) {
    if (session.isDownDisarmed) return 0.0;
    if (config.useHostUnionGate &&
        hostBounds != null &&
        hostBounds.bottom <= bottomTriggerY) {
      return 0.0;
    }
    if (!target.canScrollDown()) {
      session._disarmDown();
      return 0.0;
    }

    final ratio = ((globalPointer.dy - bottomTriggerY) / effectiveZone).clamp(
      0.0,
      1.0,
    );
    final velocity = config.maxVelocity * ratio * (0.5 + 0.5 * ratio);
    final desiredDy = velocity * dtSeconds;
    if (desiredDy == 0.0) return 0.0;

    final applied = target.scrollByVisualDelta(desiredDy);
    if (applied.abs() < 1e-6 || !target.canScrollDown()) {
      session._disarmDown();
    }
    return applied;
  }

  return 0.0;
}
