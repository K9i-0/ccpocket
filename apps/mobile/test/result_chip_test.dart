import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/result_chip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
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

    final errorText = tester.widget<Text>(find.text('Error: boom'));
    expect(
      errorText.style?.color,
      AppTheme.darkTheme.extension<AppColors>()!.errorText,
    );
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets(
    'success metadata row uses tabular figures without Chip pill or overflow',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 240,
            child: ResultChip(
              message: ResultMessage(
                subtype: 'success',
                cost: 0.0156,
                duration: 4200,
                inputTokens: 1200,
                outputTokens: 300,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Chip), findsNothing);
      final label = tester.widget<Text>(
        find.text('Done (\$0.0156, 4.2s, 1200in/300out tok)'),
      );
      expect(
        label.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
