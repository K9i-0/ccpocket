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

  patrolWidgetTest('restores a missing final answer without duplicating it', (
    $,
  ) async {
    await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
    await pumpN($.tester);

    await emitAndPump($.tester, bridge, [
      const HistoryMessage(
        messages: [
          ToolResultMessage(
            toolUseId: 'tool-1',
            toolName: 'Read',
            content: 'tool output',
          ),
          ResultMessage(subtype: 'success', result: 'Recovered final answer'),
          StatusMessage(status: ProcessStatus.idle),
        ],
      ),
    ]);
    await pumpN($.tester);

    expect($('Recovered final answer'), findsOneWidget);

    await emitAndPump($.tester, bridge, [
      makeAssistantMessage('assistant-1', 'Recovered final answer'),
    ]);
    await pumpN($.tester);

    expect($('Recovered final answer'), findsOneWidget);
  });
}
