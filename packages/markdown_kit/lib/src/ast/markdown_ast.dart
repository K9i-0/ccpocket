import 'package:meta/meta.dart';

/// A half-open range `[start, end)` of UTF-16 offsets into
/// [MarkdownDocument.source].
@immutable
class MarkdownSourceRange {
  /// Creates the range from [start] up to, but not including, [end].
  const MarkdownSourceRange(this.start, this.end)
    : assert(start >= 0),
      assert(end >= start);

  /// Offset of the first code unit.
  final int start;

  /// Offset one past the last code unit.
  final int end;

  /// Number of code units covered.
  int get length => end - start;

  /// Whether [offset] lies inside the range.
  bool contains(int offset) => offset >= start && offset < end;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownSourceRange &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'MarkdownSourceRange($start, $end)';
}

/// Root AST node representing a parsed Markdown document.
@immutable
class MarkdownDocument {
  /// Creates a document from already-parsed [blocks].
  ///
  /// [blockSourceRanges], when given, must have one entry per block.
  const MarkdownDocument({
    required this.blocks,
    this.source = '',
    this.blockSourceRanges,
  });

  /// Empty document with no blocks.
  static const empty = MarkdownDocument(blocks: []);

  /// Top-level blocks in reading order.
  final List<MarkdownBlock> blocks;

  /// The Markdown source string that produced this document.
  final String source;

  /// Where each of [blocks] came from in [source], or null when the document
  /// was not produced by a parser that records it.
  ///
  /// This is what links a position in the source to a block on screen, for
  /// example to keep an editor and its preview scrolled to the same place.
  ///
  /// The ranges are as fine as the parser can split the source without
  /// changing the result, which is coarser than one block in two cases:
  ///
  /// - Blocks with no blank line between them (a heading directly followed by
  ///   its paragraph) share one range covering all of them.
  /// - In a document with link reference definitions, footnote definitions or
  ///   a raw HTML block that may span blank lines, every block shares one
  ///   range covering the whole source.
  ///
  /// Blocks that share a range refer to the same instance. A range includes
  /// the blank lines that follow its blocks. Ranges are in source order and do
  /// not overlap, but source that produces no block (a comment) is in none.
  ///
  /// Not part of `==`: the ranges are derived from [source].
  final List<MarkdownSourceRange>? blockSourceRanges;

  /// Whether the document has no blocks.
  bool get isEmpty => blocks.isEmpty;

  /// Whether the document has at least one block.
  bool get isNotEmpty => blocks.isNotEmpty;

  /// Index of the first block made from the source at [sourceOffset], or null
  /// when [blockSourceRanges] is null or the document is empty.
  ///
  /// An offset in source that produced no block maps to the next block, and an
  /// offset past the last range to the last block.
  int? blockIndexAtSourceOffset(int sourceOffset) {
    final ranges = blockSourceRanges;
    if (ranges == null || ranges.isEmpty) return null;
    // First range that ends after the offset.
    var low = 0;
    var high = ranges.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (ranges[middle].end > sourceOffset) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    return low < ranges.length ? low : ranges.length - 1;
  }

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
  /// Creates a paragraph.
  const ParagraphBlock({required this.inlines});

  /// Inline contents of the paragraph.
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
  /// Creates a heading. [level] must be between 1 and 6.
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
  /// Creates a code block.
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
  /// Creates a blockquote.
  const BlockquoteBlock({required this.children});

  /// The quoted blocks, in reading order.
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
enum AlertKind {
  /// `> [!NOTE]`: information worth knowing even when skimming.
  note,

  /// `> [!TIP]`: optional advice that helps the reader.
  tip,

  /// `> [!IMPORTANT]`: information the reader needs in order to succeed.
  important,

  /// `> [!WARNING]`: something that needs attention to avoid a problem.
  warning,

  /// `> [!CAUTION]`: a risk or negative outcome of an action.
  caution,
}

/// A GitHub-Flavored Markdown alert (`> [!NOTE]`, `> [!TIP]`, etc.).
@immutable
final class AlertBlock extends MarkdownBlock {
  /// Creates an alert.
  const AlertBlock({required this.kind, required this.children});

  /// Which of the five GitHub alert types this is. It selects the title, icon
  /// and colors the alert is rendered with.
  final AlertKind kind;

  /// The alert's content, without the `[!NOTE]`-style marker line.
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
  /// Creates a list item.
  const ListItemNode({required this.children, this.checked});

  /// Nested blocks inside this list item.
  final List<MarkdownBlock> children;

  /// Checkbox state for GFM task list items (`null` for regular items).
  final bool? checked;

  /// Whether this is a GFM task list item (`- [ ]` or `- [x]`), drawn with a
  /// checkbox instead of a bullet or number.
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
  /// Creates a list.
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
enum TableColumnAlign {
  /// No alignment given (`---`). Cells align to the start of the text
  /// direction.
  none,

  /// Left-aligned (`:---`).
  left,

  /// Centered (`:---:`).
  center,

  /// Right-aligned (`---:`).
  right,
}

/// A single row of inline cell contents inside a [TableBlock].
@immutable
class TableRowNode {
  /// Creates a table row.
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
  /// Creates a table.
  const TableBlock({
    required this.alignments,
    required this.header,
    required this.rows,
  });

  /// Alignment of each column, in column order, taken from the delimiter row. A
  /// column beyond the end of this list is treated as [TableColumnAlign.none].
  final List<TableColumnAlign> alignments;

  /// The header row.
  final TableRowNode header;

  /// The body rows, in reading order. A row may have fewer or more cells than
  /// the header.
  final List<TableRowNode> rows;

  /// Number of cells in the header row.
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
  /// Creates a thematic break.
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
  /// Creates a details block.
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
  /// Creates a footnote definition.
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
  /// Creates a footnote section.
  const FootnoteDefinitionsBlock({required this.definitions});

  /// The footnote definitions, in the order they are displayed.
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
  /// Creates a display-mode LaTeX block.
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
  /// Creates a text node.
  const TextInline(this.text);

  /// The literal text.
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
  /// Creates an emphasis node.
  const EmphasisInline({required this.children});

  /// The emphasized content.
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
  /// Creates a strong emphasis node.
  const StrongInline({required this.children});

  /// The strongly emphasized content.
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
  /// Creates a strikethrough node.
  const StrikethroughInline({required this.children});

  /// The struck-through content.
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
  /// Creates an underline node.
  const UnderlineInline({required this.children});

  /// The underlined content.
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
  /// Creates a subscript node.
  const SubscriptInline({required this.children});

  /// The subscript content.
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
  /// Creates a superscript node.
  const SuperscriptInline({required this.children});

  /// The superscript content.
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
  /// Creates a keyboard input node.
  const KeyboardInline({required this.children});

  /// The content of the keycap.
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
  /// Creates an inline code span.
  const InlineCodeInline(this.code);

  /// The code, without the surrounding backticks.
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
  /// Creates a link.
  const LinkInline({
    required this.destination,
    required this.children,
    this.title,
    this.isAutolink = false,
  });

  /// Where the link points: a URL, a relative path or an anchor. It is passed
  /// unchanged to `MarkdownBuilders.onLinkTap`.
  final String destination;

  /// The optional link title (`[label](destination "title")`), or null when
  /// none was given.
  final String? title;

  /// The link's label.
  final List<MarkdownInline> children;

  /// Whether the link's label is its own address, as in
  /// `<https://example.com>` or a bare `www.example.com`, rather than separate
  /// link text.
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
  /// Creates an image.
  const ImageInline({required this.source, this.alt = '', this.title});

  /// Where the image comes from: a URL or a path.
  final String source;

  /// The alternative text, empty when none was given. It stands in for the
  /// image in selected and copied text.
  final String alt;

  /// The optional image title (`![alt](source "title")`), or null when none was
  /// given.
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
  /// Creates a line break, hard by default.
  const LineBreakInline({this.isHard = true});

  /// Whether this is a hard break, rendered as a new line. A soft break (a
  /// plain newline in the source) is rendered as a space.
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
  /// Creates a footnote reference.
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
  /// Creates an inline LaTeX expression.
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
  /// Creates a custom inline node of the given [kind].
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
