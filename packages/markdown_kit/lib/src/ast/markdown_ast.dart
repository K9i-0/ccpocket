import 'package:meta/meta.dart';

/// Root AST node representing a parsed Markdown document.
@immutable
class MarkdownDocument {
  const MarkdownDocument({required this.blocks, this.source = ''});

  /// Empty document with no blocks.
  static const empty = MarkdownDocument(blocks: []);

  /// Top-level blocks in reading order.
  final List<MarkdownBlock> blocks;

  /// The Markdown source string that produced this document.
  final String source;

  bool get isEmpty => blocks.isEmpty;

  bool get isNotEmpty => blocks.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownDocument &&
        other.source == source &&
        _listEquals(other.blocks, blocks);
  }

  @override
  int get hashCode => Object.hash(source, Object.hashAll(blocks));

  @override
  String toString() =>
      'MarkdownDocument(blocks: ${blocks.length}, sourceLength: ${source.length})';
}

/// Base class for all block-level Markdown AST nodes.
@immutable
sealed class MarkdownBlock {
  const MarkdownBlock();
}

/// A paragraph consisting of inline nodes.
@immutable
final class ParagraphBlock extends MarkdownBlock {
  const ParagraphBlock({required this.inlines});

  final List<MarkdownInline> inlines;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParagraphBlock && _listEquals(other.inlines, inlines);
  }

  @override
  int get hashCode => Object.hash(ParagraphBlock, Object.hashAll(inlines));

  @override
  String toString() => 'ParagraphBlock(inlines: $inlines)';
}

/// An ATX or Setext heading (`h1` through `h6`).
@immutable
final class HeadingBlock extends MarkdownBlock {
  const HeadingBlock({required this.level, required this.inlines, this.id})
    : assert(level >= 1 && level <= 6);

  /// Heading level from 1 (`#`) to 6 (`######`).
  final int level;

  /// Inline contents of the heading.
  final List<MarkdownInline> inlines;

  /// Optional generated heading anchor identifier.
  final String? id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HeadingBlock &&
        other.level == level &&
        other.id == id &&
        _listEquals(other.inlines, inlines);
  }

  @override
  int get hashCode =>
      Object.hash(HeadingBlock, level, id, Object.hashAll(inlines));

  @override
  String toString() =>
      'HeadingBlock(level: $level, id: $id, inlines: $inlines)';
}

/// A fenced or indented code block.
@immutable
final class CodeBlock extends MarkdownBlock {
  const CodeBlock({
    required this.code,
    this.language,
    this.infoString,
    this.isFenced = true,
    this.closed = true,
  });

  /// Raw source text of the code block without fence delimiters.
  final String code;

  /// Primary language identifier parsed from the fence info string, if any.
  final String? language;

  /// Full trimmed fence info string, if any.
  final String? infoString;

  /// Whether this block originated from a fenced code block (vs indented).
  final bool isFenced;

  /// Whether the opening fence had a matching closing fence.
  ///
  /// During streaming, an active code block has `closed == false`, which lets
  /// syntax highlighters avoid polluting shared caches with partial code.
  final bool closed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CodeBlock &&
        other.code == code &&
        other.language == language &&
        other.infoString == infoString &&
        other.isFenced == isFenced &&
        other.closed == closed;
  }

  @override
  int get hashCode =>
      Object.hash(CodeBlock, code, language, infoString, isFenced, closed);

  @override
  String toString() =>
      'CodeBlock(language: $language, isFenced: $isFenced, closed: $closed, '
      'length: ${code.length})';
}

/// A standard blockquote containing nested blocks.
@immutable
final class BlockquoteBlock extends MarkdownBlock {
  const BlockquoteBlock({required this.children});

  final List<MarkdownBlock> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockquoteBlock && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(BlockquoteBlock, Object.hashAll(children));

  @override
  String toString() => 'BlockquoteBlock(children: $children)';
}

/// Semantic kind of a GitHub-Flavored Markdown alert callout.
enum AlertKind { note, tip, important, warning, caution }

/// A GitHub-Flavored Markdown alert (`> [!NOTE]`, `> [!TIP]`, etc.).
@immutable
final class AlertBlock extends MarkdownBlock {
  const AlertBlock({required this.kind, required this.children});

  final AlertKind kind;
  final List<MarkdownBlock> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlertBlock &&
        other.kind == kind &&
        _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(AlertBlock, kind, Object.hashAll(children));

  @override
  String toString() => 'AlertBlock(kind: $kind, children: $children)';
}

/// A single item inside a [ListBlock].
@immutable
class ListItemNode {
  const ListItemNode({required this.children, this.checked});

  /// Nested blocks inside this list item.
  final List<MarkdownBlock> children;

  /// Checkbox state for GFM task list items (`null` for regular items).
  final bool? checked;

  bool get isTaskItem => checked != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListItemNode &&
        other.checked == checked &&
        _listEquals(other.children, children);
  }

  @override
  int get hashCode =>
      Object.hash(ListItemNode, checked, Object.hashAll(children));

  @override
  String toString() => 'ListItemNode(checked: $checked, children: $children)';
}

/// An ordered, unordered, or task list.
@immutable
final class ListBlock extends MarkdownBlock {
  const ListBlock({
    required this.ordered,
    required this.items,
    this.start = 1,
    this.tight = true,
  });

  /// Whether items are numbered (`true`) or bulleted (`false`).
  final bool ordered;

  /// Starting number for ordered lists.
  final int start;

  /// Whether the list has no blank lines separating items.
  final bool tight;

  /// List items in reading order.
  final List<ListItemNode> items;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListBlock &&
        other.ordered == ordered &&
        other.start == start &&
        other.tight == tight &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode =>
      Object.hash(ListBlock, ordered, start, tight, Object.hashAll(items));

  @override
  String toString() =>
      'ListBlock(ordered: $ordered, start: $start, tight: $tight, items: $items)';
}

/// Horizontal column alignment inside a [TableBlock].
enum TableColumnAlign { none, left, center, right }

/// A single row of inline cell contents inside a [TableBlock].
@immutable
class TableRowNode {
  const TableRowNode({required this.cells});

  /// Inline nodes for each cell in column order.
  final List<List<MarkdownInline>> cells;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableRowNode || other.cells.length != cells.length) {
      return false;
    }
    for (var i = 0; i < cells.length; i++) {
      if (!_listEquals(other.cells[i], cells[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(TableRowNode, Object.hashAll(cells.map(Object.hashAll)));

  @override
  String toString() => 'TableRowNode(cells: $cells)';
}

/// A GitHub-Flavored Markdown table.
@immutable
final class TableBlock extends MarkdownBlock {
  const TableBlock({
    required this.alignments,
    required this.header,
    required this.rows,
  });

  final List<TableColumnAlign> alignments;
  final TableRowNode header;
  final List<TableRowNode> rows;

  int get columnCount => header.cells.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TableBlock &&
        other.header == header &&
        _listEquals(other.alignments, alignments) &&
        _listEquals(other.rows, rows);
  }

  @override
  int get hashCode => Object.hash(
    TableBlock,
    header,
    Object.hashAll(alignments),
    Object.hashAll(rows),
  );

  @override
  String toString() =>
      'TableBlock(columns: $columnCount, rows: ${rows.length})';
}

/// A thematic break / horizontal rule (`---`, `***`, `___`).
@immutable
final class ThematicBreakBlock extends MarkdownBlock {
  const ThematicBreakBlock();

  @override
  bool operator ==(Object other) => other is ThematicBreakBlock;

  @override
  int get hashCode => (ThematicBreakBlock).hashCode;

  @override
  String toString() => 'ThematicBreakBlock()';
}

/// An HTML `<details>` disclosure block with optional `<summary>` header.
@immutable
final class HtmlDetailsBlock extends MarkdownBlock {
  const HtmlDetailsBlock({
    required this.summary,
    required this.children,
    this.initiallyOpen = false,
  });

  /// Inline contents of `<summary>...</summary>`, empty when absent.
  final List<MarkdownInline> summary;

  /// Parsed Markdown blocks inside `<details>...</details>`.
  final List<MarkdownBlock> children;

  /// Whether the `<details>` element had the `open` attribute.
  final bool initiallyOpen;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HtmlDetailsBlock &&
        other.initiallyOpen == initiallyOpen &&
        _listEquals(other.summary, summary) &&
        _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(
    HtmlDetailsBlock,
    initiallyOpen,
    Object.hashAll(summary),
    Object.hashAll(children),
  );

  @override
  String toString() =>
      'HtmlDetailsBlock(initiallyOpen: $initiallyOpen, summary: $summary, '
      'children: $children)';
}

/// A single footnote definition (`[^label]: ...`).
@immutable
class FootnoteDefinition {
  const FootnoteDefinition({
    required this.label,
    required this.children,
    this.index,
  });

  /// Raw footnote identifier (without leading `^`).
  final String label;

  /// Parsed body blocks of the footnote.
  final List<MarkdownBlock> children;

  /// Optional 1-based ordinal assigned during document resolution.
  final int? index;

  /// Canonical bracketed display label (e.g. `[1]` or `[note]`).
  String get displayLabel => '[${index ?? label}]';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FootnoteDefinition &&
        other.label == label &&
        other.index == index &&
        _listEquals(other.children, children);
  }

  @override
  int get hashCode =>
      Object.hash(FootnoteDefinition, label, index, Object.hashAll(children));

  @override
  String toString() =>
      'FootnoteDefinition(label: $label, index: $index, children: $children)';
}

/// A section containing resolved footnote definitions for the document.
@immutable
final class FootnoteDefinitionsBlock extends MarkdownBlock {
  const FootnoteDefinitionsBlock({required this.definitions});

  final List<FootnoteDefinition> definitions;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FootnoteDefinitionsBlock &&
        _listEquals(other.definitions, definitions);
  }

  @override
  int get hashCode =>
      Object.hash(FootnoteDefinitionsBlock, Object.hashAll(definitions));

  @override
  String toString() => 'FootnoteDefinitionsBlock(definitions: $definitions)';
}

/// A display-mode LaTeX math block (`\[...\]` or opt-in `$$...$$`).
@immutable
final class BlockLatexBlock extends MarkdownBlock {
  const BlockLatexBlock({required this.expression, this.closed = true});

  /// Raw LaTeX expression without surrounding delimiters.
  final String expression;

  /// Whether the opening delimiter had a matching closing delimiter.
  final bool closed;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockLatexBlock &&
        other.expression == expression &&
        other.closed == closed;
  }

  @override
  int get hashCode => Object.hash(BlockLatexBlock, expression, closed);

  @override
  String toString() =>
      'BlockLatexBlock(expression: $expression, closed: $closed)';
}

/// Base class for all inline-level Markdown AST nodes.
@immutable
sealed class MarkdownInline {
  const MarkdownInline();
}

/// Plain literal text.
@immutable
final class TextInline extends MarkdownInline {
  const TextInline(this.text);

  final String text;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextInline && other.text == text;
  }

  @override
  int get hashCode => Object.hash(TextInline, text);

  @override
  String toString() => 'TextInline($text)';
}

/// Emphasized (italic) inline content.
@immutable
final class EmphasisInline extends MarkdownInline {
  const EmphasisInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmphasisInline && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(EmphasisInline, Object.hashAll(children));

  @override
  String toString() => 'EmphasisInline($children)';
}

/// Strongly emphasized (bold) inline content.
@immutable
final class StrongInline extends MarkdownInline {
  const StrongInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StrongInline && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(StrongInline, Object.hashAll(children));

  @override
  String toString() => 'StrongInline($children)';
}

/// Strikethrough inline content (`~~text~~`, `<s>`, `<del>`).
@immutable
final class StrikethroughInline extends MarkdownInline {
  const StrikethroughInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StrikethroughInline &&
        _listEquals(other.children, children);
  }

  @override
  int get hashCode =>
      Object.hash(StrikethroughInline, Object.hashAll(children));

  @override
  String toString() => 'StrikethroughInline($children)';
}

/// Underlined inline content (`<u>text</u>`).
@immutable
final class UnderlineInline extends MarkdownInline {
  const UnderlineInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnderlineInline && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(UnderlineInline, Object.hashAll(children));

  @override
  String toString() => 'UnderlineInline($children)';
}

/// Subscript inline content (`<sub>text</sub>`).
@immutable
final class SubscriptInline extends MarkdownInline {
  const SubscriptInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscriptInline && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(SubscriptInline, Object.hashAll(children));

  @override
  String toString() => 'SubscriptInline($children)';
}

/// Superscript inline content (`<sup>text</sup>`).
@immutable
final class SuperscriptInline extends MarkdownInline {
  const SuperscriptInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SuperscriptInline && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(SuperscriptInline, Object.hashAll(children));

  @override
  String toString() => 'SuperscriptInline($children)';
}

/// Keyboard input inline content (`<kbd>Ctrl</kbd>`).
@immutable
final class KeyboardInline extends MarkdownInline {
  const KeyboardInline({required this.children});

  final List<MarkdownInline> children;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyboardInline && _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(KeyboardInline, Object.hashAll(children));

  @override
  String toString() => 'KeyboardInline($children)';
}

/// Inline code span (`` `code` ``).
@immutable
final class InlineCodeInline extends MarkdownInline {
  const InlineCodeInline(this.code);

  final String code;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InlineCodeInline && other.code == code;
  }

  @override
  int get hashCode => Object.hash(InlineCodeInline, code);

  @override
  String toString() => 'InlineCodeInline($code)';
}

/// Hyperlink (`[label](destination "title")`, autolink, or `<a href=...>`).
@immutable
final class LinkInline extends MarkdownInline {
  const LinkInline({
    required this.destination,
    required this.children,
    this.title,
    this.isAutolink = false,
  });

  final String destination;
  final String? title;
  final List<MarkdownInline> children;
  final bool isAutolink;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LinkInline &&
        other.destination == destination &&
        other.title == title &&
        other.isAutolink == isAutolink &&
        _listEquals(other.children, children);
  }

  @override
  int get hashCode => Object.hash(
    LinkInline,
    destination,
    title,
    isAutolink,
    Object.hashAll(children),
  );

  @override
  String toString() =>
      'LinkInline(destination: $destination, title: $title, '
      'isAutolink: $isAutolink, children: $children)';
}

/// Inline image (`![alt](source "title")` or `<img src=...>`).
@immutable
final class ImageInline extends MarkdownInline {
  const ImageInline({required this.source, this.alt = '', this.title});

  final String source;
  final String alt;
  final String? title;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImageInline &&
        other.source == source &&
        other.alt == alt &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(ImageInline, source, alt, title);

  @override
  String toString() => 'ImageInline(source: $source, alt: $alt, title: $title)';
}

/// A hard (`<br>`, two trailing spaces, `\`) or soft line break.
@immutable
final class LineBreakInline extends MarkdownInline {
  const LineBreakInline({this.isHard = true});

  final bool isHard;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LineBreakInline && other.isHard == isHard;
  }

  @override
  int get hashCode => Object.hash(LineBreakInline, isHard);

  @override
  String toString() => 'LineBreakInline(isHard: $isHard)';
}

/// Inline reference to a footnote (`[^1]`).
@immutable
final class FootnoteRefInline extends MarkdownInline {
  const FootnoteRefInline({required this.label, this.index});

  /// Raw footnote identifier (without leading `^`).
  final String label;

  /// Resolved 1-based ordinal when a matching definition exists.
  final int? index;

  /// Canonical rendered label used by both renderers and selection text.
  String get displayLabel => '[${index ?? label}]';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FootnoteRefInline &&
        other.label == label &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(FootnoteRefInline, label, index);

  @override
  String toString() => 'FootnoteRefInline(label: $label, index: $index)';
}

/// Inline LaTeX math expression (`\(...\)` or opt-in `$...$`).
@immutable
final class InlineLatexInline extends MarkdownInline {
  const InlineLatexInline(this.expression);

  /// Raw LaTeX expression without surrounding delimiters.
  final String expression;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InlineLatexInline && other.expression == expression;
  }

  @override
  int get hashCode => Object.hash(InlineLatexInline, expression);

  @override
  String toString() => 'InlineLatexInline($expression)';
}

/// Extension inline node produced by custom [MarkdownInlineRule] scanners.
@immutable
final class CustomInline extends MarkdownInline {
  const CustomInline({
    required this.kind,
    required this.text,
    this.data = const {},
  });

  /// Application-defined discriminator (e.g. `'file_path'`, `'color_code'`).
  final String kind;

  /// Canonical plain text represented by this inline node.
  final String text;

  /// Optional structured metadata for custom inline builders.
  final Map<String, Object?> data;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomInline &&
        other.kind == kind &&
        other.text == text &&
        _mapEquals(other.data, data);
  }

  @override
  int get hashCode => Object.hash(
    CustomInline,
    kind,
    text,
    Object.hashAllUnordered(
      data.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'CustomInline(kind: $kind, text: $text, data: $data)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
