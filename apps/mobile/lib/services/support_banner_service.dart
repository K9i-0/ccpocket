import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'in_app_review_service.dart';
import 'revenuecat_service.dart';

class SupportBannerService {
  SupportBannerService({
    required SharedPreferences prefs,
    required InAppReviewService reviewService,
    this.forceShowInDebug = false,
  }) : _prefs = prefs,
       _reviewService = reviewService;

  static const dismissedKey = 'support_banner.dismissed';
  static const debugForceShowKey = 'support_banner.debug_force_show';

  final SharedPreferences _prefs;
  final InAppReviewService _reviewService;
  final bool forceShowInDebug;
  final ValueNotifier<int> _changes = ValueNotifier<int>(0);
  bool _disposed = false;

  Listenable get listenable => _changes;

  bool get debugForceShowOverride =>
      _prefs.getBool(debugForceShowKey) ?? forceShowInDebug;
  bool get shouldForceShowInDebug => kDebugMode && debugForceShowOverride;
  bool get isDismissed => _prefs.getBool(dismissedKey) ?? false;

  Future<bool> shouldShow({
    required bool hasBridgeUpdate,
    required SupportCatalogState catalog,
  }) async {
    if (shouldForceShowInDebug) {
      return true;
    }

    if (hasBridgeUpdate ||
        isDismissed ||
        !catalog.isAvailable ||
        catalog.isSupporter ||
        !catalog.hasPackages) {
      return false;
    }

    final eligibility = await _reviewService.getSupportBannerEligibility();
    return eligibility.isEligible;
  }

  Future<void> dismiss() async {
    await _prefs.setBool(dismissedKey, true);
  }

  Future<void> setDebugForceShowOverride(bool value) async {
    await _prefs.setBool(debugForceShowKey, value);
    if (!_disposed) {
      _changes.value++;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _changes.dispose();
  }
}
