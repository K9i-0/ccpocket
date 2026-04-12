import 'package:ccpocket/features/settings/widgets/support_section.dart';
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

  int refreshCalls = 0;
  int restoreCalls = 0;
  String? lastPurchaseId;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }

  @override
  Future<SupportActionResult> purchasePackage(String packageId) async {
    lastPurchaseId = packageId;
    return SupportActionResult(
      type: SupportActionResultType.success,
      packageId: packageId,
    );
  }

  @override
  Future<SupportActionResult> restorePurchases() async {
    restoreCalls += 1;
    return const SupportActionResult(type: SupportActionResultType.success);
  }
}

Widget _wrap(RevenueCatService revenueCatService) {
  return RepositoryProvider<RevenueCatService>.value(
    value: revenueCatService,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SupportSectionCard()),
    ),
  );
}

void main() {
  testWidgets('renders packages and restore action', (tester) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        summary: SupportHistorySummary(
          supporterSince: DateTime(2026, 1, 10),
          oneTimeSupportCount: 3,
          coffeeSupportCount: 2,
          lunchSupportCount: 1,
        ),
        packages: [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Supporter \$10/mo',
            priceLabel: '\$10.00',
            kind: SupportPackageKind.monthly,
          ),
          SupportPackage(
            id: r'$rc_custom_coffee',
            productId: 'support_coffee_5',
            title: '\$5 Coffee',
            priceLabel: '\$5.00',
            kind: SupportPackageKind.coffee,
          ),
        ],
      ),
      supporter: const SupporterState.inactive(),
    );

    await tester.pumpWidget(_wrap(service));

    expect(find.text('Supporter Monthly'), findsOneWidget);
    expect(find.text('Coffee Support'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('About Supporter'), findsOneWidget);
    expect(find.text('Your support'), findsOneWidget);
    expect(find.text('One-time ×3'), findsOneWidget);
    expect(find.text('Coffee ×2'), findsOneWidget);
    expect(find.text('Lunch ×1'), findsOneWidget);
  });

  testWidgets('purchase button invokes service', (tester) async {
    final service = FakeRevenueCatService(
      catalog: const SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        packages: [
          SupportPackage(
            id: r'$rc_custom_lunch',
            productId: 'support_lunch_10',
            title: '\$10 Lunch',
            priceLabel: '\$10.00',
            kind: SupportPackageKind.lunch,
          ),
        ],
      ),
      supporter: const SupporterState.inactive(),
    );

    await tester.pumpWidget(_wrap(service));
    await tester.tap(find.text('Support'));
    await tester.pump();

    expect(service.lastPurchaseId, r'$rc_custom_lunch');
  });
}
