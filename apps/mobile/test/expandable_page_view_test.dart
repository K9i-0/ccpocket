import 'package:ccpocket/widgets/expandable_page_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('ExpandablePageView', () {
    testWidgets('measures initial page and interpolates height across pages', (
      tester,
    ) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      final heights = [120.0, 260.0, 180.0];
      final changedPages = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpandablePageView.builder(
                controller: controller,
                itemCount: heights.length,
                onPageChanged: changedPages.add,
                itemBuilder: (context, index) => SizedBox(
                  height: heights[index],
                  child: Center(child: Text('Page $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ExpandablePageView)).height, 120.0);

      // Animate to page 1 and verify height settles to 260.
      controller.animateToPage(
        1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Trigger measurement of newly built page 1, then check interpolation.
      await tester.pump();
      final midHeight = tester.getSize(find.byType(ExpandablePageView)).height;
      expect(midHeight, greaterThan(120.0));
      expect(midHeight, lessThan(260.0));

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ExpandablePageView)).height, 260.0);
      expect(changedPages, contains(1));

      // Jump directly to page 2 (unmeasured until built) and verify height.
      controller.jumpToPage(2);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ExpandablePageView)).height, 180.0);
    });

    testWidgets('updates height when current page content expands in place', (
      tester,
    ) async {
      var expanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Column(
                  children: [
                    ExpandablePageView.builder(
                      itemCount: 2,
                      itemBuilder: (context, index) => SizedBox(
                        height: index == 0 ? (expanded ? 240.0 : 100.0) : 150.0,
                        child: Text('Page $index'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => expanded = !expanded),
                      child: const Text('Toggle'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ExpandablePageView)).height, 100.0);

      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ExpandablePageView)).height, 240.0);
    });

    testWidgets('renders nothing when itemCount is zero', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandablePageView.builder(
              itemCount: 0,
              itemBuilder: (context, index) => const SizedBox(height: 100),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(ExpandablePageView)).height, 0.0);
      expect(find.byType(PageView), findsNothing);
    });
  });
}
