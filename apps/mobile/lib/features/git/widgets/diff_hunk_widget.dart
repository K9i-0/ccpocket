import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';

const _codeFontSize = 12.0;
const _codeHeight = 1.4;
const _lineNumberFontSize = 10.0;
const _prefixWidth = 10.0;
const _gutterGap = 2.0;

double calcLineNumberWidth(DiffFile file) {
  var maxNum = 0;
  for (final hunk in file.hunks) {
    for (final line in hunk.lines) {
      final n = line.oldLineNumber ?? 0;
      final m = line.newLineNumber ?? 0;
      if (n > maxNum) maxNum = n;
      if (m > maxNum) maxNum = m;
    }
  }
  final digits = maxNum.toString().length.clamp(2, 6);
  final painter = TextPainter(
    text: const TextSpan(
      text: '0',
      style: TextStyle(fontSize: _lineNumberFontSize, fontFamily: 'monospace'),
    ),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  final charWidth = painter.width;
  painter.dispose();
  return digits * charWidth + 4;
}

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
  final double lineNumberWidth;
  final bool lineWrapEnabled;
  final String dismissKey;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeStage;
  final VoidCallback? onSwipeUnstage;
  final VoidCallback? onSwipeRevert;

  const DiffHunkWidget({
    super.key,
    required this.hunk,
    required this.lineNumberWidth,
    required this.dismissKey,
    this.lineWrapEnabled = false,
    this.onLongPress,
    this.onSwipeStage,
    this.onSwipeUnstage,
    this.onSwipeRevert,
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
      setState(_calcMaxContentWidth);
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hunk.header.isNotEmpty)
          _DiffHunkHeader(
            header: widget.hunk.header,
            onLongPress: widget.onLongPress,
          ),
        if (widget.hunk.lines.isNotEmpty)
          _DiffHunkBody(
            lines: widget.hunk.lines,
            maxContentWidth: _maxContentWidth,
            lineNumberWidth: widget.lineNumberWidth,
            lineWrapEnabled: widget.lineWrapEnabled,
            onLongPress: widget.onLongPress,
          ),
        const SizedBox(height: 4),
      ],
    );

    if (!widget.lineWrapEnabled ||
        (widget.onSwipeStage == null &&
            widget.onSwipeUnstage == null &&
            widget.onSwipeRevert == null)) {
      return content;
    }

    return _HunkSwipeDismissible(
      dismissKey: widget.dismissKey,
      onSwipeStage: widget.onSwipeStage,
      onSwipeUnstage: widget.onSwipeUnstage,
      onSwipeRevert: widget.onSwipeRevert,
      child: content,
    );
  }
}

class _DiffHunkHeader extends StatelessWidget {
  final String header;
  final VoidCallback? onLongPress;

  const _DiffHunkHeader({required this.header, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: appColors.codeBackground,
        child: Row(
          children: [
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
      ),
    );
  }
}

class _DiffHunkBody extends StatelessWidget {
  final List<DiffLine> lines;
  final double maxContentWidth;
  final double lineNumberWidth;
  final bool lineWrapEnabled;
  final VoidCallback? onLongPress;

  const _DiffHunkBody({
    required this.lines,
    required this.maxContentWidth,
    required this.lineNumberWidth,
    required this.lineWrapEnabled,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    if (lineWrapEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DiffGutterRow(
                  line: line,
                  appColors: appColors,
                  lineNumberWidth: lineNumberWidth,
                ),
                Expanded(
                  child: _DiffCodeRow(
                    line: line,
                    appColors: appColors,
                    wrap: true,
                    onLongPress: onLongPress,
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              _DiffGutterRow(
                line: line,
                appColors: appColors,
                lineNumberWidth: lineNumberWidth,
              ),
          ],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : maxContentWidth;
              final effectiveWidth = maxContentWidth > minWidth
                  ? maxContentWidth
                  : minWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines)
                      _DiffCodeRow(
                        line: line,
                        appColors: appColors,
                        wrap: false,
                        contentWidth: effectiveWidth,
                        onLongPress: onLongPress,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DiffGutterRow extends StatelessWidget {
  final DiffLine line;
  final AppColors appColors;
  final double lineNumberWidth;

  const _DiffGutterRow({
    required this.line,
    required this.appColors,
    required this.lineNumberWidth,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, prefix) = _lineStyle(line, appColors);
    final displayNumber = line.newLineNumber ?? line.oldLineNumber;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: lineNumberWidth,
            child: Text(
              displayNumber?.toString() ?? '',
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
  final bool wrap;
  final double? contentWidth;
  final VoidCallback? onLongPress;

  const _DiffCodeRow({
    required this.line,
    required this.appColors,
    required this.wrap,
    this.contentWidth,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, _) = _lineStyle(line, appColors);
    final text = Text(
      line.content,
      softWrap: wrap,
      overflow: wrap ? TextOverflow.visible : TextOverflow.clip,
      style: _codeStyle.copyWith(color: textColor),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 1),
        constraints: wrap ? null : BoxConstraints(minWidth: contentWidth ?? 0),
        child: text,
      ),
    );
  }
}

class _HunkSwipeDismissible extends StatelessWidget {
  final String dismissKey;
  final VoidCallback? onSwipeStage;
  final VoidCallback? onSwipeUnstage;
  final VoidCallback? onSwipeRevert;
  final Widget child;

  const _HunkSwipeDismissible({
    required this.dismissKey,
    this.onSwipeStage,
    this.onSwipeUnstage,
    this.onSwipeRevert,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLeftAction = onSwipeRevert != null || onSwipeUnstage != null;
    final isRevert = onSwipeRevert != null;
    final leftLabel = isRevert ? 'Revert' : 'Unstage';
    final leftColor = isRevert ? cs.error : cs.tertiary;
    final leftIcon = isRevert ? Icons.undo : Icons.remove_circle_outline;

    final direction = onSwipeStage != null && hasLeftAction
        ? DismissDirection.horizontal
        : onSwipeStage != null
        ? DismissDirection.startToEnd
        : hasLeftAction
        ? DismissDirection.endToStart
        : DismissDirection.none;

    return Dismissible(
      key: ValueKey('hunk_swipe_$dismissKey'),
      direction: direction,
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          onSwipeStage?.call();
        } else if (onSwipeRevert != null) {
          onSwipeRevert!.call();
        } else {
          onSwipeUnstage?.call();
        }
        return false;
      },
      background: onSwipeStage != null
          ? Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: cs.primary.withValues(alpha: 0.15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Stage',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : hasLeftAction
          ? const SizedBox.shrink()
          : null,
      secondaryBackground: hasLeftAction
          ? Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: leftColor.withValues(alpha: 0.15),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    leftLabel,
                    style: TextStyle(
                      color: leftColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(leftIcon, color: leftColor, size: 20),
                ],
              ),
            )
          : null,
      child: child,
    );
  }
}
