import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';

class DiffHunkWidget extends StatelessWidget {
  final DiffHunk hunk;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelection;

  const DiffHunkWidget({
    super.key,
    required this.hunk,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: selectionMode ? onToggleSelection : null,
      behavior: selectionMode
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hunk.header.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: appColors.codeBackground,
              child: Row(
                children: [
                  if (selectionMode) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: selected,
                        onChanged: onToggleSelection != null
                            ? (_) => onToggleSelection!()
                            : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      hunk.header,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: appColors.subtleText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final line in hunk.lines)
            DiffLineWidget(line: line, absorb: selectionMode),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class DiffLineWidget extends StatelessWidget {
  final DiffLine line;

  /// When true, tap is handled by the parent (hunk selection) so this widget
  /// only keeps long-press for copy.
  final bool absorb;

  const DiffLineWidget({super.key, required this.line, this.absorb = false});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
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

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: line.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Line copied'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                line.oldLineNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: appColors.subtleText,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(
                line.newLineNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: appColors.subtleText,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 12,
              child: Text(
                prefix,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  line.content,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
