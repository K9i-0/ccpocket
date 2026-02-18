import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Rewind mode for the action sheet.
enum RewindMode {
  both('both', 'Restore conversation & code', Icons.restore),
  conversation(
    'conversation',
    'Restore conversation only',
    Icons.chat_bubble_outline,
  ),
  code('code', 'Restore code only', Icons.code);

  final String value;
  final String label;
  final IconData icon;
  const RewindMode(this.value, this.label, this.icon);
}

/// Bottom sheet that shows rewind options for a selected user message.
///
/// Shows a dry-run preview (file change count, insertions/deletions)
/// and lets the user choose a rewind mode.
class RewindActionSheet extends StatelessWidget {
  final UserChatEntry userMessage;
  final RewindPreviewMessage? preview;
  final bool isLoadingPreview;
  final void Function(RewindMode mode) onRewind;

  const RewindActionSheet({
    super.key,
    required this.userMessage,
    this.preview,
    this.isLoadingPreview = false,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(Icons.history, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Rewind',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Selected message preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                userMessage.text.length > 120
                    ? '${userMessage.text.substring(0, 120)}...'
                    : userMessage.text,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: appColors.subtleText),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),

            // Dry-run preview
            if (isLoadingPreview)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (preview != null) ...[
              _RewindPreviewInfo(preview: preview!),
              const SizedBox(height: 12),
            ],

            // Rewind options
            ...RewindMode.values.map(
              (mode) => _RewindOptionTile(
                mode: mode,
                preview: preview,
                onSelected: () => _showConfirmation(context, mode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmation(BuildContext context, RewindMode mode) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Rewind'),
        content: Text(
          'This will ${mode.label.toLowerCase()}. This action cannot be undone.\n\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rewind'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        onRewind(mode);
      }
    });
  }
}

class _RewindPreviewInfo extends StatelessWidget {
  final RewindPreviewMessage preview;

  const _RewindPreviewInfo({required this.preview});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!preview.canRewind) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 16, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preview.error ?? 'Cannot rewind files',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      );
    }

    final fileCount = preview.filesChanged?.length ?? 0;
    final insertions = preview.insertions ?? 0;
    final deletions = preview.deletions ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            '$fileCount file${fileCount == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (insertions > 0 || deletions > 0) ...[
            const SizedBox(width: 12),
            Text(
              '+$insertions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '-$deletions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewindOptionTile extends StatelessWidget {
  final RewindMode mode;
  final RewindPreviewMessage? preview;
  final VoidCallback onSelected;

  const _RewindOptionTile({
    required this.mode,
    this.preview,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Disable code-related options if preview says cannot rewind
    final codeDisabled =
        (mode == RewindMode.code || mode == RewindMode.both) &&
        preview != null &&
        !preview!.canRewind;

    return Padding(
      key: ValueKey('rewind_mode_${mode.value}'),
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          mode.icon,
          size: 20,
          color: codeDisabled
              ? colorScheme.outline.withValues(alpha: 0.5)
              : colorScheme.primary,
        ),
        title: Text(
          mode.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: codeDisabled
                ? colorScheme.outline.withValues(alpha: 0.5)
                : null,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: codeDisabled ? null : onSelected,
      ),
    );
  }
}
