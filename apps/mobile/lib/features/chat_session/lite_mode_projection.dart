import '../../models/messages.dart';

/// A presentation-only projection. The original transcript stays available for
/// switching modes, permissions, plan extraction, and resuming the agent.
List<ChatEntry> liteModeEntries(List<ChatEntry> entries) {
  final visible = <ChatEntry>[];
  for (final entry in entries) {
    if (entry case ServerChatEntry(:final message)) {
      switch (message) {
        case ToolResultMessage():
          if (message.toolName == 'ImageGeneration' ||
              message.permissionOutcome != null) {
            visible.add(entry);
          }
          continue;
        case ToolUseSummaryMessage():
          continue;
        case AssistantServerMessage(:final message, :final messageUuid):
          final content = message.content
              .where(
                (part) => switch (part) {
                  TextContent(:final text) => text.trim().isNotEmpty,
                  ToolUseContent(:final name) =>
                    name == 'ExitPlanMode' || name == 'AskUserQuestion',
                  ThinkingContent() => false,
                },
              )
              .toList();
          if (content.length == message.content.length) {
            visible.add(entry);
          } else if (content.isNotEmpty) {
            visible.add(
              ServerChatEntry(
                AssistantServerMessage(
                  messageUuid: messageUuid,
                  message: AssistantMessage(
                    id: message.id,
                    role: message.role,
                    model: message.model,
                    content: content,
                  ),
                ),
                timestamp: entry.timestamp,
              ),
            );
          }
          continue;
        default:
          break;
      }
    }
    visible.add(entry);
  }
  return visible;
}
