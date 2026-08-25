import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/plan_card.dart';

void main() {
  const shortPlan =
      '## Step 1\n- Do something\n\n## Step 2\n- Do another thing';

  const longPlan =
      '# Implementation Plan\n\n'
      '## Overview\n\n'
      'A long plan with many sections.\n\n'
      '## Step 1: Data Layer\n\n'
      '- Create model class\n'
      '- Add repository\n\n'
      '## Step 2: State Management\n\n'
      '- Add notifier\n'
      '- Wire up providers\n\n'
      '## Step 3: UI\n\n'
      '- Build list screen\n'
      '- Build detail screen\n\n'
      '## Step 4: Navigation\n\n'
      '- Add routes\n'
      '- Wire up deep links\n\n'
      '## Step 5: Testing\n\n'
      '- Unit tests\n'
      '- Widget tests\n\n'
      '## Step 6: Documentation\n\n'
      '- Update README';

  Widget buildSubject({
    required String planText,
    VoidCallback? onViewFullPlan,
    double? width,
  }) {
    Widget card = PlanCard(
      planText: planText,
      onViewFullPlan: onViewFullPlan ?? () {},
    );
    if (width != null) card = SizedBox(width: width, child: card);
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(child: card),
        ),
      ),
    );
  }

  group('PlanCard', () {
    testWidgets('shows header with icon and title', (tester) async {
      await tester.pumpWidget(buildSubject(planText: shortPlan));

      expect(find.text('Implementation Plan'), findsOneWidget);
      expect(find.byIcon(Icons.assignment), findsOneWidget);
    });

    testWidgets('shows section count badge', (tester) async {
      await tester.pumpWidget(buildSubject(planText: shortPlan));

      // shortPlan has 2 sections (## Step 1, ## Step 2)
      expect(find.text('2 sections'), findsOneWidget);
    });

    testWidgets('short plan: hides View Full Plan button', (tester) async {
      await tester.pumpWidget(buildSubject(planText: shortPlan));

      expect(find.byKey(const ValueKey('view_full_plan_button')), findsNothing);
    });

    testWidgets('long plan: shows View Full Plan button', (tester) async {
      await tester.pumpWidget(buildSubject(planText: longPlan));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('view_full_plan_button')),
        findsOneWidget,
      );
      expect(find.text('View Full Plan'), findsOneWidget);
    });

    testWidgets('long plan: tapping View Full Plan fires callback', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(planText: longPlan, onViewFullPlan: () => tapped = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('view_full_plan_button')));
      expect(tapped, isTrue);
    });

    testWidgets('renders markdown content', (tester) async {
      await tester.pumpWidget(buildSubject(planText: shortPlan));

      // Markdown renders "Step 1" and "Step 2" as headings
      expect(find.textContaining('Step 1'), findsOneWidget);
      expect(find.textContaining('Step 2'), findsOneWidget);
    });

    testWidgets('wrapped single-paragraph plan is collapsed on Android width', (
      tester,
    ) async {
      final wrappedPlan = List.filled(
        80,
        'This plan text must wrap naturally on a narrow phone.',
      ).join(' ');

      await tester.pumpWidget(buildSubject(planText: wrappedPlan, width: 320));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('view_full_plan_button')),
        findsOneWidget,
      );
    });

    testWidgets('source line count alone does not collapse a short plan', (
      tester,
    ) async {
      const shortElevenLinePlan = 'a\n\nb\n\nc\n\nd\n\ne\n\nf';

      await tester.pumpWidget(
        buildSubject(planText: shortElevenLinePlan, width: 320),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('view_full_plan_button')), findsNothing);
    });

    testWidgets('header does not overflow at narrow Android width', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(planText: longPlan, width: 280));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
