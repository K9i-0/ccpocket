import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_card/approval_areas.dart';

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
}
