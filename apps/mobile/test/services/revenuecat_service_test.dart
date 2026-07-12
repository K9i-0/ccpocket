import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as purchases;

class FakeRevenueCatGateway implements RevenueCatGateway {
  RevenueCatOfferingData currentOffering = const RevenueCatOfferingData(
    identifier: 'default',
    packages: [],
  );
  RevenueCatCustomerInfo currentInfo = const RevenueCatCustomerInfo(
    activeEntitlementIds: {},
  );
  RevenueCatCustomerInfoListener? listener;
  bool configured = false;
  bool debugLogsEnabled = false;
  int configureCalls = 0;
  Object? configureError;
  Object? purchaseError;
  Object? restoreError;
  String? lastPurchasedPackageId;
  int restoreCalls = 0;

  @override
  Future<RevenueCatOfferingData> getCurrentOffering() async {
    return currentOffering;
  }

  @override
  void addCustomerInfoUpdateListener(RevenueCatCustomerInfoListener listener) {
    this.listener = listener;
  }

  @override
  Future<void> configure(String publicApiKey) async {
    configureCalls += 1;
    if (configureError != null) throw configureError!;
    configured = true;
  }

  @override
  Future<RevenueCatCustomerInfo> getCustomerInfo() async {
    return currentInfo;
  }

  @override
  Future<RevenueCatCustomerInfo> purchasePackage(String packageId) async {
    if (purchaseError != null) throw purchaseError!;
    lastPurchasedPackageId = packageId;
    return currentInfo;
  }

  @override
  void removeCustomerInfoUpdateListener(
    RevenueCatCustomerInfoListener listener,
  ) {
    if (this.listener == listener) {
      this.listener = null;
    }
  }

  @override
  Future<void> setDebugLogsEnabled() async {
    debugLogsEnabled = true;
  }

  @override
  Future<RevenueCatCustomerInfo> restorePurchases() async {
    if (restoreError != null) throw restoreError!;
    restoreCalls += 1;
    return currentInfo;
  }

  void emit(RevenueCatCustomerInfo info) {
    listener?.call(info);
  }
}

void main() {
  test('maps Android base plan to parent product and plan identifiers', () {
    const option = purchases.SubscriptionOption(
      'monthly-3',
      'supporter_monthly_10:monthly-3',
      'supporter_monthly_10',
      [],
      [],
      true,
      null,
      false,
      null,
      null,
      null,
      null,
      null,
    );
    const storeProduct = purchases.StoreProduct(
      'supporter_monthly_10:monthly-3',
      'Monthly support',
      'Supporter Monthly',
      2.99,
      r'$2.99',
      'USD',
      defaultOption: option,
      subscriptionPeriod: 'P1M',
    );
    const package = purchases.Package(
      r'$rc_custom_monthly_3',
      purchases.PackageType.custom,
      storeProduct,
      purchases.PresentedOfferingContext('default', null, null),
    );

    final mapped = mapRevenueCatPackage(package);

    expect(mapped.productId, 'supporter_monthly_10');
    expect(mapped.subscriptionPlanId, 'monthly-3');
    expect(mapped.kind, SupportPackageKind.monthly);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('RevenueCatService', () {
    test('stays unavailable on unsupported platforms', () async {
      final service = RevenueCatService(
        gateway: FakeRevenueCatGateway(),
        publicApiKey: 'test_key',
        platform: TargetPlatform.macOS,
      );

      await service.initialize();

      expect(service.supporterState.value.isAvailable, isFalse);
      expect(service.supporterState.value.isSupporter, isFalse);
    });

    test('marks active when supporter entitlement is present', () async {
      final gateway = FakeRevenueCatGateway()
        ..currentOffering = RevenueCatOfferingData(
          identifier: 'default',
          packages: const [
            SupportPackage(
              id: r'$rc_monthly',
              productId: 'supporter_monthly_10',
              title: 'Supporter \$9.99/mo',
              priceLabel: r'$9.99',
              kind: SupportPackageKind.monthly,
            ),
          ],
        )
        ..currentInfo = RevenueCatCustomerInfo(
          activeEntitlementIds: const {'supporter'},
          activeSubscriptionProductId: 'supporter_monthly_10',
          activeSubscriptionPlanId: 'monthly',
          historySummary: SupportHistorySummary(
            supporterSince: DateTime(2026, 1, 10),
            latestSubscriptionPurchaseAt: DateTime(2026, 4, 1),
            oneTimeSupportCount: 3,
            snackSupportCount: 1,
            coffeeSupportCount: 2,
            lunchSupportCount: 1,
          ),
        );
      final service = RevenueCatService(
        gateway: gateway,
        publicApiKey: 'test_key',
        platform: TargetPlatform.iOS,
      );

      await service.initialize();

      expect(gateway.configured, isTrue);
      expect(service.supporterState.value.isAvailable, isTrue);
      expect(service.supporterState.value.isSupporter, isTrue);
      expect(service.catalogState.value.packages, hasLength(1));
      expect(service.catalogState.value.summary.oneTimeSupportCount, 3);
      expect(service.catalogState.value.summary.snackSupportCount, 1);
      expect(service.catalogState.value.summary.coffeeSupportCount, 2);
      expect(
        service.catalogState.value.activeSubscriptionProductId,
        'supporter_monthly_10',
      );
      expect(service.catalogState.value.activeSubscriptionPlanId, 'monthly');
      expect(
        service.catalogState.value.summary.supporterSince,
        DateTime(2026, 1, 10),
      );
    });

    test('updates state when customer info changes', () async {
      final gateway = FakeRevenueCatGateway()
        ..currentInfo = const RevenueCatCustomerInfo(activeEntitlementIds: {});
      final service = RevenueCatService(
        gateway: gateway,
        publicApiKey: 'test_key',
        platform: TargetPlatform.android,
      );

      await service.initialize();
      gateway.emit(
        const RevenueCatCustomerInfo(activeEntitlementIds: {'supporter'}),
      );

      expect(service.supporterState.value.isSupporter, isTrue);
    });

    test('refresh retries configure after init failure', () async {
      final gateway = FakeRevenueCatGateway()
        ..configureError = StateError('setup failed')
        ..currentOffering = RevenueCatOfferingData(
          identifier: 'default',
          packages: const [
            SupportPackage(
              id: r'$rc_monthly',
              productId: 'supporter_monthly_10',
              title: 'Supporter \$9.99/mo',
              priceLabel: r'$9.99',
              kind: SupportPackageKind.monthly,
            ),
          ],
        );
      final service = RevenueCatService(
        gateway: gateway,
        publicApiKey: 'test_key',
        platform: TargetPlatform.iOS,
      );

      await service.initialize();
      expect(service.catalogState.value.errorMessage, contains('setup failed'));
      expect(gateway.configureCalls, 1);

      gateway.configureError = null;
      await service.refresh();

      expect(gateway.configureCalls, 2);
      expect(service.catalogState.value.packages, hasLength(1));
      expect(service.catalogState.value.errorMessage, isNull);
    });

    test('purchases a package and updates purchase state', () async {
      final gateway = FakeRevenueCatGateway()
        ..currentOffering = RevenueCatOfferingData(
          identifier: 'default',
          packages: const [
            SupportPackage(
              id: r'$rc_custom_coffee',
              productId: 'support_coffee_5',
              title: r'$4.99 Drink',
              priceLabel: r'$4.99',
              kind: SupportPackageKind.coffee,
            ),
          ],
        );
      final service = RevenueCatService(
        gateway: gateway,
        publicApiKey: 'test_key',
        platform: TargetPlatform.iOS,
      );

      await service.initialize();
      final result = await service.purchasePackage(r'$rc_custom_coffee');

      expect(result.type, SupportActionResultType.success);
      expect(gateway.lastPurchasedPackageId, r'$rc_custom_coffee');
      expect(service.catalogState.value.purchasingPackageId, isNull);
    });

    test('returns cancelled when the user cancels purchase', () async {
      final gateway = FakeRevenueCatGateway()
        ..currentOffering = RevenueCatOfferingData(
          identifier: 'default',
          packages: const [
            SupportPackage(
              id: r'$rc_custom_lunch',
              productId: 'support_lunch_10',
              title: r'$9.99 Lunch',
              priceLabel: r'$9.99',
              kind: SupportPackageKind.lunch,
            ),
          ],
        )
        ..purchaseError = PlatformException(code: '1');
      final service = RevenueCatService(
        gateway: gateway,
        publicApiKey: 'test_key',
        platform: TargetPlatform.android,
      );

      await service.initialize();
      final result = await service.purchasePackage(r'$rc_custom_lunch');

      expect(result.type, SupportActionResultType.cancelled);
      expect(service.catalogState.value.purchasingPackageId, isNull);
    });

    test('restores purchases and updates supporter status', () async {
      final gateway = FakeRevenueCatGateway()
        ..currentInfo = const RevenueCatCustomerInfo(
          activeEntitlementIds: {'supporter'},
        );
      final service = RevenueCatService(
        gateway: gateway,
        publicApiKey: 'test_key',
        platform: TargetPlatform.iOS,
      );

      await service.initialize();
      final result = await service.restorePurchases();

      expect(result.type, SupportActionResultType.success);
      expect(gateway.restoreCalls, 1);
      expect(service.catalogState.value.isSupporter, isTrue);
    });
  });
}
