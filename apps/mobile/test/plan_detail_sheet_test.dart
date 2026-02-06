import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/theme/app_theme.dart';
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
}
