import 'package:ccpocket/features/settings/supporter_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRevenueCatService extends RevenueCatService {
  FakeRevenueCatService({
    required SupportCatalogState catalog,
    required SupporterState supporter,
  }) : super(publicApiKey: '', platform: TargetPlatform.iOS) {
    catalogState.value = catalog;
    supporterState.value = supporter;
  }
}

Widget _wrap(RevenueCatService revenueCatService) {
  return RepositoryProvider<RevenueCatService>.value(
    value: revenueCatService,
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SupporterScreen(),
    ),
  );
}

AppLocalizations _localizations(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(SupporterScreen)));
}

void main() {
  testWidgets('shows impact section and hides summary when inactive', (
    tester,
  ) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        packages: const [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Monthly',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
        ],
        summary: const SupportHistorySummary.empty(),
      ),
      supporter: const SupporterState.inactive(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    expect(find.byKey(const ValueKey('supporter_impact_card')), findsOneWidget);
    expect(find.text(l.supporterImpactTitle), findsOneWidget);
    expect(find.text(l.supporterPackagesTitle), findsOneWidget);
    expect(find.text(l.supporterSummaryTitle), findsNothing);
    await tester.scrollUntilVisible(
      find.text(l.supporterPrivacyPolicyLink),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.supporterPrivacyPolicyLink), findsOneWidget);
    expect(find.text(l.supporterTermsOfUseLink), findsOneWidget);
  });

  testWidgets('shows minimal summary for one-time supporters', (tester) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        packages: const [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Monthly',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
        ],
        summary: const SupportHistorySummary(
          oneTimeSupportCount: 2,
          coffeeSupportCount: 1,
          lunchSupportCount: 1,
        ),
      ),
      supporter: const SupporterState.inactive(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    expect(find.text(l.supportEntryOneTimeTitle), findsOneWidget);
    expect(find.text(l.supporterSummaryTitle), findsOneWidget);
    expect(find.text(l.supporterSummarySinceLabel), findsNothing);
    expect(find.text(l.supporterSummaryStreakLabel), findsNothing);
    expect(find.text(l.supporterSummaryLunchCount(1)), findsOneWidget);
    expect(find.text(l.supporterSummaryCoffeeCount(1)), findsOneWidget);
  });

  testWidgets('shows summary only while subscription is active', (
    tester,
  ) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: true,
        packages: const [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Monthly',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
        ],
        summary: SupportHistorySummary(
          supporterSince: DateTime(2026, 2, 14),
          oneTimeSupportCount: 2,
          coffeeSupportCount: 3,
          lunchSupportCount: 1,
        ),
      ),
      supporter: const SupporterState.active(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    expect(find.text(l.supporterSummaryTitle), findsOneWidget);
    expect(find.text(l.supporterImpactTitle), findsOneWidget);
    expect(find.text(l.supporterSummaryOngoingLabel), findsOneWidget);
    expect(find.text(l.supporterSummaryCoffeeCount(3)), findsOneWidget);
    expect(find.text(l.supporterSummaryLunchCount(1)), findsOneWidget);
  });

  testWidgets('shows support period label for former subscribers', (
    tester,
  ) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        packages: const [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Monthly',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
        ],
        summary: SupportHistorySummary(
          supporterSince: DateTime(2026, 2, 14),
          oneTimeSupportCount: 2,
          coffeeSupportCount: 1,
        ),
      ),
      supporter: const SupporterState.inactive(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    expect(find.text(l.supporterSummaryTitle), findsOneWidget);
    expect(find.text(l.supporterSummarySupportPeriodLabel), findsOneWidget);
    expect(find.text(l.supporterSummaryOngoingLabel), findsNothing);
  });

  testWidgets('orders lunch before drink and shows monthly icon perk copy', (
    tester,
  ) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: true,
        packages: const [
          SupportPackage(
            id: r'$rc_custom_coffee',
            productId: 'support_coffee_5',
            title: 'Drink',
            priceLabel: '\$4.99',
            kind: SupportPackageKind.coffee,
          ),
          SupportPackage(
            id: r'$rc_custom_lunch',
            productId: 'support_lunch_10',
            title: 'Lunch',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.lunch,
          ),
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Monthly',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
        ],
        summary: SupportHistorySummary(
          supporterSince: DateTime(2026, 2, 14),
          coffeeSupportCount: 2,
          lunchSupportCount: 1,
        ),
      ),
      supporter: const SupporterState.active(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    final lunchBadgePosition = tester.getTopLeft(
      find.text(l.supporterSummaryLunchCount(1)),
    );
    final drinkBadgePosition = tester.getTopLeft(
      find.text(l.supporterSummaryCoffeeCount(2)),
    );
    expect(lunchBadgePosition.dx, lessThan(drinkBadgePosition.dx));

    await tester.scrollUntilVisible(
      find.text(l.supporterMonthlyTitle),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.supporterMonthlyDescription), findsOneWidget);
    expect(find.text(l.supporterMonthlyPerkLabel), findsOneWidget);

    final lunchCardPosition = tester.getTopLeft(
      find.text(l.supporterLunchTitle),
    );
    final drinkCardPosition = tester.getTopLeft(
      find.text(l.supporterCoffeeTitle),
    );
    expect(lunchCardPosition.dy, lessThan(drinkCardPosition.dy));
  });

  testWidgets('shows lower-priced monthly and one-time options first', (
    tester,
  ) async {
    final service = FakeRevenueCatService(
      catalog: const SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: true,
        activeSubscriptionProductId: 'supporter_monthly_10_ios',
        packages: [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10_ios',
            title: 'Supporter Monthly Plus',
            priceLabel: r'$9.99',
            price: 9.99,
            kind: SupportPackageKind.monthly,
          ),
          SupportPackage(
            id: r'$rc_custom_monthly_3',
            productId: 'supporter_monthly_3_ios',
            title: 'Supporter Monthly',
            priceLabel: r'$2.99',
            price: 2.99,
            kind: SupportPackageKind.monthly,
          ),
          SupportPackage(
            id: r'$rc_custom_snack',
            productId: 'support_snack_3',
            title: 'Snack Support',
            priceLabel: r'$2.99',
            price: 2.99,
            kind: SupportPackageKind.snack,
          ),
          SupportPackage(
            id: r'$rc_custom_coffee',
            productId: 'support_coffee_5',
            title: 'Drink',
            priceLabel: r'$4.99',
            price: 4.99,
            kind: SupportPackageKind.coffee,
          ),
        ],
      ),
      supporter: const SupporterState.active(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    await tester.scrollUntilVisible(
      find.text('Supporter Monthly'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    final lightPosition = tester.getTopLeft(find.text('Supporter Monthly'));
    final fullPosition = tester.getTopLeft(find.text('Supporter Monthly Plus'));
    expect(lightPosition.dy, lessThan(fullPosition.dy));

    await tester.scrollUntilVisible(
      find.text(l.supporterSnackTitle),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    final snackPosition = tester.getTopLeft(find.text(l.supporterSnackTitle));
    final drinkPosition = tester.getTopLeft(find.text(l.supporterCoffeeTitle));
    expect(snackPosition.dy, lessThan(drinkPosition.dy));
    expect(find.text(l.supporterActiveButton), findsOneWidget);
  });

  testWidgets('matches Android base plan and blocks unsupported plan changes', (
    tester,
  ) async {
    final service = FakeRevenueCatService(
      catalog: const SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: true,
        activeSubscriptionProductId: 'supporter_monthly_10',
        activeSubscriptionPlanId: 'monthly-3',
        packages: [
          SupportPackage(
            id: r'$rc_custom_monthly_3',
            productId: 'supporter_monthly_10',
            title: 'Supporter Monthly',
            priceLabel: r'$2.99',
            price: 2.99,
            kind: SupportPackageKind.monthly,
            subscriptionPeriod: 'P1M',
            subscriptionPlanId: 'monthly-3',
          ),
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Supporter Monthly Plus',
            priceLabel: r'$9.99',
            price: 9.99,
            kind: SupportPackageKind.monthly,
            subscriptionPeriod: 'P1M',
            subscriptionPlanId: 'monthly',
          ),
        ],
      ),
      supporter: const SupporterState.active(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    await tester.scrollUntilVisible(
      find.text(l.supporterMonthlyTitle),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    final activeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l.supporterActiveButton),
    );
    final subscribedButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l.supporterSubscribedButton),
    );
    expect(activeButton.onPressed, isNull);
    expect(subscribedButton.onPressed, isNull);
  });
}
