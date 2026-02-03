import 'package:flutter/material.dart';

import '../../../services/url_history_service.dart';

class UrlHistoryList extends StatelessWidget {
  final List<UrlHistoryEntry> entries;
  final ValueChanged<UrlHistoryEntry> onSelect;
  final ValueChanged<String> onRemove;

  const UrlHistoryList({
    super.key,
    required this.entries,
    required this.onSelect,
    required this.onRemove,
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
                  entry.url,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: entry.apiKey.isNotEmpty
                    ? Text(
                        'With API Key',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      )
                    : null,
                trailing: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
                onTap: () => onSelect(entry),
              ),
            ),
          ),
      ],
    );
  }
}
