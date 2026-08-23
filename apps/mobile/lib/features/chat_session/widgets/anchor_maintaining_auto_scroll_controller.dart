import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// An auto-scroll controller that can correct a visible anchor during layout.
///
/// [ScrollPosition.correctForNewDimensions] runs after the viewport has laid
/// out its children but before that frame is painted. Applying an exact,
/// measured correction there prevents the one-frame jump that a post-frame
/// [jumpTo] would expose.
class AnchorMaintainingAutoScrollController extends SimpleAutoScrollController {
  AnchorMaintainingAutoScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.suggestedRowHeight,
    super.viewportBoundaryGetter,
    super.copyTagsFrom,
    super.debugLabel,
  }) : super(beginGetter: _top, endGetter: _bottom);

  /// Returns the exact pixel correction needed to keep the captured message
  /// at the same viewport position, or null when no correction is pending.
  ValueGetter<double?>? layoutAnchorCorrection;

  /// Persists a correction because [ScrollPosition.correctPixels] deliberately
  /// does not notify regular scroll listeners.
  ValueChanged<double>? onLayoutAnchorCorrected;

  int _streamingExtentCorrectionGeneration = 0;
  int? _pendingStreamingExtentCorrection;

  /// Requests a one-frame fallback that preserves the reverse-list position
  /// when the active streaming row itself is the content being read.
  int requestStreamingExtentCorrection() {
    final generation = ++_streamingExtentCorrectionGeneration;
    _pendingStreamingExtentCorrection = generation;
    return generation;
  }

  void clearStreamingExtentCorrection(int generation) {
    if (_pendingStreamingExtentCorrection == generation) {
      _pendingStreamingExtentCorrection = null;
    }
  }

  void _clearStreamingExtentCorrection() {
    _pendingStreamingExtentCorrection = null;
  }

  double? _takeStreamingExtentCorrection(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    if (_pendingStreamingExtentCorrection == null) return null;
    _pendingStreamingExtentCorrection = null;
    return newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
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

  static double _top(Rect rect) => rect.top;
  static double _bottom(Rect rect) => rect.bottom;
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

  final AnchorMaintainingAutoScrollController controller;

  @override
  bool correctForNewDimensions(
    ScrollMetrics oldPosition,
    ScrollMetrics newPosition,
  ) {
    final correction = controller.layoutAnchorCorrection?.call();
    if (correction != null) {
      controller._clearStreamingExtentCorrection();
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
    final streamingCorrection = controller._takeStreamingExtentCorrection(
      oldPosition,
      newPosition,
    );
    if (streamingCorrection != null) {
      final target = clampDouble(
        pixels + streamingCorrection,
        newPosition.minScrollExtent,
        newPosition.maxScrollExtent,
      );
      if ((target - pixels).abs() > 0.5) {
        correctPixels(target);
        controller.onLayoutAnchorCorrected?.call(target);
        return false;
      }
      return true;
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }
}
