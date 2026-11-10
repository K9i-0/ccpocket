import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsageInfo.fromJson', () {
    test('parses model-scoped weekly windows', () {
      final info = UsageInfo.fromJson({
        'provider': 'claude',
        'fiveHour': {'utilization': 84, 'resetsAt': '2026-11-10T09:30:00Z'},
        'sevenDay': {'utilization': 14, 'resetsAt': '2026-11-12T08:00:00Z'},
        'modelWindows': [
          {
            'label': 'Fable',
            'utilization': 28,
            'resetsAt': '2026-11-12T08:00:00Z',
          },
        ],
      });

      expect(info.modelWindows, hasLength(1));
      expect(info.modelWindows.single.label, 'Fable');
      expect(info.modelWindows.single.utilization, 28);
      expect(
        info.modelWindows.single.resetsAtDateTime,
        DateTime.utc(2026, 11, 12, 8),
      );
    });

    test('defaults to no model windows for older Bridges', () {
      final info = UsageInfo.fromJson({
        'provider': 'claude',
        'fiveHour': {'utilization': 84, 'resetsAt': '2026-11-10T09:30:00Z'},
        'sevenDay': null,
      });

      expect(info.modelWindows, isEmpty);
    });
  });
}
