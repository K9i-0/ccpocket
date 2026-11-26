import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../ast/rendered_text.dart';
import '../selection/selection_model.dart';
import 'markdown_theme.dart';
import 'selectable_paragraph.dart';

/// Result of converting a list of [MarkdownInline] nodes into a renderable
/// [InlineSpan] paired with its canonical-to-painter [TextOffsetMapping].
typedef BuiltInlineSpans = ({InlineSpan span, TextOffsetMapping mapping});

/// Callback that builds an [InlineSpan] and [TextOffsetMapping] for cell
/// inlines with a given [baseStyle].
typedef MarkdownCellInlineBuilder =
    BuiltInlineSpans Function(
      BuildContext context,
      List<MarkdownInline> inlines,
      TextStyle baseStyle,
    );

/// Renders a GFM [TableBlock] with natural column sizing, horizontal scroll
/// when content exceeds the viewport width, and exact per-cell selection
/// offsets matching [extractBlockRenderedText].
class MarkdownTableWidget extends StatelessWidget {
  const MarkdownTableWidget({
    super.key,
    required this.documentId,
    required this.blockIndex,
    required this.table,
    required this.theme,
    this.baseOffsetInBlock = 0,
    this.baseTextStyle,
    this.selectionColor,
    this.inlineBuilder,
    this.onSurfaceAttach,
    this.onSurfaceDetach,
  });

  final String documentId;
  final int blockIndex;
  final TableBlock table;
  final MarkdownThemeData theme;
  final int baseOffsetInBlock;
  final TextStyle? baseTextStyle;
  final Color? selectionColor;
  final MarkdownCellInlineBuilder? inlineBuilder;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach;

  @override
  Widget build(BuildContext context) {
    final columnCount = _resolveColumnCount();
    if (columnCount == 0) return const SizedBox.shrink();

    final tableStyle = theme.tableStyle;
    final bodyStyle = baseTextStyle ?? theme.bodyStyle;
    final headerStyle = bodyStyle.merge(tableStyle.headerTextStyle);
    final effectiveSelectionColor = selectionColor ?? theme.selectionColor;
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    // Pre-build all cell spans and exact block offsets once so measurement and
    // widget construction share identical data and canonical offsets.
    final builtRows = <_BuiltTableRow>[];
    var offsetCursor = baseOffsetInBlock;

    builtRows.add(
      _buildRow(
        context: context,
        row: table.header,
        columnCount: columnCount,
        style: headerStyle,
        isHeader: true,
        startOffset: offsetCursor,
      ),
    );
    offsetCursor += extractTableRowRenderedText(table.header).length;

    for (final row in table.rows) {
      // Matches extractBlockRenderedText(TableBlock): rows joined by '\n'.
      offsetCursor += 1;
      builtRows.add(
        _buildRow(
          context: context,
          row: row,
          columnCount: columnCount,
          style: bodyStyle,
          isHeader: false,
          startOffset: offsetCursor,
        ),
      );
      offsetCursor += extractTableRowRenderedText(row).length;
    }

    final naturalColumnWidths = _measureNaturalColumnWidths(
      rows: builtRows,
      columnCount: columnCount,
      tableStyle: tableStyle,
      textDirection: textDirection,
      textScaler: textScaler,
    );

    final borderWidth = tableStyle.borderWidth;
    final totalBorderWidth = borderWidth * (columnCount + 1);
    final totalNaturalWidth =
        naturalColumnWidths.fold<double>(0.0, (sum, w) => sum + w) +
        totalBorderWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final needsHorizontalScroll =
            availableWidth.isFinite && totalNaturalWidth > availableWidth;

        final columnWidths = <int, TableColumnWidth>{
          for (var c = 0; c < columnCount; c++)
            c: FixedColumnWidth(naturalColumnWidths[c]),
        };

        final tableWidget = ClipRRect(
          borderRadius: tableStyle.borderRadius,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: borderWidth > 0
                  ? Border.all(
                      color: tableStyle.borderColor,
                      width: borderWidth,
                    )
                  : null,
              borderRadius: tableStyle.borderRadius,
            ),
            child: Table(
              columnWidths: columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: borderWidth > 0
                  ? TableBorder.symmetric(
                      inside: BorderSide(
                        color: tableStyle.borderColor,
                        width: borderWidth,
                      ),
                    )
                  : null,
              children: [
                for (var r = 0; r < builtRows.length; r++)
                  _buildTableRowWidget(
                    row: builtRows[r],
                    rowIndex: r,
                    tableStyle: tableStyle,
                    selectionColor: effectiveSelectionColor,
                    textDirection: textDirection,
                  ),
              ],
            ),
          ),
        );

        if (needsHorizontalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tableWidget,
          );
        }
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: tableWidget,
        );
      },
    );
  }

  int _resolveColumnCount() {
    var count = table.header.cells.length;
    for (final row in table.rows) {
      if (row.cells.length > count) {
        count = row.cells.length;
      }
    }
    return count;
  }

  _BuiltTableRow _buildRow({
    required BuildContext context,
    required TableRowNode row,
    required int columnCount,
    required TextStyle style,
    required bool isHeader,
    required int startOffset,
  }) {
    final cells = <_BuiltTableCell>[];
    var cursor = startOffset;

    for (var c = 0; c < columnCount; c++) {
      if (c < row.cells.length) {
        if (c > 0) {
          // Matches extractTableRowRenderedText: cells joined by '\t'.
          cursor += 1;
        }
        final cellInlines = row.cells[c];
        final canonicalText = extractInlinesRenderedText(cellInlines);
        final built = _buildCellSpans(context, cellInlines, style);
        cells.add(
          _BuiltTableCell(
            span: built.span,
            mapping: built.mapping,
            offsetInBlock: cursor,
            canonicalLength: canonicalText.length,
            isPresentInAst: true,
          ),
        );
        cursor += canonicalText.length;
      } else {
        // Ragged row visual filler beyond AST cells: never participates in
        // selection offsets.
        cells.add(
          const _BuiltTableCell(
            span: TextSpan(text: ''),
            mapping: TextOffsetMapping.identity(0),
            offsetInBlock: 0,
            canonicalLength: 0,
            isPresentInAst: false,
          ),
        );
      }
    }

    return _BuiltTableRow(isHeader: isHeader, cells: cells);
  }

  BuiltInlineSpans _buildCellSpans(
    BuildContext context,
    List<MarkdownInline> inlines,
    TextStyle style,
  ) {
    final customBuilder = inlineBuilder;
    if (customBuilder != null) {
      return customBuilder(context, inlines, style);
    }
    final text = extractInlinesRenderedText(inlines);
    return (
      span: TextSpan(text: text, style: style),
      mapping: TextOffsetMapping.identity(text.length),
    );
  }

  List<double> _measureNaturalColumnWidths({
    required List<_BuiltTableRow> rows,
    required int columnCount,
    required MarkdownTableStyle tableStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final minW = tableStyle.minColumnWidth;
    final maxW = math.max(minW, tableStyle.maxColumnWidth);
    final padH = tableStyle.cellPadding.horizontal;
    final widths = List<double>.filled(columnCount, minW);

    for (final row in rows) {
      for (var c = 0; c < columnCount; c++) {
        final cell = row.cells[c];
        if (!cell.isPresentInAst) continue;
        final measured = _measureSpanSingleLineWidth(
          span: cell.span,
          textDirection: textDirection,
          textScaler: textScaler,
        );
        final candidate = (measured + padH + 2.0).clamp(minW, maxW);
        if (candidate > widths[c]) {
          widths[c] = candidate;
        }
      }
    }
    return widths;
  }

  double _measureSpanSingleLineWidth({
    required InlineSpan span,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final placeholderCount = _countPlaceholders(span);
    final painter = TextPainter(
      text: span,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    if (placeholderCount > 0) {
      painter.setPlaceholderDimensions(
        List<PlaceholderDimensions>.filled(
          placeholderCount,
          const PlaceholderDimensions(
            size: Size(48.0, 20.0),
            alignment: PlaceholderAlignment.middle,
          ),
        ),
      );
    }
    painter.layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  int _countPlaceholders(InlineSpan span) {
    var count = 0;
    span.visitChildren((child) {
      if (child is PlaceholderSpan) {
        count++;
      }
      return true;
    });
    return count;
  }

  TableRow _buildTableRowWidget({
    required _BuiltTableRow row,
    required int rowIndex,
    required MarkdownTableStyle tableStyle,
    required Color selectionColor,
    required TextDirection textDirection,
  }) {
    Color? backgroundColor;
    if (row.isHeader) {
      backgroundColor = tableStyle.headerBackground;
    } else if (rowIndex.isEven && tableStyle.rowStripeColor != null) {
      // rowIndex 1 is first body row; stripe alternating body rows (2, 4, ...).
      backgroundColor = tableStyle.rowStripeColor;
    }

    return TableRow(
      decoration: backgroundColor != null
          ? BoxDecoration(color: backgroundColor)
          : null,
      children: [
        for (var c = 0; c < row.cells.length; c++)
          _buildCellWidget(
            cell: row.cells[c],
            columnIndex: c,
            tableStyle: tableStyle,
            selectionColor: selectionColor,
            textDirection: textDirection,
          ),
      ],
    );
  }

  Widget _buildCellWidget({
    required _BuiltTableCell cell,
    required int columnIndex,
    required MarkdownTableStyle tableStyle,
    required Color selectionColor,
    required TextDirection textDirection,
  }) {
    final align = columnIndex < table.alignments.length
        ? table.alignments[columnIndex]
        : TableColumnAlign.none;

    final textAlign = switch (align) {
      TableColumnAlign.center => TextAlign.center,
      TableColumnAlign.right => TextAlign.end,
      TableColumnAlign.left || TableColumnAlign.none => TextAlign.start,
    };

    final boxAlignment = switch (align) {
      TableColumnAlign.center => Alignment.center,
      TableColumnAlign.right => AlignmentDirectional.centerEnd,
      TableColumnAlign.left ||
      TableColumnAlign.none => AlignmentDirectional.centerStart,
    };

    final Widget content;
    if (!cell.isPresentInAst || cell.canonicalLength == 0) {
      content = const SizedBox.shrink();
    } else {
      content = SelectableParagraph(
        documentId: documentId,
        blockIndex: blockIndex,
        textOffsetInBlock: cell.offsetInBlock,
        canonicalLength: cell.canonicalLength,
        offsetMapping: cell.mapping,
        text: cell.span,
        textAlign: textAlign,
        textDirection: textDirection,
        selectionColor: selectionColor,
        inlineCodeStyle: theme.inlineCodeStyle,
        onSurfaceAttach: onSurfaceAttach,
        onSurfaceDetach: onSurfaceDetach,
      );
    }

    return Padding(
      padding: tableStyle.cellPadding,
      child: Align(alignment: boxAlignment, child: content),
    );
  }
}

class _BuiltTableRow {
  const _BuiltTableRow({required this.isHeader, required this.cells});

  final bool isHeader;
  final List<_BuiltTableCell> cells;
}

class _BuiltTableCell {
  const _BuiltTableCell({
    required this.span,
    required this.mapping,
    required this.offsetInBlock,
    required this.canonicalLength,
    required this.isPresentInAst,
  });

  final InlineSpan span;
  final TextOffsetMapping mapping;
  final int offsetInBlock;
  final int canonicalLength;
  final bool isPresentInAst;
}
