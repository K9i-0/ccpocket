import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Target alignment within the viewport for [IndexedScrollController.scrollToIndex].
enum IndexedScrollPosition {
  /// Aligns the item's visual leading edge (top for vertical lists, left for
  /// horizontal lists) with the corresponding viewport edge.
  begin,

  /// Centers the item within the viewport.
  middle,

  /// Aligns the item's visual trailing edge (bottom for vertical lists, right
  /// for horizontal lists) with the corresponding viewport edge.
  end,
}

/// A [ScrollController] that supports scrolling to arbitrary item indices in
/// lazy, variable-height scroll views and layout-time scroll anchor correction.
///
/// Wrap items with [IndexedScrollTag] so the controller can measure mounted
/// items and locate off-screen indices via bounded jump-and-measure steps.
///
/// [ScrollPosition.correctForNewDimensions] runs after the viewport has laid
/// out its children but before that frame is painted. Providing
/// [layoutAnchorCorrection] applies an exact, measured correction there,
/// preventing the one-frame jump that a post-frame [jumpTo] would expose.
class IndexedScrollController extends ScrollController {
  IndexedScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
  });

  static const int _kMaxSearchSteps = 40;
  static const int _kMaxRefinementPasses = 2;
  static const double _kOffsetTolerance = 1.0;

  final Map<int, IndexedScrollTagState> _tagMap =
      <int, IndexedScrollTagState>{};
  late final Map<int, IndexedScrollTagState> _unmodifiableTagMap =
      UnmodifiableMapView<int, IndexedScrollTagState>(_tagMap);

  /// Currently mounted [IndexedScrollTag] states keyed by their logical index.
  Map<int, IndexedScrollTagState> get tagMap => _unmodifiableTagMap;

  /// Returns the exact pixel correction needed to keep the captured item
  /// at the same viewport position, or null when no correction is pending.
  ValueGetter<double?>? layoutAnchorCorrection;

  /// Persists a correction because [ScrollPosition.correctPixels] deliberately
  /// does not notify regular scroll listeners.
  ValueChanged<double>? onLayoutAnchorCorrected;

  bool _isAutoScrolling = false;
  bool _disposed = false;
  int _scrollToken = 0;

  /// Whether a programmatic [scrollToIndex] operation is currently running.
  bool get isAutoScrolling => _isAutoScrolling;

  void _registerTag(int index, IndexedScrollTagState state) {
    if (_disposed) return;
    _tagMap[index] = state;
  }

  void _unregisterTag(int index, IndexedScrollTagState state) {
    if (identical(_tagMap[index], state)) {
      _tagMap.remove(index);
    }
  }

  /// Cancels any in-flight [scrollToIndex] operation.
  void cancelAutoScroll() {
    _scrollToken++;
    _isAutoScrolling = false;
  }

  /// Scrolls the attached scrollable so the item tagged with [index] is placed
  /// at [preferPosition] in the viewport.
  ///
  /// Handles both already-mounted items and off-screen items in variable-height
  /// lazy lists (both normal and `reverse: true` / inverted-index layouts).
  /// Cancels cleanly if the user scrolls, another [scrollToIndex] starts,
  /// [cancelAutoScroll] is called, or this controller is disposed.
  Future<void> scrollToIndex(
    int index, {
    Duration duration = const Duration(milliseconds: 250),
    IndexedScrollPosition preferPosition = IndexedScrollPosition.middle,
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (_disposed || !hasClients || positions.length != 1) return;

    final token = ++_scrollToken;
    _isAutoScrolling = true;

    void onControllerScroll() {
      if (_disposed || _scrollToken != token || !hasClients) return;
      if (positions.length == 1 &&
          position.userScrollDirection != ScrollDirection.idle) {
        cancelAutoScroll();
      }
    }

    addListener(onControllerScroll);
    try {
      bool isCancelled() =>
          _disposed ||
          _scrollToken != token ||
          !hasClients ||
          positions.length != 1;

      bool? indicesIncreaseWithOffset;
      int? lastDirection;
      var directionFlips = 0;
      int? previousClosestDistance;

      // Phase 1: If the target index is not yet mounted, step toward it in
      // bounded jump-and-measure iterations until it enters the mounted tree.
      for (var step = 0; step < _kMaxSearchSteps; step++) {
        if (isCancelled()) return;

        final existing = _tagMap[index];
        if (existing != null &&
            existing.mounted &&
            _offsetForTag(existing, preferPosition) != null) {
          break;
        }

        final metrics = _collectMountedTagMetrics();
        if (metrics.isEmpty) return;

        var minEntry = metrics.first;
        var maxEntry = metrics.first;
        var closestDistance = (metrics.first.index - index).abs();
        for (final entry in metrics) {
          if (entry.index < minEntry.index) minEntry = entry;
          if (entry.index > maxEntry.index) maxEntry = entry;
          final dist = (entry.index - index).abs();
          if (dist < closestDistance) closestDistance = dist;
        }

        // If the target index falls strictly between two mounted indices yet
        // has no tag, it does not exist in this list.
        if (index > minEntry.index && index < maxEntry.index) {
          return;
        }

        if (minEntry.index != maxEntry.index &&
            (maxEntry.offset - minEntry.offset).abs() > 0.5) {
          indicesIncreaseWithOffset = maxEntry.offset > minEntry.offset;
        } else if (indicesIncreaseWithOffset != null &&
            previousClosestDistance != null &&
            closestDistance > previousClosestDistance) {
          // Single-tag guess moved away from the target; flip orientation.
          indicesIncreaseWithOffset = !indicesIncreaseWithOffset;
        }
        previousClosestDistance = closestDistance;

        final scrollPosition = position;
        final viewportDimension = scrollPosition.viewportDimension;
        if (!viewportDimension.isFinite || viewportDimension <= 0) return;

        final targetIsHigherIndex = index > maxEntry.index;
        bool moveTowardMaxExtent;
        if (indicesIncreaseWithOffset != null) {
          moveTowardMaxExtent = indicesIncreaseWithOffset
              ? targetIsHigherIndex
              : !targetIsHigherIndex;
        } else {
          // Only one tag is mounted so far; respect scroll boundaries first,
          // otherwise probe assuming ascending index order.
          final atMin =
              scrollPosition.pixels <= scrollPosition.minScrollExtent + 0.5;
          final atMax =
              scrollPosition.pixels >= scrollPosition.maxScrollExtent - 0.5;
          if (atMin && !atMax) {
            moveTowardMaxExtent = true;
            indicesIncreaseWithOffset = targetIsHigherIndex;
          } else if (atMax && !atMin) {
            moveTowardMaxExtent = false;
            indicesIncreaseWithOffset = !targetIsHigherIndex;
          } else {
            indicesIncreaseWithOffset = true;
            moveTowardMaxExtent = targetIsHigherIndex;
          }
        }

        final direction = moveTowardMaxExtent ? 1 : -1;
        if (lastDirection != null && lastDirection != direction) {
          directionFlips++;
        }
        lastDirection = direction;

        final double avgItemExtent;
        if (minEntry.index != maxEntry.index) {
          final spanOffsets = (maxEntry.offset - minEntry.offset).abs();
          final spanIndices = (maxEntry.index - minEntry.index).abs();
          avgItemExtent = math.max(24.0, spanOffsets / spanIndices);
        } else {
          avgItemExtent = math.max(minEntry.extent, viewportDimension * 0.5);
        }

        final indexDelta = targetIsHigherIndex
            ? index - maxEntry.index
            : minEntry.index - index;
        var delta = indexDelta * avgItemExtent;

        // After a direction flip (overshoot in variable-height lists), cap
        // steps below viewportDimension so we cannot skip over the target.
        if (directionFlips > 0) {
          delta = math.min(delta, viewportDimension * 0.75);
        }
        // Ensure forward progress across items taller than the estimated step.
        delta = math.max(delta, viewportDimension * 0.5);

        final nextOffset = clampDouble(
          scrollPosition.pixels + direction * delta,
          scrollPosition.minScrollExtent,
          scrollPosition.maxScrollExtent,
        );

        if ((nextOffset - scrollPosition.pixels).abs() < 0.5) {
          // Reached the end of scrollable content in this direction.
          return;
        }

        jumpTo(nextOffset);
        await _waitForEndOfFrame();
      }

      // Phase 2: Target is mounted; align it cleanly and refine if lazy layout
      // shifted extents during the animation.
      for (var pass = 0; pass <= _kMaxRefinementPasses; pass++) {
        if (isCancelled()) return;
        final targetState = _tagMap[index];
        if (targetState == null || !targetState.mounted) return;

        final targetOffset = _offsetForTag(targetState, preferPosition);
        if (targetOffset == null) return;

        final remaining = (targetOffset - position.pixels).abs();
        if (remaining <= _kOffsetTolerance) return;

        if (duration <= Duration.zero) {
          jumpTo(targetOffset);
        } else {
          final passDuration = pass == 0
              ? duration
              : Duration(
                  milliseconds: math.max(
                    1,
                    math.min(120, duration.inMilliseconds ~/ 2),
                  ),
                );
          await animateTo(targetOffset, duration: passDuration, curve: curve);
        }

        if (isCancelled()) return;
        await _waitForEndOfFrame();
      }
    } finally {
      if (!_disposed) {
        removeListener(onControllerScroll);
      }
      if (_scrollToken == token) {
        _isAutoScrolling = false;
      }
    }
  }

  List<_MountedTagMetric> _collectMountedTagMetrics() {
    if (!hasClients || positions.length != 1) return const [];
    final isVertical = position.axis == Axis.vertical;
    final metrics = <_MountedTagMetric>[];
    for (final entry in _tagMap.entries) {
      final state = entry.value;
      if (!state.mounted) continue;
      final renderObject = state.context.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) continue;
      final revealed = viewport.getOffsetToReveal(renderObject, 0.0);
      if (!revealed.offset.isFinite) continue;
      final extent = isVertical
          ? renderObject.size.height
          : renderObject.size.width;
      metrics.add(
        _MountedTagMetric(
          index: entry.key,
          offset: revealed.offset,
          extent: extent,
        ),
      );
    }
    return metrics;
  }

  double? _offsetForTag(
    IndexedScrollTagState tagState,
    IndexedScrollPosition preferPosition,
  ) {
    if (!tagState.mounted || !hasClients || positions.length != 1) return null;
    final renderObject = tagState.context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) return null;

    final axisDirection = position.axisDirection;
    final isReversed =
        axisDirection == AxisDirection.up ||
        axisDirection == AxisDirection.left;
    final alignment = switch (preferPosition) {
      IndexedScrollPosition.begin => isReversed ? 1.0 : 0.0,
      IndexedScrollPosition.middle => 0.5,
      IndexedScrollPosition.end => isReversed ? 0.0 : 1.0,
    };

    final revealed = viewport.getOffsetToReveal(renderObject, alignment);
    if (!revealed.offset.isFinite) return null;
    return clampDouble(
      revealed.offset,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  Future<void> _waitForEndOfFrame() {
    final completer = Completer<void>();
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    binding.ensureVisualUpdate();
    return completer.future;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _AnchorMaintainingScrollPosition(
      controller: this,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollToken++;
    _isAutoScrolling = false;
    _tagMap.clear();
    super.dispose();
  }
}

/// Associates a scrollable child widget with a logical [index] so
/// [IndexedScrollController.scrollToIndex] can measure and reveal it.
class IndexedScrollTag extends StatefulWidget {
  const IndexedScrollTag({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  final IndexedScrollController controller;
  final int index;
  final Widget child;

  @override
  State<IndexedScrollTag> createState() => IndexedScrollTagState();
}

/// State for [IndexedScrollTag], exposed in [IndexedScrollController.tagMap].
class IndexedScrollTagState extends State<IndexedScrollTag> {
  @override
  void initState() {
    super.initState();
    widget.controller._registerTag(widget.index, this);
  }

  @override
  void didUpdateWidget(covariant IndexedScrollTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.index != widget.index) {
      oldWidget.controller._unregisterTag(oldWidget.index, this);
      widget.controller._registerTag(widget.index, this);
    }
  }

  @override
  void activate() {
    super.activate();
    widget.controller._registerTag(widget.index, this);
  }

  @override
  void dispose() {
    widget.controller._unregisterTag(widget.index, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MountedTagMetric {
  const _MountedTagMetric({
    required this.index,
    required this.offset,
    required this.extent,
  });

  final int index;
  final double offset;
  final double extent;
}

class _AnchorMaintainingScrollPosition extends ScrollPositionWithSingleContext {
  _AnchorMaintainingScrollPosition({
    required this.controller,
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    required super.oldPosition,
    required super.debugLabel,
  });

  final IndexedScrollController controller;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final correction = controller.layoutAnchorCorrection?.call();
    if (correction != null) {
      final target = clampDouble(
        pixels + correction,
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
      if ((target - pixels).abs() > 0.5) {
        correctPixels(target);
        controller.onLayoutAnchorCorrected?.call(target);
        return false;
      }
      // The measured anchor already accounts for every layout change in this
      // frame, including a simultaneous viewport resize. Do not apply the
      // resize physics a second time when the correction has converged.
      return true;
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }
}
