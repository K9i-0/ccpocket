import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_toast.dart';

/// A shell command in monospace with a copy button.
class CopyableCommand extends StatelessWidget {
  const CopyableCommand({super.key, required this.command, this.label});

  final String command;

  /// Short tag such as "Homebrew" shown before the command.
  final String? label;

  Future<void> _copy(BuildContext context) async {
    final messenger = AppToast.maybeOf(context);
    final copied = AppLocalizations.of(context).copied;
    await Clipboard.setData(ClipboardData(text: command));
    messenger
      ?..hide()
      ..show(copied);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null && label!.isNotEmpty)
                  Text(
                    label!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                SelectableText(
                  command,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('copy_command_button:$command'),
            visualDensity: VisualDensity.compact,
            tooltip: AppLocalizations.of(context).copy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copy(context),
          ),
        ],
      ),
    );
  }
}
