import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/plan_detail_sheet.dart';

void main() {
  const planText =
      '# Test Plan\n\n'
      '## Step 1\n'
      '- Create model\n'
      '- Add repository\n\n'
      '## Step 2\n'
      '- Build UI screen\n'
      '- Add navigation';

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open_sheet'),
            onPressed: () => showPlanDetailSheet(context, planText),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  AssistantServerMessage buildExitPlanMessage(String plan) {
    return AssistantServerMessage(
      message: AssistantMessage(
        id: 'msg-1',
        role: 'assistant',
        content: [
          TextContent(text: plan),
          ToolUseContent(
            id: 'tu-1',
            name: 'ExitPlanMode',
            input: {'plan': plan},
          ),
        ],
        model: 'test-model',
      ),
    );
  }

  group('PlanDetailSheet', () {
    testWidgets('opens and shows header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Implementation Plan'), findsWidgets);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('renders plan markdown content', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Test Plan'), findsOneWidget);
      expect(find.textContaining('Step 1'), findsOneWidget);
      expect(find.textContaining('Step 2'), findsOneWidget);
    });

    testWidgets('applies keyboard inset padding', (tester) async {
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      final animatedPadding = tester.widget<AnimatedPadding>(
        find.byType(AnimatedPadding).first,
      );
      final padding = animatedPadding.padding as EdgeInsets;
      final expectedBottomInset = 320 / tester.view.devicePixelRatio;
      expect(padding.bottom, expectedBottomInset);
    });

    testWidgets('can be dismissed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Implementation Plan'), const Offset(0, 500));
      await tester.pumpAndSettle();

      expect(find.text('Implementation Plan'), findsNothing);
    });
  });

  group('AssistantBubble plan card', () {
    testWidgets('opens plan sheet from View Full Plan button', (tester) async {
      const longPlan =
          '# Original Plan\n\n'
          '## Step 1\n- Do something\n- Another task\n\n'
          '## Step 2\n- More work\n- Even more\n\n'
          '## Step 3\n- Final step\n- Done';

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantBubble(message: buildExitPlanMessage(longPlan)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('view_full_plan_button')));
      await tester.pumpAndSettle();

      expect(find.text('Implementation Plan'), findsWidgets);
      expect(find.byKey(const ValueKey('plan_edit_toggle')), findsNothing);
      expect(find.textContaining('Original Plan'), findsWidgets);
    });
  });
}
