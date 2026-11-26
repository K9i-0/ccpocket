import 'dart:math' as math;

import '../ast/markdown_ast.dart';
import 'selection_model.dart';

/// Formats a [MarkdownSelectedContent] snapshot as clean plain text.
///
/// Structural empty blocks (such as [ThematicBreakBlock]) are omitted.
/// List items and table rows already preserve `\n` and `\t` separators in
/// canonical rendered text ([MarkdownSelectedBlock.fullText]).
class MarkdownPlainTextFormatter implements MarkdownSelectionFormatter {
  const MarkdownPlainTextFormatter({
    this.blockSeparator = '\n\n',
    this.documentSeparator = '\n\n',
  });

  /// Separator inserted between non-empty blocks within the same document.
  final String blockSeparator;

  /// Separator inserted between non-empty documents in cross-document copies.
  final String documentSeparator;

  @override
  String format(MarkdownSelectedContent content) {
    if (content.isEmpty) return '';

    final docParts = <String>[];
    for (final doc in content.documents) {
      final blockParts = <String>[];
      for (final selectedBlock in doc.blocks) {
        if (selectedBlock.isEmpty) continue;
        final text = selectedBlock.selectedText;
        if (text.isEmpty) continue;
        blockParts.add(text);
      }
      if (blockParts.isNotEmpty) {
        docParts.add(blockParts.join(blockSeparator));
      }
    }
    return docParts.join(documentSeparator);
  }
}

/// Formats a [MarkdownSelectedContent] snapshot as reconstructed Markdown.
///
/// Fully selected blocks are serialized back into canonical GFM Markdown
/// syntax (`#` headings, `>` blockquotes, `> [!NOTE]` alerts, fenced code
/// blocks, nested lists & task lists, pipe tables, `---`, `<details>`, `$$`
/// block math, and footnote definitions). Partially selected boundary blocks
/// safely fall back to their sliced plain text so unselected text never leaks.
class MarkdownMarkupFormatter implements MarkdownSelectionFormatter {
  const MarkdownMarkupFormatter({
    this.blockSeparator = '\n\n',
    this.documentSeparator = '\n\n',
    this.listIndent = '  ',
  });

  /// Separator inserted between formatted blocks within the same document.
  final String blockSeparator;

  /// Separator inserted between formatted documents in cross-document copies.
  final String documentSeparator;

  /// Indentation string used for continuation blocks of bullet list items and
  /// footnote definitions.
  ///
  /// Ordered list items always indent by the width of their own marker
  /// (`1. ` is three columns, `10. ` four) because CommonMark only treats
  /// content indented at least that far as belonging to the item.
  final String listIndent;

  @override
  String format(MarkdownSelectedContent content) {
    if (content.isEmpty) return '';

    final docParts = <String>[];
    for (final doc in content.documents) {
      final blockParts = <String>[];
      for (final selectedBlock in doc.blocks) {
        final formatted = _formatSelectedBlock(selectedBlock);
        if (formatted.isNotEmpty) {
          blockParts.add(formatted);
        }
      }
      if (blockParts.isNotEmpty) {
        docParts.add(blockParts.join(blockSeparator));
      }
    }
    return docParts.join(documentSeparator);
  }

  String _formatSelectedBlock(MarkdownSelectedBlock selectedBlock) {
    if (selectedBlock.isPartial) {
      return selectedBlock.selectedText;
    }
    return _formatBlock(selectedBlock.block);
  }

  String _formatBlock(MarkdownBlock block) {
    return switch (block) {
      ParagraphBlock(:final inlines) => _formatInlines(inlines),
      HeadingBlock(:final level, :final inlines) => _formatHeading(
        level,
        inlines,
      ),
      CodeBlock(:final code, :final language, :final infoString) =>
        _formatCodeBlock(code, language: language, infoString: infoString),
      BlockquoteBlock(:final children) => _formatBlockquote(children),
      AlertBlock(:final kind, :final children) => _formatAlert(kind, children),
      ListBlock(:final ordered, :final start, :final tight, :final items) =>
        _formatList(ordered: ordered, start: start, tight: tight, items: items),
      TableBlock(:final alignments, :final header, :final rows) => _formatTable(
        alignments: alignments,
        header: header,
        rows: rows,
      ),
      ThematicBreakBlock() => '---',
      HtmlDetailsBlock(:final summary, :final children, :final initiallyOpen) =>
        _formatDetails(
          summary: summary,
          children: children,
          initiallyOpen: initiallyOpen,
        ),
      FootnoteDefinitionsBlock(:final definitions) => _formatFootnotes(
        definitions,
      ),
      BlockLatexBlock(:final expression) => _formatBlockLatex(expression),
    };
  }

  String _formatHeading(int level, List<MarkdownInline> inlines) {
    final prefix = '#' * level;
    // An ATX heading is a single line; a line break inside it (from a
    // multi-line setext heading) would cut the heading short.
    final body = _formatInlines(inlines).replaceAll(_lineBreakInHeading, ' ');
    return body.isEmpty ? prefix : '$prefix $body';
  }

  String _formatCodeBlock(String code, {String? language, String? infoString}) {
    final maxRun = _longestBacktickRun(code);
    final fence = '`' * math.max(3, maxRun + 1);
    final info = (infoString != null && infoString.isNotEmpty)
        ? infoString
        : (language ?? '');
    if (code.isEmpty) {
      return '$fence$info\n$fence';
    }
    if (code.endsWith('\n')) {
      return '$fence$info\n$code$fence';
    }
    return '$fence$info\n$code\n$fence';
  }

  String _formatBlockquote(List<MarkdownBlock> children) {
    final inner = _formatChildBlocks(children);
    if (inner.isEmpty) return '>';
    return _prefixLines(inner, '> ', emptyLinePrefix: '>');
  }

  String _formatAlert(AlertKind kind, List<MarkdownBlock> children) {
    final tag = switch (kind) {
      AlertKind.note => 'NOTE',
      AlertKind.tip => 'TIP',
      AlertKind.important => 'IMPORTANT',
      AlertKind.warning => 'WARNING',
      AlertKind.caution => 'CAUTION',
    };
    final header = '> [!$tag]';
    final inner = _formatChildBlocks(children);
    if (inner.isEmpty) return header;
    final body = _prefixLines(inner, '> ', emptyLinePrefix: '>');
    return '$header\n$body';
  }

  String _formatList({
    required bool ordered,
    required int start,
    required bool tight,
    required List<ListItemNode> items,
  }) {
    if (items.isEmpty) return '';
    final itemJoin = tight ? '\n' : '\n\n';
    final formattedItems = <String>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final baseMarker = ordered ? '${start + i}. ' : '- ';
      final taskMarker = switch (item.checked) {
        true => '[x] ',
        false => '[ ] ',
        null => '',
      };
      final marker = '$baseMarker$taskMarker';
      formattedItems.add(
        _formatListItem(
          marker,
          item,
          tight: tight,
          indent: ordered ? ' ' * baseMarker.length : listIndent,
        ),
      );
    }
    return formattedItems.join(itemJoin);
  }

  String _formatListItem(
    String marker,
    ListItemNode item, {
    required bool tight,
    required String indent,
  }) {
    if (item.children.isEmpty) {
      return marker.trimRight();
    }

    final buffer = StringBuffer();
    for (var i = 0; i < item.children.length; i++) {
      final child = item.children[i];
      final formatted = _formatBlock(child);
      if (i == 0) {
        if (child is ListBlock) {
          buffer.write(marker.trimRight());
          if (formatted.isNotEmpty) {
            buffer.write('\n');
            buffer.write(_prefixLines(formatted, indent));
          }
        } else {
          final lines = formatted.split('\n');
          buffer.write(marker);
          buffer.write(lines.first);
          for (var lineIdx = 1; lineIdx < lines.length; lineIdx++) {
            buffer.write('\n');
            final line = lines[lineIdx];
            if (line.isNotEmpty) {
              buffer.write(indent);
              buffer.write(line);
            }
          }
        }
      } else {
        if (formatted.isEmpty) continue;
        final needsBlankLine = !tight && child is! ListBlock;
        buffer.write(needsBlankLine ? '\n\n' : '\n');
        buffer.write(_prefixLines(formatted, indent));
      }
    }
    return buffer.toString();
  }

  String _formatTable({
    required List<TableColumnAlign> alignments,
    required TableRowNode header,
    required List<TableRowNode> rows,
  }) {
    var colCount = math.max(header.cells.length, alignments.length);
    for (final row in rows) {
      colCount = math.max(colCount, row.cells.length);
    }
    if (colCount == 0) return '';

    String formatRow(TableRowNode row) {
      final cells = <String>[];
      for (var c = 0; c < colCount; c++) {
        if (c < row.cells.length) {
          cells.add(_formatTableCell(row.cells[c]));
        } else {
          cells.add('');
        }
      }
      return '| ${cells.join(' | ')} |';
    }

    final alignCells = <String>[];
    for (var c = 0; c < colCount; c++) {
      final align = c < alignments.length
          ? alignments[c]
          : TableColumnAlign.none;
      alignCells.add(switch (align) {
        TableColumnAlign.none => '---',
        TableColumnAlign.left => ':---',
        TableColumnAlign.center => ':---:',
        TableColumnAlign.right => '---:',
      });
    }

    final lines = <String>[
      formatRow(header),
      '| ${alignCells.join(' | ')} |',
      for (final row in rows) formatRow(row),
    ];
    return lines.join('\n');
  }

  String _formatTableCell(List<MarkdownInline> inlines) {
    final raw = _formatInlines(inlines);
    return raw.replaceAll('|', r'\|').replaceAll('\n', '<br>');
  }

  String _formatDetails({
    required List<MarkdownInline> summary,
    required List<MarkdownBlock> children,
    required bool initiallyOpen,
  }) {
    final openTag = initiallyOpen ? '<details open>' : '<details>';
    final summaryText = _formatInlines(summary);
    final bodyText = _formatChildBlocks(children);

    final buffer = StringBuffer(openTag);
    if (summaryText.isNotEmpty) {
      buffer.write('\n<summary>$summaryText</summary>');
    }
    if (bodyText.isNotEmpty) {
      buffer.write('\n\n$bodyText');
    }
    buffer.write('\n</details>');
    return buffer.toString();
  }

  String _formatFootnotes(List<FootnoteDefinition> definitions) {
    if (definitions.isEmpty) return '';
    final parts = <String>[];
    var hasMultiLine = false;
    for (final def in definitions) {
      final body = _formatChildBlocks(def.children);
      if (body.contains('\n')) {
        hasMultiLine = true;
      }
      final lines = body.split('\n');
      final buffer = StringBuffer('[^${def.label}]:');
      if (lines.first.isNotEmpty) {
        buffer.write(' ${lines.first}');
      }
      for (var i = 1; i < lines.length; i++) {
        buffer.write('\n');
        if (lines[i].isNotEmpty) {
          buffer.write(listIndent);
          buffer.write(lines[i]);
        }
      }
      parts.add(buffer.toString());
    }
    return parts.join(hasMultiLine ? '\n\n' : '\n');
  }

  String _formatBlockLatex(String expression) {
    if (expression.isEmpty) return '\$\$\n\$\$';
    final trimmed = expression.endsWith('\n')
        ? expression.substring(0, expression.length - 1)
        : expression;
    return '\$\$\n$trimmed\n\$\$';
  }

  String _formatChildBlocks(List<MarkdownBlock> children) {
    final parts = <String>[];
    for (final child in children) {
      final formatted = _formatBlock(child);
      if (formatted.isNotEmpty) {
        parts.add(formatted);
      }
    }
    return parts.join(blockSeparator);
  }

  String _formatInlines(List<MarkdownInline> inlines) {
    if (inlines.isEmpty) return '';
    final buffer = StringBuffer();
    for (final inline in inlines) {
      _writeInline(inline, buffer);
    }
    return buffer.toString();
  }

  void _writeInline(MarkdownInline inline, StringBuffer buffer) {
    switch (inline) {
      case TextInline(:final text):
        buffer.write(text);
      case EmphasisInline(:final children):
        buffer.write('*');
        buffer.write(_formatInlines(children));
        buffer.write('*');
      case StrongInline(:final children):
        buffer.write('**');
        buffer.write(_formatInlines(children));
        buffer.write('**');
      case StrikethroughInline(:final children):
        buffer.write('~~');
        buffer.write(_formatInlines(children));
        buffer.write('~~');
      case UnderlineInline(:final children):
        buffer.write('<u>');
        buffer.write(_formatInlines(children));
        buffer.write('</u>');
      case SubscriptInline(:final children):
        buffer.write('<sub>');
        buffer.write(_formatInlines(children));
        buffer.write('</sub>');
      case SuperscriptInline(:final children):
        buffer.write('<sup>');
        buffer.write(_formatInlines(children));
        buffer.write('</sup>');
      case KeyboardInline(:final children):
        buffer.write('<kbd>');
        buffer.write(_formatInlines(children));
        buffer.write('</kbd>');
      case InlineCodeInline(:final code):
        buffer.write(_formatInlineCode(code));
      case LinkInline(
        :final destination,
        :final title,
        :final children,
        :final isAutolink,
      ):
        final label = _formatInlines(children);
        if (isAutolink && label == destination && title == null) {
          buffer.write('<$destination>');
        } else if (title != null && title.isNotEmpty) {
          final escapedTitle = title.replaceAll('"', r'\"');
          buffer.write('[$label]($destination "$escapedTitle")');
        } else {
          buffer.write('[$label]($destination)');
        }
      case ImageInline(:final source, :final alt, :final title):
        if (title != null && title.isNotEmpty) {
          final escapedTitle = title.replaceAll('"', r'\"');
          buffer.write('![$alt]($source "$escapedTitle")');
        } else {
          buffer.write('![$alt]($source)');
        }
      case LineBreakInline(:final isHard):
        buffer.write(isHard ? '  \n' : '\n');
      case FootnoteRefInline(:final label):
        buffer.write('[^$label]');
      case InlineLatexInline(:final expression):
        buffer.write('\$$expression\$');
      case CustomInline(:final text):
        buffer.write(text);
    }
  }

  String _formatInlineCode(String code) {
    final delim = '`' * (_longestBacktickRun(code) + 1);
    final startsOrEndsWithTick = code.startsWith('`') || code.endsWith('`');
    final startsAndEndsWithSpace =
        code.length >= 2 &&
        code.startsWith(' ') &&
        code.endsWith(' ') &&
        code.trim().isNotEmpty;
    if (startsOrEndsWithTick || startsAndEndsWithSpace) {
      return '$delim $code $delim';
    }
    return '$delim$code$delim';
  }

  int _longestBacktickRun(String text) {
    var longest = 0;
    var current = 0;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x60) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  String _prefixLines(
    String text,
    String prefix, {
    String emptyLinePrefix = '',
  }) {
    final lines = text.split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) buffer.write('\n');
      final line = lines[i];
      if (line.isEmpty) {
        buffer.write(emptyLinePrefix);
      } else {
        buffer.write(prefix);
        buffer.write(line);
      }
    }
    return buffer.toString();
  }
}

final _lineBreakInHeading = RegExp(r' *\n');
