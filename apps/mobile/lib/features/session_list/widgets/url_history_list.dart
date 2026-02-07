import 'package:flutter/material.dart';

import '../../../services/url_history_service.dart';

class UrlHistoryList extends StatelessWidget {
  final List<UrlHistoryEntry> entries;
  final ValueChanged<UrlHistoryEntry> onSelect;
  final ValueChanged<String> onRemove;
  final void Function(String url, String? name)? onUpdateName;

  const UrlHistoryList({
    super.key,
    required this.entries,
    required this.onSelect,
    required this.onRemove,
    this.onUpdateName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Recent Connections',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in entries)
          Dismissible(
            key: ValueKey(entry.url),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
            onDismissed: (_) => onRemove(entry.url),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.link,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  entry.displayName,
                  style: TextStyle(
                    fontFamily: entry.name?.isNotEmpty == true
                        ? null
                        : 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.name?.isNotEmpty == true)
                      Text(
                        entry.url,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (entry.apiKey.isNotEmpty)
                      Text(
                        'With API Key',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
                onTap: () => onSelect(entry),
                onLongPress: onUpdateName != null
                    ? () => _showEditNameDialog(context, entry)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    UrlHistoryEntry entry,
  ) async {
    final controller = TextEditingController(text: entry.name ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.url,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Home Mac, Work Server',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (entry.name?.isNotEmpty == true)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text(
                'Clear',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      onUpdateName?.call(entry.url, result.isEmpty ? null : result);
    }
  }
}
