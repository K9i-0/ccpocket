import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';

class DiffFileHeader extends StatelessWidget {
  final DiffFile file;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  const DiffFileHeader({
    super.key,
    required this.file,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final stats = file.stats;
    return GestureDetector(
      onTap: onToggleCollapse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: appColors.codeBackground,
          border: Border(bottom: BorderSide(color: appColors.codeBorder)),
        ),
        child: Row(
          children: [
            Icon(
              file.isNewFile
                  ? Icons.add_circle_outline
                  : file.isDeleted
                      ? Icons.remove_circle_outline
                      : Icons.edit_note,
              size: 16,
              color: appColors.subtleText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.filePath,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: appColors.toolResultTextExpanded,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (stats.added > 0)
              Text(
                '+${stats.added}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appColors.diffAdditionText,
                ),
              ),
            if (stats.added > 0 && stats.removed > 0) const SizedBox(width: 6),
            if (stats.removed > 0)
              Text(
                '-${stats.removed}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appColors.diffDeletionText,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 20,
              color: appColors.subtleText,
            ),
          ],
        ),
      ),
    );
  }
}
