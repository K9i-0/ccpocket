import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
        title: Text(
          formatCommandText(entry.text),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
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
