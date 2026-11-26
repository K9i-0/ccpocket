import 'markdown_ast.dart';

/// Canonical plain-text extraction for a single [MarkdownInline] node.
///
/// Serves as the single source of truth for UTF-16 selection offsets across
/// both the selection engine and renderers.
String extractInlineRenderedText(MarkdownInline inline) {
  final buffer = StringBuffer();
  _writeInlineText(inline, buffer);
  return buffer.toString();
}

/// Canonical plain-text extraction for a list of [MarkdownInline] nodes.
String extractInlinesRenderedText(List<MarkdownInline> inlines) {
  if (inlines.isEmpty) return '';
  final buffer = StringBuffer();
  for (final inline in inlines) {
    _writeInlineText(inline, buffer);
  }
  return buffer.toString();
}

/// Canonical plain-text extraction for a single [ListItemNode].
String extractListItemRenderedText(ListItemNode item) {
  return _joinNonEmptyBlocks(item.children);
}

/// Canonical plain-text extraction for a single [TableRowNode].
///
/// Cells are separated by `\t`, preserving empty cells so column alignment
/// remains intact when copied.
String extractTableRowRenderedText(TableRowNode row) {
  if (row.cells.isEmpty) return '';
  return row.cells.map(extractInlinesRenderedText).join('\t');
}

/// Canonical plain-text extraction for a single [FootnoteDefinition].
String extractFootnoteDefinitionRenderedText(FootnoteDefinition definition) {
  return _joinNonEmptyBlocks(definition.children);
}

/// Canonical plain-text extraction for a single [MarkdownBlock].
///
/// Rules:
/// - [ParagraphBlock] / [HeadingBlock]: concatenated inline rendered text.
/// - [CodeBlock]: raw [CodeBlock.code] (no fence markers or language header).
/// - [ListBlock]: item texts joined by `\n` (no synthetic bullet/number glyph).
/// - [TableBlock]: cells joined by `\t`, header and body rows joined by `\n`.
/// - [BlockquoteBlock] / [AlertBlock]: non-empty child blocks joined by `\n`.
/// - [HtmlDetailsBlock]: optional summary text and non-empty child blocks
///   joined by `\n`.
/// - [ThematicBreakBlock]: empty string `''`.
/// - [FootnoteDefinitionsBlock]: non-empty definition texts joined by `\n`.
/// - [BlockLatexBlock]: [BlockLatexBlock.expression] fallback text.
String extractBlockRenderedText(MarkdownBlock block) {
  return switch (block) {
    ParagraphBlock(:final inlines) => extractInlinesRenderedText(inlines),
    HeadingBlock(:final inlines) => extractInlinesRenderedText(inlines),
    CodeBlock(:final code) => code,
    BlockquoteBlock(:final children) => _joinNonEmptyBlocks(children),
    AlertBlock(:final children) => _joinNonEmptyBlocks(children),
    ListBlock(:final items) => _joinNonEmptyStrings(
      items.map(extractListItemRenderedText),
    ),
    TableBlock(:final header, :final rows) => <String>[
      extractTableRowRenderedText(header),
      for (final row in rows) extractTableRowRenderedText(row),
    ].join('\n'),
    ThematicBreakBlock() => '',
    HtmlDetailsBlock(:final summary, :final children) => _joinNonEmptyStrings([
      extractInlinesRenderedText(summary),
      for (final child in children) extractBlockRenderedText(child),
    ]),
    FootnoteDefinitionsBlock(:final definitions) => _joinNonEmptyStrings(
      definitions.map(extractFootnoteDefinitionRenderedText),
    ),
    BlockLatexBlock(:final expression) => expression,
  };
}

/// Canonical plain-text extraction for an entire [MarkdownDocument].
///
/// Non-empty top-level blocks are joined by `\n\n`.
String extractDocumentRenderedText(MarkdownDocument document) {
  final parts = <String>[];
  for (final block in document.blocks) {
    final text = extractBlockRenderedText(block);
    if (text.isNotEmpty) {
      parts.add(text);
    }
  }
  return parts.join('\n\n');
}

String _joinNonEmptyBlocks(List<MarkdownBlock> blocks) {
  return _joinNonEmptyStrings(blocks.map(extractBlockRenderedText));
}

String _joinNonEmptyStrings(Iterable<String> parts) {
  final buffer = StringBuffer();
  var wroteAny = false;
  for (final part in parts) {
    if (part.isEmpty) continue;
    if (wroteAny) buffer.write('\n');
    buffer.write(part);
    wroteAny = true;
  }
  return buffer.toString();
}

void _writeInlineText(MarkdownInline inline, StringBuffer buffer) {
  switch (inline) {
    case TextInline(:final text):
      buffer.write(text);
    case EmphasisInline(:final children):
    case StrongInline(:final children):
    case StrikethroughInline(:final children):
    case UnderlineInline(:final children):
    case SubscriptInline(:final children):
    case SuperscriptInline(:final children):
    case KeyboardInline(:final children):
    case LinkInline(:final children):
      for (final child in children) {
        _writeInlineText(child, buffer);
      }
    case InlineCodeInline(:final code):
      buffer.write(code);
    case ImageInline(:final alt):
      buffer.write(alt);
    case LineBreakInline(:final isHard):
      buffer.write(isHard ? '\n' : ' ');
    case FootnoteRefInline():
      buffer.write(inline.displayLabel);
    case InlineLatexInline(:final expression):
      buffer.write(expression);
    case CustomInline(:final text):
      buffer.write(text);
  }
}
