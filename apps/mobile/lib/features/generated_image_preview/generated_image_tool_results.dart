import '../../models/messages.dart';

/// Tool results are terminal even when generation fails or returns no image.
/// Their matching in-progress rows must no longer remain in the chat.
Set<String> completedGeneratedImageToolUseIds(List<ChatEntry> entries) {
  return {
    for (final entry in entries)
      if (entry case ServerChatEntry(message: final ToolResultMessage message)
          when message.toolName == 'ImageGeneration')
        message.toolUseId,
  };
}
