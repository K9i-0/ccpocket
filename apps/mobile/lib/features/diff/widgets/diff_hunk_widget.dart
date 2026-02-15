import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';

// Shared constants for diff rendering.
const _codeFontSize = 12.0;
const _codeHeight = 1.4;
const _lineNumberFontSize = 10.0;
const _lineNumberWidth = 40.0;
const _prefixWidth = 12.0;
const _gutterGap = 4.0;

const _codeStyle = TextStyle(
  fontSize: _codeFontSize,
  fontFamily: 'monospace',
  height: _codeHeight,
);

(Color bgColor, Color textColor, String prefix) _lineStyle(
  DiffLine line,
  AppColors appColors,
) {
  return switch (line.type) {
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
}

class DiffHunkWidget extends StatefulWidget {
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
  State<DiffHunkWidget> createState() => _DiffHunkWidgetState();
}

class _DiffHunkWidgetState extends State<DiffHunkWidget> {
  double _maxContentWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _calcMaxContentWidth();
  }

  @override
  void didUpdateWidget(DiffHunkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hunk != widget.hunk) {
      setState(() {
        _calcMaxContentWidth();
      });
    }
  }

  void _calcMaxContentWidth() {
    final painter = TextPainter(textDirection: ui.TextDirection.ltr);
    var maxWidth = 0.0;
    for (final line in widget.hunk.lines) {
      painter.text = TextSpan(text: line.content, style: _codeStyle);
      painter.layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
    }
    painter.dispose();
    _maxContentWidth = maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.selectionMode ? widget.onToggleSelection : null,
      behavior: widget.selectionMode
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.hunk.header.isNotEmpty)
            _DiffHunkHeader(
              header: widget.hunk.header,
              selectionMode: widget.selectionMode,
              selected: widget.selected,
              onToggleSelection: widget.onToggleSelection,
            ),
          if (widget.hunk.lines.isNotEmpty)
            _DiffHunkBody(
              lines: widget.hunk.lines,
              maxContentWidth: _maxContentWidth,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DiffHunkHeader extends StatelessWidget {
  final String header;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelection;

  const _DiffHunkHeader({
    required this.header,
    required this.selectionMode,
    required this.selected,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Container(
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
              header,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: appColors.subtleText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffHunkBody extends StatelessWidget {
  final List<DiffLine> lines;
  final double maxContentWidth;

  const _DiffHunkBody({required this.lines, required this.maxContentWidth});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed gutter: line numbers + prefix
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              _DiffGutterRow(line: line, appColors: appColors),
          ],
        ),
        // Scrollable code content
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  _DiffCodeRow(
                    line: line,
                    appColors: appColors,
                    contentWidth: maxContentWidth,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiffGutterRow extends StatelessWidget {
  final DiffLine line;
  final AppColors appColors;

  const _DiffGutterRow({required this.line, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, prefix) = _lineStyle(line, appColors);

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _lineNumberWidth,
            child: Text(
              line.oldLineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: _lineNumberFontSize,
                fontFamily: 'monospace',
                color: appColors.subtleText,
              ),
            ),
          ),
          SizedBox(
            width: _lineNumberWidth,
            child: Text(
              line.newLineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: _lineNumberFontSize,
                fontFamily: 'monospace',
                color: appColors.subtleText,
              ),
            ),
          ),
          const SizedBox(width: _gutterGap),
          SizedBox(
            width: _prefixWidth,
            child: Text(
              prefix,
              style: TextStyle(
                fontSize: _codeFontSize,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: textColor,
                height: _codeHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffCodeRow extends StatelessWidget {
  final DiffLine line;
  final AppColors appColors;
  final double contentWidth;

  const _DiffCodeRow({
    required this.line,
    required this.appColors,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, _) = _lineStyle(line, appColors);

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
        constraints: BoxConstraints(minWidth: contentWidth),
        child: Text(line.content, style: _codeStyle.copyWith(color: textColor)),
      ),
    );
  }
}
