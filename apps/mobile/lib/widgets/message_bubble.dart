import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_spacing.dart';
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
  final void Function(UserChatEntry)? onRewindMessage;
  final ValueNotifier<int>? collapseToolResults;
  final ValueNotifier<String?>? editedPlanText;
  final String? resolvedPlanText;
  final bool allowPlanEditing;
  final String? pendingPlanToolUseId;

  /// Tool use IDs that should be hidden (replaced by a tool_use_summary).
  final Set<String> hiddenToolUseIds;

  /// Called when the user taps the image attachment indicator.
  final void Function(UserChatEntry)? onImageTap;

  const ChatEntryWidget({
    super.key,
    required this.entry,
    this.previous,
    this.httpBaseUrl,
    this.onRetryMessage,
    this.onRewindMessage,
    this.collapseToolResults,
    this.editedPlanText,
    this.resolvedPlanText,
    this.allowPlanEditing = true,
    this.pendingPlanToolUseId,
    this.hiddenToolUseIds = const {},
    this.onImageTap,
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
            allowPlanEditing: allowPlanEditing,
            pendingPlanToolUseId: pendingPlanToolUseId,
            hiddenToolUseIds: hiddenToolUseIds,
          ),
          final UserChatEntry user => UserBubble(
            text: user.text,
            status: user.status,
            onRetry: onRetryMessage != null
                ? () => onRetryMessage!(user)
                : null,
            onRewind: onRewindMessage != null && user.messageUuid != null
                ? () => onRewindMessage!(user)
                : null,
            imageUrls: user.imageUrls,
            httpBaseUrl: httpBaseUrl,
            imageBytesList: user.imageBytesList,
            imageCount: user.imageCount,
          ),
          StreamingChatEntry(:final text) => StreamingBubble(text: text),
        },
        // Image attachment tap button — placed below the bubble to avoid
        // gesture conflicts with the bubble's GestureDetector.
        if (entry case final UserChatEntry user
            when user.imageCount > 0 &&
                user.imageUrls.isEmpty &&
                user.imageBytesList.isEmpty &&
                onImageTap != null &&
                user.messageUuid != null)
          _ImageAttachmentButton(
            imageCount: user.imageCount,
            onTap: () => onImageTap!(user),
          ),
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
  final bool allowPlanEditing;
  final String? pendingPlanToolUseId;

  /// Tool use IDs that should be hidden (replaced by a tool_use_summary).
  final Set<String> hiddenToolUseIds;

  const ServerMessageWidget({
    super.key,
    required this.message,
    this.httpBaseUrl,
    this.collapseToolResults,
    this.editedPlanText,
    this.resolvedPlanText,
    this.allowPlanEditing = true,
    this.pendingPlanToolUseId,
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
        allowPlanEditing: allowPlanEditing,
        pendingPlanToolUseId: pendingPlanToolUseId,
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
        msg.toolName == 'ExitPlanMode' || msg.toolName == 'AskUserQuestion'
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
      WindowListMessage() => const SizedBox.shrink(),
      ScreenshotResultMessage() => const SizedBox.shrink(),
      DebugBundleMessage() => const SizedBox.shrink(),
      final ToolUseSummaryMessage msg => ToolUseSummaryBubble(message: msg),
      RewindPreviewMessage() => const SizedBox.shrink(),
      RewindResultMessage() => const SizedBox.shrink(),
      UserInputMessage() => const SizedBox.shrink(),
      InputAckMessage() => const SizedBox.shrink(),
      InputRejectedMessage() => const SizedBox.shrink(),
      UsageResultMessage() => const SizedBox.shrink(),
      RecordingListMessage() => const SizedBox.shrink(),
      RecordingContentMessage() => const SizedBox.shrink(),
      MessageImagesResultMessage() => const SizedBox.shrink(),
      PromptHistoryBackupResultMessage() => const SizedBox.shrink(),
      PromptHistoryRestoreResultMessage() => const SizedBox.shrink(),
      PromptHistoryBackupInfoMessage() => const SizedBox.shrink(),
    };
  }
}

/// Standalone tappable button shown below a user bubble when the message
/// has image attachments that can be loaded from JSONL.
class _ImageAttachmentButton extends StatelessWidget {
  final int imageCount;
  final VoidCallback onTap;

  const _ImageAttachmentButton({required this.imageCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(
          right: AppSpacing.bubbleMarginH,
          bottom: 4,
        ),
        child: Material(
          color: appColors.subtleText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: appColors.subtleText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    imageCount > 1
                        ? '${AppLocalizations.of(context).imageAttached} x$imageCount'
                        : AppLocalizations.of(context).imageAttached,
                    style: TextStyle(fontSize: 12, color: appColors.subtleText),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: appColors.subtleText,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
