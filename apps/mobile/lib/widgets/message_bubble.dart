import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../theme/app_theme.dart';
import 'bubbles/assistant_bubble.dart';
import 'bubbles/error_bubble.dart';
import 'bubbles/permission_request_bubble.dart';
import 'bubbles/result_chip.dart';
import 'bubbles/status_chip.dart';
import 'bubbles/streaming_bubble.dart';
import 'bubbles/system_chip.dart';
import 'bubbles/tool_result_bubble.dart';
import 'bubbles/tool_use_summary_bubble.dart';
import 'bubbles/user_bubble.dart';

export 'bubbles/ask_user_question_widget.dart';

class ChatEntryWidget extends StatelessWidget {
  final ChatEntry entry;
  final ChatEntry? previous;
  final String? httpBaseUrl;
  final void Function(UserChatEntry)? onRetryMessage;
  final ValueNotifier<int>? collapseToolResults;
  final ValueNotifier<String?>? editedPlanText;
  final String? resolvedPlanText;

  /// Tool use IDs that should be hidden (replaced by a tool_use_summary).
  final Set<String> hiddenToolUseIds;

  const ChatEntryWidget({
    super.key,
    required this.entry,
    this.previous,
    this.httpBaseUrl,
    this.onRetryMessage,
    this.collapseToolResults,
    this.editedPlanText,
    this.resolvedPlanText,
    this.hiddenToolUseIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_shouldShowTimestamp())
          _TimestampWidget(timestamp: entry.timestamp),
        switch (entry) {
          ServerChatEntry(:final message) => ServerMessageWidget(
            message: message,
            httpBaseUrl: httpBaseUrl,
            collapseToolResults: collapseToolResults,
            editedPlanText: editedPlanText,
            resolvedPlanText: resolvedPlanText,
            hiddenToolUseIds: hiddenToolUseIds,
          ),
          final UserChatEntry user => UserBubble(
            text: user.text,
            status: user.status,
            onRetry: onRetryMessage != null
                ? () => onRetryMessage!(user)
                : null,
          ),
          StreamingChatEntry(:final text) => StreamingBubble(text: text),
        },
      ],
    );
  }

  bool _shouldShowTimestamp() {
    if (previous == null) return true;
    // Show if sender type changed
    if (entry.runtimeType != previous.runtimeType) return true;
    // Show if more than 2 minutes apart
    final diff = entry.timestamp.difference(previous!.timestamp);
    return diff.inMinutes >= 2;
  }
}

class _TimestampWidget extends StatelessWidget {
  final DateTime timestamp;
  const _TimestampWidget({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: appColors.subtleText.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            time,
            style: TextStyle(fontSize: 10, color: appColors.subtleText),
          ),
        ),
      ),
    );
  }
}

class ServerMessageWidget extends StatelessWidget {
  final ServerMessage message;
  final String? httpBaseUrl;
  final ValueNotifier<int>? collapseToolResults;
  final ValueNotifier<String?>? editedPlanText;
  final String? resolvedPlanText;

  /// Tool use IDs that should be hidden (replaced by a tool_use_summary).
  final Set<String> hiddenToolUseIds;

  const ServerMessageWidget({
    super.key,
    required this.message,
    this.httpBaseUrl,
    this.collapseToolResults,
    this.editedPlanText,
    this.resolvedPlanText,
    this.hiddenToolUseIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return switch (message) {
      final SystemMessage msg => SystemChip(message: msg),
      final AssistantServerMessage msg => AssistantBubble(
        message: msg,
        editedPlanText: editedPlanText,
        resolvedPlanText: resolvedPlanText,
      ),
      // Hide tool results that are summarized by a tool_use_summary
      final ToolResultMessage msg =>
        hiddenToolUseIds.contains(msg.toolUseId)
            ? const SizedBox.shrink()
            : ToolResultBubble(
                message: msg,
                httpBaseUrl: httpBaseUrl,
                collapseNotifier: collapseToolResults,
              ),
      final ResultMessage msg => ResultChip(message: msg),
      final ErrorMessage msg => ErrorBubble(message: msg),
      final StatusMessage msg => StatusChip(message: msg),
      HistoryMessage() => const SizedBox.shrink(),
      final PermissionRequestMessage msg =>
        msg.toolName == 'ExitPlanMode'
            ? const SizedBox.shrink()
            : PermissionRequestBubble(message: msg),
      StreamDeltaMessage() => const SizedBox.shrink(),
      ThinkingDeltaMessage() => const SizedBox.shrink(),
      RecentSessionsMessage() => const SizedBox.shrink(),
      PastHistoryMessage() => const SizedBox.shrink(),
      SessionListMessage() => const SizedBox.shrink(),
      GalleryListMessage() => const SizedBox.shrink(),
      GalleryNewImageMessage() => const SizedBox.shrink(),
      FileListMessage() => const SizedBox.shrink(),
      ProjectHistoryMessage() => const SizedBox.shrink(),
      DiffResultMessage() => const SizedBox.shrink(),
      WorktreeListMessage() => const SizedBox.shrink(),
      WorktreeRemovedMessage() => const SizedBox.shrink(),
      final ToolUseSummaryMessage msg => ToolUseSummaryBubble(message: msg),
    };
  }
}
