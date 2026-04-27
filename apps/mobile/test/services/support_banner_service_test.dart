import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupportBannerService', () {
    test(
      'shows banner without approval actions when engagement thresholds are met',
      () async {
        final now = DateTime(2026, 4, 15, 12);
        SharedPreferences.setMockInitialValues({
          'review.first_seen_at_ms': now
              .subtract(const Duration(days: 5))
              .millisecondsSinceEpoch,
          'review.successful_connections': 3,
          'review.created_sessions': 3,
          'review.usage_days': const ['2026-04-13', '2026-04-15'],
        });
        final prefs = await SharedPreferences.getInstance();
        final reviewService = InAppReviewService(
          prefs: prefs,
          now: () => now,
          appVersionLoader: () async => '1.50.0',
        );
        final service = SupportBannerService(
          prefs: prefs,
          reviewService: reviewService,
        );

        final shouldShow = await service.shouldShow(
          hasBridgeUpdate: false,
          catalog: _inactiveCatalog,
        );

        expect(shouldShow, isTrue);
      },
    );

    test('does not show banner after dismissal', () async {
      final now = DateTime(2026, 4, 15, 12);
      SharedPreferences.setMockInitialValues({
        'review.first_seen_at_ms': now
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch,
        'review.successful_connections': 3,
        'review.created_sessions': 3,
        'review.approval_actions': 5,
        'review.usage_days': const ['2026-04-13', '2026-04-15'],
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SupportBannerService(
        prefs: prefs,
        reviewService: InAppReviewService(
          prefs: prefs,
          now: () => now,
          appVersionLoader: () async => '1.50.0',
        ),
      );

      await service.dismiss();
      final shouldShow = await service.shouldShow(
        hasBridgeUpdate: false,
        catalog: _inactiveCatalog,
      );

      expect(shouldShow, isFalse);
    });

    test('does not show banner when bridge update banner is visible', () async {
      final now = DateTime(2026, 4, 15, 12);
      SharedPreferences.setMockInitialValues({
        'review.first_seen_at_ms': now
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch,
        'review.successful_connections': 3,
        'review.created_sessions': 3,
        'review.approval_actions': 5,
        'review.usage_days': const ['2026-04-13', '2026-04-15'],
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SupportBannerService(
        prefs: prefs,
        reviewService: InAppReviewService(
          prefs: prefs,
          now: () => now,
          appVersionLoader: () async => '1.50.0',
        ),
      );

      final shouldShow = await service.shouldShow(
        hasBridgeUpdate: true,
        catalog: _inactiveCatalog,
      );

      expect(shouldShow, isFalse);
    });

    test('allows debug override to force-show banner', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = SupportBannerService(
        prefs: prefs,
        reviewService: InAppReviewService(
          prefs: prefs,
          now: () => DateTime(2026, 4, 15, 12),
          appVersionLoader: () async => '1.50.0',
        ),
      );

      await service.setDebugForceShowOverride(true);
      final shouldShow = await service.shouldShow(
        hasBridgeUpdate: true,
        catalog: const SupportCatalogState.unavailable(),
      );

      expect(service.debugForceShowOverride, isTrue);
      expect(service.shouldForceShowInDebug, isTrue);
      expect(shouldShow, isTrue);
    });
  });
}

const _inactiveCatalog = SupportCatalogState(
  isAvailable: true,
  isLoading: false,
  isSupporter: false,
  packages: [
    SupportPackage(
      id: r'$rc_monthly',
      productId: 'supporter_monthly_10',
      title: 'Supporter',
      priceLabel: '\$9.99',
      kind: SupportPackageKind.monthly,
    ),
  ],
);
