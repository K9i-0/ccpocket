import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/horizontal_chip_bar.dart';

class ProjectFilterChips extends StatelessWidget {
  final Set<String> accumulatedProjectPaths;
  final List<RecentSession> recentSessions;
  final String? currentFilterPath;
  final ValueChanged<String?> onSelected;

  const ProjectFilterChips({
    super.key,
    required this.accumulatedProjectPaths,
    required this.recentSessions,
    required this.currentFilterPath,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Count sessions from loaded data
    final loadedCounts = <String, int>{};
    for (final s in recentSessions) {
      loadedCounts[s.projectName] = (loadedCounts[s.projectName] ?? 0) + 1;
    }

    // Collect unique project entries from accumulated paths
    final chipEntries = <({String path, String name})>[];
    final seenNames = <String>{};
    for (final path in accumulatedProjectPaths) {
      final name = path.split('/').last;
      if (name.isNotEmpty && seenNames.add(name)) {
        chipEntries.add((path: path, name: name));
      }
    }

    return HorizontalChipBar(
      height: 36,
      fontSize: 12,
      showFade: true,
      selectedColor: cs.primary,
      selectedTextColor: cs.onPrimary,
      unselectedTextColor: appColors.subtleText,
      items: [
        ChipItem(
          label: 'All (${recentSessions.length})',
          isSelected: currentFilterPath == null,
          onSelected: () => onSelected(null),
        ),
        for (final entry in chipEntries)
          ChipItem(
            label: loadedCounts.containsKey(entry.name)
                ? '${entry.name} (${loadedCounts[entry.name]})'
                : entry.name,
            isSelected: currentFilterPath == entry.path,
            onSelected: () => onSelected(entry.path),
          ),
      ],
    );
  }
}
