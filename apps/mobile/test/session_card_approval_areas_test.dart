import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_card/approval_areas.dart';
import 'package:ccpocket/widgets/session_card/ask_user_area.dart';

Widget _wrap(Widget child, {ThemeData? theme, double width = 340}) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: theme ?? AppTheme.darkTheme,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('SessionCardToolApprovalArea', () {
    testWidgets(
      'keeps readable >=12px button labels on narrow cards without error styling on Always Allow',
      (tester) async {
        const permission = PermissionRequestMessage(
          toolUseId: 'tu-narrow',
          toolName: 'Bash',
          input: {
            'command': 'flutter test apps/mobile/test/approval_bar_test.dart',
            'availableDecisions': ['accept', 'acceptForSession', 'decline'],
          },
        );

        await tester.pumpWidget(
          _wrap(
            SessionCardToolApprovalArea(
              permission: permission,
              statusColor: AppColors.dark().statusApproval,
              onApprove: () {},
              onApproveAlways: () {},
              onReject: () {},
            ),
            width: 320,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Permanently allow'), findsOneWidget);
        expect(find.text('Allow Once'), findsOneWidget);

        for (final label in ['Reject', 'Permanently allow', 'Allow Once']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.fontSize ?? 14, greaterThanOrEqualTo(12));
        }

        final alwaysButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey('approve_always_button')),
        );
        final errorColor = AppTheme.darkTheme.colorScheme.error;
        expect(
          alwaysButton.style?.foregroundColor?.resolve({}),
          isNot(errorColor),
        );

        final targetText = tester.widget<Text>(
          find.text('flutter test apps/mobile/test/approval_bar_test.dart'),
        );
        expect(targetText.style?.fontFamily, 'JetBrainsMono');
        expect(targetText.style?.fontFamilyFallback, contains('monospace'));
      },
    );

    testWidgets('codex plan approval uses neutral Keep Planning outline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SessionCardCodexPlanApprovalArea(
            statusColor: AppColors.light().statusApproval,
            canOpenPlan: true,
            onOpenPlan: () {},
            onApprove: () {},
            onReject: () {},
          ),
          theme: AppTheme.lightTheme,
        ),
      );

      final rejectButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('reject_button')),
      );
      expect(
        rejectButton.style?.foregroundColor?.resolve({}),
        isNot(AppTheme.lightTheme.colorScheme.error),
      );
    });
  });

  group('SessionCardAskUserArea', () {
    testWidgets(
      'uses neutral section and option styling aligned with AskUserQuestionWidget',
      (tester) async {
        const permission = PermissionRequestMessage(
          toolUseId: 'tu-ask-single-style',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'Which database should we use?',
                'header': 'DB',
                'options': [
                  {'label': 'SQLite', 'description': ''},
                  {'label': 'PostgreSQL', 'description': ''},
                ],
                'multiSelect': false,
              },
            ],
          },
        );
        final darkColors = AppColors.dark();
        final cs = AppTheme.darkTheme.colorScheme;

        await tester.pumpWidget(
          _wrap(
            SessionCardAskUserArea(
              permission: permission,
              statusColor: darkColors.statusApproval,
              preferQuestionIds: false,
              onAnswer: (_) {},
              onTap: () {},
            ),
          ),
        );

        expect(find.byType(SessionApprovalSection), findsOneWidget);

        final optionButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'SQLite'),
        );
        expect(optionButton.style?.foregroundColor?.resolve({}), cs.onSurface);
        expect(
          optionButton.style?.foregroundColor?.resolve({}),
          isNot(darkColors.statusApproval),
        );

        final otherButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Other answer...'),
        );
        expect(
          otherButton.style?.foregroundColor?.resolve({}),
          cs.onSurfaceVariant,
        );
      },
    );

    testWidgets(
      'uses primary CTA and primary accent selection for multi-select questions',
      (tester) async {
        const permission = PermissionRequestMessage(
          toolUseId: 'tu-ask-multi-style',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'Pick targets',
                'header': 'Targets',
                'options': [
                  {'label': 'iOS', 'description': ''},
                  {'label': 'Android', 'description': ''},
                ],
                'multiSelect': true,
              },
            ],
          },
        );
        final darkColors = AppColors.dark();
        final cs = AppTheme.darkTheme.colorScheme;

        await tester.pumpWidget(
          _wrap(
            SessionCardAskUserArea(
              permission: permission,
              statusColor: darkColors.statusApproval,
              preferQuestionIds: false,
              onAnswer: (_) {},
              onTap: () {},
            ),
          ),
        );

        await tester.tap(find.text('iOS'));
        await tester.pump();

        final selectedButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'iOS'),
        );
        expect(
          selectedButton.style?.side?.resolve({})?.color,
          cs.primary.withValues(alpha: 0.65),
        );

        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm (1)'),
        );
        expect(confirmButton.style?.backgroundColor?.resolve({}), cs.primary);
        expect(confirmButton.style?.foregroundColor?.resolve({}), cs.onPrimary);
      },
    );

    testWidgets(
      'uses primary progress bar and submit CTA in multi-question flow',
      (tester) async {
        const permission = PermissionRequestMessage(
          toolUseId: 'tu-ask-mq-style',
          toolName: 'AskUserQuestion',
          input: {
            'questions': [
              {
                'question': 'First?',
                'header': 'Step 1',
                'options': [
                  {'label': 'A', 'description': ''},
                ],
                'multiSelect': false,
              },
              {
                'question': 'Second?',
                'header': 'Step 2',
                'options': [
                  {'label': 'B', 'description': ''},
                ],
                'multiSelect': false,
              },
            ],
          },
        );
        final lightColors = AppColors.light();
        final cs = AppTheme.lightTheme.colorScheme;

        await tester.pumpWidget(
          _wrap(
            SessionCardAskUserArea(
              permission: permission,
              statusColor: lightColors.statusApproval,
              preferQuestionIds: false,
              onAnswer: (_) {},
              onTap: () {},
            ),
            theme: AppTheme.lightTheme,
          ),
        );
        await tester.pumpAndSettle();

        final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(
          (progress.valueColor as AlwaysStoppedAnimation<Color>).value,
          cs.primary,
        );

        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('B'));
        await tester.pumpAndSettle();

        final submitButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey('ask_submit_summary_button')),
        );
        expect(submitButton.style?.backgroundColor?.resolve({}), cs.primary);
        expect(submitButton.style?.foregroundColor?.resolve({}), cs.onPrimary);
      },
    );
  });
}
