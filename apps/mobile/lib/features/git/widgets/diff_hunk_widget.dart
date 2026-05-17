import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/git_diff_interaction_mode.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/code_text_style.dart';
import '../../../utils/diff_parser.dart';
import '../../../widgets/adaptive_context_menu.dart';
import 'git_swipe_action_background.dart';

const _prefixWidth = 10.0;
const _gutterGap = 2.0;

double calcLineNumberWidth(DiffFile file, CodeTextSettings codeSettings) {
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
    text: TextSpan(
      text: '0',
      style: codeSettings.style(fontSize: _lineNumberFontSize(codeSettings)),
    ),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  final charWidth = painter.width;
  painter.dispose();
  return digits * charWidth + 4;
}

double _lineNumberFontSize(CodeTextSettings settings) =>
    (settings.fontSize - 2).clamp(minCodeFontSize, maxCodeFontSize);

TextStyle _codeStyle(CodeTextSettings settings) =>
    settings.style(height: codeLineHeight);

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
  final GitDiffInteractionMode interactionMode;
  final String dismissKey;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset?>? onShowActions;
  final VoidCallback? onSwipeStage;
  final VoidCallback? onSwipeUnstage;
  final VoidCallback? onSwipeRevert;
  final CodeTextSettings codeSettings;

  const DiffHunkWidget({
    super.key,
    required this.hunk,
    required this.lineNumberWidth,
    required this.dismissKey,
    this.lineWrapEnabled = false,
    this.interactionMode = GitDiffInteractionMode.quickActions,
    this.onLongPress,
    this.onShowActions,
    this.onSwipeStage,
    this.onSwipeUnstage,
    this.onSwipeRevert,
    this.codeSettings = const CodeTextSettings(),
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
    if (oldWidget.hunk != widget.hunk ||
        oldWidget.codeSettings.family != widget.codeSettings.family ||
        oldWidget.codeSettings.fontSize != widget.codeSettings.fontSize) {
      setState(_calcMaxContentWidth);
    }
  }

  void _calcMaxContentWidth() {
    final painter = TextPainter(textDirection: ui.TextDirection.ltr);
    var maxWidth = 0.0;
    for (final line in widget.hunk.lines) {
      painter.text = TextSpan(
        text: line.content,
        style: _codeStyle(widget.codeSettings),
      );
      painter.layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
    }
    painter.dispose();
    _maxContentWidth = maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hunk.header.isNotEmpty)
          _DiffHunkHeader(
            header: widget.hunk.header,
            codeSettings: widget.codeSettings,
            onLongPress: widget.onShowActions == null
                ? widget.onLongPress
                : null,
          ),
        if (widget.hunk.lines.isNotEmpty)
          _DiffHunkBody(
            lines: widget.hunk.lines,
            maxContentWidth: _maxContentWidth,
            lineNumberWidth: widget.lineNumberWidth,
            lineWrapEnabled: widget.lineWrapEnabled,
            codeSettings: widget.codeSettings,
            onLongPress: widget.onShowActions == null
                ? widget.onLongPress
                : null,
          ),
        const SizedBox(height: 4),
      ],
    );

    final onShowActions = widget.onShowActions;
    if (onShowActions != null) {
      content = AdaptiveContextMenuRegion(
        onOpen: onShowActions,
        child: content,
      );
    }

    final hasSwipeAction =
        widget.onSwipeStage != null ||
        widget.onSwipeUnstage != null ||
        widget.onSwipeRevert != null;
    if (!hasSwipeAction) {
      return content;
    }

    return switch (widget.interactionMode) {
      GitDiffInteractionMode.quickActions =>
        widget.lineWrapEnabled
            ? _HunkSwipeDismissible(
                dismissKey: widget.dismissKey,
                onSwipeStage: widget.onSwipeStage,
                onSwipeUnstage: widget.onSwipeUnstage,
                onSwipeRevert: widget.onSwipeRevert,
                child: content,
              )
            : content,
      GitDiffInteractionMode.scrollFirst => content,
    };
  }
}

class _DiffHunkHeader extends StatelessWidget {
  final String header;
  final CodeTextSettings codeSettings;
  final VoidCallback? onLongPress;

  const _DiffHunkHeader({
    required this.header,
    required this.codeSettings,
    this.onLongPress,
  });

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
                style: codeSettings.style(
                  fontSize: (codeSettings.fontSize - 1).clamp(
                    minCodeFontSize,
                    maxCodeFontSize,
                  ),
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
  final CodeTextSettings codeSettings;
  final VoidCallback? onLongPress;

  const _DiffHunkBody({
    required this.lines,
    required this.maxContentWidth,
    required this.lineNumberWidth,
    required this.lineWrapEnabled,
    required this.codeSettings,
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
                  codeSettings: codeSettings,
                ),
                Expanded(
                  child: _DiffCodeRow(
                    line: line,
                    appColors: appColors,
                    wrap: true,
                    codeSettings: codeSettings,
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
                codeSettings: codeSettings,
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
                        codeSettings: codeSettings,
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
  final CodeTextSettings codeSettings;

  const _DiffGutterRow({
    required this.line,
    required this.appColors,
    required this.lineNumberWidth,
    required this.codeSettings,
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
              style: codeSettings.style(
                fontSize: _lineNumberFontSize(codeSettings),
                color: appColors.subtleText,
              ),
            ),
          ),
          const SizedBox(width: _gutterGap),
          SizedBox(
            width: _prefixWidth,
            child: Text(
              prefix,
              style: codeSettings.style(
                fontWeight: FontWeight.w600,
                color: textColor,
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
  final CodeTextSettings codeSettings;
  final double? contentWidth;
  final VoidCallback? onLongPress;

  const _DiffCodeRow({
    required this.line,
    required this.appColors,
    required this.wrap,
    required this.codeSettings,
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
      style: _codeStyle(codeSettings).copyWith(color: textColor),
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
    final hasLeftAction = onSwipeRevert != null || onSwipeUnstage != null;
    final isRevert = onSwipeRevert != null;
    final leftLabel = isRevert ? 'Revert' : 'Unstage';
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
          ? const GitSwipeActionBackground(
              alignment: Alignment.topLeft,
              padding: EdgeInsets.only(left: 12, top: 8),
              icon: Icons.add_circle_outline,
              label: 'Stage',
              tone: GitSwipeActionTone.primary,
            )
          : hasLeftAction
          ? const SizedBox.shrink()
          : null,
      secondaryBackground: hasLeftAction
          ? GitSwipeActionBackground(
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 12, top: 8),
              icon: leftIcon,
              label: leftLabel,
              tone: isRevert
                  ? GitSwipeActionTone.danger
                  : GitSwipeActionTone.neutral,
            )
          : null,
      child: child,
    );
  }
}
