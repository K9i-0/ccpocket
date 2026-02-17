import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet that lists all rewindable user messages as a message history.
///
/// Provides two actions per message:
/// - Tap message → [onScrollToMessage] (scroll chat to that position)
/// - Tap rewind icon → [onRewindMessage] (open rewind action sheet)
class UserMessageHistorySheet extends StatelessWidget {
  final List<UserChatEntry> messages;
  final void Function(UserChatEntry message) onScrollToMessage;
  final void Function(UserChatEntry message) onRewindMessage;

  const UserMessageHistorySheet({
    super.key,
    required this.messages,
    required this.onScrollToMessage,
    required this.onRewindMessage,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.history, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Message History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${messages.length} message${messages.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: appColors.subtleText,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Message list
            if (messages.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: appColors.subtleText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: appColors.subtleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Messages will appear here after Claude processes them',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: appColors.subtleText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 56),
                  itemBuilder: (context, index) {
                    // Show newest first
                    final msg = messages[messages.length - 1 - index];
                    return _MessageTile(
                      message: msg,
                      index: messages.length - index,
                      onTap: () {
                        Navigator.of(context).pop();
                        onScrollToMessage(msg);
                      },
                      onRewind: () {
                        Navigator.of(context).pop();
                        onRewindMessage(msg);
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  final UserChatEntry message;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onRewind;

  const _MessageTile({
    required this.message,
    required this.index,
    required this.onTap,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final timeStr = _formatTime(message.timestamp);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.surfaceContainerHigh,
        child: Text(
          '#$index',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: appColors.subtleText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        message.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Text(
        timeStr,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: appColors.subtleText),
      ),
      trailing: IconButton(
        icon: Icon(Icons.history, size: 18, color: colorScheme.primary),
        tooltip: 'Rewind to here',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: onRewind,
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
