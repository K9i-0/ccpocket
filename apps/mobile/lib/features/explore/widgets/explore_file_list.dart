import 'package:flutter/material.dart';

import '../state/explore_state.dart';
import 'explore_entry_tile.dart';

class ExploreFileList extends StatelessWidget {
  final List<ExploreEntry> entries;
  final ValueChanged<ExploreEntry> onTapEntry;
  final String? highlightedFilePath;
  final Key? highlightedEntryKey;

  const ExploreFileList({
    super.key,
    required this.entries,
    required this.onTapEntry,
    this.highlightedFilePath,
    this.highlightedEntryKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('explore_list'),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isHighlighted = entry.relativePath == highlightedFilePath;
        return ExploreEntryTile(
          key: isHighlighted ? highlightedEntryKey : null,
          entry: entry,
          onTap: () => onTapEntry(entry),
          isHighlighted: isHighlighted,
        );
      },
    );
  }
}
