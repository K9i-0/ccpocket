import 'package:ccpocket/features/settings/models/usage_pace.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsagePace', () {
    final now = DateTime.utc(2026, 8, 26, 12);
    const weeklyDuration = Duration(days: 7);

    UsagePace? calculate(double utilization) {
      return UsagePace.calculate(
        window: UsageWindow(
          utilization: utilization,
          resetsAt: now
              .add(const Duration(days: 3, hours: 12))
              .toIso8601String(),
        ),
        windowDuration: weeklyDuration,
        now: now,
      );
    }

    test('reports on pace when actual usage matches elapsed time', () {
      final pace = calculate(50);

      expect(pace, isNotNull);
      expect(pace!.stage, UsagePaceStage.onTrack);
      expect(pace.expectedUsedPercent, closeTo(50, 0.001));
      expect(pace.deltaPercent, closeTo(0, 0.001));
      expect(pace.willLastToReset, isTrue);
      expect(pace.timeUntilLimit, isNull);
    });

    test('projects an early limit when consumption is ahead of pace', () {
      final pace = calculate(60);

      expect(pace!.stage, UsagePaceStage.ahead);
      expect(pace.deltaPercent, closeTo(10, 0.001));
      expect(pace.willLastToReset, isFalse);
      expect(pace.timeUntilLimit, const Duration(days: 2, hours: 8));
    });

    test('reports headroom when consumption is behind pace', () {
      final pace = calculate(38);

      expect(pace!.stage, UsagePaceStage.behind);
      expect(pace.deltaPercent, closeTo(-12, 0.001));
      expect(pace.willLastToReset, isTrue);
    });

    test('uses CodexBar stage thresholds', () {
      expect(calculate(52)!.stage, UsagePaceStage.onTrack);
      expect(calculate(56)!.stage, UsagePaceStage.slightlyAhead);
      expect(calculate(62)!.stage, UsagePaceStage.ahead);
      expect(calculate(63)!.stage, UsagePaceStage.farAhead);
      expect(calculate(44)!.stage, UsagePaceStage.slightlyBehind);
      expect(calculate(38)!.stage, UsagePaceStage.behind);
      expect(calculate(37)!.stage, UsagePaceStage.farBehind);
    });

    test('returns null when reset metadata is unavailable or stale', () {
      expect(
        UsagePace.calculate(
          window: const UsageWindow(utilization: 20, resetsAt: ''),
          windowDuration: weeklyDuration,
          now: now,
        ),
        isNull,
      );
      expect(
        UsagePace.calculate(
          window: UsageWindow(
            utilization: 20,
            resetsAt: now
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
          ),
          windowDuration: weeklyDuration,
          now: now,
        ),
        isNull,
      );
    });

    test('waits for three percent of the window before trusting pace', () {
      UsagePace paceAtElapsed(double elapsedPercent, double utilization) {
        final elapsedMicroseconds =
            (weeklyDuration.inMicroseconds * elapsedPercent / 100).round();
        return UsagePace.calculate(
          window: UsageWindow(
            utilization: utilization,
            resetsAt: now
                .add(
                  weeklyDuration - Duration(microseconds: elapsedMicroseconds),
                )
                .toIso8601String(),
          ),
          windowDuration: weeklyDuration,
          now: now,
        )!;
      }

      expect(paceAtElapsed(2.99, 1).isReliable, isFalse);
      expect(paceAtElapsed(3, 3).isReliable, isTrue);
      expect(paceAtElapsed(1, 100).isReliable, isTrue);
    });
  });
}
