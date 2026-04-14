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

AppLocalizations _localizations(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(SupportSectionCard)));
}

void main() {
  testWidgets('renders inactive support entry only', (tester) async {
    final service = FakeRevenueCatService(
      catalog: SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        packages: [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Supporter \$9.99/mo',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
          SupportPackage(
            id: r'$rc_custom_coffee',
            productId: 'support_coffee_5',
            title: '\$4.99 Coffee',
            priceLabel: '\$4.99',
            kind: SupportPackageKind.coffee,
          ),
        ],
      ),
      supporter: const SupporterState.inactive(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    expect(
      find.byKey(const ValueKey('supporter_entry_button')),
      findsOneWidget,
    );
    expect(find.text(l.supportEntryInactiveTitle), findsOneWidget);
    expect(find.text(l.supportEntryInactiveSubtitle), findsOneWidget);
    expect(find.text('Supporter Monthly'), findsNothing);
    expect(find.text('Coffee Support'), findsNothing);
    expect(find.text(l.supporterRestoreButton), findsNothing);
  });

  testWidgets('renders active support entry with badge', (tester) async {
    final service = FakeRevenueCatService(
      catalog: const SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: true,
        packages: [
          SupportPackage(
            id: r'$rc_monthly',
            productId: 'supporter_monthly_10',
            title: 'Supporter \$9.99/mo',
            priceLabel: '\$9.99',
            kind: SupportPackageKind.monthly,
          ),
        ],
      ),
      supporter: const SupporterState.active(),
    );

    await tester.pumpWidget(_wrap(service));
    final l = _localizations(tester);

    expect(
      find.byKey(const ValueKey('supporter_entry_button')),
      findsOneWidget,
    );
    expect(find.text(l.supportEntryActiveTitle), findsOneWidget);
    expect(find.textContaining('CC Pocket'), findsOneWidget);
    expect(find.text('Supporter Monthly'), findsNothing);
  });
}
