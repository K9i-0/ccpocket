import 'package:ccpocket/widgets/indexed_scroll_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('IndexedScrollController', () {
    testWidgets('scrolls to already-mounted item with begin, middle, end', (
      tester,
    ) async {
      final controller = IndexedScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ListView.builder(
                controller: controller,
                itemCount: 30,
                itemBuilder: (_, index) => IndexedScrollTag(
                  key: ValueKey('item_$index'),
                  controller: controller,
                  index: index,
                  child: SizedBox(height: 80, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        ),
      );

      // Scroll so item 12 (offset 960..1040) is mounted with room above and
      // below to test begin, middle, and end without clamping to scroll bounds.
      controller.jumpTo(600);
      await tester.pump();

      final beginFuture = controller.scrollToIndex(
        12,
        preferPosition: IndexedScrollPosition.begin,
        duration: const Duration(milliseconds: 100),
      );
      expect(controller.isAutoScrolling, isTrue);
      await tester.pumpAndSettle();
      await beginFuture;
      expect(controller.isAutoScrolling, isFalse);

      final item12 = find.text('Item 12');
      expect(item12, findsOneWidget);
      expect(tester.getTopLeft(item12).dy, closeTo(0, 1.0));

      // Align middle (viewport center = 300).
      final middleFuture = controller.scrollToIndex(
        12,
        preferPosition: IndexedScrollPosition.middle,
        duration: const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      await middleFuture;
      expect(tester.getCenter(item12).dy, closeTo(300, 1.0));

      // Align end (viewport bottom = 600).
      final endFuture = controller.scrollToIndex(
        12,
        preferPosition: IndexedScrollPosition.end,
        duration: const Duration(milliseconds: 100),
      );
      await tester.pumpAndSettle();
      await endFuture;
      expect(tester.getBottomLeft(item12).dy, closeTo(600, 1.0));
    });

    testWidgets(
      'scrolls to off-screen items forward and backward in variable-height lazy list',
      (tester) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);

        double heightFor(int index) => 40.0 + ((index * 37) % 180);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ListView.builder(
                  controller: controller,
                  itemCount: 120,
                  itemBuilder: (_, index) => IndexedScrollTag(
                    key: ValueKey('var_$index'),
                    controller: controller,
                    index: index,
                    child: SizedBox(
                      height: heightFor(index),
                      child: Text('Var $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Var 95'), findsNothing);

        // Jump far forward to off-screen item 95 aligned to begin.
        final forwardFuture = controller.scrollToIndex(
          95,
          preferPosition: IndexedScrollPosition.begin,
          duration: const Duration(milliseconds: 120),
        );
        await tester.pumpAndSettle();
        await forwardFuture;

        final item95 = find.text('Var 95');
        expect(item95, findsOneWidget);
        expect(tester.getTopLeft(item95).dy, closeTo(0, 1.5));
        expect(controller.isAutoScrolling, isFalse);

        // Jump far backward to off-screen item 12 aligned to middle.
        final backwardFuture = controller.scrollToIndex(
          12,
          preferPosition: IndexedScrollPosition.middle,
          duration: const Duration(milliseconds: 120),
        );
        await tester.pumpAndSettle();
        await backwardFuture;

        final item12 = find.text('Var 12');
        expect(item12, findsOneWidget);
        expect(tester.getCenter(item12).dy, closeTo(300, 1.5));
        expect(controller.isAutoScrolling, isFalse);
      },
    );

    testWidgets(
      'handles reverse: true lists with standard indices (0 at bottom)',
      (tester) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ListView.builder(
                  controller: controller,
                  reverse: true,
                  itemCount: 80,
                  itemBuilder: (_, index) => IndexedScrollTag(
                    key: ValueKey('rev_$index'),
                    controller: controller,
                    index: index,
                    child: SizedBox(
                      height: 50.0 + (index % 4) * 30.0,
                      child: Text('Rev $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Rev 60'), findsNothing);

        // Scroll up to off-screen item 60 aligned to visual middle.
        final middleFuture = controller.scrollToIndex(
          60,
          preferPosition: IndexedScrollPosition.middle,
          duration: const Duration(milliseconds: 80),
        );
        await tester.pumpAndSettle();
        await middleFuture;

        final item60 = find.text('Rev 60');
        expect(item60, findsOneWidget);
        expect(tester.getCenter(item60).dy, closeTo(300, 1.5));

        // Align item 60 to visual top (begin) and bottom (end).
        final beginFuture = controller.scrollToIndex(
          60,
          preferPosition: IndexedScrollPosition.begin,
          duration: const Duration(milliseconds: 80),
        );
        await tester.pumpAndSettle();
        await beginFuture;
        expect(tester.getTopLeft(item60).dy, closeTo(0, 1.5));

        final endFuture = controller.scrollToIndex(
          60,
          preferPosition: IndexedScrollPosition.end,
          duration: const Duration(milliseconds: 80),
        );
        await tester.pumpAndSettle();
        await endFuture;
        expect(tester.getBottomLeft(item60).dy, closeTo(600, 1.5));
      },
    );

    testWidgets(
      'handles reverse: true lists with inverted entry indices (ChatMessageList layout)',
      (tester) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);
        const totalCount = 100;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: ListView.builder(
                  controller: controller,
                  reverse: true,
                  itemCount: totalCount,
                  itemBuilder: (_, index) {
                    final entryIndex = totalCount - 1 - index;
                    return IndexedScrollTag(
                      key: ValueKey('chat_$entryIndex'),
                      controller: controller,
                      index: entryIndex,
                      child: SizedBox(
                        height: 60.0 + (entryIndex % 5) * 25.0,
                        child: Text('Chat $entryIndex'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Newest message (99) is mounted at bottom; older message (10) is off-screen.
        expect(find.text('Chat 99'), findsOneWidget);
        expect(find.text('Chat 10'), findsNothing);

        final toOldFuture = controller.scrollToIndex(
          10,
          preferPosition: IndexedScrollPosition.middle,
          duration: const Duration(milliseconds: 100),
        );
        await tester.pumpAndSettle();
        await toOldFuture;

        final item10 = find.text('Chat 10');
        expect(item10, findsOneWidget);
        expect(tester.getCenter(item10).dy, closeTo(300, 1.5));

        // Scroll back to a newer off-screen message (85).
        final toNewFuture = controller.scrollToIndex(
          85,
          preferPosition: IndexedScrollPosition.middle,
          duration: const Duration(milliseconds: 100),
        );
        await tester.pumpAndSettle();
        await toNewFuture;

        final item85 = find.text('Chat 85');
        expect(item85, findsOneWidget);
        expect(tester.getCenter(item85).dy, closeTo(300, 1.5));
      },
    );

    testWidgets('supports Duration.zero immediate jump without error', (
      tester,
    ) async {
      final controller = IndexedScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ListView.builder(
                controller: controller,
                itemCount: 40,
                itemBuilder: (_, index) => IndexedScrollTag(
                  key: ValueKey('zero_$index'),
                  controller: controller,
                  index: index,
                  child: SizedBox(height: 100, child: Text('Zero $index')),
                ),
              ),
            ),
          ),
        ),
      );

      final future = controller.scrollToIndex(
        25,
        preferPosition: IndexedScrollPosition.begin,
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await future;

      expect(find.text('Zero 25'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Zero 25')).dy, closeTo(0, 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'handles non-existent and out-of-range indices without looping',
      (tester) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: ListView.builder(
                  controller: controller,
                  itemCount: 20,
                  itemBuilder: (_, index) {
                    // Leave a gap at index 5.
                    if (index == 5) {
                      return const SizedBox(height: 80, child: Text('Gap'));
                    }
                    return IndexedScrollTag(
                      key: ValueKey('gap_$index'),
                      controller: controller,
                      index: index,
                      child: SizedBox(height: 80, child: Text('Item $index')),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Missing index between mounted tags completes cleanly.
        final gapFuture = controller.scrollToIndex(5);
        await tester.pumpAndSettle();
        await gapFuture;
        expect(controller.isAutoScrolling, isFalse);

        // Out-of-range high index stops at maxScrollExtent.
        final highFuture = controller.scrollToIndex(999);
        await tester.pumpAndSettle();
        await highFuture;
        expect(controller.isAutoScrolling, isFalse);

        // Negative index stops at minScrollExtent.
        final lowFuture = controller.scrollToIndex(-10);
        await tester.pumpAndSettle();
        await lowFuture;
        expect(controller.isAutoScrolling, isFalse);
      },
    );

    testWidgets('cancels cleanly on subsequent scrollToIndex or user drag', (
      tester,
    ) async {
      final controller = IndexedScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (_, index) => IndexedScrollTag(
                  key: ValueKey('cancel_$index'),
                  controller: controller,
                  index: index,
                  child: SizedBox(height: 100, child: Text('Cancel $index')),
                ),
              ),
            ),
          ),
        ),
      );

      // Subsequent scrollToIndex supersedes an in-flight one.
      final first = controller.scrollToIndex(
        80,
        preferPosition: IndexedScrollPosition.begin,
        duration: const Duration(milliseconds: 400),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final second = controller.scrollToIndex(
        20,
        preferPosition: IndexedScrollPosition.begin,
        duration: const Duration(milliseconds: 120),
      );
      expect(controller.isAutoScrolling, isTrue);
      await tester.pumpAndSettle();
      await Future.wait([first, second]);

      expect(controller.isAutoScrolling, isFalse);
      expect(find.text('Cancel 20'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Cancel 20')).dy, closeTo(0, 1.5));

      // User drag cancels an active auto-scroll.
      final draggedFuture = controller.scrollToIndex(
        90,
        preferPosition: IndexedScrollPosition.begin,
        duration: const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      await draggedFuture;

      expect(controller.isAutoScrolling, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancels cleanly when disposed mid-scroll', (tester) async {
      final controller = IndexedScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: ListView.builder(
                controller: controller,
                itemCount: 100,
                itemBuilder: (_, index) => IndexedScrollTag(
                  key: ValueKey('disp_$index'),
                  controller: controller,
                  index: index,
                  child: SizedBox(height: 100, child: Text('Disp $index')),
                ),
              ),
            ),
          ),
        ),
      );

      final scrollFuture = controller.scrollToIndex(
        90,
        duration: const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pumpAndSettle();
      await scrollFuture;

      expect(controller.isAutoScrolling, isFalse);
      expect(controller.tagMap, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'preserves tagMap integrity when IndexedScrollTag indices shift in didUpdateWidget',
      (tester) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);
        var offset = 0;

        Widget buildList() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ListView(
                controller: controller,
                children: [
                  for (var i = 0; i < 4; i++)
                    IndexedScrollTag(
                      key: ValueKey('stable_$i'),
                      controller: controller,
                      index: i + offset,
                      child: SizedBox(height: 60, child: Text('Row $i')),
                    ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpWidget(buildList());
        expect(controller.tagMap.keys.toList()..sort(), [0, 1, 2, 3]);

        // Shift every tag's index by +1 (overlapping old and new indices).
        offset = 1;
        await tester.pumpWidget(buildList());
        expect(controller.tagMap.keys.toList()..sort(), [1, 2, 3, 4]);
      },
    );

    testWidgets(
      'applies layoutAnchorCorrection in correctForNewDimensions and notifies callback',
      (tester) async {
        final controller = IndexedScrollController();
        addTearDown(controller.dispose);

        var viewportHeight = 400.0;
        var pendingCorrection = 0.0;
        final reportedTargets = <double>[];

        controller.layoutAnchorCorrection = () {
          if (pendingCorrection == 0.0) return null;
          final value = pendingCorrection;
          pendingCorrection = 0.0;
          return value;
        };
        controller.onLayoutAnchorCorrected = reportedTargets.add;

        Widget buildList() => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: viewportHeight,
              child: ListView.builder(
                controller: controller,
                itemCount: 40,
                itemBuilder: (_, index) =>
                    SizedBox(height: 60, child: Text('Anchor $index')),
              ),
            ),
          ),
        );

        await tester.pumpWidget(buildList());
        controller.jumpTo(300);
        await tester.pump();
        expect(controller.offset, closeTo(300, 0.1));

        // Resize the viewport so ScrollPosition.correctForNewDimensions runs.
        pendingCorrection = 75.0;
        viewportHeight = 320.0;
        await tester.pumpWidget(buildList());
        await tester.pump();

        expect(controller.offset, closeTo(375.0, 0.1));
        expect(reportedTargets, hasLength(1));
        expect(reportedTargets.single, closeTo(375.0, 0.1));
      },
    );
  });
}
