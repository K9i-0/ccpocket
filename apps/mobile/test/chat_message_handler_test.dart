import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';

void main() {
  late ChatMessageHandler handler;

  setUp(() {
    handler = ChatMessageHandler();
  });

  group('StatusMessage handling', () {
    test('waitingApproval triggers heavy haptic', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.waitingApproval),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.waitingApproval);
      expect(update.sideEffects, contains(ChatSideEffect.heavyHaptic));
      expect(update.resetPending, isFalse);
    });

    test('waitingApproval in background sends notification', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.waitingApproval),
        isBackground: true,
      );
      expect(
        update.sideEffects,
        contains(ChatSideEffect.notifyApprovalRequired),
      );
    });

    test('idle status resets pending state', () {
      final update = handler.handle(
        const StatusMessage(status: ProcessStatus.idle),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.idle);
      expect(update.resetPending, isTrue);
    });
  });

  group('ThinkingDelta handling', () {
    test('accumulates thinking text', () {
      handler.handle(
        const ThinkingDeltaMessage(text: 'Hello '),
        isBackground: false,
      );
      handler.handle(
        const ThinkingDeltaMessage(text: 'world'),
        isBackground: false,
      );
      expect(handler.currentThinkingText, 'Hello world');
    });
  });

  group('StreamDelta handling', () {
    test('first delta creates streaming entry', () {
      final update = handler.handle(
        const StreamDeltaMessage(text: 'Hi'),
        isBackground: false,
      );
      expect(update.entriesToAdd, hasLength(1));
      expect(handler.currentStreaming, isNotNull);
      expect(handler.currentStreaming!.text, 'Hi');
    });

    test('subsequent deltas append to existing streaming', () {
      handler.handle(const StreamDeltaMessage(text: 'Hi'), isBackground: false);
      final update = handler.handle(
        const StreamDeltaMessage(text: ' there'),
        isBackground: false,
      );
      expect(update.entriesToAdd, isEmpty);
      expect(handler.currentStreaming!.text, 'Hi there');
    });
  });

  group('AssistantMessage handling', () {
    test('triggers collapse tool results', () {
      final update = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [const TextContent(text: 'Hello')],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update.sideEffects, contains(ChatSideEffect.collapseToolResults));
      expect(update.markUserMessagesSent, isTrue);
    });

    test('injects accumulated thinking text', () {
      handler.handle(
        const ThinkingDeltaMessage(text: 'Thinking...'),
        isBackground: false,
      );
      handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [const TextContent(text: 'Response')],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      // Thinking text should be cleared after injection
      expect(handler.currentThinkingText, isEmpty);
    });

    test('detects AskUserQuestion tool use', () {
      final update = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [
              const ToolUseContent(
                id: 'tu-ask',
                name: 'AskUserQuestion',
                input: {'questions': []},
              ),
            ],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update.askToolUseId, 'tu-ask');
      expect(update.sideEffects, contains(ChatSideEffect.mediumHaptic));
    });

    test('detects EnterPlanMode', () {
      final update = handler.handle(
        AssistantServerMessage(
          message: AssistantMessage(
            id: 'msg-1',
            role: 'assistant',
            content: [
              const ToolUseContent(
                id: 'tu-plan',
                name: 'EnterPlanMode',
                input: {},
              ),
            ],
            model: 'test',
          ),
        ),
        isBackground: false,
      );
      expect(update.inPlanMode, isTrue);
      expect(update.pendingToolUseId, 'tu-plan');
    });
  });

  group('PastHistory handling', () {
    test('converts past messages to entries', () {
      final update = handler.handle(
        const PastHistoryMessage(
          claudeSessionId: 'sess-1',
          messages: [
            PastMessage(
              role: 'user',
              content: [TextContent(text: 'Hello')],
            ),
            PastMessage(
              role: 'assistant',
              content: [TextContent(text: 'Hi')],
            ),
          ],
        ),
        isBackground: false,
      );
      expect(update.entriesToPrepend, hasLength(2));
      expect(update.entriesToPrepend[0], isA<UserChatEntry>());
      expect(update.entriesToPrepend[1], isA<ServerChatEntry>());
    });
  });

  group('ResultMessage handling', () {
    test('stopped resets all state', () {
      final update = handler.handle(
        const ResultMessage(subtype: 'stopped'),
        isBackground: false,
      );
      expect(update.status, ProcessStatus.idle);
      expect(update.resetPending, isTrue);
      expect(update.resetAsk, isTrue);
      expect(update.resetStreaming, isTrue);
      expect(update.inPlanMode, isFalse);
      expect(update.sideEffects, contains(ChatSideEffect.clearPlanFeedback));
    });

    test('success adds cost delta', () {
      final update = handler.handle(
        const ResultMessage(subtype: 'success', cost: 0.05),
        isBackground: false,
      );
      expect(update.costDelta, 0.05);
      expect(update.sideEffects, contains(ChatSideEffect.lightHaptic));
    });

    test('success in background sends notification', () {
      final update = handler.handle(
        const ResultMessage(subtype: 'success', cost: 0.05),
        isBackground: true,
      );
      expect(
        update.sideEffects,
        contains(ChatSideEffect.notifySessionComplete),
      );
    });
  });

  group('PermissionRequestMessage.summary', () {
    test('extracts command from input', () {
      const perm = PermissionRequestMessage(
        toolUseId: 'tu-1',
        toolName: 'Bash',
        input: {'command': 'ls -la'},
      );
      expect(perm.summary, 'ls -la');
    });

    test('truncates long values', () {
      const perm = PermissionRequestMessage(
        toolUseId: 'tu-1',
        toolName: 'Read',
        input: {
          'file_path':
              '/very/long/path/that/exceeds/sixty/characters/definitely/yes/indeed/it/does/wow.dart',
        },
      );
      expect(perm.summary.length, lessThanOrEqualTo(63)); // 60 + "..."
    });

    test('falls back to toolName when no recognized keys', () {
      const perm = PermissionRequestMessage(
        toolUseId: 'tu-1',
        toolName: 'CustomTool',
        input: {'foo': 'bar'},
      );
      expect(perm.summary, 'CustomTool');
    });
  });
}
