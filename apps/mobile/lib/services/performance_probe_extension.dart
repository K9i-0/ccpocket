import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../theme/markdown_style.dart';

final _probe = _FrameTimingProbe();

void registerPerformanceProbeExtensions() {
  if (!kDebugMode) return;
  _probe.ensureAttached();

  registerMarionetteExtension(
    name: 'ccpocket.performance.reset',
    description: 'Reset collected Flutter frame timing samples.',
    callback: (params) async {
      _probe.reset();
      markdownPerformanceProbe.reset();
      return MarionetteExtensionResult.success({'status': 'reset'});
    },
  );

  registerMarionetteExtension(
    name: 'ccpocket.performance.summary',
    description: 'Return Flutter frame timing summary since last reset.',
    callback: (params) async {
      final thresholdMs =
          int.tryParse(params['thresholdMs']?.toString() ?? '') ?? 16;
      return MarionetteExtensionResult.success({
        ..._probe.summary(threshold: Duration(milliseconds: thresholdMs)),
        'markdown': markdownPerformanceProbe.summary(),
      });
    },
  );
}

class _FrameTimingProbe {
  final List<FrameTiming> _samples = [];
  var _attached = false;

  void ensureAttached() {
    if (_attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_samples.addAll);
  }

  void reset() {
    _samples.clear();
  }

  Map<String, Object?> summary({required Duration threshold}) {
    final build = _samples.map((t) => t.buildDuration.inMicroseconds).toList();
    final raster = _samples
        .map((t) => t.rasterDuration.inMicroseconds)
        .toList();
    final total = _samples.map((t) => t.totalSpan.inMicroseconds).toList();
    final thresholdUs = threshold.inMicroseconds;

    return {
      'frameCount': _samples.length,
      'jankyFrames': total.where((v) => v > thresholdUs).length,
      'thresholdMs': threshold.inMilliseconds,
      'build': _durationStats(build),
      'raster': _durationStats(raster),
      'total': _durationStats(total),
    };
  }

  Map<String, Object?> _durationStats(List<int> values) {
    if (values.isEmpty) {
      return {'avgMs': 0, 'p90Ms': 0, 'p99Ms': 0, 'maxMs': 0};
    }

    values.sort();
    final sum = values.fold<int>(0, (a, b) => a + b);
    return {
      'avgMs': _roundMs(sum / values.length),
      'p90Ms': _roundMs(_percentile(values, 0.90).toDouble()),
      'p99Ms': _roundMs(_percentile(values, 0.99).toDouble()),
      'maxMs': _roundMs(values.last.toDouble()),
    };
  }

  int _percentile(List<int> sortedValues, double percentile) {
    final index = math.min(
      sortedValues.length - 1,
      (sortedValues.length * percentile).ceil() - 1,
    );
    return sortedValues[math.max(0, index)];
  }

  double _roundMs(double micros) {
    return (micros / 1000 * 10).roundToDouble() / 10;
  }
}
