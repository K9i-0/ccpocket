import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';

/// Maximum number of diff lines shown inline before truncation.
const _maxInlineLines = 20;

const _codeFontSize = 11.0;
const _codeHeight = 1.4;

/// Compact inline diff view for Edit/Write/MultiEdit tool inputs.
///
/// Renders color-coded additions (green) and deletions (red) extracted from
/// the tool's `old_string` / `new_string` input.  Designed to be embedded
/// inside [ToolUseTile]'s expanded card.
class InlineEditDiff extends StatelessWidget {
  final DiffFile diffFile;

  /// Called when the user taps to open the full [DiffScreen].
  final VoidCallback? onTapFullDiff;

  const InlineEditDiff({super.key, required this.diffFile, this.onTapFullDiff});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Flatten all hunk lines for inline display.
    final allLines = <({DiffLine line, bool isSeparator})>[];
    for (var i = 0; i < diffFile.hunks.length; i++) {
      if (i > 0) {
        // Add a visual separator between hunks (for MultiEdit).
        allLines.add((
          line: const DiffLine(type: DiffLineType.context, content: ''),
          isSeparator: true,
        ));
      }
      for (final line in diffFile.hunks[i].lines) {
        allLines.add((line: line, isSeparator: false));
      }
    }

    final isTruncated = allLines.length > _maxInlineLines;
    final visibleLines = isTruncated
        ? allLines.take(_maxInlineLines).toList()
        : allLines;
    final remaining = allLines.length - _maxInlineLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Diff lines
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            color: appColors.codeBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in visibleLines)
                  if (entry.isSeparator)
                    _HunkSeparator(appColors: appColors)
                  else
                    _DiffLineRow(line: entry.line, appColors: appColors),
              ],
            ),
          ),
        ),

        // Truncation hint
        if (isTruncated)
          GestureDetector(
            onTap: onTapFullDiff,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '... $remaining more lines',
                style: TextStyle(
                  fontSize: 11,
                  color: appColors.subtleText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  final DiffLine line;
  final AppColors appColors;

  const _DiffLineRow({required this.line, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, prefix) = switch (line.type) {
      DiffLineType.addition => (
        appColors.diffAdditionBackground,
        appColors.diffAdditionText,
        '+',
      ),
      DiffLineType.deletion => (
        appColors.diffDeletionBackground,
        appColors.diffDeletionText,
        '-',
      ),
      DiffLineType.context => (
        Colors.transparent,
        appColors.toolResultTextExpanded,
        ' ',
      ),
    };

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
      child: Text(
        '$prefix ${line.content}',
        style: TextStyle(
          fontSize: _codeFontSize,
          fontFamily: 'monospace',
          color: textColor,
          height: _codeHeight,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _HunkSeparator extends StatelessWidget {
  final AppColors appColors;

  const _HunkSeparator({required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: appColors.codeBorder,
    );
  }
}
