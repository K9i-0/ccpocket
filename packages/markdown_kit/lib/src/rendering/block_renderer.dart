import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../ast/rendered_text.dart';
import '../selection/selection_model.dart';
import 'details_widget.dart';
import 'list_item_widget.dart';
import 'markdown_builders.dart';
import 'markdown_theme.dart';
import 'selectable_paragraph.dart';
import 'table_widget.dart';

/// Renders a single [MarkdownBlock] (at [blockIndex] inside [documentId]) into
/// a pure `package:flutter/widgets.dart` widget tree.
///
/// Computes exact `textOffsetInBlock` values for every nested
/// [SelectableParagraph] inside lists, blockquotes, alerts, tables, details,
/// footnotes, and code blocks so every character offset matches
/// [extractBlockRenderedText] 1-to-1.
class MarkdownBlockRenderer extends StatelessWidget {
  const MarkdownBlockRenderer({
    super.key,
    required this.documentId,
    required this.blockIndex,
    required this.block,
    this.theme,
    this.builders = const MarkdownBuilders(),
    this.selectionColor,
    this.selectable = true,
    this.onSurfaceAttach,
    this.onSurfaceDetach,
    this.baseOffsetInBlock = 0,
    this.listDepth = 0,
    this.baseTextStyle,
  });

  final String documentId;
  final int blockIndex;
  final MarkdownBlock block;
  final MarkdownThemeData? theme;
  final MarkdownBuilders builders;
  final Color? selectionColor;
  final bool selectable;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach;

  /// Starting canonical UTF-16 offset of [block] within the enclosing
  /// top-level block (non-zero when rendering nested blocks).
  final int baseOffsetInBlock;

  /// Nesting depth of enclosing [ListBlock]s (used to vary bullet markers).
  final int listDepth;

  /// Optional inherited base [TextStyle] propagated by blockquotes, alerts,
  /// and footnote definitions.
  final TextStyle? baseTextStyle;

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? MarkdownTheme.of(context);
    final effectiveSelectionColor =
        selectionColor ?? effectiveTheme.selectionColor;
    final effectiveBodyStyle = baseTextStyle ?? effectiveTheme.bodyStyle;

    return switch (block) {
      ParagraphBlock() => _buildParagraph(
        context,
        block as ParagraphBlock,
        effectiveTheme,
        effectiveBodyStyle,
        effectiveSelectionColor,
      ),
      HeadingBlock() => _buildHeading(
        context,
        block as HeadingBlock,
        effectiveTheme,
        effectiveSelectionColor,
      ),
      CodeBlock() => _buildCodeBlock(
        context,
        block as CodeBlock,
        effectiveTheme,
        effectiveSelectionColor,
      ),
      BlockquoteBlock() => _buildBlockquote(
        context,
        block as BlockquoteBlock,
        effectiveTheme,
        effectiveBodyStyle,
        effectiveSelectionColor,
      ),
      AlertBlock() => _buildAlert(
        context,
        block as AlertBlock,
        effectiveTheme,
        effectiveBodyStyle,
        effectiveSelectionColor,
      ),
      ListBlock() => _buildList(
        context,
        block as ListBlock,
        effectiveTheme,
        effectiveBodyStyle,
        effectiveSelectionColor,
      ),
      TableBlock() => _buildTable(
        context,
        block as TableBlock,
        effectiveTheme,
        effectiveBodyStyle,
        effectiveSelectionColor,
      ),
      ThematicBreakBlock() => _buildThematicBreak(effectiveTheme),
      HtmlDetailsBlock() => _buildDetails(
        context,
        block as HtmlDetailsBlock,
        effectiveTheme,
        effectiveBodyStyle,
        effectiveSelectionColor,
      ),
      FootnoteDefinitionsBlock() => _buildFootnoteDefinitions(
        context,
        block as FootnoteDefinitionsBlock,
        effectiveTheme,
        effectiveSelectionColor,
      ),
      BlockLatexBlock() => _buildBlockLatex(
        context,
        block as BlockLatexBlock,
        effectiveTheme,
        effectiveSelectionColor,
      ),
    };
  }

  Widget _buildParagraph(
    BuildContext context,
    ParagraphBlock paragraph,
    MarkdownThemeData effectiveTheme,
    TextStyle style,
    Color effectiveSelectionColor,
  ) {
    final built = _buildInlines(
      context,
      paragraph.inlines,
      style,
      effectiveTheme,
    );
    return SelectableParagraph(
      documentId: documentId,
      blockIndex: blockIndex,
      textOffsetInBlock: baseOffsetInBlock,
      canonicalLength: built.mapping.canonicalLength,
      offsetMapping: built.mapping,
      text: built.span,
      selectionColor: effectiveSelectionColor,
      inlineCodeStyle: effectiveTheme.inlineCodeStyle,
      selectable: selectable,
      onSurfaceAttach: selectable ? onSurfaceAttach : null,
      onSurfaceDetach: selectable ? onSurfaceDetach : null,
    );
  }

  Widget _buildHeading(
    BuildContext context,
    HeadingBlock heading,
    MarkdownThemeData effectiveTheme,
    Color effectiveSelectionColor,
  ) {
    final style = effectiveTheme.headingStyleForLevel(heading.level);
    final built = _buildInlines(
      context,
      heading.inlines,
      style,
      effectiveTheme,
    );
    return SelectableParagraph(
      documentId: documentId,
      blockIndex: blockIndex,
      textOffsetInBlock: baseOffsetInBlock,
      canonicalLength: built.mapping.canonicalLength,
      offsetMapping: built.mapping,
      text: built.span,
      selectionColor: effectiveSelectionColor,
      inlineCodeStyle: effectiveTheme.inlineCodeStyle,
      selectable: selectable,
      onSurfaceAttach: selectable ? onSurfaceAttach : null,
      onSurfaceDetach: selectable ? onSurfaceDetach : null,
    );
  }

  Widget _buildCodeBlock(
    BuildContext context,
    CodeBlock codeBlock,
    MarkdownThemeData effectiveTheme,
    Color effectiveSelectionColor,
  ) {
    final codeStyle = effectiveTheme.codeBlockStyle;
    final highlighter = builders.codeHighlighter;

    final InlineSpan codeSpan;
    final highlighted = highlighter?.call(
      context,
      codeBlock,
      codeStyle.textStyle,
    );
    // Offsets are counted in the code itself, so spans that add, drop or
    // replace characters cannot be used.
    if (highlighted != null &&
        TextSpan(children: highlighted).toPlainText() == codeBlock.code) {
      codeSpan = TextSpan(style: codeStyle.textStyle, children: highlighted);
    } else {
      codeSpan = TextSpan(text: codeBlock.code, style: codeStyle.textStyle);
    }

    final mappingBuilder = TextOffsetMappingBuilder()
      ..addBuiltSpan(canonicalText: codeBlock.code, span: codeSpan);
    final mapping = mappingBuilder.build();

    // Code reads left to right whatever the direction of the prose around it.
    final codeContent = Directionality(
      textDirection: TextDirection.ltr,
      child: SelectableParagraph(
        documentId: documentId,
        blockIndex: blockIndex,
        textOffsetInBlock: baseOffsetInBlock,
        canonicalLength: codeBlock.code.length,
        offsetMapping: mapping,
        text: codeSpan,
        selectionColor: effectiveSelectionColor,
        inlineCodeStyle: effectiveTheme.inlineCodeStyle,
        selectable: selectable,
        onSurfaceAttach: selectable ? onSurfaceAttach : null,
        onSurfaceDetach: selectable ? onSurfaceDetach : null,
      ),
    );

    final customBuilder = builders.codeBlockBuilder;
    if (customBuilder != null) {
      return customBuilder(context, codeBlock, codeContent, effectiveTheme);
    }

    final language = codeBlock.language;
    final hasHeader = language != null && language.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: codeStyle.backgroundColor,
        border: codeStyle.borderWidth > 0
            ? Border.all(
                color: codeStyle.borderColor,
                width: codeStyle.borderWidth,
              )
            : null,
        borderRadius: codeStyle.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: codeStyle.borderRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: codeStyle.headerBackgroundColor,
                  border: codeStyle.borderWidth > 0
                      ? Border(
                          bottom: BorderSide(
                            color: codeStyle.borderColor,
                            width: codeStyle.borderWidth,
                          ),
                        )
                      : null,
                ),
                child: Padding(
                  padding: codeStyle.headerPadding,
                  child: Text(language, style: codeStyle.headerStyle),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: codeStyle.padding,
              child: codeContent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockquote(
    BuildContext context,
    BlockquoteBlock blockquote,
    MarkdownThemeData effectiveTheme,
    TextStyle parentStyle,
    Color effectiveSelectionColor,
  ) {
    final quoteStyle = effectiveTheme.blockquoteStyle;
    final childTextStyle = quoteStyle.textStyle != null
        ? parentStyle.merge(quoteStyle.textStyle)
        : parentStyle;

    final body = _buildJoinedChildBlocks(
      children: blockquote.children,
      startOffset: baseOffsetInBlock,
      effectiveTheme: effectiveTheme,
      childBaseTextStyle: childTextStyle,
      effectiveSelectionColor: effectiveSelectionColor,
      spacing: effectiveTheme.blockSpacing * 0.75,
    );

    return ClipRRect(
      borderRadius: quoteStyle.borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: quoteStyle.backgroundColor,
          border: BorderDirectional(
            start: BorderSide(
              color: quoteStyle.barColor,
              width: quoteStyle.barWidth,
            ),
          ),
        ),
        child: Padding(
          // The wider inset belongs beside the bar, on the start side.
          padding: Directionality.of(context) == TextDirection.rtl
              ? quoteStyle.padding.flipped.copyWith(
                  top: quoteStyle.padding.top,
                  bottom: quoteStyle.padding.bottom,
                )
              : quoteStyle.padding,
          child: body,
        ),
      ),
    );
  }

  Widget _buildAlert(
    BuildContext context,
    AlertBlock alert,
    MarkdownThemeData effectiveTheme,
    TextStyle parentStyle,
    Color effectiveSelectionColor,
  ) {
    final alertStyle = effectiveTheme.alertStyleFor(alert.kind);
    final childTextStyle = alertStyle.textStyle != null
        ? parentStyle.merge(alertStyle.textStyle)
        : parentStyle;

    final body = _buildJoinedChildBlocks(
      children: alert.children,
      startOffset: baseOffsetInBlock,
      effectiveTheme: effectiveTheme,
      childBaseTextStyle: childTextStyle,
      effectiveSelectionColor: effectiveSelectionColor,
      spacing: effectiveTheme.blockSpacing * 0.75,
    );

    final customBuilder = builders.alertBuilder;
    if (customBuilder != null) {
      return customBuilder(context, alert, body, effectiveTheme);
    }

    final title = _alertKindTitle(alert.kind);

    return ClipRRect(
      borderRadius: alertStyle.borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: alertStyle.backgroundColor,
          borderRadius: alertStyle.borderRadius,
          border: alertStyle.borderWidth > 0
              ? Border.all(
                  color: alertStyle.borderColor,
                  width: alertStyle.borderWidth,
                )
              : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: alertStyle.accentColor,
                width: alertStyle.barWidth,
              ),
            ),
          ),
          child: Padding(
            padding: alertStyle.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Non-selectable decorative header matching GitHub alert labels.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size.square(14.0),
                      painter: _AlertGlyphPainter(
                        kind: alert.kind,
                        color: alertStyle.accentColor,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    // Flexible so a large text scale wraps the title
                    // instead of overflowing the row.
                    Flexible(child: Text(title, style: alertStyle.titleStyle)),
                  ],
                ),
                if (alert.children.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  body,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ListBlock list,
    MarkdownThemeData effectiveTheme,
    TextStyle style,
    Color effectiveSelectionColor,
  ) {
    if (list.items.isEmpty) return const SizedBox.shrink();

    final itemWidgets = <Widget>[];
    var cursor = baseOffsetInBlock;
    var wroteAny = false;
    final itemSpacing = list.tight
        ? effectiveTheme.listItemSpacing
        : effectiveTheme.listItemSpacing * 2.0;

    // Every item reserves room for the widest ordinal so "9." and "10." keep
    // their text in one column.
    final widestOrdinalText = list.ordered
        ? '${list.start + list.items.length - 1}.'
        : null;

    for (var i = 0; i < list.items.length; i++) {
      final item = list.items[i];
      final itemText = extractListItemRenderedText(item);
      if (itemText.isNotEmpty && wroteAny) {
        cursor += 1; // '\n' separator in extractBlockRenderedText(ListBlock).
      }
      final itemStartOffset = cursor;
      if (itemText.isNotEmpty) {
        cursor += itemText.length;
        wroteAny = true;
      }

      final MarkdownListMarkerKind markerKind;
      String? ordinalText;
      if (item.isTaskItem) {
        markerKind = item.checked!
            ? MarkdownListMarkerKind.taskChecked
            : MarkdownListMarkerKind.taskUnchecked;
      } else if (list.ordered) {
        markerKind = MarkdownListMarkerKind.ordered;
        ordinalText = '${list.start + i}.';
      } else {
        markerKind = MarkdownListMarkerKind.bullet;
      }

      final childContent = _buildJoinedChildBlocks(
        children: item.children,
        startOffset: itemStartOffset,
        effectiveTheme: effectiveTheme,
        childBaseTextStyle: style,
        effectiveSelectionColor: effectiveSelectionColor,
        spacing: effectiveTheme.listItemSpacing,
        nextListDepth: listDepth + 1,
      );

      if (i > 0 && itemSpacing > 0) {
        itemWidgets.add(SizedBox(height: itemSpacing));
      }
      itemWidgets.add(
        MarkdownListItemWidget(
          markerKind: markerKind,
          markerColor: effectiveTheme.listBulletColor,
          checkboxFillColor: effectiveTheme.listCheckboxFillColor,
          checkboxCheckColor: effectiveTheme.listCheckboxCheckColor,
          bulletSize: effectiveTheme.listBulletSize,
          indent: effectiveTheme.listIndent,
          markerTextStyle: style,
          ordinalText: ordinalText,
          ordinalSizingText: widestOrdinalText,
          nestingDepth: listDepth,
          child: childContent,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: itemWidgets,
    );
  }

  Widget _buildTable(
    BuildContext context,
    TableBlock table,
    MarkdownThemeData effectiveTheme,
    TextStyle style,
    Color effectiveSelectionColor,
  ) {
    final customBuilder = builders.tableBuilder;
    if (customBuilder != null) {
      return customBuilder(context, table, effectiveTheme);
    }
    return MarkdownTableWidget(
      documentId: documentId,
      blockIndex: blockIndex,
      table: table,
      theme: effectiveTheme,
      baseOffsetInBlock: baseOffsetInBlock,
      baseTextStyle: style,
      selectionColor: effectiveSelectionColor,
      selectable: selectable,
      inlineBuilder: (ctx, inlines, cellStyle) =>
          _buildInlines(ctx, inlines, cellStyle, effectiveTheme),
      onSurfaceAttach: selectable ? onSurfaceAttach : null,
      onSurfaceDetach: selectable ? onSurfaceDetach : null,
    );
  }

  Widget _buildThematicBreak(MarkdownThemeData effectiveTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        height: effectiveTheme.dividerThickness,
        color: effectiveTheme.dividerColor,
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    HtmlDetailsBlock details,
    MarkdownThemeData effectiveTheme,
    TextStyle style,
    Color effectiveSelectionColor,
  ) {
    return MarkdownDetailsWidget(
      documentId: documentId,
      blockIndex: blockIndex,
      block: details,
      theme: effectiveTheme,
      baseOffsetInBlock: baseOffsetInBlock,
      selectionColor: effectiveSelectionColor,
      selectable: selectable,
      inlineBuilder: (ctx, inlines, summaryStyle) =>
          _buildInlines(ctx, inlines, summaryStyle, effectiveTheme),
      childBlockBuilder: (ctx, childBlock, offsetInBlock) {
        return MarkdownBlockRenderer(
          documentId: documentId,
          blockIndex: blockIndex,
          block: childBlock,
          theme: effectiveTheme,
          builders: builders,
          selectionColor: effectiveSelectionColor,
          selectable: selectable,
          onSurfaceAttach: selectable ? onSurfaceAttach : null,
          onSurfaceDetach: selectable ? onSurfaceDetach : null,
          baseOffsetInBlock: offsetInBlock,
          listDepth: listDepth,
          baseTextStyle: style,
        );
      },
      onSurfaceAttach: selectable ? onSurfaceAttach : null,
      onSurfaceDetach: selectable ? onSurfaceDetach : null,
    );
  }

  Widget _buildFootnoteDefinitions(
    BuildContext context,
    FootnoteDefinitionsBlock footnotes,
    MarkdownThemeData effectiveTheme,
    Color effectiveSelectionColor,
  ) {
    if (footnotes.definitions.isEmpty) return const SizedBox.shrink();
    final fnStyle = effectiveTheme.footnoteStyle;
    final rows = <Widget>[];
    var cursor = baseOffsetInBlock;
    var wroteAny = false;

    for (var i = 0; i < footnotes.definitions.length; i++) {
      final def = footnotes.definitions[i];
      final defText = extractFootnoteDefinitionRenderedText(def);
      if (defText.isNotEmpty && wroteAny) {
        cursor += 1; // '\n' separator in extractBlockRenderedText.
      }
      final defStartOffset = cursor;
      if (defText.isNotEmpty) {
        cursor += defText.length;
        wroteAny = true;
      }

      final body = _buildJoinedChildBlocks(
        children: def.children,
        startOffset: defStartOffset,
        effectiveTheme: effectiveTheme,
        childBaseTextStyle: fnStyle.textStyle,
        effectiveSelectionColor: effectiveSelectionColor,
        spacing: fnStyle.itemSpacing * 0.75,
      );

      if (i > 0 && fnStyle.itemSpacing > 0) {
        rows.add(SizedBox(height: fnStyle.itemSpacing));
      }
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Non-selectable footnote label matching displayLabel.
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0, top: 1.0),
              child: Text(def.displayLabel, style: fnStyle.labelStyle),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fnStyle.dividerThickness > 0) ...[
          Container(
            height: fnStyle.dividerThickness,
            color: fnStyle.dividerColor,
          ),
          const SizedBox(height: 8.0),
        ],
        ...rows,
      ],
    );
  }

  Widget _buildBlockLatex(
    BuildContext context,
    BlockLatexBlock latex,
    MarkdownThemeData effectiveTheme,
    Color effectiveSelectionColor,
  ) {
    final customBuilder = builders.blockLatexBuilder;
    if (customBuilder != null) {
      return customBuilder(context, latex, effectiveTheme);
    }

    final latexStyle = effectiveTheme.latexStyle;
    final formatted = formatLatexFallback(latex.expression);
    final mappingBuilder = TextOffsetMappingBuilder();
    if (formatted == latex.expression) {
      mappingBuilder.addOneToOne(formatted.length);
    } else {
      mappingBuilder.addAtomic(
        canonicalLength: latex.expression.length,
        painterLength: formatted.length,
      );
    }
    final mapping = mappingBuilder.build();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: latexStyle.blockBackgroundColor,
        border: latexStyle.blockBorderColor != null
            ? Border.all(color: latexStyle.blockBorderColor!, width: 1.0)
            : null,
        borderRadius: latexStyle.blockBorderRadius,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: latexStyle.blockPadding,
        child: SelectableParagraph(
          documentId: documentId,
          blockIndex: blockIndex,
          textOffsetInBlock: baseOffsetInBlock,
          canonicalLength: latex.expression.length,
          offsetMapping: mapping,
          text: TextSpan(text: formatted, style: latexStyle.blockStyle),
          textAlign: TextAlign.center,
          selectionColor: effectiveSelectionColor,
          inlineCodeStyle: effectiveTheme.inlineCodeStyle,
          selectable: selectable,
          onSurfaceAttach: selectable ? onSurfaceAttach : null,
          onSurfaceDetach: selectable ? onSurfaceDetach : null,
        ),
      ),
    );
  }

  Widget _buildJoinedChildBlocks({
    required List<MarkdownBlock> children,
    required int startOffset,
    required MarkdownThemeData effectiveTheme,
    required TextStyle childBaseTextStyle,
    required Color effectiveSelectionColor,
    required double spacing,
    int? nextListDepth,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    final depth = nextListDepth ?? listDepth;
    final widgets = <Widget>[];
    var cursor = startOffset;
    var wroteAny = false;

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final childText = extractBlockRenderedText(child);
      if (childText.isNotEmpty && wroteAny) {
        cursor += 1; // '\n' separator from _joinNonEmptyBlocks.
      }
      final childOffset = cursor;
      if (childText.isNotEmpty) {
        cursor += childText.length;
        wroteAny = true;
      }

      if (i > 0 && spacing > 0) {
        widgets.add(SizedBox(height: spacing));
      }
      widgets.add(
        MarkdownBlockRenderer(
          documentId: documentId,
          blockIndex: blockIndex,
          block: child,
          theme: effectiveTheme,
          builders: builders,
          selectionColor: effectiveSelectionColor,
          selectable: selectable,
          onSurfaceAttach: selectable ? onSurfaceAttach : null,
          onSurfaceDetach: selectable ? onSurfaceDetach : null,
          baseOffsetInBlock: childOffset,
          listDepth: depth,
          baseTextStyle: childBaseTextStyle,
        ),
      );
    }

    if (widgets.length == 1) return widgets.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  // ---------------------------------------------------------------------------
  // Inline AST -> InlineSpan + TextOffsetMapping conversion
  // ---------------------------------------------------------------------------

  BuiltInlineSpans _buildInlines(
    BuildContext context,
    List<MarkdownInline> inlines,
    TextStyle baseStyle,
    MarkdownThemeData effectiveTheme,
  ) {
    final mappingBuilder = TextOffsetMappingBuilder();
    final spans = _buildInlineList(
      context,
      inlines,
      baseStyle,
      effectiveTheme,
      mappingBuilder,
    );
    return (
      span: TextSpan(style: baseStyle, children: spans),
      mapping: mappingBuilder.build(),
    );
  }

  List<InlineSpan> _buildInlineList(
    BuildContext context,
    List<MarkdownInline> inlines,
    TextStyle currentStyle,
    MarkdownThemeData effectiveTheme,
    TextOffsetMappingBuilder mappingBuilder,
  ) {
    final result = <InlineSpan>[];
    for (final inline in inlines) {
      result.add(
        _buildSingleInline(
          context,
          inline,
          currentStyle,
          effectiveTheme,
          mappingBuilder,
        ),
      );
    }
    return result;
  }

  InlineSpan _buildSingleInline(
    BuildContext context,
    MarkdownInline inline,
    TextStyle currentStyle,
    MarkdownThemeData effectiveTheme,
    TextOffsetMappingBuilder mappingBuilder,
  ) {
    return switch (inline) {
      TextInline(:final text) => () {
        mappingBuilder.addOneToOne(text.length);
        return TextSpan(text: text, style: currentStyle);
      }(),
      EmphasisInline(:final children) => TextSpan(
        style: _mergeTextStyle(currentStyle, effectiveTheme.emphasisStyle),
        children: _buildInlineList(
          context,
          children,
          _mergeTextStyle(currentStyle, effectiveTheme.emphasisStyle),
          effectiveTheme,
          mappingBuilder,
        ),
      ),
      StrongInline(:final children) => TextSpan(
        style: _mergeTextStyle(currentStyle, effectiveTheme.strongStyle),
        children: _buildInlineList(
          context,
          children,
          _mergeTextStyle(currentStyle, effectiveTheme.strongStyle),
          effectiveTheme,
          mappingBuilder,
        ),
      ),
      StrikethroughInline(:final children) => TextSpan(
        style: _mergeTextStyle(currentStyle, effectiveTheme.strikethroughStyle),
        children: _buildInlineList(
          context,
          children,
          _mergeTextStyle(currentStyle, effectiveTheme.strikethroughStyle),
          effectiveTheme,
          mappingBuilder,
        ),
      ),
      UnderlineInline(:final children) => TextSpan(
        style: _mergeTextStyle(currentStyle, effectiveTheme.underlineStyle),
        children: _buildInlineList(
          context,
          children,
          _mergeTextStyle(currentStyle, effectiveTheme.underlineStyle),
          effectiveTheme,
          mappingBuilder,
        ),
      ),
      SubscriptInline(:final children) => () {
        final subStyle = currentStyle.copyWith(
          fontSize: (currentStyle.fontSize ?? 15.0) * 0.78,
          fontFeatures: const [FontFeature.subscripts()],
        );
        return TextSpan(
          style: subStyle,
          children: _buildInlineList(
            context,
            children,
            subStyle,
            effectiveTheme,
            mappingBuilder,
          ),
        );
      }(),
      SuperscriptInline(:final children) => () {
        final supStyle = currentStyle.copyWith(
          fontSize: (currentStyle.fontSize ?? 15.0) * 0.78,
          fontFeatures: const [FontFeature.superscripts()],
        );
        return TextSpan(
          style: supStyle,
          children: _buildInlineList(
            context,
            children,
            supStyle,
            effectiveTheme,
            mappingBuilder,
          ),
        );
      }(),
      KeyboardInline(:final children) => () {
        final kbdStyle = effectiveTheme.keyboardStyle.resolveTextStyle(
          currentStyle,
        );
        return CodeTextSpan(
          style: kbdStyle,
          codeStyle: effectiveTheme.keyboardStyle,
          children: _buildInlineList(
            context,
            children,
            kbdStyle,
            effectiveTheme,
            mappingBuilder,
          ),
        );
      }(),
      InlineCodeInline(:final code) => () {
        final codeStyle = effectiveTheme.inlineCodeStyle;
        final resolvedStyle = codeStyle.resolveTextStyle(currentStyle);
        final customBuilder = builders.inlineCodeBuilder;
        if (customBuilder != null) {
          final span = customBuilder(context, code, resolvedStyle, codeStyle);
          mappingBuilder.addBuiltSpan(canonicalText: code, span: span);
          return span;
        }
        mappingBuilder.addOneToOne(code.length);
        return CodeTextSpan(
          text: code,
          style: resolvedStyle,
          codeStyle: codeStyle,
        );
      }(),
      LinkInline(:final destination, :final title, :final children) => () {
        final linkStyle = _mergeTextStyle(
          currentStyle,
          effectiveTheme.linkStyle,
        );
        final onTap = builders.onLinkTap != null
            ? () => builders.onLinkTap!(destination, title ?? '')
            : null;
        final customBuilder = builders.inlineLinkBuilder;
        if (customBuilder != null) {
          // Build label spans against an isolated builder so if the custom
          // link builder transforms or wraps them, offsets still stay exact.
          final scratch = TextOffsetMappingBuilder();
          final labelSpans = _buildInlineList(
            context,
            children,
            linkStyle,
            effectiveTheme,
            scratch,
          );
          final span = customBuilder(
            context,
            inline,
            labelSpans,
            linkStyle,
            onTap,
          );
          mappingBuilder.addBuiltSpan(
            canonicalText: extractInlineRenderedText(inline),
            span: span,
          );
          return span;
        }
        final labelSpans = _buildInlineList(
          context,
          children,
          linkStyle,
          effectiveTheme,
          mappingBuilder,
        );
        return TappableTextSpan(
          children: labelSpans,
          style: linkStyle,
          hoverStyle: effectiveTheme.linkHoverStyle,
          mouseCursor: onTap != null ? SystemMouseCursors.click : null,
          onTap: onTap,
        );
      }(),
      ImageInline(:final alt) => () {
        final imageWidget =
            builders.imageBuilder?.call(context, inline, effectiveTheme) ??
            _buildDefaultImage(inline, effectiveTheme);
        mappingBuilder.addAtomic(canonicalLength: alt.length, painterLength: 1);
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: imageWidget,
        );
      }(),
      LineBreakInline(:final isHard) => () {
        final text = isHard ? '\n' : ' ';
        mappingBuilder.addOneToOne(1);
        return TextSpan(text: text, style: currentStyle);
      }(),
      FootnoteRefInline() => () {
        final label = inline.displayLabel;
        mappingBuilder.addOneToOne(label.length);
        return TextSpan(
          text: label,
          style: _mergeTextStyle(
            currentStyle,
            effectiveTheme.footnoteStyle.refStyle,
          ),
        );
      }(),
      InlineLatexInline(:final expression) => () {
        final latexStyle = _mergeTextStyle(
          currentStyle,
          effectiveTheme.latexStyle.inlineStyle,
        );
        final customBuilder = builders.inlineLatexBuilder;
        if (customBuilder != null) {
          final span = customBuilder(context, inline, latexStyle);
          mappingBuilder.addBuiltSpan(canonicalText: expression, span: span);
          return span;
        }
        final formatted = formatLatexFallback(expression);
        if (formatted == expression) {
          mappingBuilder.addOneToOne(formatted.length);
        } else {
          mappingBuilder.addAtomic(
            canonicalLength: expression.length,
            painterLength: formatted.length,
          );
        }
        return TextSpan(text: formatted, style: latexStyle);
      }(),
      CustomInline(:final text) => () {
        final customBuilder = builders.customInlineBuilder;
        if (customBuilder != null) {
          final span = customBuilder(context, inline, currentStyle);
          mappingBuilder.addBuiltSpan(canonicalText: text, span: span);
          return span;
        }
        mappingBuilder.addOneToOne(text.length);
        return TextSpan(text: text, style: currentStyle);
      }(),
    };
  }

  Widget _buildDefaultImage(
    ImageInline image,
    MarkdownThemeData effectiveTheme,
  ) {
    final src = image.source;
    final isNetwork = src.startsWith('http://') || src.startsWith('https://');
    if (isNetwork) {
      return Image.network(
        src,
        semanticLabel: image.alt.isNotEmpty ? image.alt : null,
        errorBuilder: (context, error, stackTrace) {
          return _buildImageFallbackChip(image, effectiveTheme);
        },
      );
    }
    return _buildImageFallbackChip(image, effectiveTheme);
  }

  Widget _buildImageFallbackChip(
    ImageInline image,
    MarkdownThemeData effectiveTheme,
  ) {
    final label = image.alt.isNotEmpty ? image.alt : image.source;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveTheme.inlineCodeStyle.backgroundColor,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: effectiveTheme.dividerColor, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        child: Text(
          label.isNotEmpty ? label : 'image',
          // An inline widget is already drawn at the paragraph's text scale.
          textScaler: TextScaler.noScaling,
          style: effectiveTheme.bodyStyle.copyWith(
            fontSize: (effectiveTheme.bodyStyle.fontSize ?? 15.0) * 0.85,
          ),
        ),
      ),
    );
  }

  TextStyle _mergeTextStyle(TextStyle base, TextStyle overlay) {
    final merged = base.merge(overlay);
    final baseDec = base.decoration;
    final overlayDec = overlay.decoration;
    if (baseDec != null &&
        baseDec != TextDecoration.none &&
        overlayDec != null &&
        overlayDec != TextDecoration.none &&
        baseDec != overlayDec) {
      return merged.copyWith(
        decoration: TextDecoration.combine([baseDec, overlayDec]),
      );
    }
    return merged;
  }

  String _alertKindTitle(AlertKind kind) {
    return switch (kind) {
      AlertKind.note => 'NOTE',
      AlertKind.tip => 'TIP',
      AlertKind.important => 'IMPORTANT',
      AlertKind.warning => 'WARNING',
      AlertKind.caution => 'CAUTION',
    };
  }
}

/// Formats common LaTeX math commands into clean readable Unicode text when no
/// custom LaTeX renderer is provided.
String formatLatexFallback(String expression) {
  var out = expression.trim();
  if (out.isEmpty) return '';

  // Convert simple \frac{num}{den} into (num)/(den) or num/den.
  out = out.replaceAllMapped(_fracPattern, (match) {
    final num = match.group(1)!.trim();
    final den = match.group(2)!.trim();
    final numFormatted = num.length > 1 && num.contains(' ') ? '($num)' : num;
    final denFormatted = den.length > 1 && den.contains(' ') ? '($den)' : den;
    return '$numFormatted/$denFormatted';
  });

  // Replace known LaTeX control sequences with Unicode symbols.
  out = out.replaceAllMapped(_commandPattern, (match) {
    final cmd = match.group(1)!;
    return _latexSymbols[cmd] ?? match.group(0)!;
  });

  // Convert simple superscripts (^{...} or ^x) when every char has a Unicode
  // superscript glyph.
  out = out.replaceAllMapped(_superscriptPattern, (match) {
    final content = match.group(1) ?? match.group(2)!;
    final converted = _mapChars(content, _superscriptMap);
    return converted ?? match.group(0)!;
  });

  // Convert simple subscripts (_{...} or _x) when every char has a Unicode
  // subscript glyph.
  out = out.replaceAllMapped(_subscriptPattern, (match) {
    final content = match.group(1) ?? match.group(2)!;
    final converted = _mapChars(content, _subscriptMap);
    return converted ?? match.group(0)!;
  });

  return out;
}

String? _mapChars(String input, Map<String, String> table) {
  if (input.isEmpty) return null;
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final mapped = table[ch];
    if (mapped == null) return null;
    buffer.write(mapped);
  }
  return buffer.toString();
}

final RegExp _fracPattern = RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}');
final RegExp _commandPattern = RegExp(r'\\([A-Za-z]+)');
final RegExp _superscriptPattern = RegExp(r'\^\{([^{}]+)\}|\^([0-9+\-=()ni])');
final RegExp _subscriptPattern = RegExp(
  r'_\{([^{}]+)\}|_([0-9+\-=()aehijklmnoprstuvx])',
);

const Map<String, String> _latexSymbols = {
  'alpha': 'α',
  'beta': 'β',
  'gamma': 'γ',
  'delta': 'δ',
  'epsilon': 'ε',
  'varepsilon': 'ε',
  'zeta': 'ζ',
  'eta': 'η',
  'theta': 'θ',
  'iota': 'ι',
  'kappa': 'κ',
  'lambda': 'λ',
  'mu': 'μ',
  'nu': 'ν',
  'xi': 'ξ',
  'pi': 'π',
  'rho': 'ρ',
  'sigma': 'σ',
  'tau': 'τ',
  'upsilon': 'υ',
  'phi': 'φ',
  'varphi': 'φ',
  'chi': 'χ',
  'psi': 'ψ',
  'omega': 'ω',
  'Gamma': 'Γ',
  'Delta': 'Δ',
  'Theta': 'Θ',
  'Lambda': 'Λ',
  'Xi': 'Ξ',
  'Pi': 'Π',
  'Sigma': 'Σ',
  'Phi': 'Φ',
  'Psi': 'Ψ',
  'Omega': 'Ω',
  'times': '×',
  'div': '÷',
  'pm': '±',
  'mp': '∓',
  'cdot': '·',
  'neq': '≠',
  'ne': '≠',
  'leq': '≤',
  'le': '≤',
  'geq': '≥',
  'ge': '≥',
  'approx': '≈',
  'equiv': '≡',
  'sim': '∼',
  'propto': '∝',
  'infty': '∞',
  'sum': '∑',
  'prod': '∏',
  'int': '∫',
  'partial': '∂',
  'nabla': '∇',
  'sqrt': '√',
  'in': '∈',
  'notin': '∉',
  'subset': '⊂',
  'subseteq': '⊆',
  'supset': '⊃',
  'supseteq': '⊇',
  'cup': '∪',
  'cap': '∩',
  'emptyset': '∅',
  'forall': '∀',
  'exists': '∃',
  'neg': '¬',
  'land': '∧',
  'lor': '∨',
  'rightarrow': '→',
  'to': '→',
  'leftarrow': '←',
  'Rightarrow': '⇒',
  'Leftarrow': '⇐',
  'leftrightarrow': '↔',
  'Leftrightarrow': '⇔',
  'ldots': '…',
  'cdots': '⋯',
  'dots': '…',
};

const Map<String, String> _superscriptMap = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '+': '⁺',
  '-': '⁻',
  '=': '⁼',
  '(': '⁽',
  ')': '⁾',
  'n': 'ⁿ',
  'i': 'ⁱ',
};

const Map<String, String> _subscriptMap = {
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  '+': '₊',
  '-': '₋',
  '=': '₌',
  '(': '₍',
  ')': '₎',
  'a': 'ₐ',
  'e': 'ₑ',
  'h': 'ₕ',
  'i': 'ᵢ',
  'j': 'ⱼ',
  'k': 'ₖ',
  'l': 'ₗ',
  'm': 'ₘ',
  'n': 'ₙ',
  'o': 'ₒ',
  'p': 'ₚ',
  'r': 'ᵣ',
  's': 'ₛ',
  't': 'ₜ',
  'u': 'ᵤ',
  'v': 'ᵥ',
  'x': 'ₓ',
};

/// Pure-Canvas icon painter for default [AlertBlock] headers (no material
/// icon font dependency).
class _AlertGlyphPainter extends CustomPainter {
  const _AlertGlyphPainter({required this.kind, required this.color});

  final AlertKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 1.0;

    switch (kind) {
      case AlertKind.note:
      case AlertKind.important:
        canvas.drawCircle(center, radius, stroke);
        canvas.drawCircle(Offset(center.dx, size.height * 0.3), 1.0, fill);
        canvas.drawLine(
          Offset(center.dx, size.height * 0.48),
          Offset(center.dx, size.height * 0.75),
          stroke,
        );
      case AlertKind.tip:
        canvas.drawCircle(center, radius, stroke);
        final path = Path()
          ..moveTo(size.width * 0.28, size.height * 0.52)
          ..lineTo(size.width * 0.45, size.height * 0.68)
          ..lineTo(size.width * 0.74, size.height * 0.34);
        canvas.drawPath(path, stroke);
      case AlertKind.warning:
      case AlertKind.caution:
        final tri = Path()
          ..moveTo(size.width * 0.5, size.height * 0.12)
          ..lineTo(size.width * 0.9, size.height * 0.86)
          ..lineTo(size.width * 0.1, size.height * 0.86)
          ..close();
        canvas.drawPath(tri, stroke);
        canvas.drawLine(
          Offset(center.dx, size.height * 0.38),
          Offset(center.dx, size.height * 0.6),
          stroke,
        );
        canvas.drawCircle(Offset(center.dx, size.height * 0.74), 1.0, fill);
    }
  }

  @override
  bool shouldRepaint(_AlertGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
