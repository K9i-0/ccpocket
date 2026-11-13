import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/widgets/anchor_maintaining_auto_scroll_controller.dart';
import 'package:ccpocket/hooks/use_scroll_tracking.dart';

void main() {
  group('scroll state thresholds', () {
    test('reading intent changes immediately after leaving latest', () {
      expect(isReadingHistoryAt(0), isFalse);
      expect(isReadingHistoryAt(1), isFalse);
      expect(isReadingHistoryAt(2), isTrue);
    });

    test('return button uses an independent, less sensitive threshold', () {
      expect(shouldShowScrollToLatestAt(100), isFalse);
      expect(shouldShowScrollToLatestAt(101), isTrue);
    });

    test('automatic tool collapse is disabled while reading history', () {
      expect(shouldAutoCollapseToolResults(false), isTrue);
      expect(shouldAutoCollapseToolResults(true), isFalse);
    });
  });

  group('useScrollTracking', () {
    testWidgets('starts at latest', (tester) async {
      late ScrollTrackingResult result;
      await tester.pumpWidget(
        _ScrollHarness(
          sessionId: 'starts-at-latest',
          onResult: (value) => result = value,
        ),
      );
      await tester.pumpAndSettle();

      expect(result.controller.offset, 0);
      expect(result.isReadingHistory, isFalse);
      expect(result.showScrollToLatest, isFalse);
      expect(result.isReadingHistoryNow(), isFalse);
    });

    testWidgets('tracks reading separately from return-button visibility', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      await tester.pumpWidget(
        _ScrollHarness(
          sessionId: 'independent-thresholds',
          onResult: (value) => result = value,
        ),
      );
      await tester.pumpAndSettle();

      result.controller.jumpTo(16);
      await tester.pump();
      expect(result.isReadingHistory, isTrue);
      expect(result.showScrollToLatest, isFalse);

      result.controller.jumpTo(160);
      await tester.pump();
      expect(result.isReadingHistory, isTrue);
      expect(result.showScrollToLatest, isTrue);
      expect(result.isReadingHistoryNow(), isTrue);
    });

    testWidgets('goToLatest clears reading state and reaches offset zero', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      await tester.pumpWidget(
        _ScrollHarness(
          sessionId: 'go-to-latest',
          onResult: (value) => result = value,
        ),
      );
      await tester.pumpAndSettle();
      result.controller.jumpTo(240);
      await tester.pump();

      result.goToLatest();
      await tester.pump();
      expect(result.isReadingHistory, isFalse);
      expect(result.showScrollToLatest, isFalse);
      await tester.pumpAndSettle();

      expect(result.controller.offset, 0);
      expect(result.isReadingHistoryNow(), isFalse);
    });

    testWidgets('restores the saved offset when returning to a session', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      var sessionId = 'restore-source';

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(240);
      await tester.pump();

      sessionId = 'restore-other';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(result.controller.offset, 0);

      sessionId = 'restore-source';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(result.controller.offset, closeTo(240, 0.1));
      expect(result.isReadingHistory, isTrue);
      expect(result.showScrollToLatest, isTrue);
    });

    testWidgets('restores an offset corrected during layout', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      late ScrollTrackingResult result;
      var sessionId = 'layout-correction-source';
      var itemCount = 100;

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        itemCount: itemCount,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(240);
      await tester.pump();

      final controller =
          result.controller as AnchorMaintainingAutoScrollController;
      var needsCorrection = true;
      controller.layoutAnchorCorrection = () {
        if (!needsCorrection) return 0;
        needsCorrection = false;
        return 50;
      };
      tester.view.physicalSize = const Size(800, 500);
      itemCount = 120;
      await tester.pumpWidget(app());
      await tester.pump();
      controller.layoutAnchorCorrection = null;
      expect(result.controller.offset, closeTo(290, 0.1));

      sessionId = 'layout-correction-other';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      sessionId = 'layout-correction-source';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(result.controller.offset, closeTo(290, 0.1));
    });

    testWidgets('does not lose a saved offset while lazy content is short', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      var sessionId = 'delayed-extent-source';
      var itemCount = 200;

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        itemCount: itemCount,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(3000);
      await tester.pump();

      sessionId = 'delayed-extent-other';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(2000);
      await tester.pump();

      sessionId = 'delayed-extent-source';
      itemCount = 20;
      await tester.pumpWidget(app());
      await tester.pump();
      expect(result.controller.offset, lessThan(3000));

      // Simulate history arriving well after the initial frames.
      for (var i = 0; i < 25; i++) {
        await tester.pump();
      }

      itemCount = 200;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(result.controller.offset, closeTo(3000, 0.1));
      expect(result.isReadingHistory, isTrue);
    });

    testWidgets(
      'user scroll cancels restore when saved offset no longer exists',
      (tester) async {
        late ScrollTrackingResult result;
        var sessionId = 'shortened-source';
        var itemCount = 200;

        Widget app() => _ScrollHarness(
          sessionId: sessionId,
          itemCount: itemCount,
          onResult: (value) => result = value,
        );

        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        result.controller.jumpTo(3000);
        await tester.pump();

        sessionId = 'shortened-other';
        itemCount = 30;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        sessionId = 'shortened-source';
        await tester.pumpWidget(app());

        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        final userOffset = result.controller.offset;
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        expect(
          userOffset,
          lessThan(result.controller.position.maxScrollExtent),
        );
        expect(result.controller.offset, closeTo(userOffset, 0.1));
      },
    );

    testWidgets('completed restore does not override a programmatic scroll', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      var sessionId = 'completed-restore-source';
      var itemCount = 200;

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        itemCount: itemCount,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(3000);
      await tester.pump();

      sessionId = 'completed-restore-other';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      sessionId = 'completed-restore-source';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(result.controller.offset, closeTo(3000, 0.1));

      result.controller.jumpTo(1000);
      await tester.pump();
      itemCount = 250;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(result.controller.offset, closeTo(1000, 0.1));
    });

    testWidgets('pending restore target survives leaving the session', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      var sessionId = 'pending-restore-source';
      var itemCount = 200;

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        itemCount: itemCount,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(3000);
      await tester.pump();

      sessionId = 'pending-restore-other';
      itemCount = 10;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      sessionId = 'pending-restore-source';
      await tester.pumpWidget(app());
      await tester.pump();
      expect(result.controller.offset, lessThan(3000));

      sessionId = 'pending-restore-other';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      sessionId = 'pending-restore-source';
      itemCount = 200;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(result.controller.offset, closeTo(3000, 0.1));
    });

    testWidgets('new session does not inherit the previous session offset', (
      tester,
    ) async {
      late ScrollTrackingResult result;
      var sessionId = 'previous-scrolled-session';

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        itemCount: 200,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(2000);
      await tester.pump();

      sessionId = 'brand-new-session';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(result.controller.offset, closeTo(0, 0.1));

      sessionId = 'previous-scrolled-session';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(result.controller.offset, closeTo(2000, 0.1));

      sessionId = 'brand-new-session';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(result.controller.offset, closeTo(0, 0.1));
    });

    testWidgets('goToLatest resumes normal offset persistence', (tester) async {
      late ScrollTrackingResult result;
      var sessionId = 'go-latest-pending-source';
      var itemCount = 200;

      Widget app() => _ScrollHarness(
        sessionId: sessionId,
        itemCount: itemCount,
        onResult: (value) => result = value,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(3000);
      await tester.pump();

      sessionId = 'go-latest-pending-other';
      itemCount = 20;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      sessionId = 'go-latest-pending-source';
      await tester.pumpWidget(app());
      await tester.pump();

      result.goToLatest();
      await tester.pumpAndSettle();
      itemCount = 200;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      result.controller.jumpTo(500);
      await tester.pump();

      sessionId = 'go-latest-pending-other';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      sessionId = 'go-latest-pending-source';
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(result.controller.offset, closeTo(500, 0.1));
    });
  });
}

class _ScrollHarness extends StatelessWidget {
  const _ScrollHarness({
    required this.sessionId,
    required this.onResult,
    this.itemCount = 100,
  });

  final String sessionId;
  final ValueChanged<ScrollTrackingResult> onResult;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HookBuilder(
        builder: (context) {
          final result = useScrollTracking(sessionId);
          onResult(result);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            result.onScrollMetricsChanged();
          });
          return NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              result.onScrollMetricsChanged();
              return false;
            },
            child: ListView.builder(
              controller: result.controller,
              reverse: true,
              itemCount: itemCount,
              itemBuilder: (_, index) =>
                  SizedBox(height: 50, child: Text('$index')),
            ),
          );
        },
      ),
    );
  }
}
