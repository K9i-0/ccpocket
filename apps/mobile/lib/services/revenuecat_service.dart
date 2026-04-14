import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as purchases;
import 'package:purchases_flutter/purchases_flutter.dart'
    show PurchasesErrorCode, PurchasesErrorHelper;

import '../core/logger.dart';

const _supporterEntitlementId = 'supporter';
const _debugTestStorePublicKey = 'test_kxZnEyrhheCZDdsIBOOCNMwTWsR';
const _revenueCatPublicKey = String.fromEnvironment('REVENUECAT_PUBLIC_KEY');

enum SupportPackageKind { monthly, coffee, lunch, other }

enum SupportActionResultType { success, cancelled, error }

@immutable
class SupportActionResult {
  const SupportActionResult({required this.type, this.packageId, this.message});

  final SupportActionResultType type;
  final String? packageId;
  final String? message;
}

@immutable
class SupportPackage {
  const SupportPackage({
    required this.id,
    required this.productId,
    required this.title,
    required this.priceLabel,
    required this.kind,
    this.subscriptionPeriod,
  });

  final String id;
  final String productId;
  final String title;
  final String priceLabel;
  final SupportPackageKind kind;
  final String? subscriptionPeriod;

  bool get isSubscription => kind == SupportPackageKind.monthly;
}

@immutable
class SupportHistorySummary {
  const SupportHistorySummary({
    this.supporterSince,
    this.latestSubscriptionPurchaseAt,
    this.oneTimeSupportCount = 0,
    this.coffeeSupportCount = 0,
    this.lunchSupportCount = 0,
  });

  const SupportHistorySummary.empty() : this();

  final DateTime? supporterSince;
  final DateTime? latestSubscriptionPurchaseAt;
  final int oneTimeSupportCount;
  final int coffeeSupportCount;
  final int lunchSupportCount;

  bool get hasActivity => supporterSince != null || oneTimeSupportCount > 0;
}

@immutable
class SupporterState {
  const SupporterState({
    required this.isAvailable,
    required this.isLoading,
    required this.isSupporter,
    this.errorMessage,
  });

  const SupporterState.unavailable()
    : this(isAvailable: false, isLoading: false, isSupporter: false);

  const SupporterState.loading()
    : this(isAvailable: true, isLoading: true, isSupporter: false);

  const SupporterState.inactive()
    : this(isAvailable: true, isLoading: false, isSupporter: false);

  const SupporterState.active()
    : this(isAvailable: true, isLoading: false, isSupporter: true);

  const SupporterState.error(String message)
    : this(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        errorMessage: message,
      );

  final bool isAvailable;
  final bool isLoading;
  final bool isSupporter;
  final String? errorMessage;
}

@immutable
class SupportCatalogState {
  const SupportCatalogState({
    required this.isAvailable,
    required this.isLoading,
    required this.isSupporter,
    required this.packages,
    this.summary = const SupportHistorySummary.empty(),
    this.isRestoring = false,
    this.purchasingPackageId,
    this.errorMessage,
  });

  const SupportCatalogState.unavailable()
    : this(
        isAvailable: false,
        isLoading: false,
        isSupporter: false,
        packages: const [],
      );

  const SupportCatalogState.loading()
    : this(
        isAvailable: true,
        isLoading: true,
        isSupporter: false,
        packages: const [],
      );

  final bool isAvailable;
  final bool isLoading;
  final bool isSupporter;
  final bool isRestoring;
  final String? purchasingPackageId;
  final String? errorMessage;
  final List<SupportPackage> packages;
  final SupportHistorySummary summary;

  bool get hasPackages => packages.isNotEmpty;
  bool get isBusy =>
      isLoading || isRestoring || (purchasingPackageId?.isNotEmpty ?? false);

  SupportCatalogState copyWith({
    bool? isAvailable,
    bool? isLoading,
    bool? isSupporter,
    bool? isRestoring,
    Object? purchasingPackageId = _copySentinel,
    Object? errorMessage = _copySentinel,
    List<SupportPackage>? packages,
    SupportHistorySummary? summary,
  }) {
    return SupportCatalogState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      isSupporter: isSupporter ?? this.isSupporter,
      isRestoring: isRestoring ?? this.isRestoring,
      purchasingPackageId: identical(purchasingPackageId, _copySentinel)
          ? this.purchasingPackageId
          : purchasingPackageId as String?,
      errorMessage: identical(errorMessage, _copySentinel)
          ? this.errorMessage
          : errorMessage as String?,
      packages: packages ?? this.packages,
      summary: summary ?? this.summary,
    );
  }
}

const _copySentinel = Object();

@immutable
class RevenueCatCustomerInfo {
  const RevenueCatCustomerInfo({
    required this.activeEntitlementIds,
    this.historySummary = const SupportHistorySummary.empty(),
  });

  final Set<String> activeEntitlementIds;
  final SupportHistorySummary historySummary;
}

@immutable
class RevenueCatOfferingData {
  const RevenueCatOfferingData({
    required this.identifier,
    required this.packages,
  });

  final String? identifier;
  final List<SupportPackage> packages;
}

typedef RevenueCatCustomerInfoListener =
    void Function(RevenueCatCustomerInfo info);

abstract class RevenueCatGateway {
  Future<void> setDebugLogsEnabled();
  Future<void> configure(String publicApiKey);
  Future<RevenueCatOfferingData> getCurrentOffering();
  Future<RevenueCatCustomerInfo> getCustomerInfo();
  Future<RevenueCatCustomerInfo> purchasePackage(String packageId);
  Future<RevenueCatCustomerInfo> restorePurchases();
  void addCustomerInfoUpdateListener(RevenueCatCustomerInfoListener listener);
  void removeCustomerInfoUpdateListener(
    RevenueCatCustomerInfoListener listener,
  );
}

class PurchasesRevenueCatGateway implements RevenueCatGateway {
  final _listenerMap =
      <RevenueCatCustomerInfoListener, purchases.CustomerInfoUpdateListener>{};
  final _packageCache = <String, purchases.Package>{};

  @override
  Future<void> setDebugLogsEnabled() {
    return purchases.Purchases.setLogLevel(purchases.LogLevel.debug);
  }

  @override
  Future<void> configure(String publicApiKey) {
    return purchases.Purchases.configure(
      purchases.PurchasesConfiguration(publicApiKey),
    );
  }

  @override
  Future<RevenueCatOfferingData> getCurrentOffering() async {
    final offerings = await purchases.Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) {
      _packageCache.clear();
      return const RevenueCatOfferingData(identifier: null, packages: []);
    }

    _packageCache
      ..clear()
      ..addEntries(
        current.availablePackages.map(
          (package) => MapEntry(package.identifier, package),
        ),
      );

    return RevenueCatOfferingData(
      identifier: current.identifier,
      packages: current.availablePackages.map(_mapPackage).toList(),
    );
  }

  @override
  Future<RevenueCatCustomerInfo> getCustomerInfo() async {
    final info = await purchases.Purchases.getCustomerInfo();
    return _mapInfo(info);
  }

  @override
  Future<RevenueCatCustomerInfo> purchasePackage(String packageId) async {
    final package = await _loadPackage(packageId);
    final result = await purchases.Purchases.purchase(
      purchases.PurchaseParams.package(package),
    );
    return _mapInfo(result.customerInfo);
  }

  @override
  Future<RevenueCatCustomerInfo> restorePurchases() async {
    final info = await purchases.Purchases.restorePurchases();
    return _mapInfo(info);
  }

  @override
  void addCustomerInfoUpdateListener(RevenueCatCustomerInfoListener listener) {
    void wrapped(purchases.CustomerInfo info) {
      listener(_mapInfo(info));
    }

    _listenerMap[listener] = wrapped;
    purchases.Purchases.addCustomerInfoUpdateListener(wrapped);
  }

  @override
  void removeCustomerInfoUpdateListener(
    RevenueCatCustomerInfoListener listener,
  ) {
    final wrapped = _listenerMap.remove(listener);
    if (wrapped != null) {
      purchases.Purchases.removeCustomerInfoUpdateListener(wrapped);
    }
  }

  RevenueCatCustomerInfo _mapInfo(purchases.CustomerInfo info) {
    final entitlement = info.entitlements.all[_supporterEntitlementId];
    final oneTimeTransactions = info.nonSubscriptionTransactions;
    final coffeeCount = oneTimeTransactions
        .where(
          (transaction) =>
              _packageKindFor(transaction.productIdentifier, '') ==
              SupportPackageKind.coffee,
        )
        .length;
    final lunchCount = oneTimeTransactions
        .where(
          (transaction) =>
              _packageKindFor(transaction.productIdentifier, '') ==
              SupportPackageKind.lunch,
        )
        .length;

    return RevenueCatCustomerInfo(
      activeEntitlementIds: info.entitlements.active.keys.toSet(),
      historySummary: SupportHistorySummary(
        supporterSince: _parseDate(entitlement?.originalPurchaseDate),
        latestSubscriptionPurchaseAt: _parseDate(
          entitlement?.latestPurchaseDate,
        ),
        oneTimeSupportCount: oneTimeTransactions.length,
        coffeeSupportCount: coffeeCount,
        lunchSupportCount: lunchCount,
      ),
    );
  }

  SupportPackage _mapPackage(purchases.Package package) {
    final product = package.storeProduct;
    return SupportPackage(
      id: package.identifier,
      productId: product.identifier,
      title: product.title,
      priceLabel: product.priceString,
      subscriptionPeriod: product.subscriptionPeriod,
      kind: _packageKindFor(product.identifier, package.identifier),
    );
  }

  Future<purchases.Package> _loadPackage(String packageId) async {
    final cached = _packageCache[packageId];
    if (cached != null) return cached;
    await getCurrentOffering();
    final refreshed = _packageCache[packageId];
    if (refreshed != null) return refreshed;
    throw StateError('Unknown support package: $packageId');
  }

  SupportPackageKind _packageKindFor(String productId, String packageId) {
    if (productId == 'supporter_monthly_10' ||
        productId == 'supporter_monthly_10_ios' ||
        packageId == r'$rc_monthly') {
      return SupportPackageKind.monthly;
    }
    if (productId == 'support_coffee_5' || packageId == r'$rc_custom_coffee') {
      return SupportPackageKind.coffee;
    }
    if (productId == 'support_lunch_10' || packageId == r'$rc_custom_lunch') {
      return SupportPackageKind.lunch;
    }
    return SupportPackageKind.other;
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

class RevenueCatService {
  RevenueCatService({
    RevenueCatGateway? gateway,
    String? publicApiKey,
    TargetPlatform? platform,
  }) : _gateway = gateway ?? PurchasesRevenueCatGateway(),
       _platform = platform,
       _publicApiKey = publicApiKey ?? _defaultPublicApiKey,
       supporterState = ValueNotifier(const SupporterState.unavailable()),
       catalogState = ValueNotifier(const SupportCatalogState.unavailable());

  final RevenueCatGateway _gateway;
  final TargetPlatform? _platform;
  final String _publicApiKey;
  final ValueNotifier<SupporterState> supporterState;
  final ValueNotifier<SupportCatalogState> catalogState;

  Future<void>? _initializeFuture;
  bool _isConfigured = false;

  static String get _defaultPublicApiKey {
    if (_revenueCatPublicKey.isNotEmpty) return _revenueCatPublicKey;
    return kDebugMode ? _debugTestStorePublicKey : '';
  }

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    final platform = _platform ?? defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> refresh() async {
    if (!catalogState.value.isAvailable) return;
    try {
      await _ensureConfigured();
      final offering = await _gateway.getCurrentOffering();
      final info = await _gateway.getCustomerInfo();
      _updateState(
        info,
        packages: offering.packages,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      logger.warning('[revenuecat] refresh failed', error, stackTrace);
      supporterState.value = SupporterState.error(error.toString());
      catalogState.value = catalogState.value.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<SupportActionResult> purchasePackage(String packageId) async {
    final state = catalogState.value;
    if (!state.isAvailable) {
      return const SupportActionResult(type: SupportActionResultType.error);
    }
    catalogState.value = state.copyWith(
      purchasingPackageId: packageId,
      errorMessage: null,
    );
    try {
      final info = await _gateway.purchasePackage(packageId);
      _updateState(info, purchasingPackageId: null, errorMessage: null);
      return SupportActionResult(
        type: SupportActionResultType.success,
        packageId: packageId,
      );
    } on PlatformException catch (error, stackTrace) {
      logger.warning('[revenuecat] purchase failed', error, stackTrace);
      final code = PurchasesErrorHelper.getErrorCode(error);
      final type = code == PurchasesErrorCode.purchaseCancelledError
          ? SupportActionResultType.cancelled
          : SupportActionResultType.error;
      catalogState.value = catalogState.value.copyWith(
        purchasingPackageId: null,
        errorMessage: type == SupportActionResultType.error
            ? error.message ?? error.toString()
            : null,
      );
      return SupportActionResult(
        type: type,
        packageId: packageId,
        message: error.message,
      );
    } catch (error, stackTrace) {
      logger.warning('[revenuecat] purchase failed', error, stackTrace);
      catalogState.value = catalogState.value.copyWith(
        purchasingPackageId: null,
        errorMessage: error.toString(),
      );
      return SupportActionResult(
        type: SupportActionResultType.error,
        packageId: packageId,
        message: error.toString(),
      );
    }
  }

  Future<SupportActionResult> restorePurchases() async {
    final state = catalogState.value;
    if (!state.isAvailable) {
      return const SupportActionResult(type: SupportActionResultType.error);
    }
    catalogState.value = state.copyWith(isRestoring: true, errorMessage: null);
    try {
      final info = await _gateway.restorePurchases();
      _updateState(info, isRestoring: false, errorMessage: null);
      return const SupportActionResult(type: SupportActionResultType.success);
    } on PlatformException catch (error, stackTrace) {
      logger.warning('[revenuecat] restore failed', error, stackTrace);
      catalogState.value = catalogState.value.copyWith(
        isRestoring: false,
        errorMessage: error.message ?? error.toString(),
      );
      return SupportActionResult(
        type: SupportActionResultType.error,
        message: error.message,
      );
    } catch (error, stackTrace) {
      logger.warning('[revenuecat] restore failed', error, stackTrace);
      catalogState.value = catalogState.value.copyWith(
        isRestoring: false,
        errorMessage: error.toString(),
      );
      return SupportActionResult(
        type: SupportActionResultType.error,
        message: error.toString(),
      );
    }
  }

  Future<void> dispose() async {
    _gateway.removeCustomerInfoUpdateListener(_handleCustomerInfoUpdated);
    supporterState.dispose();
    catalogState.dispose();
  }

  Future<void> _initialize() async {
    if (!isSupportedPlatform || _publicApiKey.isEmpty) {
      supporterState.value = const SupporterState.unavailable();
      catalogState.value = const SupportCatalogState.unavailable();
      return;
    }

    supporterState.value = const SupporterState.loading();
    catalogState.value = const SupportCatalogState.loading();
    try {
      if (kDebugMode) {
        await _gateway.setDebugLogsEnabled();
      }
      _gateway.addCustomerInfoUpdateListener(_handleCustomerInfoUpdated);
      await _ensureConfigured();
      final offering = await _gateway.getCurrentOffering();
      final info = await _gateway.getCustomerInfo();
      _updateState(
        info,
        packages: offering.packages,
        isLoading: false,
        errorMessage: null,
      );
      logger.info('[revenuecat] initialized');
    } catch (error, stackTrace) {
      logger.warning('[revenuecat] init failed', error, stackTrace);
      supporterState.value = SupporterState.error(error.toString());
      catalogState.value = SupportCatalogState(
        isAvailable: true,
        isLoading: false,
        isSupporter: false,
        packages: const [],
        errorMessage: error.toString(),
      );
    }
  }

  void _handleCustomerInfoUpdated(RevenueCatCustomerInfo info) {
    _updateState(info);
  }

  Future<void> _ensureConfigured() async {
    if (_isConfigured) return;
    await _gateway.configure(_publicApiKey);
    _isConfigured = true;
  }

  void _updateState(
    RevenueCatCustomerInfo info, {
    List<SupportPackage>? packages,
    bool? isLoading,
    bool? isRestoring,
    String? purchasingPackageId,
    Object? errorMessage = _copySentinel,
  }) {
    final isSupporter = info.activeEntitlementIds.contains(
      _supporterEntitlementId,
    );
    supporterState.value = isSupporter
        ? const SupporterState.active()
        : const SupporterState.inactive();
    final current = catalogState.value;
    catalogState.value = current.copyWith(
      isAvailable: true,
      isLoading: isLoading ?? current.isLoading,
      isSupporter: isSupporter,
      isRestoring: isRestoring ?? false,
      purchasingPackageId: purchasingPackageId,
      errorMessage: errorMessage,
      packages: packages ?? current.packages,
      summary: info.historySummary,
    );
  }
}
