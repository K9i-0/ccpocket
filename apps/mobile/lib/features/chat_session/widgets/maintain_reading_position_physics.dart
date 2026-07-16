import 'package:flutter/foundation.dart' show ValueGetter, clampDouble;
import 'package:flutter/widgets.dart';

/// Keeps the content currently being read visually fixed while output grows
/// at the bottom of a `reverse: true` chat list.
///
/// The correction happens during layout, before a frame is painted, so the
/// viewport does not flicker between the unadjusted and corrected positions.
class MaintainReadingPositionPhysics extends ScrollPhysics {
  const MaintainReadingPositionPhysics({
    required this.shouldMaintain,
    super.parent,
  });

  final ValueGetter<bool> shouldMaintain;

  /// Matches the threshold used by the chat's scroll-to-bottom affordance.
  static const double scrolledUpThreshold = 100;
  static const double extentChangeTolerance = 1;

  @override
  MaintainReadingPositionPhysics applyTo(ScrollPhysics? ancestor) {
    return MaintainReadingPositionPhysics(
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
    if (oldPosition.pixels <= scrolledUpThreshold) return adjusted;

    final delta = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
    if (delta <= extentChangeTolerance) return adjusted;

    return clampDouble(
      adjusted + delta,
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }
}
