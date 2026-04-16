import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'in_app_review_service.dart';
import 'revenuecat_service.dart';

class SupportBannerService extends ChangeNotifier {
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
    notifyListeners();
  }
}
