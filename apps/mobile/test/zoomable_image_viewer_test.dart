import 'package:ccpocket/widgets/zoomable_image_viewer.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('reports zoom state transitions via onZoomChanged', (
    tester,
  ) async {
    final zoomStates = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoomableImageViewer(
            minScale: 1.0,
            onZoomChanged: zoomStates.add,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(InteractiveViewer));
    expect(zoomStates, isEmpty);

    await doubleTap(tester, center);
    expect(zoomStates, [true]);

    await doubleTap(tester, center);
    expect(zoomStates, [true, false]);
  });

  testWidgets('coordinates PageView physics lock via onZoomChanged', (
    tester,
  ) async {
    var isZoomed = false;
    var currentPage = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PageView.builder(
                physics: isZoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: 2,
                onPageChanged: (page) => setState(() {
                  currentPage = page;
                  isZoomed = false;
                }),
                itemBuilder: (context, index) {
                  return ZoomableImageViewer(
                    key: ValueKey('page_$index'),
                    minScale: 1.0,
                    onZoomChanged: (zoomed) {
                      if (index == currentPage) {
                        setState(() => isZoomed = zoomed);
                      }
                    },
                    child: Text('Page $index'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Page 0'), findsOneWidget);

    // Zoom in: PageView locks scrolling.
    final center = tester.getCenter(find.byType(PageView));
    await doubleTap(tester, center);
    expect(isZoomed, isTrue);
    expect(
      tester.widget<PageView>(find.byType(PageView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(currentPage, 0);

    // Zoom out: PageView unlocks and swipes smoothly to page 1.
    await doubleTap(tester, center);
    expect(isZoomed, isFalse);
    expect(tester.widget<PageView>(find.byType(PageView)).physics, isNull);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(currentPage, 1);
    expect(find.text('Page 1'), findsOneWidget);
  });

  testWidgets('calls onSwipeNext and onSwipePrevious only while unzoomed', (
    tester,
  ) async {
    var nextCalls = 0;
    var previousCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoomableImageViewer(
            onSwipeNext: () => nextCalls++,
            onSwipePrevious: () => previousCalls++,
            child: const SizedBox(width: 200, height: 100),
          ),
        ),
      ),
    );

    final viewer = find.byType(InteractiveViewer);
    await tester.drag(viewer, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(nextCalls, 1);

    await tester.drag(viewer, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(previousCalls, 1);

    // Zoomed drags should pan instead of firing swipe callbacks.
    await doubleTap(tester, tester.getCenter(viewer));
    await tester.drag(viewer, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(nextCalls, 1);
  });
}
