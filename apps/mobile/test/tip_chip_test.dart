import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/tip_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders localized git unavailable tip', (tester) async {
    await tester.pumpWidget(_buildTip(locale: const Locale('ja')));

    expect(find.text('Git未検出 — Git機能は利用できません'), findsOneWidget);
    expect(find.textContaining('ファイル一覧'), findsNothing);

    await tester.pumpWidget(_buildTip(locale: const Locale('en')));

    expect(
      find.text('Git not detected — Git features are unavailable'),
      findsOneWidget,
    );
  });
}

Widget _buildTip({required Locale locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.darkTheme,
    home: const Scaffold(
      body: TipChip(
        message: SystemMessage(subtype: 'tip', tipCode: 'git_not_available'),
      ),
    ),
  );
}
