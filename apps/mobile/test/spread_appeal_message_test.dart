import 'package:ccpocket/features/settings/widgets/spread_appeal_message.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SpreadAppealMessage', () {
    testWidgets(
      'reacts to SupportBannerService changes via RepositoryProvider',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final reviewService = InAppReviewService(
          prefs: prefs,
          now: () => DateTime(2026, 4, 15, 12),
          appVersionLoader: () async => '1.50.0',
        );
        final supportBannerService = SupportBannerService(
          prefs: prefs,
          reviewService: reviewService,
        );
        addTearDown(supportBannerService.dispose);

        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<InAppReviewService>.value(
                value: reviewService,
              ),
              RepositoryProvider<SupportBannerService>.value(
                value: supportBannerService,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SpreadAppealMessage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('spread_appeal_message')),
          findsNothing,
        );

        await supportBannerService.setDebugForceShowOverride(true);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('spread_appeal_message')),
          findsOneWidget,
        );

        await supportBannerService.setDebugForceShowOverride(false);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('spread_appeal_message')),
          findsNothing,
        );
      },
    );

    testWidgets('renders empty when optional providers are absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SpreadAppealMessage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('spread_appeal_message')), findsNothing);
    });
  });
}
