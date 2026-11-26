import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../ast/rendered_text.dart';
import '../selection/selection_model.dart';
import 'markdown_theme.dart';
import 'selectable_paragraph.dart';
import 'table_widget.dart' show BuiltInlineSpans, MarkdownCellInlineBuilder;

/// Callback used by [MarkdownDetailsWidget] to render each nested
/// [MarkdownBlock] inside `<details>` at its exact [offsetInBlock].
typedef MarkdownChildBlockBuilder =
    Widget Function(
      BuildContext context,
      MarkdownBlock block,
      int offsetInBlock,
    );

/// Collapsible `<details><summary>...</summary>...</details>` widget built
/// solely on `package:flutter/widgets.dart`.
///
/// Maintains exact [textOffsetInBlock] alignment with
/// [extractBlockRenderedText] for both the summary and every expanded child
/// block.
class MarkdownDetailsWidget extends StatefulWidget {
  const MarkdownDetailsWidget({
    super.key,
    required this.documentId,
    required this.blockIndex,
    required this.block,
    required this.theme,
    required this.childBlockBuilder,
    this.baseOffsetInBlock = 0,
    this.selectionColor,
    this.inlineBuilder,
    this.onSurfaceAttach,
    this.onSurfaceDetach,
  });

  final String documentId;
  final int blockIndex;
  final HtmlDetailsBlock block;
  final MarkdownThemeData theme;
  final MarkdownChildBlockBuilder childBlockBuilder;
  final int baseOffsetInBlock;
  final Color? selectionColor;
  final MarkdownCellInlineBuilder? inlineBuilder;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach;

  @override
  State<MarkdownDetailsWidget> createState() => _MarkdownDetailsWidgetState();
}

class _MarkdownDetailsWidgetState extends State<MarkdownDetailsWidget> {
  late bool _isOpen;

  @override
  void initState() {
    super.initState();
    _isOpen = widget.block.initiallyOpen;
  }

  @override
  void didUpdateWidget(covariant MarkdownDetailsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.initiallyOpen != widget.block.initiallyOpen) {
      _isOpen = widget.block.initiallyOpen;
    }
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  BuiltInlineSpans _buildSummarySpans(BuildContext context, TextStyle style) {
    final customBuilder = widget.inlineBuilder;
    if (customBuilder != null) {
      return customBuilder(context, widget.block.summary, style);
    }
    final text = extractInlinesRenderedText(widget.block.summary);
    return (
      span: TextSpan(text: text, style: style),
      mapping: TextOffsetMapping.identity(text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.theme.detailsStyle;
    final effectiveSelectionColor =
        widget.selectionColor ?? widget.theme.selectionColor;

    final summaryText = extractInlinesRenderedText(widget.block.summary);
    var cursor = widget.baseOffsetInBlock;
    var wroteAny = false;

    final Widget summaryWidget;
    if (summaryText.isNotEmpty) {
      final builtSummary = _buildSummarySpans(context, style.summaryStyle);
      summaryWidget = SelectableParagraph(
        documentId: widget.documentId,
        blockIndex: widget.blockIndex,
        textOffsetInBlock: cursor,
        canonicalLength: summaryText.length,
        offsetMapping: builtSummary.mapping,
        text: builtSummary.span,
        selectionColor: effectiveSelectionColor,
        inlineCodeStyle: widget.theme.inlineCodeStyle,
        onSurfaceAttach: widget.onSurfaceAttach,
        onSurfaceDetach: widget.onSurfaceDetach,
      );
      cursor += summaryText.length;
      wroteAny = true;
    } else {
      // Synthetic fallback label when `<summary>` is omitted: intentionally
      // non-selectable so canonical offsets remain exact.
      summaryWidget = Text('Details', style: style.summaryStyle);
    }

    final childWidgets = <Widget>[];
    if (_isOpen && widget.block.children.isNotEmpty) {
      for (var i = 0; i < widget.block.children.length; i++) {
        final childBlock = widget.block.children[i];
        final childText = extractBlockRenderedText(childBlock);
        if (childText.isNotEmpty && wroteAny) {
          cursor += 1; // '\n' separator in extractBlockRenderedText.
        }
        final childOffset = cursor;
        if (childText.isNotEmpty) {
          cursor += childText.length;
          wroteAny = true;
        }
        if (i > 0) {
          childWidgets.add(SizedBox(height: widget.theme.blockSpacing * 0.75));
        }
        childWidgets.add(
          widget.childBlockBuilder(context, childBlock, childOffset),
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.backgroundColor,
        border: style.borderWidth > 0
            ? Border.all(color: style.borderColor, width: style.borderWidth)
            : null,
        borderRadius: style.borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Padding(
                padding: style.headerPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: _isOpen ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: CustomPaint(
                        size: Size.square(style.iconSize),
                        painter: _DisclosureTrianglePainter(
                          color: style.iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(child: summaryWidget),
                  ],
                ),
              ),
            ),
          ),
          if (_isOpen && childWidgets.isNotEmpty) ...[
            if (style.borderWidth > 0)
              Container(height: style.borderWidth, color: style.borderColor),
            Padding(
              padding: style.bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: childWidgets,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisclosureTrianglePainter extends CustomPainter {
  const _DisclosureTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Right-pointing equilateral-ish disclosure triangle (rotates 90deg when open).
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.18)
      ..lineTo(size.width * 0.78, size.height * 0.5)
      ..lineTo(size.width * 0.28, size.height * 0.82)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DisclosureTrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
