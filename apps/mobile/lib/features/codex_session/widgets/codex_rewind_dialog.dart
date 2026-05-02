import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class CodexRewindDialog extends StatelessWidget {
  const CodexRewindDialog({
    super.key,
    required this.messageText,
    required this.onConfirm,
  });

  final String messageText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final trimmed = messageText.trim();

    return AlertDialog(
      title: Text(l.codexRewindConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.codexRewindConfirmBody, style: theme.textTheme.bodyMedium),
          if (trimmed.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              key: const ValueKey('codex_rewind_message_preview'),
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: Text(
                  trimmed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('codex_rewind_cancel_button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('codex_rewind_confirm_button'),
          onPressed: onConfirm,
          child: Text(l.rewind),
        ),
      ],
    );
  }
}
