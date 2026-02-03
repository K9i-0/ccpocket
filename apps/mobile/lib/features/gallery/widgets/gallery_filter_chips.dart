import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class GalleryFilterChips extends StatelessWidget {
  final Map<String, int> projectCounts;
  final int totalCount;
  final String? selectedProject;
  final ValueChanged<String?> onSelected;

  const GalleryFilterChips({
    super.key,
    required this.projectCounts,
    required this.totalCount,
    required this.selectedProject,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 36,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white,
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.85, 0.92, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('All ($totalCount)'),
                selected: selectedProject == null,
                onSelected: (_) => onSelected(null),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selectedProject == null
                      ? cs.onPrimary
                      : appColors.subtleText,
                ),
                selectedColor: cs.primary,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            for (final entry in projectCounts.entries)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(entry.key),
                  selected: selectedProject == entry.key,
                  onSelected: (_) => onSelected(entry.key),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: selectedProject == entry.key
                        ? cs.onPrimary
                        : appColors.subtleText,
                  ),
                  selectedColor: cs.primary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
