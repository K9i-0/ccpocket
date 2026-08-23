import 'package:flutter/foundation.dart' show ValueGetter, clampDouble;
import 'package:flutter/widgets.dart';

/// Keeps the reverse-list offset stable when the viewport itself changes size,
/// for example when the keyboard or a bottom overlay opens.
///
/// Message-content changes are deliberately ignored here. A lazy list's
/// `maxScrollExtent` is only an estimate, so using its delta can produce large
/// jumps. The chat message list preserves a measured visible anchor for those
/// changes instead.
class MaintainReadingPositionOnResizePhysics extends ScrollPhysics {
  const MaintainReadingPositionOnResizePhysics({
    required this.shouldMaintain,
    super.parent,
  });

  final ValueGetter<bool> shouldMaintain;

  static const double dimensionChangeTolerance = 1;

  @override
  MaintainReadingPositionOnResizePhysics applyTo(ScrollPhysics? ancestor) {
    return MaintainReadingPositionOnResizePhysics(
      shouldMaintain: shouldMaintain,
      parent: buildParent(ancestor),
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    if (isScrolling || !shouldMaintain()) return adjusted;

    final viewportDelta =
        oldPosition.viewportDimension - newPosition.viewportDimension;
    if (viewportDelta.abs() <= dimensionChangeTolerance) return adjusted;

    // Animated IME resizing can produce unstable lazy-list extent estimates.
    // Keep the reverse-list offset unchanged until resizing settles.
    return clampDouble(
      newPosition.pixels,
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }
}
