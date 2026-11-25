import '../../models/chat_display_filter.dart';
import '../../models/messages.dart';

const _taskToolNames = {'TodoWrite', 'UpdatePlan', 'TaskCreate', 'TaskUpdate'};

const _subagentToolNames = {'Task', 'Agent', 'SubAgent', 'invoke_subagent'};

const _codeEditToolNames = {
  'Edit',
  'Write',
  'MultiEdit',
  'NotebookEdit',
  'FileChange',
  'FileEdit',
  'apply_patch',
};

bool _isSwarmConversation(String name, Map<String, dynamic> input) =>
    name == 'SwarmPost' || (name == 'swarm' && input['action'] == 'add');

bool _shouldKeepToolUse(
  String name,
  Map<String, dynamic> input,
  ChatDisplayFilter filter,
) {
  if (name == 'ExitPlanMode' || name == 'ImageGeneration') return true;
  // AskUserQuestion is rendered via the dedicated approval/answer transcript
  // entry rather than as a raw tool_use tile when filtering is active.
  if (name == 'AskUserQuestion') return false;
  if (_isSwarmConversation(name, input)) return filter.subagents;
  if (_taskToolNames.contains(name)) return filter.tasks;
  if (_subagentToolNames.contains(name)) return filter.subagents;
  if (_codeEditToolNames.contains(name)) return filter.codeEdits;
  return filter.otherTools;
}

/// A presentation-only projection. The original transcript stays available for
/// switching modes, permissions, plan extraction, and resuming the agent.
List<ChatEntry> liteModeEntries(
  List<ChatEntry> entries, {
  ChatDisplayFilter filter = ChatDisplayFilter.recommended,
}) {
  if (!filter.isFiltered) return entries;

  final visible = <ChatEntry>[];
  for (final entry in entries) {
    if (entry case ServerChatEntry(:final message)) {
      switch (message) {
        case ToolResultMessage():
          if (filter.toolResults ||
              message.toolName == 'ImageGeneration' ||
              message.permissionOutcome != null) {
            visible.add(entry);
          }
          continue;
        case ToolUseSummaryMessage():
          if (filter.subagents) {
            visible.add(entry);
          }
          continue;
        case AssistantServerMessage(
          :final message,
          :final messageUuid,
          :final images,
        ):
          final content = message.content
              .where(
                (part) => switch (part) {
                  TextContent(:final text) => text.trim().isNotEmpty,
                  ThinkingContent(:final thinking) =>
                    filter.thinking && thinking.trim().isNotEmpty,
                  ToolUseContent(:final name, :final input) =>
                    _shouldKeepToolUse(name, input, filter),
                },
              )
              .toList();
          if (content.length == message.content.length &&
              (content.isNotEmpty || images.isNotEmpty)) {
            visible.add(entry);
          } else if (content.isNotEmpty || images.isNotEmpty) {
            visible.add(
              ServerChatEntry(
                AssistantServerMessage(
                  messageUuid: messageUuid,
                  images: images,
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
