import 'package:ccpocket/features/chat/state/streaming_state_cubit.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  group('Streaming', () {
    patrolWidgetTest('G1: StreamDelta accumulates text', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const StreamDeltaMessage(text: 'Hello '),
        const StreamDeltaMessage(text: 'world'),
        const StreamDeltaMessage(text: '!'),
      ]);
      await pumpN($.tester);

      expect($('Hello world!'), findsOneWidget);
    });

    patrolWidgetTest('G2: AssistantMessage replaces streaming', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      // First emit stream deltas to show streaming text
      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const StreamDeltaMessage(text: 'Partial '),
        const StreamDeltaMessage(text: 'text'),
      ]);
      await pumpN($.tester);

      // Then emit the final assistant message
      await emitAndPump($.tester, bridge, [
        makeAssistantMessage('a1', 'Final complete response'),
      ]);
      await pumpN($.tester);

      expect($('Final complete response'), findsOneWidget);
    });

    patrolWidgetTest('G3: ThinkingDelta accumulates thinking text', ($) async {
      await $.pumpWidget(buildTestChatScreen(bridge: bridge));
      await pumpN($.tester);

      await emitAndPump($.tester, bridge, [
        const StatusMessage(status: ProcessStatus.running),
        const ThinkingDeltaMessage(text: 'Thinking...'),
        const ThinkingDeltaMessage(text: ' more'),
      ]);
      await pumpN($.tester);

      // ThinkingDelta accumulates in the StreamingStateCubit's thinking
      // field (not rendered as a visible widget during streaming — only
      // finalized ThinkingContent in AssistantServerMessage renders a
      // ThinkingBubble). Verify the cubit state directly.
      final element = $.tester.element(find.byType(Scaffold).first);
      final cubit = element.read<StreamingStateCubit>();
      expect(cubit.state.thinking, 'Thinking... more');
    });
  });
}
