import 'package:meta/meta.dart';

import '../ast/markdown_ast.dart';

/// A single match returned by [MarkdownInlineRule.matchAt].
@immutable
class MarkdownInlineMatch {
  const MarkdownInlineMatch({required this.end, required this.inline});

  /// Exclusive UTF-16 end index inside the scanned [TextInline.text] string.
  /// Must be strictly greater than the `index` passed to [MarkdownInlineRule.matchAt].
  final int end;

  /// Replacement inline AST node (typically [CustomInline] or [LinkInline]).
  final MarkdownInline inline;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownInlineMatch &&
        other.end == end &&
        other.inline == inline;
  }

  @override
  int get hashCode => Object.hash(end, inline);

  @override
  String toString() => 'MarkdownInlineMatch(end: $end, inline: $inline)';
}

/// Fast post-parse inline scanner rule.
///
/// Subclasses MUST either provide a non-empty [triggerCodeUnits] set OR
/// override [mayMatch] with a cheap pre-filter so ordinary prose skips regex
/// evaluation completely.
abstract class MarkdownInlineRule {
  const MarkdownInlineRule();

  /// Optional set of UTF-16 code units that can start a match.
  ///
  /// When non-null and non-empty, [MarkdownInlineScanner] only invokes
  /// [matchAt] at indices whose code unit is in this set.
  Set<int>? get triggerCodeUnits => null;

  /// Cheap per-[TextInline] pre-filter evaluated before scanning offsets.
  ///
  /// Return `false` to skip this rule completely for [text]. By default,
  /// inspects [triggerCodeUnits].
  bool mayMatch(String text) {
    final triggers = triggerCodeUnits;
    assert(
      triggers != null && triggers.isNotEmpty,
      'MarkdownInlineRule must either provide non-empty triggerCodeUnits '
      'or override mayMatch(String).',
    );
    if (triggers == null || triggers.isEmpty) return true;
    for (var i = 0; i < text.length; i++) {
      if (triggers.contains(text.codeUnitAt(i))) return true;
    }
    return false;
  }

  /// Attempts to match at UTF-16 [index] in [text].
  ///
  /// Returns a [MarkdownInlineMatch] with `end > index` on success, or `null`.
  MarkdownInlineMatch? matchAt(String text, int index);
}

/// Applies post-parse [MarkdownInlineRule]s across AST [TextInline] nodes
/// without ever modifying code spans ([InlineCodeInline], [CodeBlock]) or
/// existing link labels ([LinkInline]).
class MarkdownInlineScanner {
  const MarkdownInlineScanner(this.rules);

  final List<MarkdownInlineRule> rules;

  bool get isEmpty => rules.isEmpty;

  /// Scans [document] and returns either the identical instance (when no rules
  /// matched) or a new [MarkdownDocument] with matched nodes replaced.
  MarkdownDocument scanDocument(MarkdownDocument document) {
    if (rules.isEmpty || document.blocks.isEmpty) return document;
    final scanned = scanBlocks(document.blocks);
    if (identical(scanned, document.blocks)) return document;
    return MarkdownDocument(blocks: scanned, source: document.source);
  }

  /// Scans a list of [MarkdownBlock]s, preserving identity when unchanged.
  List<MarkdownBlock> scanBlocks(List<MarkdownBlock> blocks) {
    if (rules.isEmpty || blocks.isEmpty) return blocks;
    List<MarkdownBlock>? mutated;
    for (var i = 0; i < blocks.length; i++) {
      final original = blocks[i];
      final scanned = _scanBlock(original);
      if (!identical(scanned, original)) {
        mutated ??= blocks.sublist(0, i);
      }
      mutated?.add(scanned);
    }
    return mutated == null ? blocks : List.unmodifiable(mutated);
  }

  /// Scans a list of [MarkdownInline]s, preserving identity when unchanged.
  List<MarkdownInline> scanInlines(List<MarkdownInline> inlines) {
    if (rules.isEmpty || inlines.isEmpty) return inlines;
    List<MarkdownInline>? mutated;
    for (var i = 0; i < inlines.length; i++) {
      final original = inlines[i];
      switch (original) {
        case TextInline(:final text):
          final replacement = _scanText(text);
          if (replacement != null) {
            mutated ??= inlines.sublist(0, i);
            mutated.addAll(replacement);
          } else {
            mutated?.add(original);
          }
        case EmphasisInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(EmphasisInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        case StrongInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(StrongInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        case StrikethroughInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(StrikethroughInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        case UnderlineInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(UnderlineInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        case SubscriptInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(SubscriptInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        case SuperscriptInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(SuperscriptInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        case KeyboardInline(:final children):
          final scanned = scanInlines(children);
          if (!identical(scanned, children)) {
            mutated ??= inlines.sublist(0, i);
            mutated.add(KeyboardInline(children: scanned));
          } else {
            mutated?.add(original);
          }
        // Explicitly never touch code spans, link labels, images, breaks,
        // footnotes, inline math, or already-constructed custom nodes.
        case InlineCodeInline():
        case LinkInline():
        case ImageInline():
        case LineBreakInline():
        case FootnoteRefInline():
        case InlineLatexInline():
        case CustomInline():
          mutated?.add(original);
      }
    }
    return mutated == null ? inlines : List.unmodifiable(mutated);
  }

  MarkdownBlock _scanBlock(MarkdownBlock block) {
    return switch (block) {
      ParagraphBlock(:final inlines) => () {
        final scanned = scanInlines(inlines);
        return identical(scanned, inlines)
            ? block
            : ParagraphBlock(inlines: scanned);
      }(),
      HeadingBlock(:final level, :final inlines, :final id) => () {
        final scanned = scanInlines(inlines);
        return identical(scanned, inlines)
            ? block
            : HeadingBlock(level: level, inlines: scanned, id: id);
      }(),
      BlockquoteBlock(:final children) => () {
        final scanned = scanBlocks(children);
        return identical(scanned, children)
            ? block
            : BlockquoteBlock(children: scanned);
      }(),
      AlertBlock(:final kind, :final children) => () {
        final scanned = scanBlocks(children);
        return identical(scanned, children)
            ? block
            : AlertBlock(kind: kind, children: scanned);
      }(),
      ListBlock(:final ordered, :final start, :final tight, :final items) =>
        () {
          List<ListItemNode>? mutatedItems;
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            final scannedChildren = scanBlocks(item.children);
            if (!identical(scannedChildren, item.children)) {
              mutatedItems ??= items.sublist(0, i);
              mutatedItems.add(
                ListItemNode(children: scannedChildren, checked: item.checked),
              );
            } else {
              mutatedItems?.add(item);
            }
          }
          return mutatedItems == null
              ? block
              : ListBlock(
                  ordered: ordered,
                  start: start,
                  tight: tight,
                  items: List.unmodifiable(mutatedItems),
                );
        }(),
      TableBlock(:final alignments, :final header, :final rows) => () {
        final scannedHeader = _scanTableRow(header);
        var changed = !identical(scannedHeader, header);
        final scannedRows = <TableRowNode>[];
        for (final row in rows) {
          final scannedRow = _scanTableRow(row);
          if (!identical(scannedRow, row)) changed = true;
          scannedRows.add(scannedRow);
        }
        return !changed
            ? block
            : TableBlock(
                alignments: alignments,
                header: scannedHeader,
                rows: List.unmodifiable(scannedRows),
              );
      }(),
      HtmlDetailsBlock(:final summary, :final children, :final initiallyOpen) =>
        () {
          final scannedSummary = scanInlines(summary);
          final scannedChildren = scanBlocks(children);
          if (identical(scannedSummary, summary) &&
              identical(scannedChildren, children)) {
            return block;
          }
          return HtmlDetailsBlock(
            summary: scannedSummary,
            children: scannedChildren,
            initiallyOpen: initiallyOpen,
          );
        }(),
      FootnoteDefinitionsBlock(:final definitions) => () {
        List<FootnoteDefinition>? mutatedDefs;
        for (var i = 0; i < definitions.length; i++) {
          final def = definitions[i];
          final scannedChildren = scanBlocks(def.children);
          if (!identical(scannedChildren, def.children)) {
            mutatedDefs ??= definitions.sublist(0, i);
            mutatedDefs.add(
              FootnoteDefinition(
                label: def.label,
                index: def.index,
                children: scannedChildren,
              ),
            );
          } else {
            mutatedDefs?.add(def);
          }
        }
        return mutatedDefs == null
            ? block
            : FootnoteDefinitionsBlock(
                definitions: List.unmodifiable(mutatedDefs),
              );
      }(),
      // Never scan code blocks, thematic breaks, or display math.
      CodeBlock() || ThematicBreakBlock() || BlockLatexBlock() => block,
    };
  }

  TableRowNode _scanTableRow(TableRowNode row) {
    List<List<MarkdownInline>>? mutated;
    for (var i = 0; i < row.cells.length; i++) {
      final cell = row.cells[i];
      final scanned = scanInlines(cell);
      if (!identical(scanned, cell)) {
        mutated ??= row.cells.sublist(0, i);
      }
      mutated?.add(scanned);
    }
    return mutated == null
        ? row
        : TableRowNode(cells: List.unmodifiable(mutated));
  }

  List<MarkdownInline>? _scanText(String text) {
    if (text.isEmpty) return null;

    // Cheap per-segment pre-filter: skip scanning completely when no rule can
    // possibly match this text segment.
    List<MarkdownInlineRule>? activeRules;
    for (final rule in rules) {
      if (rule.mayMatch(text)) {
        (activeRules ??= <MarkdownInlineRule>[]).add(rule);
      }
    }
    if (activeRules == null) return null;

    List<MarkdownInline>? output;
    var plainStart = 0;
    var index = 0;

    while (index < text.length) {
      final codeUnit = text.codeUnitAt(index);
      MarkdownInlineMatch? matched;

      for (final rule in activeRules) {
        final triggers = rule.triggerCodeUnits;
        if (triggers != null && !triggers.contains(codeUnit)) continue;
        final candidate = rule.matchAt(text, index);
        if (candidate != null &&
            candidate.end > index &&
            candidate.end <= text.length) {
          matched = candidate;
          break;
        }
      }

      if (matched != null) {
        output ??= <MarkdownInline>[];
        if (index > plainStart) {
          output.add(TextInline(text.substring(plainStart, index)));
        }
        output.add(matched.inline);
        index = matched.end;
        plainStart = matched.end;
      } else {
        index++;
      }
    }

    if (output == null) return null;
    if (plainStart < text.length) {
      output.add(TextInline(text.substring(plainStart)));
    }
    return output;
  }
}
