import 'package:ccpocket/features/codex_session/widgets/codex_goal_card.dart';
import 'package:ccpocket/mock/mock_scenarios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const activeGoal = CodexGoalCardData(objective: 'Goal機能をCC Pocketに追加する');

  Widget buildSubject({
    CodexGoalCardData goal = activeGoal,
    VoidCallback? onEdit,
    VoidCallback? onTogglePaused,
    VoidCallback? onClear,
  }) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: CodexGoalCard(
            goal: goal,
            onEdit: onEdit ?? () {},
            onTogglePaused: onTogglePaused ?? () {},
            onClear: onClear ?? () {},
          ),
        ),
      ),
    );
  }

  group('CodexGoalCard', () {
    testWidgets('shows a compact two-row active goal', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byKey(const ValueKey('goal_card')), findsOneWidget);
      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Pursuing'), findsOneWidget);
      expect(find.text(activeGoal.objective), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      for (final key in [
        'goal_edit_button',
        'goal_pause_button',
        'goal_clear_button',
      ]) {
        expect(tester.getSize(find.byKey(ValueKey(key))), const Size(44, 44));
      }
    });

    testWidgets('dispatches edit, pause, and clear actions', (tester) async {
      var edited = false;
      var paused = false;
      var cleared = false;
      await tester.pumpWidget(
        buildSubject(
          onEdit: () => edited = true,
          onTogglePaused: () => paused = true,
          onClear: () => cleared = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('goal_edit_button')));
      await tester.tap(find.byKey(const ValueKey('goal_pause_button')));
      await tester.tap(find.byKey(const ValueKey('goal_clear_button')));

      expect(edited, isTrue);
      expect(paused, isTrue);
      expect(cleared, isTrue);
    });

    testWidgets('shows paused status and resume affordance', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          goal: const CodexGoalCardData(
            objective: 'Resume this goal',
            status: CodexGoalStatus.paused,
          ),
        ),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('disables pause for a completed goal', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        buildSubject(
          goal: const CodexGoalCardData(
            objective: 'Completed goal',
            status: CodexGoalStatus.complete,
          ),
          onTogglePaused: () => toggled = true,
        ),
      );

      final button = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey('goal_pause_button')),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('goal_pause_button')));
      expect(toggled, isFalse);
    });

    testWidgets('does not overflow on a narrow phone', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSubject());

      expect(tester.takeException(), isNull);
    });
  });

  test('Codex Goal is available from the mock preview catalog', () {
    expect(mockScenarios, contains(codexGoalPreviewScenario));
    expect(codexGoalPreviewScenario.provider, MockScenarioProvider.codex);
    expect(codexGoalPreviewScenario.name, 'Codex Goal');
  });
}
