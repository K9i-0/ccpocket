import '../../../models/messages.dart';
import '../permission_transcript.dart';
import 'chat_session_state.dart';

ApprovalState approvalStateForPermission(PermissionRequestMessage request) {
  if (request.usesAskUserUi) {
    return ApprovalState.askUser(
      toolUseId: request.toolUseId,
      input: request.input,
    );
  }
  return ApprovalState.permission(
    toolUseId: request.toolUseId,
    request: request,
  );
}

SandboxMode? sandboxModeFromContext(String? raw) => switch (raw) {
  'on' || 'workspace-write' => SandboxMode.on,
  'off' || 'danger-full-access' => SandboxMode.off,
  _ => null,
};

bool isAnsweredToolResult(ChatEntry entry) => switch (entry) {
  ServerChatEntry(
    message: ToolResultMessage(permissionOutcome: PermissionOutcome.answered),
  ) =>
    true,
  _ => false,
};

UsageTotals calculateUsageTotals(List<ChatEntry> entries) {
  double totalCost = 0;
  double durationMs = 0;
  var hasDuration = false;

  for (final entry in entries) {
    if (entry is! ServerChatEntry) continue;
    final msg = entry.message;
    if (msg is! ResultMessage) continue;

    if (msg.cost != null) {
      totalCost += msg.cost!;
    }
    if (msg.duration != null && msg.duration! >= 0) {
      durationMs += msg.duration!;
      hasDuration = true;
    }
  }

  return UsageTotals(
    totalCost: totalCost,
    totalDuration: hasDuration
        ? Duration(milliseconds: durationMs.round())
        : null,
  );
}

Set<String> hiddenToolUseIdsFromEntries(List<ChatEntry> entries) {
  final hiddenIds = <String>{};
  for (final entry in entries) {
    if (entry case ServerChatEntry(
      message: ToolUseSummaryMessage(:final precedingToolUseIds),
    )) {
      hiddenIds.addAll(precedingToolUseIds);
    }
  }
  return hiddenIds;
}

AssistantMessage? assistantMessageFromEntry(ChatEntry entry) {
  if (entry case ServerChatEntry(
    message: AssistantServerMessage(:final message),
  )) {
    return message;
  }
  return null;
}

bool hasRenderableAssistantContent(AssistantMessage message) {
  return message.content.any(
    (content) => switch (content) {
      TextContent(:final text) => text.trim().isNotEmpty,
      ThinkingContent(:final thinking) => thinking.trim().isNotEmpty,
      ToolUseContent() => true,
    },
  );
}

int userEntryMatchIndex(
  List<ChatEntry> entries, {
  required String text,
  required int imageCount,
  required String? clientMessageId,
  required String? messageUuid,
}) {
  final candidates = <int>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry is! UserChatEntry) continue;

    final hasClientMessageIds =
        clientMessageId?.isNotEmpty == true &&
        entry.clientMessageId?.isNotEmpty == true;
    if (hasClientMessageIds) {
      if (clientMessageId == entry.clientMessageId) return i;
      continue;
    }

    final hasMessageUuids =
        messageUuid?.isNotEmpty == true &&
        entry.messageUuid?.isNotEmpty == true;
    if (hasMessageUuids && messageUuid == entry.messageUuid) {
      if (entry.status != MessageStatus.failed) return i;
      continue;
    }
    // Claude may acknowledge delivery before echoing the provider UUID.
    // Match that local entry once, but never collapse distinct known turns.
    final awaitingProviderUuid =
        entry.status == MessageStatus.sent &&
        entry.clientMessageId?.isNotEmpty == true &&
        entry.messageUuid?.isNotEmpty != true &&
        messageUuid?.isNotEmpty == true;
    if (clientMessageId?.isNotEmpty == true ||
        entry.status == MessageStatus.failed ||
        (entry.status != MessageStatus.sending &&
            entry.status != MessageStatus.queued &&
            !awaitingProviderUuid)) {
      continue;
    }
    if (entry.text != text || entry.imageCount != imageCount) continue;
    candidates.add(i);
  }
  return candidates.length == 1 ? candidates.single : -1;
}

bool canWeakMatchAppendedEntry(ChatEntry entry) {
  if (entry case ServerChatEntry(
    message: AssistantServerMessage(:final messageUuid),
  )) {
    return messageUuid?.isNotEmpty == true;
  }
  return entry is ServerChatEntry &&
      (entry.message is ResultMessage ||
          entry.message is GuardianApprovalMessage);
}

String? entryStableKey(ChatEntry entry) {
  if (entry is QuestionAnswerChatEntry) {
    return 'question-answer:${entry.toolUseId}';
  }
  if (entry is UserChatEntry) {
    final uuid = entry.messageUuid;
    if (uuid != null && uuid.isNotEmpty) return 'user:uuid:$uuid';
    final clientMessageId = entry.clientMessageId;
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      return 'user:client:$clientMessageId';
    }
    return null;
  }
  if (entry is ServerChatEntry) {
    return serverMessageStableKey(entry.message);
  }
  return null;
}

String? serverMessageStableKey(ServerMessage message) {
  switch (message) {
    case AssistantServerMessage(:final messageUuid, :final message):
      if (messageUuid != null && messageUuid.isNotEmpty) {
        return 'assistant:uuid:$messageUuid';
      }
      if (message.id.isNotEmpty) return 'assistant:id:${message.id}';
      return null;
    case final ToolResultMessage result
        when isSyntheticPermissionOutcome(result):
      return 'permission_outcome:${result.toolUseId}:${result.content.trim()}';
    case ToolResultMessage(:final toolUseId):
      return 'tool_result:$toolUseId';
    case PermissionRequestMessage(:final toolUseId):
      return 'permission_request:$toolUseId';
    case PermissionResolvedMessage(:final toolUseId):
      return 'permission_resolved:$toolUseId';
    default:
      return null;
  }
}

String assistantContentSignature(AssistantMessage message) {
  return message.content
      .map((content) {
        return switch (content) {
          TextContent(:final text) => 'text:$text',
          ThinkingContent(:final thinking) => 'thinking:$thinking',
          ToolUseContent(:final id, :final name) => 'tool_use:$id:$name',
        };
      })
      .join('\u0001');
}

bool shouldPreserveEntryAcrossHistoryReplace(ChatEntry entry) {
  if (entry is UserChatEntry || entry is QuestionAnswerChatEntry) {
    return true;
  }
  if (entry is ServerChatEntry) {
    return entry.message is! StatusMessage &&
        entry.message is! InputAckMessage &&
        entry.message is! InputRejectedMessage &&
        entry.message is! ConversationQueueMessage &&
        entry.message is! BackgroundTasksMessage &&
        entry.message is! AgentActivityMessage;
  }
  return false;
}

Map<String, Map<String, dynamic>> questionInputsByToolUseId(
  List<ChatEntry> entries,
) {
  final result = <String, Map<String, dynamic>>{};
  for (final entry in entries) {
    if (entry is! ServerChatEntry) continue;
    switch (entry.message) {
      case PermissionRequestMessage(
            :final toolUseId,
            :final toolName,
            :final input,
          )
          when toolName == 'AskUserQuestion':
        result[toolUseId] = input;
      case AssistantServerMessage(:final message):
        for (final content in message.content) {
          if (content case ToolUseContent(
            :final id,
            name: 'AskUserQuestion',
            :final input,
          )) {
            result[id] = input;
          }
        }
      default:
        break;
    }
  }
  return result;
}

String questionAnswerClientMessageId(String toolUseId) =>
    'question-answer:$toolUseId';

bool isPermissionModeFailure(ErrorMessage msg) {
  return msg.errorCode == 'set_permission_mode_rejected' ||
      msg.errorCode == 'auto_mode_unavailable' ||
      msg.message.startsWith('Failed to set permission mode:') ||
      msg.message.startsWith(
        'Failed to restart session for permission mode change:',
      );
}

bool isAntigravityModelFailure(ErrorMessage msg) {
  return msg.errorCode == 'set_antigravity_model_rejected' ||
      msg.errorCode == 'set_antigravity_model_unsupported';
  // A rejected `set_antigravity_settings` needs no rollback here: the
  // Bridge sends the session's real settings right after the error.
}

bool isSandboxModeFailure(ErrorMessage msg) {
  return msg.errorCode == 'set_sandbox_mode_rejected' ||
      msg.message.startsWith('Failed to set sandbox mode:') ||
      msg.message.startsWith(
        'Failed to restart session for sandbox mode change:',
      );
}

Set<String> normalizeProjectMentionPaths(Iterable<String> paths) {
  final normalized = <String>{};
  for (final path in paths) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) continue;
    normalized.add(trimmed);
  }
  return normalized;
}

String? resolveProjectMentionPath(String rawPath, Set<String> paths) {
  if (paths.contains(rawPath)) return rawPath;

  final stripped = rawPath.replaceFirst(RegExp(r'[,.;:!?]+$'), '');
  if (stripped != rawPath && paths.contains(stripped)) return stripped;

  if (!rawPath.endsWith('/') && paths.contains('$rawPath/')) {
    return '$rawPath/';
  }
  return null;
}

String resolveProjectMentionPayloadPath(
  String mentionPath,
  String? projectPath,
) {
  if (mentionPath.startsWith('/') || projectPath == null) {
    return mentionPath;
  }
  final root = projectPath.trim();
  if (root.isEmpty) return mentionPath;
  return root.endsWith('/') ? '$root$mentionPath' : '$root/$mentionPath';
}

class UsageTotals {
  final double totalCost;
  final Duration? totalDuration;

  const UsageTotals({required this.totalCost, required this.totalDuration});
}
