import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/in_app_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppReviewService', () {
    test(
      'requests review without approval actions when other thresholds are met',
      () async {
        final now = DateTime(2026, 3, 7, 12);
        SharedPreferences.setMockInitialValues({
          'review.first_seen_at_ms': now
              .subtract(const Duration(days: 5))
              .millisecondsSinceEpoch,
          'review.successful_connections': 3,
          'review.created_sessions': 3,
          'review.usage_days': ['2026-03-05', '2026-03-07'],
        });
        final prefs = await SharedPreferences.getInstance();
        final gateway = _FakeInAppReviewGateway(available: true);
        final service = InAppReviewService(
          prefs: prefs,
          gateway: gateway,
          appVersionLoader: () async => '1.30.0',
          now: () => now,
        );

        await service.maybeRequestReview(trigger: 'test');

        expect(gateway.requestCount, 1);
        expect(prefs.getString('review.last_prompt_version'), '1.30.0');
        expect(
          prefs.getInt('review.last_prompt_at_ms'),
          now.millisecondsSinceEpoch,
        );
      },
    );

    test('continues counting approval actions for telemetry', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = InAppReviewService(
        prefs: prefs,
        appVersionLoader: () async => '1.30.0',
        now: () => DateTime(2026, 3, 7, 12),
      );

      service.recordOutgoingMessage(ClientMessage.approve('tool-1'));
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('review.approval_actions'), 1);
      expect(service.buildProgressSummary(), contains('approval_actions:1'));
    });

    test('does not request review when a recent error exists', () async {
      final now = DateTime(2026, 3, 7, 12);
      SharedPreferences.setMockInitialValues({
        'review.first_seen_at_ms': now
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch,
        'review.successful_connections': 4,
        'review.created_sessions': 4,
        'review.approval_actions': 8,
        'review.usage_days': ['2026-03-04', '2026-03-07'],
        'review.last_negative_at_ms': now
            .subtract(const Duration(hours: 3))
            .millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      final gateway = _FakeInAppReviewGateway(available: true);
      final service = InAppReviewService(
        prefs: prefs,
        gateway: gateway,
        appVersionLoader: () async => '1.30.0',
        now: () => now,
      );

      final eligibility = await service.getEligibility();
      await service.maybeRequestReview(trigger: 'test');

      expect(eligibility.isEligible, isFalse);
      expect(eligibility.reason, 'recent_negative_signal');
      expect(gateway.requestCount, 0);
    });
  });
}

class _FakeInAppReviewGateway extends InAppReviewGateway {
  _FakeInAppReviewGateway({required this.available});

  final bool available;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requestCount += 1;
  }
}
