import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet that lists all rewindable user messages.
///
/// Tapping a message calls [onMessageSelected] with the selected entry.
class RewindMessageListSheet extends StatelessWidget {
  final List<UserChatEntry> messages;
  final void Function(UserChatEntry message) onMessageSelected;

  const RewindMessageListSheet({
    super.key,
    required this.messages,
    required this.onMessageSelected,
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
                    'Rewind to message',
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
                        'No rewindable messages',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: appColors.subtleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Messages become rewindable after Claude processes them',
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
                        onMessageSelected(msg);
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

  const _MessageTile({
    required this.message,
    required this.index,
    required this.onTap,
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
      trailing: Text(
        timeStr,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: appColors.subtleText),
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
