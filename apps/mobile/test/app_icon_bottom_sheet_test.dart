import 'package:ccpocket/features/settings/widgets/app_icon_bottom_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp({
  required bool isSupporter,
  required ValueChanged<AppIconVariant> onChanged,
  required VoidCallback onSupporterRequired,
}) {
  return MaterialApp(
    locale: const Locale('ja'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showAppIconBottomSheet(
            context: context,
            current: AppIconVariant.defaultIcon,
            isSupporter: isSupporter,
            onChanged: onChanged,
            onSupporterRequired: onSupporterRequired,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  group('AppIconBottomSheet', () {
    testWidgets('shows supporter divider between dark and supporter icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          isSupporter: false,
          onChanged: (_) {},
          onSupporterRequired: () {},
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('ダーク'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app_icon_supporter_divider')),
        findsOneWidget,
      );
      expect(find.text('月額Supporter特典'), findsOneWidget);
      expect(find.text('ライト'), findsOneWidget);
      expect(find.text('メタリック'), findsOneWidget);
    });

    testWidgets('non-supporter tap opens supporter flow for locked icons', (
      tester,
    ) async {
      AppIconVariant? selected;
      var supporterRequired = 0;

      await tester.pumpWidget(
        _buildTestApp(
          isSupporter: false,
          onChanged: (icon) => selected = icon,
          onSupporterRequired: () => supporterRequired++,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('app_icon_option_light_outline')),
      );
      await tester.pumpAndSettle();

      expect(selected, isNull);
      expect(supporterRequired, 1);
    });

    testWidgets('supporter can select supporter icon directly', (tester) async {
      AppIconVariant? selected;
      var supporterRequired = 0;

      await tester.pumpWidget(
        _buildTestApp(
          isSupporter: true,
          onChanged: (icon) => selected = icon,
          onSupporterRequired: () => supporterRequired++,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('app_icon_option_pro_copper_emerald')),
      );
      await tester.pumpAndSettle();

      expect(selected, AppIconVariant.proCopperEmerald);
      expect(supporterRequired, 0);
    });
  });
}
