import 'package:ccpocket/features/settings/auth_help_screen.dart';
import 'package:ccpocket/features/settings/widgets/app_locale_bottom_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Korean localization', () {
    test('is included in supported locales and app language options', () {
      expect(AppLocalizations.supportedLocales, contains(const Locale('ko')));
      expect(
        appLocales,
        contains(
          predicate<(String, String, String?)>((locale) {
            return locale.$1 == 'ko' &&
                locale.$2 == '한국어' &&
                locale.$3 == 'Korean';
          }),
        ),
      );
    });

    testWidgets('auth help loads Korean markdown by default for ko locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko'),
          theme: AppTheme.lightTheme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthHelpScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Claude 인증 문제 해결'), findsOneWidget);
      expect(find.text('한국어'), findsOneWidget);
      expect(find.textContaining('Bridge 컴퓨터를 직접 사용할 수 없을 때'), findsOneWidget);
    });
  });
}
