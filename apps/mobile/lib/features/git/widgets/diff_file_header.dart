import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';
import '../../../widgets/adaptive_context_menu.dart';
import 'diff_file_path_text.dart';

/// Whether a file is staged, unstaged, or unknown.
enum FileStageStatus { staged, unstaged, unknown }

class DiffFileHeader extends StatelessWidget {
  final DiffFile file;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final FileStageStatus stageStatus;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset?>? onShowActions;

  const DiffFileHeader({
    super.key,
    required this.file,
    required this.collapsed,
    required this.onToggleCollapse,
    this.stageStatus = FileStageStatus.unknown,
    this.onLongPress,
    this.onShowActions,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final stats = file.stats;
    final header = GestureDetector(
      key: ValueKey('diff_file_header_${file.filePath}'),
      onTap: onToggleCollapse,
      onLongPress: this.onShowActions == null ? onLongPress : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: appColors.codeBackground,
          border: Border(bottom: BorderSide(color: appColors.codeBorder)),
        ),
        child: Row(
          children: [
            _buildLeadingIcon(appColors),
            const SizedBox(width: 8),
            Expanded(
              child: DiffFilePathText(
                filePath: file.filePath,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: appColors.toolResultTextExpanded,
                ),
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
    final onShowActions = this.onShowActions;
    if (onShowActions == null) return header;
    return AdaptiveContextMenuRegion(onOpen: onShowActions, child: header);
  }

  Widget _buildLeadingIcon(AppColors appColors) {
    // Stage status badge takes priority
    if (stageStatus == FileStageStatus.staged) {
      return Icon(
        Icons.check_circle,
        size: 16,
        color: appColors.diffAdditionText,
      );
    }

    // Default: file type icon
    return Icon(
      file.isNewFile
          ? Icons.add_circle_outline
          : file.isDeleted
          ? Icons.remove_circle_outline
          : Icons.edit_note,
      size: 16,
      color: appColors.subtleText,
    );
  }
}
