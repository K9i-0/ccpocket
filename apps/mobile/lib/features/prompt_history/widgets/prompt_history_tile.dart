import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/prompt_history_service.dart';
import '../../../utils/command_parser.dart';

/// A single row in the prompt history list.
///
/// Shows the prompt text, use count badge, a favorite star toggle, and supports
/// swipe-to-delete.
class PromptHistoryTile extends StatelessWidget {
  final PromptHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const PromptHistoryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey('prompt_history_dismiss_${entry.id}'),
      endActionPane: entry.isFavorite
          ? null
          : ActionPane(
              motion: const BehindMotion(),
              extentRatio: 0.18,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => onDelete(),
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
      child: ListTile(
        key: ValueKey('prompt_history_item_${entry.id}'),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        title: Tooltip(
          message: entry.text,
          waitDuration: const Duration(milliseconds: 600),
          child: Text(
            formatCommandText(entry.text),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.useCount > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'x${entry.useCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            _PromptHistoryCopyButton(
              key: ValueKey('prompt_history_copy_${entry.id}'),
              textToCopy: entry.text,
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleFavorite();
              },
              child: Icon(
                entry.isFavorite ? Icons.star : Icons.star_border,
                size: 20,
                color: entry.isFavorite ? Colors.amber : cs.outline,
              ),
            ),
          ],
        ),
        dense: true,
      ),
    );
  }
}

class _PromptHistoryCopyButton extends StatefulWidget {
  const _PromptHistoryCopyButton({super.key, required this.textToCopy});

  final String textToCopy;

  @override
  State<_PromptHistoryCopyButton> createState() =>
      _PromptHistoryCopyButtonState();
}

class _PromptHistoryCopyButtonState extends State<_PromptHistoryCopyButton> {
  Timer? _resetTimer;
  var _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    HapticFeedback.selectionClick();
    unawaited(Clipboard.setData(ClipboardData(text: widget.textToCopy)));
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: _copied ? (l?.copied ?? 'Copied') : (l?.copy ?? 'Copy'),
      onPressed: _copy,
      icon: Icon(_copied ? Icons.check : Icons.copy_outlined, size: 16),
      color: _copied ? cs.primary : cs.outline,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      visualDensity: VisualDensity.compact,
    );
  }
}
