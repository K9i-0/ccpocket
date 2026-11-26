import 'package:ccpocket/widgets/indexed_scroll_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Chat tags items with an index that runs against the scroll offset, and a
  // long message can be the only mounted tag. The search then starts in the
  // wrong direction; turning around must not shrink its steps, or a target
  // dozens of screens away is never reached.
  for (final reverse in [true, false]) {
    {
      testWidgets('reaches a far target past tall items (reverse=$reverse)', (
        tester,
      ) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);
        const count = 120;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ListView.builder(
                  controller: controller,
                  reverse: reverse,
                  itemCount: count,
                  itemBuilder: (_, index) => IndexedScrollTag(
                    key: ValueKey('item_$index'),
                    controller: controller,
                    index: count - 1 - index,
                    // Every item is taller than the viewport, so only one or
                    // two tags are ever mounted.
                    child: SizedBox(
                      height: 1500,
                      child: Text('Item ${count - 1 - index}'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // Start in the middle of item 60 so exactly one tag is mounted and
        // neither scroll boundary hints at the orientation.
        controller.jumpTo(60 * 1500 + 400);
        await tester.pump();
        for (final target in [5, 115]) {
          controller.jumpTo(60 * 1500 + 400);
          await tester.pump();
          final f = controller.scrollToIndex(
            target,
            preferPosition: IndexedScrollPosition.begin,
            duration: Duration.zero,
          );
          await tester.pumpAndSettle();
          await f;
          expect(
            find.text('Item $target'),
            findsOneWidget,
            reason: 'target $target reverse=$reverse',
          );
        }
      });
    }
  }
}
