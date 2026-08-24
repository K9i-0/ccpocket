import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const timestampText = '12:34';
  final timestamp = DateTime(2026, 8, 23, 12, 34);

  Widget buildSubject(ChatEntry entry, {Set<String> hiddenIds = const {}}) {
    return MaterialApp(
      home: Scaffold(
        body: ChatEntryWidget(entry: entry, hiddenToolUseIds: hiddenIds),
      ),
    );
  }

  testWidgets('does not render a timestamp for an empty streaming row', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(StreamingChatEntry(text: '', timestamp: timestamp)),
    );

    expect(find.text(timestampText), findsNothing);
  });

  testWidgets('does not render a timestamp for a hidden server event', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        ServerChatEntry(
          const StatusMessage(status: ProcessStatus.running),
          timestamp: timestamp,
        ),
      ),
    );

    expect(find.text(timestampText), findsNothing);
  });

  testWidgets('does not render a timestamp for an empty assistant event', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        ServerChatEntry(
          const AssistantServerMessage(
            message: AssistantMessage(
              id: 'assistant-1',
              role: 'assistant',
              content: [],
              model: 'codex',
            ),
          ),
          timestamp: timestamp,
        ),
      ),
    );

    expect(find.text(timestampText), findsNothing);
  });

  testWidgets('does not render a timestamp for a summarized tool result', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        ServerChatEntry(
          const ToolResultMessage(toolUseId: 'tool-1', content: 'hidden'),
          timestamp: timestamp,
        ),
        hiddenIds: const {'tool-1'},
      ),
    );

    expect(find.text(timestampText), findsNothing);
  });

  test('timestamp grouping skips hidden entries', () {
    final firstVisible = UserChatEntry(
      'question',
      timestamp: DateTime(2026, 8, 23, 12),
    );
    final hidden = ServerChatEntry(
      const StatusMessage(status: ProcessStatus.running),
      timestamp: DateTime(2026, 8, 23, 12, 1),
    );
    final nextVisible = UserChatEntry(
      'follow-up',
      timestamp: DateTime(2026, 8, 23, 12, 3),
    );

    final sequence = deriveVisibleChatSequence([
      firstVisible,
      hidden,
      nextVisible,
    ]);

    expect(sequence.previousEntries[1], same(firstVisible));
    expect(sequence.previousEntries[2], same(firstVisible));
    expect(sequence.lastVisibleEntry, same(nextVisible));
  });

  test('timestamp grouping counts a replacement widget as visible', () {
    final entry = ServerChatEntry(
      const ToolResultMessage(toolUseId: 'image-tool', content: 'hidden'),
      timestamp: timestamp,
    );

    final sequence = deriveVisibleChatSequence(
      [entry],
      hiddenToolUseIds: const {'image-tool'},
      externallyVisibleIndices: const {0},
    );

    expect(sequence.lastVisibleEntry, same(entry));
  });
}
