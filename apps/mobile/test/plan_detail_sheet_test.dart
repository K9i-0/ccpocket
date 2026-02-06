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

  Widget buildSubject() {
    return MaterialApp(
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
  });
}
