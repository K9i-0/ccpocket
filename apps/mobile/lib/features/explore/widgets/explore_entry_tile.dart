import 'package:flutter/material.dart';

import '../state/explore_state.dart';

class ExploreEntryTile extends StatelessWidget {
  final ExploreEntry entry;
  final VoidCallback onTap;

  const ExploreEntryTile({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('explore_entry_${entry.relativePath}'),
      dense: true,
      leading: Icon(
        entry.isDirectory ? Icons.folder_outlined : Icons.description_outlined,
        size: 20,
      ),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.isDirectory
          ? null
          : Text(
              entry.relativePath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
      trailing: entry.isDirectory
          ? const Icon(Icons.chevron_right, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
