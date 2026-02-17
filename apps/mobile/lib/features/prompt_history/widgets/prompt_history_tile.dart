import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/prompt_history_service.dart';
import '../../../utils/command_parser.dart';

/// A single row in the prompt history list.
///
/// Shows the prompt text, use count badge, project name badge (when showing
/// all projects), a favorite star toggle, and supports swipe-to-delete.
class PromptHistoryTile extends StatelessWidget {
  final PromptHistoryEntry entry;
  final bool showProjectBadge;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  const PromptHistoryTile({
    super.key,
    required this.entry,
    required this.showProjectBadge,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('prompt_history_dismiss_${entry.id}'),
      direction: entry.isFavorite
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: cs.error,
        child: Icon(Icons.delete, color: cs.onError),
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
        subtitle: _buildSubtitle(cs),
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

  Widget? _buildSubtitle(ColorScheme cs) {
    if (!showProjectBadge || entry.projectPath.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.projectName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
