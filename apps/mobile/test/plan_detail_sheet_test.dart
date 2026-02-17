import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
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

  String? sheetResult;

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open_sheet'),
            onPressed: () async {
              sheetResult = await showPlanDetailSheet(context, planText);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  setUp(() {
    sheetResult = null;
  });

  group('PlanDetailSheet', () {
    testWidgets('opens and shows header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Implementation Plan'), findsOneWidget);
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

    testWidgets('can be dismissed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      // Drag down to dismiss
      await tester.drag(find.text('Implementation Plan'), const Offset(0, 500));
      await tester.pumpAndSettle();

      // Sheet should be dismissed - header no longer visible
      expect(find.text('Implementation Plan'), findsNothing);
    });

    testWidgets('shows edit toggle button', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan_edit_toggle')), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('hides edit controls when editable is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('open_sheet_readonly'),
                onPressed: () async {
                  await showPlanDetailSheet(context, planText, editable: false);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open_sheet_readonly')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan_edit_toggle')), findsNothing);
      expect(find.byKey(const ValueKey('plan_edit_field')), findsNothing);
      expect(find.byKey(const ValueKey('plan_edit_apply')), findsNothing);
    });

    testWidgets('toggles to edit mode', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      // Tap edit toggle
      await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
      await tester.pumpAndSettle();

      // Should show edit field and action buttons
      expect(find.byKey(const ValueKey('plan_edit_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_edit_cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_edit_apply')), findsOneWidget);
      // Icon should change to view icon
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('applies keyboard inset padding in edit mode', (tester) async {
      addTearDown(tester.view.resetViewInsets);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
      await tester.pumpAndSettle();

      final animatedPadding = tester.widget<AnimatedPadding>(
        find.byType(AnimatedPadding).first,
      );
      final padding = animatedPadding.padding as EdgeInsets;
      final expectedBottomInset = 320 / tester.view.devicePixelRatio;
      expect(padding.bottom, expectedBottomInset);

      expect(find.byKey(const ValueKey('plan_edit_cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan_edit_apply')), findsOneWidget);
    });

    testWidgets('Apply disabled when text unchanged', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
      await tester.pumpAndSettle();

      // Apply button should be disabled when text hasn't changed
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('plan_edit_apply')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Apply enabled after editing', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
      await tester.pumpAndSettle();

      // Type additional text
      await tester.enterText(
        find.byKey(const ValueKey('plan_edit_field')),
        '$planText\n\n## Step 3\n- Deploy',
      );
      await tester.pumpAndSettle();

      // Apply button should be enabled
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('plan_edit_apply')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Apply pops with edited text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
      await tester.pumpAndSettle();

      const edited = 'Edited plan content';
      await tester.enterText(
        find.byKey(const ValueKey('plan_edit_field')),
        edited,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan_edit_apply')));
      await tester.pumpAndSettle();

      expect(sheetResult, edited);
    });

    testWidgets('Cancel resets text and returns to view mode', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
      await tester.pumpAndSettle();

      // Type something
      await tester.enterText(
        find.byKey(const ValueKey('plan_edit_field')),
        'Modified text',
      );
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.byKey(const ValueKey('plan_edit_cancel')));
      await tester.pumpAndSettle();

      // Should be back in view mode
      expect(find.byKey(const ValueKey('plan_edit_field')), findsNothing);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  group('AssistantBubble PlanCard → editedPlanText integration', () {
    // Must exceed PlanCard._shortPlanLineThreshold (10 lines) to show footer
    const originalPlan =
        '# Original Plan\n\n'
        '## Step 1\n- Do something\n- Another task\n\n'
        '## Step 2\n- More work\n- Even more\n\n'
        '## Step 3\n- Final step\n- Done';

    AssistantServerMessage buildExitPlanMessage() {
      return AssistantServerMessage(
        message: AssistantMessage(
          id: 'msg-1',
          role: 'assistant',
          content: [
            const TextContent(text: originalPlan),
            const ToolUseContent(
              id: 'tu-1',
              name: 'ExitPlanMode',
              input: {'plan': originalPlan},
            ),
          ],
          model: 'test-model',
        ),
      );
    }

    testWidgets(
      'PlanCard View Full Plan → edit → Apply updates editedPlanText',
      (tester) async {
        final editedPlanText = ValueNotifier<String?>(null);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssistantBubble(
                  message: buildExitPlanMessage(),
                  editedPlanText: editedPlanText,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // PlanCard should show the original plan text
        expect(find.text('Implementation Plan'), findsOneWidget);
        // No edited badge yet
        expect(find.byKey(const ValueKey('plan_edited_badge')), findsNothing);

        // Tap "View Full Plan" to open PlanDetailSheet
        await tester.tap(find.byKey(const ValueKey('view_full_plan_button')));
        await tester.pumpAndSettle();

        // Sheet should be open with edit toggle
        expect(find.byKey(const ValueKey('plan_edit_toggle')), findsOneWidget);

        // Switch to edit mode
        await tester.tap(find.byKey(const ValueKey('plan_edit_toggle')));
        await tester.pumpAndSettle();

        // Enter edited text
        const editedText = '# Edited Plan\n\n## New Step\n- Changed';
        await tester.enterText(
          find.byKey(const ValueKey('plan_edit_field')),
          editedText,
        );
        await tester.pumpAndSettle();

        // Tap Apply
        await tester.tap(find.byKey(const ValueKey('plan_edit_apply')));
        await tester.pumpAndSettle();

        // ValueNotifier should be updated
        expect(editedPlanText.value, editedText);

        // PlanCard should now show the "Edited" badge
        expect(find.byKey(const ValueKey('plan_edited_badge')), findsOneWidget);

        editedPlanText.dispose();
      },
    );

    testWidgets('Dismiss sheet without Apply does not update editedPlanText', (
      tester,
    ) async {
      final editedPlanText = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantBubble(
                message: buildExitPlanMessage(),
                editedPlanText: editedPlanText,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const ValueKey('view_full_plan_button')));
      await tester.pumpAndSettle();

      // Dismiss by dragging down
      await tester.drag(
        find.text('Implementation Plan').last,
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();

      // ValueNotifier should remain null
      expect(editedPlanText.value, isNull);

      editedPlanText.dispose();
    });

    testWidgets('read-only plan card opens sheet without edit controls', (
      tester,
    ) async {
      final editedPlanText = ValueNotifier<String?>('Existing edit');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantBubble(
                message: buildExitPlanMessage(),
                editedPlanText: editedPlanText,
                allowPlanEditing: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('view_full_plan_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan_edit_toggle')), findsNothing);
      editedPlanText.dispose();
    });
  });
}
