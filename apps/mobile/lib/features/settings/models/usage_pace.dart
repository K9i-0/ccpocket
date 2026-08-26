import '../../../models/messages.dart';

enum UsagePaceStage {
  onTrack,
  slightlyAhead,
  ahead,
  farAhead,
  slightlyBehind,
  behind,
  farBehind,
}

class UsagePace {
  static const minimumReliableExpectedPercent = 3.0;

  final UsagePaceStage stage;
  final double deltaPercent;
  final double expectedUsedPercent;
  final double actualUsedPercent;
  final Duration? timeUntilLimit;
  final bool willLastToReset;

  const UsagePace({
    required this.stage,
    required this.deltaPercent,
    required this.expectedUsedPercent,
    required this.actualUsedPercent,
    required this.timeUntilLimit,
    required this.willLastToReset,
  });

  /// Whether enough of the window has elapsed for a useful projection.
  /// A reached limit is always actionable, even at the start of a window.
  bool get isReliable =>
      actualUsedPercent >= 100 ||
      expectedUsedPercent >= minimumReliableExpectedPercent;

  /// Compares actual usage with linear progress through the quota window.
  ///
  /// Thresholds and projection behavior follow CodexBar's UsagePace model.
  static UsagePace? calculate({
    required UsageWindow window,
    required Duration windowDuration,
    DateTime? now,
  }) {
    final resetsAt = window.resetsAtDateTime;
    if (resetsAt == null || windowDuration <= Duration.zero) return null;

    final currentTime = now ?? DateTime.now();
    final timeUntilReset = resetsAt.difference(currentTime);
    if (timeUntilReset <= Duration.zero || timeUntilReset > windowDuration) {
      return null;
    }

    final elapsed = windowDuration - timeUntilReset;
    final actual = window.utilization.clamp(0, 100).toDouble();
    if (elapsed == Duration.zero && actual > 0) return null;

    final expected =
        elapsed.inMicroseconds / windowDuration.inMicroseconds * 100;
    final delta = actual - expected;
    final projection = _projectLimit(
      actualUsedPercent: actual,
      elapsed: elapsed,
      timeUntilReset: timeUntilReset,
    );

    return UsagePace(
      stage: _stageFor(delta),
      deltaPercent: delta,
      expectedUsedPercent: expected.clamp(0, 100),
      actualUsedPercent: actual,
      timeUntilLimit: projection.timeUntilLimit,
      willLastToReset: projection.willLastToReset,
    );
  }

  static UsagePaceStage _stageFor(double delta) {
    final distance = delta.abs();
    if (distance <= 2) return UsagePaceStage.onTrack;
    if (distance <= 6) {
      return delta >= 0
          ? UsagePaceStage.slightlyAhead
          : UsagePaceStage.slightlyBehind;
    }
    if (distance <= 12) {
      return delta >= 0 ? UsagePaceStage.ahead : UsagePaceStage.behind;
    }
    return delta >= 0 ? UsagePaceStage.farAhead : UsagePaceStage.farBehind;
  }

  static _LimitProjection _projectLimit({
    required double actualUsedPercent,
    required Duration elapsed,
    required Duration timeUntilReset,
  }) {
    if (actualUsedPercent >= 100) {
      return const _LimitProjection(
        timeUntilLimit: Duration.zero,
        willLastToReset: false,
      );
    }
    if (actualUsedPercent == 0) {
      return const _LimitProjection(
        timeUntilLimit: null,
        willLastToReset: true,
      );
    }
    if (elapsed <= Duration.zero) {
      return const _LimitProjection(
        timeUntilLimit: null,
        willLastToReset: false,
      );
    }

    final usagePerMicrosecond = actualUsedPercent / elapsed.inMicroseconds;
    final projectedMicroseconds =
        ((100 - actualUsedPercent) / usagePerMicrosecond).round();
    final timeUntilLimit = Duration(microseconds: projectedMicroseconds);
    if (timeUntilLimit >= timeUntilReset) {
      return const _LimitProjection(
        timeUntilLimit: null,
        willLastToReset: true,
      );
    }
    return _LimitProjection(
      timeUntilLimit: timeUntilLimit,
      willLastToReset: false,
    );
  }
}

class _LimitProjection {
  final Duration? timeUntilLimit;
  final bool willLastToReset;

  const _LimitProjection({
    required this.timeUntilLimit,
    required this.willLastToReset,
  });
}
