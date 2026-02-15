import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'helpers/chat_test_helpers.dart';

void main() {
  late MockBridgeService bridge;

  setUp(() {
    bridge = MockBridgeService();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('Usage summary', () {
    patrolWidgetTest('U1: Shows usage from restored history', ($) async {
      await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const HistoryMessage(
          messages: [
            ResultMessage(
              subtype: 'success',
              cost: 0.0123,
              duration: 2100,
              inputTokens: 1200,
              cachedInputTokens: 300,
              outputTokens: 450,
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
      ]);
      await pumpN($.tester);

      expect($(#usage_summary_bar), findsOneWidget);
      expect(find.textContaining('\$0.0123'), findsWidgets);
      expect(find.textContaining('in 1.5k'), findsOneWidget);
      expect(find.textContaining('out 450'), findsOneWidget);
    });
  });
}
