import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowForkForAssistant', () {
    test('only returns true for the assistant message before result', () {
      final first = _assistant('a1');
      final second = _assistant('a2');
      final entries = <ChatEntry>[
        UserChatEntry('hello'),
        ServerChatEntry(first),
        ServerChatEntry(_toolResult('tool1')),
        ServerChatEntry(second),
        ServerChatEntry(_toolResult('tool2')),
        ServerChatEntry(_result()),
      ];

      expect(shouldShowForkForAssistant(entries, 1), isFalse);
      expect(shouldShowForkForAssistant(entries, 3), isTrue);
    });

    test('does not show fork before the next user turn', () {
      final entries = <ChatEntry>[
        UserChatEntry('first'),
        ServerChatEntry(_assistant('a1')),
        UserChatEntry('second'),
        ServerChatEntry(_assistant('a2')),
      ];

      expect(shouldShowForkForAssistant(entries, 1), isFalse);
      expect(shouldShowForkForAssistant(entries, 3), isFalse);
    });
  });
}

AssistantServerMessage _assistant(String id) => AssistantServerMessage(
  message: AssistantMessage(
    id: id,
    role: 'assistant',
    content: [TextContent(text: id)],
    model: 'codex',
  ),
);

ToolResultMessage _toolResult(String id) =>
    ToolResultMessage(toolUseId: id, content: 'ok');

ResultMessage _result() => const ResultMessage(subtype: 'success');
