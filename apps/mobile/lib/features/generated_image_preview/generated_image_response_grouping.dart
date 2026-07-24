import '../../models/messages.dart';

class GeneratedImageResponseGroup {
  final int anchorEntryIndex;
  final Set<int> memberEntryIndices;
  final List<ToolResultMessage> messages;

  const GeneratedImageResponseGroup({
    required this.anchorEntryIndex,
    required this.memberEntryIndices,
    required this.messages,
  });

  Set<String> get toolUseIds => {
    for (final message in messages) message.toolUseId,
  };
}

/// Groups completed image-generation results inside one user response turn.
///
/// A result boundary or the next user message closes the group. The final
/// image result becomes the anchor where the combined gallery is rendered.
List<GeneratedImageResponseGroup> groupGeneratedImageResponses(
  List<ChatEntry> entries,
) {
  final groups = <GeneratedImageResponseGroup>[];
  final pendingIndices = <int>[];
  final pendingMessages = <ToolResultMessage>[];

  void flush() {
    if (pendingIndices.isEmpty) return;
    groups.add(
      GeneratedImageResponseGroup(
        anchorEntryIndex: pendingIndices.last,
        memberEntryIndices: Set.unmodifiable(pendingIndices),
        messages: List.unmodifiable(pendingMessages),
      ),
    );
    pendingIndices.clear();
    pendingMessages.clear();
  }

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final isResultBoundary =
        entry is ServerChatEntry && entry.message is ResultMessage;
    if (entry is UserChatEntry || isResultBoundary) {
      flush();
    }

    if (entry case ServerChatEntry(
      message: final ToolResultMessage message,
    ) when message.toolName == 'ImageGeneration' && message.images.isNotEmpty) {
      pendingIndices.add(index);
      pendingMessages.add(message);
    }
  }
  flush();
  return groups;
}

/// Tool results are terminal even when generation fails or returns no image.
/// Their matching in-progress rows must no longer remain in the chat.
Set<String> completedGeneratedImageToolUseIds(List<ChatEntry> entries) {
  return {
    for (final entry in entries)
      if (entry case ServerChatEntry(
        message: final ToolResultMessage message,
      ) when message.toolName == 'ImageGeneration')
        message.toolUseId,
  };
}
