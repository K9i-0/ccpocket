import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';
import '../../theme/code_text_style.dart';
import '../../utils/diff_parser.dart';
import '../google_search_text_selection.dart';

/// Maximum number of diff lines shown inline before truncation.
const _maxInlineLines = 20;

const _codeHeight = 1.4;

/// Compact inline diff view for Edit/Write/MultiEdit tool inputs.
///
/// Renders color-coded additions (green) and deletions (red) extracted from
/// the tool's `old_string` / `new_string` input.  Designed to be embedded
/// inside [ToolUseTile]'s expanded card.
class InlineEditDiff extends StatelessWidget {
  final DiffFile diffFile;

  /// Called when the user taps to open the full [GitScreen].
  final VoidCallback? onTapFullDiff;

  const InlineEditDiff({super.key, required this.diffFile, this.onTapFullDiff});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final codeSettings = codeTextSettingsOf(context);
    final codeFontSize = (codeSettings.fontSize - 1).clamp(
      minCodeFontSize,
      maxCodeFontSize,
    );
    final borderColor = cs.outlineVariant.withValues(alpha: 0.7);

    final totalLines =
        diffFile.hunks.fold<int>(
          0,
          (total, hunk) => total + hunk.lines.length,
        ) +
        (diffFile.hunks.isEmpty ? 0 : diffFile.hunks.length - 1);
    final visibleLines = <({DiffLine line, bool isSeparator})>[];
    for (var i = 0; i < diffFile.hunks.length; i++) {
      if (visibleLines.length >= _maxInlineLines) break;
      if (i > 0) {
        // Add a visual separator between hunks (for MultiEdit).
        visibleLines.add((
          line: const DiffLine(type: DiffLineType.context, content: ''),
          isSeparator: true,
        ));
      }
      for (final line in diffFile.hunks[i].lines) {
        if (visibleLines.length >= _maxInlineLines) break;
        visibleLines.add((line: line, isSeparator: false));
      }
    }

    final isTruncated = totalLines > _maxInlineLines;
    final remaining = totalLines - _maxInlineLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Diff lines
        DecoratedBox(
          decoration: BoxDecoration(
            color: appColors.codeBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: GoogleSearchSelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in visibleLines)
                    if (entry.isSeparator)
                      _HunkSeparator(color: borderColor)
                    else
                      _DiffLineRow(
                        line: entry.line,
                        appColors: appColors,
                        codeSettings: codeSettings,
                        fontSize: codeFontSize,
                      ),
                ],
              ),
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
  final CodeTextSettings codeSettings;
  final double fontSize;

  const _DiffLineRow({
    required this.line,
    required this.appColors,
    required this.codeSettings,
    required this.fontSize,
  });

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
        style: codeSettings.style(
          fontSize: fontSize,
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
  final Color color;

  const _HunkSeparator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: color,
    );
  }
}
