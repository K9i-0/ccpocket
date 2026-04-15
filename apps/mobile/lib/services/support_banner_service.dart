import 'package:shared_preferences/shared_preferences.dart';

import 'in_app_review_service.dart';
import 'revenuecat_service.dart';

class SupportBannerService {
  SupportBannerService({
    required SharedPreferences prefs,
    required InAppReviewService reviewService,
  }) : _prefs = prefs,
       _reviewService = reviewService;

  static const dismissedKey = 'support_banner.dismissed';

  final SharedPreferences _prefs;
  final InAppReviewService _reviewService;

  bool get isDismissed => _prefs.getBool(dismissedKey) ?? false;

  Future<bool> shouldShow({
    required bool hasBridgeUpdate,
    required SupportCatalogState catalog,
  }) async {
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
}
