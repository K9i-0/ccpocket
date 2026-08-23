import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/widgets/maintain_reading_position_physics.dart';

void main() {
  group('MaintainReadingPositionOnResizePhysics', () {
    test('ignores message-content extent growth', () {
      final physics = MaintainReadingPositionOnResizePhysics(
        shouldMaintain: () => true,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(pixels: 240, maxScrollExtent: 1000),
        newPosition: _metrics(pixels: 240, maxScrollExtent: 1400),
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 240);
    });

    test('preserves the offset while the viewport changes', () {
      final physics = MaintainReadingPositionOnResizePhysics(
        shouldMaintain: () => true,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(
          pixels: 240,
          maxScrollExtent: 1000,
          viewportDimension: 600,
        ),
        newPosition: _metrics(
          pixels: 240,
          maxScrollExtent: 1300,
          viewportDimension: 300,
        ),
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 240);
    });

    test('does not compensate at latest', () {
      final physics = MaintainReadingPositionOnResizePhysics(
        shouldMaintain: () => false,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(
          pixels: 0,
          maxScrollExtent: 1000,
          viewportDimension: 600,
        ),
        newPosition: _metrics(
          pixels: 0,
          maxScrollExtent: 1300,
          viewportDimension: 300,
        ),
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 0);
    });

    test('does not fight an active drag', () {
      final physics = MaintainReadingPositionOnResizePhysics(
        shouldMaintain: () => true,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(
          pixels: 240,
          maxScrollExtent: 1000,
          viewportDimension: 600,
        ),
        newPosition: _metrics(
          pixels: 240,
          maxScrollExtent: 1300,
          viewportDimension: 300,
        ),
        isScrolling: true,
        velocity: 0,
      );

      expect(adjusted, 240);
    });

    test('ignores unstable lazy-list estimates during a viewport resize', () {
      final physics = MaintainReadingPositionOnResizePhysics(
        shouldMaintain: () => true,
      );

      var pixels = 2120.0;
      for (final estimatedMax in [28141.0, 31107.0, 40434.0, 31151.0]) {
        pixels = physics.adjustPositionForNewDimensions(
          oldPosition: _metrics(
            pixels: 2120,
            maxScrollExtent: 28632,
            viewportDimension: 364,
          ),
          newPosition: _metrics(
            pixels: pixels,
            maxScrollExtent: estimatedMax,
            viewportDimension: 537,
          ),
          isScrolling: false,
          velocity: 0,
        );
      }

      expect(pixels, 2120);
    });
  });
}

FixedScrollMetrics _metrics({
  required double pixels,
  required double maxScrollExtent,
  double viewportDimension = 600,
}) {
  return FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    viewportDimension: viewportDimension,
    axisDirection: AxisDirection.up,
    devicePixelRatio: 1,
  );
}
