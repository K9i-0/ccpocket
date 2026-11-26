import 'package:ccpocket/features/setup_guide/widgets/guide_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('ExpandingDotsIndicator', () {
    const activeColor = Color(0xFFD4450A);
    const inactiveColor = Color(0xFFE4E4E7);

    List<Container> dotContainers(WidgetTester tester) {
      return tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(ExpandingDotsIndicator),
              matching: find.byType(Container),
            ),
          )
          .toList();
    }

    testWidgets('expands the active dot and syncs with PageController', (
      tester,
    ) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: controller,
                    children: const [
                      SizedBox.expand(child: Text('Page 0')),
                      SizedBox.expand(child: Text('Page 1')),
                      SizedBox.expand(child: Text('Page 2')),
                    ],
                  ),
                ),
                ExpandingDotsIndicator(
                  controller: controller,
                  count: 3,
                  dotWidth: 8,
                  dotHeight: 8,
                  spacing: 6,
                  expansionFactor: 2.5,
                  activeDotColor: activeColor,
                  dotColor: inactiveColor,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var dots = dotContainers(tester);
      expect(dots, hasLength(3));
      expect(dots[0].constraints?.maxWidth, closeTo(20, 0.01));
      expect(dots[1].constraints?.maxWidth, closeTo(8, 0.01));
      expect(dots[2].constraints?.maxWidth, closeTo(8, 0.01));
      expect((dots[0].decoration! as BoxDecoration).color, activeColor);
      expect((dots[1].decoration! as BoxDecoration).color, inactiveColor);

      // Jump to page 1.
      controller.jumpToPage(1);
      await tester.pump();

      dots = dotContainers(tester);
      expect(dots[0].constraints?.maxWidth, closeTo(8, 0.01));
      expect(dots[1].constraints?.maxWidth, closeTo(20, 0.01));
      expect(dots[2].constraints?.maxWidth, closeTo(8, 0.01));
      expect((dots[0].decoration! as BoxDecoration).color, inactiveColor);
      expect((dots[1].decoration! as BoxDecoration).color, activeColor);

      // Mid-scroll interpolation between page 1 and page 2.
      final viewportWidth = tester.getSize(find.byType(PageView)).width;
      controller.jumpTo(viewportWidth * 1.5);
      await tester.pump();

      dots = dotContainers(tester);
      expect(dots[0].constraints?.maxWidth, closeTo(8, 0.01));
      expect(dots[1].constraints?.maxWidth, closeTo(14, 0.01));
      expect(dots[2].constraints?.maxWidth, closeTo(14, 0.01));
      expect(
        (dots[1].decoration! as BoxDecoration).color,
        Color.lerp(inactiveColor, activeColor, 0.5),
      );
      expect(
        (dots[2].decoration! as BoxDecoration).color,
        Color.lerp(inactiveColor, activeColor, 0.5),
      );
    });

    testWidgets('renders safely before PageController is attached', (
      tester,
    ) async {
      final controller = PageController(initialPage: 1);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandingDotsIndicator(
              controller: controller,
              count: 3,
              activeDotColor: activeColor,
              dotColor: inactiveColor,
            ),
          ),
        ),
      );

      final dots = dotContainers(tester);
      expect(dots, hasLength(3));
      expect(dots[1].constraints?.maxWidth, closeTo(20, 0.01));
      expect((dots[1].decoration! as BoxDecoration).color, activeColor);
    });

    testWidgets('returns empty box when count is zero', (tester) async {
      final controller = PageController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandingDotsIndicator(
              controller: controller,
              count: 0,
              activeDotColor: activeColor,
              dotColor: inactiveColor,
            ),
          ),
        ),
      );

      expect(dotContainers(tester), isEmpty);
    });
  });
}
