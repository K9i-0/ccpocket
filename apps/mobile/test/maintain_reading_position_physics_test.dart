import 'package:ccpocket/features/chat_session/widgets/maintain_reading_position_physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaintainReadingPositionPhysics', () {
    test('compensates for growth while streaming away from the bottom', () {
      final physics = MaintainReadingPositionPhysics(
        shouldMaintain: () => true,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(pixels: 240, maxScrollExtent: 1000),
        newPosition: _metrics(pixels: 240, maxScrollExtent: 1120),
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 360);
    });

    test('continues following output near the bottom', () {
      final physics = MaintainReadingPositionPhysics(
        shouldMaintain: () => true,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(pixels: 80, maxScrollExtent: 1000),
        newPosition: _metrics(pixels: 80, maxScrollExtent: 1120),
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 80);
    });

    test('does not compensate outside streaming', () {
      final physics = MaintainReadingPositionPhysics(
        shouldMaintain: () => false,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(pixels: 240, maxScrollExtent: 1000),
        newPosition: _metrics(pixels: 240, maxScrollExtent: 1120),
        isScrolling: false,
        velocity: 0,
      );

      expect(adjusted, 240);
    });

    test('does not fight an active user drag', () {
      final physics = MaintainReadingPositionPhysics(
        shouldMaintain: () => true,
      );

      final adjusted = physics.adjustPositionForNewDimensions(
        oldPosition: _metrics(pixels: 240, maxScrollExtent: 1000),
        newPosition: _metrics(pixels: 240, maxScrollExtent: 1120),
        isScrolling: true,
        velocity: 0,
      );

      expect(adjusted, 240);
    });
  });
}

FixedScrollMetrics _metrics({
  required double pixels,
  required double maxScrollExtent,
}) {
  return FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    viewportDimension: 600,
    axisDirection: AxisDirection.up,
    devicePixelRatio: 1,
  );
}
