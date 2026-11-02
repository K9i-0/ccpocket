import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/result_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('a Codex interrupted turn reads as stopped, not an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ResultChip(message: ResultMessage(subtype: 'interrupted'))),
    );

    expect(find.text('Stopped'), findsOneWidget);
    expect(find.textContaining('Error'), findsNothing);
  });

  testWidgets('real errors still show their message', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ResultChip(
          message: ResultMessage(subtype: 'error', error: 'boom'),
        ),
      ),
    );

    expect(find.text('Error: boom'), findsOneWidget);
  });
}
