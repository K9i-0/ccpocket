import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';

void main() {
  test('Bridge suppresses local completion without losing the result', () {
    final message = ServerMessage.fromJson({
      'type': 'result',
      'subtype': 'success',
      'notification': 'none',
    });
    final update = ChatMessageHandler().handle(
      message,
      isBackground: true,
      isCodex: true,
    );
    expect(update.entriesToAdd, hasLength(1));
    expect(
      update.sideEffects,
      isNot(contains(ChatSideEffect.notifySessionComplete)),
    );
  });

  test('opt-in progress produces a distinct notification', () {
    final message = ServerMessage.fromJson({
      'type': 'result',
      'subtype': 'success',
      'notification': 'goal_progress',
    });
    final update = ChatMessageHandler().handle(
      message,
      isBackground: true,
      isCodex: true,
    );
    expect(update.sideEffects, contains(ChatSideEffect.notifyGoalProgress));
    expect(
      update.sideEffects,
      isNot(contains(ChatSideEffect.notifySessionComplete)),
    );
  });

  test('old Bridge results retain legacy behavior', () {
    final update = ChatMessageHandler().handle(
      const ResultMessage(subtype: 'success'),
      isBackground: true,
      isCodex: true,
    );
    expect(update.sideEffects, contains(ChatSideEffect.notifySessionComplete));
  });

  test('snapshots and unknown kinds cannot trigger completion', () {
    final message = ServerMessage.fromJson({
      'type': 'goal_state',
      'goal': null,
    }) as GoalStateMessage;
    expect(goalNotificationEffect(message.notification), isNull);
    expect(goalNotificationEffect('future_kind'), isNull);
    expect(
      goalNotificationEffect('goal_complete'),
      ChatSideEffect.notifyGoalComplete,
    );
    expect(
      goalNotificationEffect('goal_blocked'),
      ChatSideEffect.notifyGoalBlocked,
    );
    expect(
      goalNotificationEffect('goal_budget_limited'),
      ChatSideEffect.notifyGoalBudgetLimited,
    );
    expect(
      goalNotificationEffect('goal_usage_limited'),
      ChatSideEffect.notifyGoalUsageLimited,
    );
  });
}
