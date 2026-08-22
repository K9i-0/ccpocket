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
      expect(forkableAssistantEntryIndices(entries), {3});
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
      expect(forkableAssistantEntryIndices(entries), isEmpty);
    });

    test('precomputes the last assistant before each result boundary', () {
      final entries = <ChatEntry>[
        ServerChatEntry(_assistant('a1')),
        ServerChatEntry(_result()),
        ServerChatEntry(_assistant('a2')),
        ServerChatEntry(_toolResult('tool')),
        ServerChatEntry(_result()),
      ];

      expect(forkableAssistantEntryIndices(entries), {0, 2});
    });
  });

  group('successResultFallbackEntryIndices', () {
    test('uses result text when the final assistant message is missing', () {
      final entries = <ChatEntry>[
        UserChatEntry('inspect this'),
        ServerChatEntry(_toolAssistant('tool-call')),
        ServerChatEntry(_toolResult('tool-call')),
        ServerChatEntry(_result(result: 'Final summary')),
      ];

      expect(successResultFallbackEntryIndices(entries), {3});
    });

    test('does not duplicate result text already shown by an assistant', () {
      final entries = <ChatEntry>[
        UserChatEntry('inspect this'),
        ServerChatEntry(_assistantWithText('final', 'Final summary')),
        ServerChatEntry(_result(result: 'Final summary')),
      ];

      expect(successResultFallbackEntryIndices(entries), isEmpty);
    });

    test('uses result text when only a progress update exists', () {
      final entries = <ChatEntry>[
        UserChatEntry('inspect this'),
        ServerChatEntry(_assistantWithText('progress', 'Checking files')),
        ServerChatEntry(_toolResult('tool-call')),
        ServerChatEntry(_result(result: 'Final summary')),
      ];

      expect(successResultFallbackEntryIndices(entries), {3});
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

AssistantServerMessage _assistantWithText(String id, String text) =>
    AssistantServerMessage(
      message: AssistantMessage(
        id: id,
        role: 'assistant',
        content: [TextContent(text: text)],
        model: 'codex',
      ),
    );

AssistantServerMessage _toolAssistant(String id) => AssistantServerMessage(
  message: AssistantMessage(
    id: 'assistant-$id',
    role: 'assistant',
    content: [ToolUseContent(id: id, name: 'Read', input: const {})],
    model: 'codex',
  ),
);

ResultMessage _result({String? result}) =>
    ResultMessage(subtype: 'success', result: result);
