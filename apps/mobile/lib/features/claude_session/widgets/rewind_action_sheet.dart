import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Rewind mode for the action sheet.
enum RewindMode {
  both('both', Icons.restore),
  conversation('conversation', Icons.chat_bubble_outline),
  code('code', Icons.code);

  final String value;
  final IconData icon;
  const RewindMode(this.value, this.icon);

  String label(AppLocalizations l) => switch (this) {
    RewindMode.both => l.rewindModeConversationAndCode,
    RewindMode.conversation => l.rewindModeConversationOnly,
    RewindMode.code => l.rewindModeCodeOnly,
  };
}

/// Bottom sheet that shows rewind options for a selected user message.
///
/// Shows a dry-run preview (file change count, insertions/deletions)
/// and lets the user choose a rewind mode.
class RewindActionSheet extends StatelessWidget {
  final UserChatEntry userMessage;
  final RewindPreviewMessage? preview;
  final bool isLoadingPreview;
  final List<RewindMode> availableModes;
  final bool showPreview;
  final void Function(RewindMode mode) onRewind;

  const RewindActionSheet({
    super.key,
    required this.userMessage,
    this.preview,
    this.isLoadingPreview = false,
    this.availableModes = const [
      RewindMode.both,
      RewindMode.conversation,
      RewindMode.code,
    ],
    this.showPreview = true,
    required this.onRewind,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

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
                  l.rewind,
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
            if (showPreview && isLoadingPreview)
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
            else if (showPreview && preview != null) ...[
              _RewindPreviewInfo(preview: preview!),
              const SizedBox(height: 12),
            ],

            // Rewind options
            ...availableModes.map(
              (mode) => _RewindOptionTile(
                mode: mode,
                preview: preview,
                label: mode.label(l),
                onSelected: () => _showConfirmation(context, mode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmation(BuildContext context, RewindMode mode) {
    final l = AppLocalizations.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.rewindConfirmTitle),
        content: Text(l.rewindConfirmBody(mode.label(l))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.rewind),
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
    final l = AppLocalizations.of(context);

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
                preview.error ?? l.rewindCannotRewindFiles,
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
            l.fileCount(fileCount),
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
  final String label;
  final VoidCallback onSelected;

  const _RewindOptionTile({
    required this.mode,
    this.preview,
    required this.label,
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
          label,
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
