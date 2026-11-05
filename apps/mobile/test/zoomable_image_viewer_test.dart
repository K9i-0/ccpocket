import 'package:ccpocket/widgets/zoomable_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double scaleOf(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  Future<void> doubleTap(WidgetTester tester, Offset position) async {
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(position);
    await tester.pumpAndSettle();
  }

  testWidgets('fills the area and toggles double-tap zoom', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZoomableImageViewer(child: SizedBox(width: 200, height: 100)),
        ),
      ),
    );

    final viewer = tester.getRect(find.byType(InteractiveViewer));
    expect(viewer.size, tester.getSize(find.byType(Scaffold)));

    await doubleTap(tester, viewer.center);
    expect(scaleOf(tester), closeTo(ZoomableImageViewer.doubleTapScale, 0.01));

    await doubleTap(tester, viewer.center);
    expect(scaleOf(tester), closeTo(1, 0.01));
  });

  testWidgets('single tap is reported after the double-tap window', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoomableImageViewer(
            onTap: () => taps++,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InteractiveViewer));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(taps, 1);
    expect(scaleOf(tester), closeTo(1, 0.01));
  });
}
