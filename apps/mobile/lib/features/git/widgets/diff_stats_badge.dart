import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';

class DiffStatsBadge extends StatelessWidget {
  final DiffFile file;

  const DiffStatsBadge({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final stats = file.stats;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stats.added > 0)
          Text(
            '+${stats.added}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.diffAdditionText,
            ),
          ),
        if (stats.added > 0 && stats.removed > 0) const SizedBox(width: 4),
        if (stats.removed > 0)
          Text(
            '-${stats.removed}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.diffDeletionText,
            ),
          ),
        if (file.isBinary)
          Text(
            'binary',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: appColors.subtleText,
            ),
          ),
      ],
    );
  }
}
