import 'package:markdown/markdown.dart' as md;
import 'package:meta/meta.dart';

import '../ast/markdown_ast.dart';
import 'block_splitter.dart';
import 'inline_scanner.dart';
import 'markdown_parser.dart';

/// Default GitHub-Flavored Markdown parser wrapping `package:markdown`.
///
/// Supports:
/// - Full GFM blocks and inlines (headings, paragraphs, fenced/indented code,
///   blockquotes, ordered/unordered/task lists, tables, thematic breaks,
///   strikethrough, autolinks, inline code, links, images).
/// - GFM alert callouts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`,
///   `> [!WARNING]`, `> [!CAUTION]`).
/// - Common HTML tags (`<br>`, `<details>/<summary>`, `<b>`/`<strong>`,
///   `<i>`/`<em>`, `<u>`, `<s>`/`<del>`, `<sub>`, `<sup>`, `<kbd>`, `<a>`,
///   `<img>`).
/// - Footnotes (`[^1]` / `[^1]: ...`).
/// - LaTeX (`\(...\)`, `\[...\]`, and opt-in `$...$` / `$$...$$`).
/// - Post-parse [MarkdownInlineRule] scanning.
/// - Bounded LRU AST cache (default 256 entries) plus block-level incremental
///   caching for streaming performance without thrashing completed documents.
class GfmMarkdownParser implements MarkdownParser {
  GfmMarkdownParser({
    this.options = const MarkdownParserOptions(),
    int maxCacheEntries = 256,
    int maxBlockCacheEntries = 512,
  }) : _documentCache = BoundedLruCache<String, MarkdownDocument>(
         maxEntries: maxCacheEntries,
       ),
       _blockCache = BoundedLruCache<String, List<MarkdownBlock>>(
         maxEntries: maxBlockCacheEntries,
       ),
       _scanner = MarkdownInlineScanner(options.inlineRules);

  final MarkdownParserOptions options;
  final BoundedLruCache<String, MarkdownDocument> _documentCache;
  final BoundedLruCache<String, List<MarkdownBlock>> _blockCache;
  final MarkdownInlineScanner _scanner;

  // Dedicated streaming slots prevent intermediate streaming frames from
  // evicting completed documents/blocks out of the shared LRU caches.
  String? _lastStreamingSource;
  MarkdownDocument? _lastStreamingDoc;
  String? _lastStreamingTailChunk;
  List<MarkdownBlock>? _lastStreamingTailBlocks;

  /// Number of entries currently stored in the document-level LRU cache.
  int get documentCacheLength => _documentCache.length;

  /// Number of entries currently stored in the block-level LRU cache.
  int get blockCacheLength => _blockCache.length;

  /// Number of source pieces shown as raw text because `package:markdown`
  /// rejected them. Tests use it to tell a real parse from a degraded one,
  /// since [parse] itself never throws.
  @visibleForTesting
  int get rawTextFallbackCount => _rawTextFallbackCount;
  int _rawTextFallbackCount = 0;

  /// Clears all document and block caches.
  void clearCache() {
    _documentCache.clear();
    _blockCache.clear();
    _lastStreamingSource = null;
    _lastStreamingDoc = null;
    _lastStreamingTailChunk = null;
    _lastStreamingTailBlocks = null;
  }

  @override
  MarkdownDocument parse(String markdown, {bool isStreaming = false}) {
    final effectiveSource = isStreaming
        ? sanitizeStreamingTail(markdown)
        : markdown;

    if (effectiveSource.isEmpty) {
      return MarkdownDocument.empty;
    }

    if (isStreaming && _lastStreamingSource == effectiveSource) {
      return _lastStreamingDoc!;
    }

    final cachedDoc = _documentCache.get(effectiveSource);
    if (cachedDoc != null) {
      return cachedDoc;
    }

    final chunks = splitMarkdownBlocks(effectiveSource);
    final List<MarkdownBlock> blocks;

    if (chunks.length <= 1) {
      blocks = _parseChunk(effectiveSource, resolveFootnotes: true);
    } else {
      final combined = <MarkdownBlock>[];
      for (var i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final isStreamingTail = isStreaming && i == chunks.length - 1;
        List<MarkdownBlock> chunkBlocks;

        if (isStreamingTail) {
          if (_lastStreamingTailChunk == chunk &&
              _lastStreamingTailBlocks != null) {
            chunkBlocks = _lastStreamingTailBlocks!;
          } else {
            chunkBlocks = _parseChunk(chunk, resolveFootnotes: false);
            _lastStreamingTailChunk = chunk;
            _lastStreamingTailBlocks = chunkBlocks;
          }
        } else {
          final cachedChunk = _blockCache.get(chunk);
          if (cachedChunk != null) {
            chunkBlocks = cachedChunk;
          } else {
            chunkBlocks = _parseChunk(chunk, resolveFootnotes: false);
            _blockCache.put(chunk, chunkBlocks);
          }
        }
        combined.addAll(chunkBlocks);
      }
      blocks = List.unmodifiable(combined);
    }

    final document = MarkdownDocument(blocks: blocks, source: effectiveSource);

    if (isStreaming) {
      _lastStreamingSource = effectiveSource;
      _lastStreamingDoc = document;
    } else {
      _documentCache.put(effectiveSource, document);
    }

    return document;
  }

  List<MarkdownBlock> _parseChunk(
    String source, {
    required bool resolveFootnotes,
  }) {
    try {
      return _parseChunkUnguarded(source, resolveFootnotes: resolveFootnotes);
    } catch (_) {
      // `package:markdown` throws on a few inputs (for example an alert marker
      // directly followed by a table delimiter row trips its "not advancing"
      // guard). Chat content is untrusted model output, so never let that fail
      // the widget build: isolate the offending part and show it as raw text.
      final pieces = splitMarkdownBlocks(
        source,
        ignoreCrossBlockConstructs: true,
      );
      if (pieces.length <= 1) return _rawTextFallback(source);
      final blocks = <MarkdownBlock>[];
      for (final piece in pieces) {
        try {
          blocks.addAll(
            _parseChunkUnguarded(piece, resolveFootnotes: resolveFootnotes),
          );
        } catch (_) {
          blocks.addAll(_rawTextFallback(piece));
        }
      }
      return List.unmodifiable(blocks);
    }
  }

  List<MarkdownBlock> _parseChunkUnguarded(
    String source, {
    required bool resolveFootnotes,
  }) {
    {
      final mdDoc = _createMdDocument();
      final rawNodes = mdDoc.parse(source);
      final footnotes = <String, FootnoteDefinition>{};
      var blocks = _convertBlockNodes(
        rawNodes,
        mdDoc: mdDoc,
        footnotes: footnotes,
      );

      if (resolveFootnotes && footnotes.isNotEmpty) {
        blocks = _attachResolvedFootnotes(blocks, footnotes);
      }

      if (!_scanner.isEmpty) {
        blocks = _scanner.scanBlocks(blocks);
      }

      return List.unmodifiable(blocks);
    }
  }

  List<MarkdownBlock> _rawTextFallback(String source) {
    _rawTextFallbackCount++;
    final text = source.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return const [];
    return List.unmodifiable([
      ParagraphBlock(inlines: [TextInline(text)]),
    ]);
  }

  md.Document _createMdDocument() {
    final blockSyntaxes = <md.BlockSyntax>[
      const _TrackingFencedCodeBlockSyntax(),
      if (options.enableHtml) const _HtmlDetailsBlockSyntax(),
      if (options.enableLatex)
        _BlockLatexSyntax(enableDollar: options.enableDollarLatex),
      if (options.enableFootnotes) const _FootnoteDefinitionBlockSyntax(),
    ];

    final inlineSyntaxes = <md.InlineSyntax>[
      if (options.enableHtml) ...[
        _HtmlBreakInlineSyntax(),
        _HtmlImageInlineSyntax(),
        _HtmlOpenTagInlineSyntax(),
        _HtmlCloseTagInlineSyntax(),
      ],
      if (options.enableLatex) ...[
        _InlineParenLatexSyntax(),
        if (options.enableDollarLatex) _InlineDoubleDollarLatexSyntax(),
        if (options.enableDollarLatex) _InlineDollarLatexSyntax(),
      ],
      if (options.enableFootnotes) _FootnoteReferenceInlineSyntax(),
    ];

    return md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      blockSyntaxes: blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      encodeHtml: false,
    );
  }

  List<MarkdownBlock> _convertBlockNodes(
    List<md.Node> nodes, {
    required md.Document mdDoc,
    required Map<String, FootnoteDefinition> footnotes,
  }) {
    final blocks = <MarkdownBlock>[];

    for (final node in nodes) {
      if (node is md.Text) {
        final trimmed = node.text.trim();
        if (trimmed.isEmpty) continue;
        if (options.enableHtml &&
            _standaloneInlineHtmlPattern.hasMatch(trimmed)) {
          final parsedInlines = _convertBlockInlines(
            mdDoc.parseInline(trimmed),
          );
          if (parsedInlines.isNotEmpty) {
            blocks.add(ParagraphBlock(inlines: parsedInlines));
            continue;
          }
        }
        // Raw HTML blocks arrive with their surrounding newlines, and an HTML
        // comment is never meant to be seen.
        if (_isHtmlCommentsOnly(trimmed)) continue;
        final decoded = _decodeHtmlEntities(trimmed);
        blocks.add(ParagraphBlock(inlines: [TextInline(decoded)]));
        continue;
      }

      if (node is! md.Element) continue;

      switch (node.tag) {
        case 'p':
          final inlines = _convertBlockInlines(node.children ?? const []);
          if (inlines.isNotEmpty) {
            blocks.add(ParagraphBlock(inlines: inlines));
          }

        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          final level = int.parse(node.tag.substring(1));
          final inlines = _convertBlockInlines(node.children ?? const []);
          blocks.add(
            HeadingBlock(level: level, inlines: inlines, id: node.generatedId),
          );

        case 'pre':
          blocks.add(_convertCodeBlock(node));

        case 'blockquote':
          final children = _convertBlockNodes(
            node.children ?? const [],
            mdDoc: mdDoc,
            footnotes: footnotes,
          );
          final alert = options.enableAlerts
              ? _tryConvertAlert(children)
              : null;
          blocks.add(
            alert ?? BlockquoteBlock(children: List.unmodifiable(children)),
          );

        case 'ul' || 'ol':
          blocks.add(
            _convertListBlock(node, mdDoc: mdDoc, footnotes: footnotes),
          );

        case 'table':
          final table = _convertTableBlock(node);
          if (table != null) blocks.add(table);

        case 'hr':
          blocks.add(const ThematicBreakBlock());

        case 'mk-details':
          blocks.add(
            _convertDetailsBlock(node, mdDoc: mdDoc, footnotes: footnotes),
          );

        case 'mk-block-latex':
          final closed = node.attributes['data-closed'] != 'false';
          blocks.add(
            BlockLatexBlock(expression: node.textContent, closed: closed),
          );

        case 'mk-footnote-def':
          final label = node.attributes['label'] ?? '';
          if (label.isNotEmpty) {
            final defChildren = _convertBlockNodes(
              node.children ?? const [],
              mdDoc: mdDoc,
              footnotes: footnotes,
            );
            footnotes.putIfAbsent(
              label,
              () => FootnoteDefinition(
                label: label,
                children: List.unmodifiable(defChildren),
              ),
            );
          }

        default:
          // Graceful fallback for unrecognised block elements (e.g. raw HTML).
          final inlines = _convertBlockInlines(node.children ?? const []);
          if (inlines.isNotEmpty) {
            blocks.add(ParagraphBlock(inlines: inlines));
          } else if (node.textContent.trim().isNotEmpty) {
            blocks.add(
              ParagraphBlock(
                inlines: [TextInline(_decodeHtmlEntities(node.textContent))],
              ),
            );
          }
      }
    }

    return blocks;
  }

  CodeBlock _convertCodeBlock(md.Element preElement) {
    md.Element? codeEl;
    for (final child in preElement.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        codeEl = child;
        break;
      }
    }

    if (codeEl == null) {
      return CodeBlock(
        code: _trimSingleTrailingNewline(preElement.textContent),
        isFenced: false,
      );
    }

    final isFenced = codeEl.attributes['data-fenced'] == 'true';
    final closed = codeEl.attributes['data-closed'] != 'false';
    final infoString = codeEl.attributes['data-info'];
    String? language;
    final classAttr = codeEl.attributes['class'];
    if (classAttr != null && classAttr.startsWith('language-')) {
      final candidate = classAttr.substring('language-'.length).trim();
      if (candidate.isNotEmpty) language = candidate;
    }

    final rawCode = isFenced
        ? codeEl.textContent
        : _trimSingleTrailingNewline(codeEl.textContent);

    return CodeBlock(
      code: rawCode,
      language: language,
      infoString: infoString,
      isFenced: isFenced,
      closed: closed,
    );
  }

  AlertBlock? _tryConvertAlert(List<MarkdownBlock> children) {
    if (children.isEmpty) return null;
    final first = children.first;
    if (first is! ParagraphBlock || first.inlines.isEmpty) return null;

    final firstInline = first.inlines.first;
    if (firstInline is! TextInline) return null;

    final alertMatch = _alertMarkerPattern.firstMatch(firstInline.text);
    if (alertMatch == null) return null;

    // The marker must stand alone on the first line of the blockquote.
    final afterMarker = firstInline.text.substring(alertMatch.end);
    if (afterMarker.isNotEmpty) return null;

    final hasMoreInlines = first.inlines.length > 1;
    if (hasMoreInlines && first.inlines[1] is! LineBreakInline) {
      return null;
    }

    final kind = _parseAlertKind(alertMatch.group(1)!);
    if (kind == null) return null;

    final remainingBlocks = <MarkdownBlock>[];
    if (first.inlines.length > 2) {
      // Skip `[!KIND]` and its trailing LineBreakInline.
      remainingBlocks.add(
        ParagraphBlock(inlines: List.unmodifiable(first.inlines.sublist(2))),
      );
    }
    if (children.length > 1) {
      remainingBlocks.addAll(children.sublist(1));
    }

    return AlertBlock(kind: kind, children: List.unmodifiable(remainingBlocks));
  }

  ListBlock _convertListBlock(
    md.Element listElement, {
    required md.Document mdDoc,
    required Map<String, FootnoteDefinition> footnotes,
  }) {
    final ordered = listElement.tag == 'ol';
    final start = int.tryParse(listElement.attributes['start'] ?? '') ?? 1;
    final items = <ListItemNode>[];
    var isTight = true;

    for (final child in listElement.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'li') continue;
      final converted = _convertListItem(
        child,
        mdDoc: mdDoc,
        footnotes: footnotes,
      );
      if (!converted.tight) isTight = false;
      items.add(converted.item);
    }

    return ListBlock(
      ordered: ordered,
      start: start,
      tight: isTight,
      items: List.unmodifiable(items),
    );
  }

  ({ListItemNode item, bool tight}) _convertListItem(
    md.Element liElement, {
    required md.Document mdDoc,
    required Map<String, FootnoteDefinition> footnotes,
  }) {
    final rawChildren = liElement.children ?? const <md.Node>[];
    bool? checked;
    var tight = true;
    var startIndex = 0;

    // Case 1: tight task list item — `<input type="checkbox">` is direct first child.
    if (rawChildren.isNotEmpty) {
      final first = rawChildren.first;
      if (first is md.Element &&
          first.tag == 'input' &&
          first.attributes['type'] == 'checkbox') {
        checked =
            first.attributes['checked'] == 'true' ||
            first.attributes['checked'] == 'checked' ||
            first.attributes.containsKey('checked');
        startIndex = 1;
      }
    }

    final itemBlocks = <MarkdownBlock>[];
    final pendingInlines = <md.Node>[];

    void flushPendingInlines() {
      if (pendingInlines.isEmpty) return;
      var inlines = _convertBlockInlines(pendingInlines);
      pendingInlines.clear();
      if (checked != null && itemBlocks.isEmpty) {
        inlines = _trimLeadingSpace(inlines);
      }
      if (inlines.isNotEmpty) {
        itemBlocks.add(ParagraphBlock(inlines: inlines));
      }
    }

    for (var i = startIndex; i < rawChildren.length; i++) {
      final child = rawChildren[i];
      if (child is md.Element && _isBlockTag(child.tag)) {
        flushPendingInlines();
        if (child.tag == 'p') {
          tight = false;
          var pChildren = child.children ?? const <md.Node>[];
          // Case 2: loose task list item — `<input type="checkbox">` inside first `<p>`.
          if (checked == null && itemBlocks.isEmpty && pChildren.isNotEmpty) {
            final firstInP = pChildren.first;
            if (firstInP is md.Element &&
                firstInP.tag == 'input' &&
                firstInP.attributes['type'] == 'checkbox') {
              checked =
                  firstInP.attributes['checked'] == 'true' ||
                  firstInP.attributes['checked'] == 'checked' ||
                  firstInP.attributes.containsKey('checked');
              pChildren = pChildren.sublist(1);
            }
          }
          var inlines = _convertBlockInlines(pChildren);
          if (checked != null && itemBlocks.isEmpty) {
            inlines = _trimLeadingSpace(inlines);
          }
          if (inlines.isNotEmpty) {
            itemBlocks.add(ParagraphBlock(inlines: inlines));
          }
        } else {
          itemBlocks.addAll(
            _convertBlockNodes([child], mdDoc: mdDoc, footnotes: footnotes),
          );
        }
      } else {
        pendingInlines.add(child);
      }
    }
    flushPendingInlines();

    return (
      item: ListItemNode(
        children: List.unmodifiable(itemBlocks),
        checked: checked,
      ),
      tight: tight,
    );
  }

  TableBlock? _convertTableBlock(md.Element tableElement) {
    final alignments = <TableColumnAlign>[];
    TableRowNode? header;
    final bodyRows = <TableRowNode>[];

    for (final section in tableElement.children ?? const <md.Node>[]) {
      if (section is! md.Element) continue;
      if (section.tag == 'thead') {
        for (final tr in section.children ?? const <md.Node>[]) {
          if (tr is! md.Element || tr.tag != 'tr') continue;
          final cells = <List<MarkdownInline>>[];
          for (final th in tr.children ?? const <md.Node>[]) {
            if (th is! md.Element || (th.tag != 'th' && th.tag != 'td')) {
              continue;
            }
            alignments.add(_parseTableAlign(th));
            cells.add(_convertBlockInlines(th.children ?? const []));
          }
          header ??= TableRowNode(cells: List.unmodifiable(cells));
        }
      } else if (section.tag == 'tbody') {
        for (final tr in section.children ?? const <md.Node>[]) {
          if (tr is! md.Element || tr.tag != 'tr') continue;
          final cells = <List<MarkdownInline>>[];
          for (final td in tr.children ?? const <md.Node>[]) {
            if (td is! md.Element || (td.tag != 'td' && td.tag != 'th')) {
              continue;
            }
            cells.add(_convertBlockInlines(td.children ?? const []));
          }
          bodyRows.add(TableRowNode(cells: List.unmodifiable(cells)));
        }
      }
    }

    if (header == null) return null;
    final columnCount = header.cells.length;

    // Normalize body rows to match header column count so renderers never hit
    // ragged-row RangeErrors.
    final normalizedRows = bodyRows.map((row) {
      if (row.cells.length == columnCount) return row;
      if (row.cells.length > columnCount) {
        return TableRowNode(
          cells: List.unmodifiable(row.cells.sublist(0, columnCount)),
        );
      }
      return TableRowNode(
        cells: List.unmodifiable([
          ...row.cells,
          for (var i = row.cells.length; i < columnCount; i++)
            const <MarkdownInline>[],
        ]),
      );
    }).toList();

    return TableBlock(
      alignments: List.unmodifiable(alignments),
      header: header,
      rows: List.unmodifiable(normalizedRows),
    );
  }

  HtmlDetailsBlock _convertDetailsBlock(
    md.Element detailsEl, {
    required md.Document mdDoc,
    required Map<String, FootnoteDefinition> footnotes,
  }) {
    final initiallyOpen = detailsEl.attributes['open'] == 'true';
    var summary = const <MarkdownInline>[];
    var children = const <MarkdownBlock>[];

    for (final child in detailsEl.children ?? const <md.Node>[]) {
      if (child is! md.Element) continue;
      if (child.tag == 'mk-summary') {
        summary = _convertBlockInlines(child.children ?? const []);
      } else if (child.tag == 'mk-details-body') {
        children = List.unmodifiable(
          _convertBlockNodes(
            child.children ?? const [],
            mdDoc: mdDoc,
            footnotes: footnotes,
          ),
        );
      }
    }

    return HtmlDetailsBlock(
      summary: summary,
      children: children,
      initiallyOpen: initiallyOpen,
    );
  }

  /// Converts the inline content of one block (paragraph, heading, table
  /// cell, summary) and drops the whitespace `package:markdown` leaves at the
  /// edges of each line.
  List<MarkdownInline> _convertBlockInlines(List<md.Node> nodes) {
    return _trimLineEdges(_convertInlineNodes(nodes));
  }

  List<MarkdownInline> _convertInlineNodes(List<md.Node> nodes) {
    if (nodes.isEmpty) return const [];

    // Stack frame for pairing inline HTML open/close sentinel tokens.
    final stack = <_HtmlInlineFrame>[
      _HtmlInlineFrame(tag: null, attributes: const {}, rawOpen: ''),
    ];

    void emit(MarkdownInline inline) => stack.last.children.add(inline);

    for (final node in nodes) {
      if (node is md.Text) {
        _emitTextWithBreaks(node.text, emit);
        continue;
      }
      if (node is! md.Element) continue;

      switch (node.tag) {
        case 'mk-html-open':
          final htmlTag = node.attributes['data-tag'] ?? '';
          final rawOpen = node.attributes['data-raw'] ?? '';
          stack.add(
            _HtmlInlineFrame(
              tag: htmlTag,
              attributes: node.attributes,
              rawOpen: rawOpen,
            ),
          );

        case 'mk-html-close':
          final closeTag = node.attributes['data-tag'] ?? '';
          final matchIdx = _findOpenFrameIndex(stack, closeTag);
          if (matchIdx > 0) {
            // Unwind any unclosed inner tags as literal text first.
            while (stack.length - 1 > matchIdx) {
              final unclosed = stack.removeLast();
              if (unclosed.rawOpen.isNotEmpty) {
                emit(TextInline(unclosed.rawOpen));
              }
              stack.last.children.addAll(unclosed.children);
            }
            final frame = stack.removeLast();
            emit(_buildHtmlInlineNode(frame));
          }
        // Unmatched stray closing tags are silently dropped.

        case 'em' || 'i':
          emit(
            EmphasisInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'strong' || 'b':
          emit(
            StrongInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'del' || 's':
          emit(
            StrikethroughInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'u':
          emit(
            UnderlineInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'sub':
          emit(
            SubscriptInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'sup':
          emit(
            SuperscriptInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'kbd':
          emit(
            KeyboardInline(
              children: _convertInlineNodes(node.children ?? const []),
            ),
          );

        case 'code':
          emit(InlineCodeInline(node.textContent));

        case 'a':
          final href = _decodeHtmlEntities(node.attributes['href'] ?? '');
          final rawTitle = node.attributes['title'];
          final title = rawTitle == null ? null : _decodeHtmlEntities(rawTitle);
          final children = _convertInlineNodes(node.children ?? const []);
          final isAutolink =
              children.length == 1 &&
              children.first is TextInline &&
              ((children.first as TextInline).text == href ||
                  'mailto:${(children.first as TextInline).text}' == href);
          emit(
            LinkInline(
              destination: href,
              title: title,
              children: children,
              isAutolink: isAutolink,
            ),
          );

        case 'img':
          final src = _decodeHtmlEntities(node.attributes['src'] ?? '');
          final alt = _decodeHtmlEntities(node.attributes['alt'] ?? '');
          final rawTitle = node.attributes['title'];
          final title = rawTitle == null ? null : _decodeHtmlEntities(rawTitle);
          emit(ImageInline(source: src, alt: alt, title: title));

        case 'br':
          emit(const LineBreakInline(isHard: true));

        case 'mk-footnote-ref':
          final label = node.attributes['label'] ?? '';
          if (label.isNotEmpty) {
            emit(FootnoteRefInline(label: label));
          }

        case 'mk-inline-latex':
          emit(InlineLatexInline(node.textContent));

        default:
          final children = _convertInlineNodes(node.children ?? const []);
          for (final child in children) {
            emit(child);
          }
      }
    }

    // Unwind any remaining unclosed HTML open tags as literal text so
    // incomplete HTML during streaming never drops content.
    while (stack.length > 1) {
      final unclosed = stack.removeLast();
      if (unclosed.rawOpen.isNotEmpty) {
        stack.last.children.add(TextInline(unclosed.rawOpen));
      }
      stack.last.children.addAll(unclosed.children);
    }

    return _coalesceTextInlines(stack.first.children);
  }

  void _emitTextWithBreaks(String rawText, void Function(MarkdownInline) emit) {
    if (rawText.isEmpty) return;
    if (!rawText.contains('\n')) {
      emit(TextInline(_decodeHtmlEntities(rawText)));
      return;
    }
    final parts = rawText.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        emit(TextInline(_decodeHtmlEntities(parts[i])));
      }
      if (i < parts.length - 1) {
        emit(LineBreakInline(isHard: options.softBreakAsHardBreak));
      }
    }
  }

  int _findOpenFrameIndex(List<_HtmlInlineFrame> stack, String closeTag) {
    for (var i = stack.length - 1; i >= 1; i--) {
      if (_canonicalHtmlTag(stack[i].tag ?? '') ==
          _canonicalHtmlTag(closeTag)) {
        return i;
      }
    }
    return -1;
  }

  MarkdownInline _buildHtmlInlineNode(_HtmlInlineFrame frame) {
    final children = _coalesceTextInlines(frame.children);
    return switch (frame.tag) {
      'b' || 'strong' => StrongInline(children: children),
      'i' || 'em' => EmphasisInline(children: children),
      'u' => UnderlineInline(children: children),
      's' || 'del' => StrikethroughInline(children: children),
      'sub' => SubscriptInline(children: children),
      'sup' => SuperscriptInline(children: children),
      'kbd' => KeyboardInline(children: children),
      'a' => LinkInline(
        destination: _decodeHtmlEntities(frame.attributes['href'] ?? ''),
        title: frame.attributes['title'] == null
            ? null
            : _decodeHtmlEntities(frame.attributes['title']!),
        children: children,
      ),
      _ => TextInline(frame.rawOpen),
    };
  }

  List<MarkdownBlock> _attachResolvedFootnotes(
    List<MarkdownBlock> blocks,
    Map<String, FootnoteDefinition> definitions,
  ) {
    final labelToIndex = <String, int>{};
    var nextIndex = 1;

    int? resolveLabel(String label) {
      if (!definitions.containsKey(label)) return null;
      return labelToIndex.putIfAbsent(label, () => nextIndex++);
    }

    List<MarkdownInline> patchInlines(List<MarkdownInline> inlines) {
      return List.unmodifiable([
        for (final inline in inlines)
          switch (inline) {
            FootnoteRefInline(:final label) => FootnoteRefInline(
              label: label,
              index: resolveLabel(label),
            ),
            EmphasisInline(:final children) => EmphasisInline(
              children: patchInlines(children),
            ),
            StrongInline(:final children) => StrongInline(
              children: patchInlines(children),
            ),
            StrikethroughInline(:final children) => StrikethroughInline(
              children: patchInlines(children),
            ),
            UnderlineInline(:final children) => UnderlineInline(
              children: patchInlines(children),
            ),
            SubscriptInline(:final children) => SubscriptInline(
              children: patchInlines(children),
            ),
            SuperscriptInline(:final children) => SuperscriptInline(
              children: patchInlines(children),
            ),
            KeyboardInline(:final children) => KeyboardInline(
              children: patchInlines(children),
            ),
            LinkInline(
              :final destination,
              :final title,
              :final children,
              :final isAutolink,
            ) =>
              LinkInline(
                destination: destination,
                title: title,
                children: patchInlines(children),
                isAutolink: isAutolink,
              ),
            TextInline() ||
            InlineCodeInline() ||
            ImageInline() ||
            LineBreakInline() ||
            InlineLatexInline() ||
            CustomInline() => inline,
          },
      ]);
    }

    List<MarkdownBlock> patchBlocks(List<MarkdownBlock> input) {
      return List.unmodifiable([
        for (final block in input)
          switch (block) {
            ParagraphBlock(:final inlines) => ParagraphBlock(
              inlines: patchInlines(inlines),
            ),
            HeadingBlock(:final level, :final inlines, :final id) =>
              HeadingBlock(
                level: level,
                inlines: patchInlines(inlines),
                id: id,
              ),
            BlockquoteBlock(:final children) => BlockquoteBlock(
              children: patchBlocks(children),
            ),
            AlertBlock(:final kind, :final children) => AlertBlock(
              kind: kind,
              children: patchBlocks(children),
            ),
            ListBlock(
              :final ordered,
              :final start,
              :final tight,
              :final items,
            ) =>
              ListBlock(
                ordered: ordered,
                start: start,
                tight: tight,
                items: List.unmodifiable([
                  for (final item in items)
                    ListItemNode(
                      children: patchBlocks(item.children),
                      checked: item.checked,
                    ),
                ]),
              ),
            TableBlock(:final alignments, :final header, :final rows) =>
              TableBlock(
                alignments: alignments,
                header: TableRowNode(
                  cells: List.unmodifiable(header.cells.map(patchInlines)),
                ),
                rows: List.unmodifiable([
                  for (final row in rows)
                    TableRowNode(
                      cells: List.unmodifiable(row.cells.map(patchInlines)),
                    ),
                ]),
              ),
            HtmlDetailsBlock(
              :final summary,
              :final children,
              :final initiallyOpen,
            ) =>
              HtmlDetailsBlock(
                summary: patchInlines(summary),
                children: patchBlocks(children),
                initiallyOpen: initiallyOpen,
              ),
            CodeBlock() ||
            ThematicBreakBlock() ||
            FootnoteDefinitionsBlock() ||
            BlockLatexBlock() => block,
          },
      ]);
    }

    final patchedBlocks = patchBlocks(blocks);

    // Order definitions by reference order first, then any unreferenced
    // definitions in original source order.
    final orderedDefs = <FootnoteDefinition>[];
    for (final entry in labelToIndex.entries) {
      final def = definitions[entry.key]!;
      orderedDefs.add(
        FootnoteDefinition(
          label: def.label,
          index: entry.value,
          children: patchBlocks(def.children),
        ),
      );
    }
    for (final entry in definitions.entries) {
      if (labelToIndex.containsKey(entry.key)) continue;
      final ordinal = nextIndex++;
      orderedDefs.add(
        FootnoteDefinition(
          label: entry.value.label,
          index: ordinal,
          children: patchBlocks(entry.value.children),
        ),
      );
    }

    return [
      ...patchedBlocks,
      FootnoteDefinitionsBlock(definitions: List.unmodifiable(orderedDefs)),
    ];
  }
}

// ---------------------------------------------------------------------------
// Custom package:markdown block & inline syntaxes
// ---------------------------------------------------------------------------

class _TrackingFencedCodeBlockSyntax extends md.BlockSyntax {
  const _TrackingFencedCodeBlockSyntax();

  @override
  RegExp get pattern => _fencedOpenPattern;

  @override
  bool canParse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    if (match == null) return false;
    final fence = match.group(2)!;
    final info = match.group(3)!;
    if (fence.startsWith('`') && info.contains('`')) return false;
    return true;
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final indent = match.group(1)!.length;
    final fence = match.group(2)!;
    final fenceChar = fence[0];
    final fenceLength = fence.length;
    final rawInfo = _unescapeBackslashes(
      _decodeHtmlEntities(match.group(3)!.trim()),
    );

    parser.advance();

    final codeLines = <String>[];
    var closed = false;

    while (!parser.isDone) {
      final line = parser.current.content;
      if (_isClosingFence(line, fenceChar, fenceLength)) {
        closed = true;
        parser.advance();
        break;
      }
      codeLines.add(_stripLeadingSpaces(line, indent));
      parser.advance();
    }

    final codeEl = md.Element.text('code', codeLines.join('\n'));
    codeEl.attributes['data-fenced'] = 'true';
    codeEl.attributes['data-closed'] = closed ? 'true' : 'false';
    if (rawInfo.isNotEmpty) {
      codeEl.attributes['data-info'] = rawInfo;
      final lang = rawInfo.split(RegExp(r'\s+')).first;
      if (lang.isNotEmpty) {
        codeEl.attributes['class'] = 'language-$lang';
      }
    }

    return md.Element('pre', [codeEl]);
  }

  bool _isClosingFence(String line, String fenceChar, int minLength) {
    final match = _fencedOpenPattern.firstMatch(line);
    if (match == null) return false;
    final marker = match.group(2)!;
    if (marker[0] != fenceChar || marker.length < minLength) return false;
    return match.group(3)!.trim().isEmpty;
  }
}

class _HtmlDetailsBlockSyntax extends md.BlockSyntax {
  const _HtmlDetailsBlockSyntax();

  @override
  RegExp get pattern => _detailsOpenLinePattern;

  @override
  md.Node? parse(md.BlockParser parser) {
    final openMatch = pattern.firstMatch(parser.current.content)!;
    final attrs = openMatch.group(1) ?? '';
    final initiallyOpen = _openAttrPattern.hasMatch(attrs);
    final firstLineRest = openMatch.group(2) ?? '';
    parser.advance();

    final collected = StringBuffer();
    var depth = 1;
    var inFenceChar = '';
    var inFenceLength = 0;

    bool processSegment(String segment) {
      if (inFenceChar.isNotEmpty) {
        collected.writeln(segment);
        final closeMatch = _fencedOpenPattern.firstMatch(segment);
        if (closeMatch != null) {
          final marker = closeMatch.group(2)!;
          if (marker[0] == inFenceChar &&
              marker.length >= inFenceLength &&
              closeMatch.group(3)!.trim().isEmpty) {
            inFenceChar = '';
            inFenceLength = 0;
          }
        }
        return false;
      }

      final fenceMatch = _fencedOpenPattern.firstMatch(segment);
      if (fenceMatch != null) {
        final marker = fenceMatch.group(2)!;
        final info = fenceMatch.group(3)!;
        if (!(marker.startsWith('`') && info.contains('`'))) {
          inFenceChar = marker[0];
          inFenceLength = marker.length;
          collected.writeln(segment);
          return false;
        }
      }

      // Walk nested <details> and </details> tags left-to-right to locate the
      // closing tag that brings depth back to 0.
      var cursor = 0;
      for (final tagMatch in _detailsAnyTagPattern.allMatches(segment)) {
        final isClose = tagMatch.group(0)!.startsWith('</');
        if (isClose) {
          depth--;
          if (depth == 0) {
            collected.write(segment.substring(cursor, tagMatch.start));
            return true;
          }
        } else {
          depth++;
        }
      }
      collected.writeln(segment);
      return false;
    }

    var closed = false;
    if (firstLineRest.isNotEmpty) {
      closed = processSegment(firstLineRest);
    }

    while (!closed && !parser.isDone) {
      final line = parser.current.content;
      parser.advance();
      closed = processSegment(line);
    }

    var innerText = collected.toString();
    var summaryNodes = const <md.Node>[];

    final summaryMatch = _leadingSummaryTagPattern.firstMatch(innerText);
    if (summaryMatch != null) {
      final summaryText = summaryMatch.group(1)!.trim();
      if (summaryText.isNotEmpty) {
        summaryNodes = parser.document.parseInline(summaryText);
      }
      innerText = innerText.substring(summaryMatch.end);
    }

    final bodyLines = _trimBlankLines(innerText);
    final bodyNodes = bodyLines.isEmpty
        ? const <md.Node>[]
        : parser.document.parseLines(bodyLines);

    final element = md.Element('mk-details', [
      md.Element('mk-summary', summaryNodes),
      md.Element('mk-details-body', bodyNodes),
    ]);
    element.attributes['open'] = initiallyOpen ? 'true' : 'false';
    return element;
  }
}

class _BlockLatexSyntax extends md.BlockSyntax {
  const _BlockLatexSyntax({required this.enableDollar});

  final bool enableDollar;

  @override
  RegExp get pattern =>
      enableDollar ? _blockLatexCombinedPattern : _blockLatexBracketOnlyPattern;

  @override
  bool canParse(md.BlockParser parser) {
    final line = parser.current.content;
    if (_bracketSingleLinePattern.hasMatch(line) ||
        _bracketMultiOpenPattern.hasMatch(line)) {
      return true;
    }
    if (enableDollar &&
        (_dollarSingleLinePattern.hasMatch(line) ||
            _dollarMultiOpenPattern.hasMatch(line))) {
      return true;
    }
    return false;
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final firstLine = parser.current.content;

    final singleBracket = _bracketSingleLinePattern.firstMatch(firstLine);
    if (singleBracket != null) {
      parser.advance();
      final el = md.Element.text(
        'mk-block-latex',
        singleBracket.group(1)!.trim(),
      );
      el.attributes['data-closed'] = 'true';
      return el;
    }

    if (_bracketMultiOpenPattern.hasMatch(firstLine)) {
      parser.advance();
      final lines = <String>[];
      var closed = false;
      while (!parser.isDone) {
        final line = parser.current.content;
        final closeMatch = _bracketMultiClosePattern.firstMatch(line);
        if (closeMatch != null) {
          final beforeClose = closeMatch.group(1)!.trimRight();
          if (beforeClose.isNotEmpty) lines.add(beforeClose);
          closed = true;
          parser.advance();
          break;
        }
        lines.add(line);
        parser.advance();
      }
      final el = md.Element.text('mk-block-latex', lines.join('\n').trim());
      el.attributes['data-closed'] = closed ? 'true' : 'false';
      return el;
    }

    if (enableDollar) {
      final singleDollar = _dollarSingleLinePattern.firstMatch(firstLine);
      if (singleDollar != null) {
        parser.advance();
        final el = md.Element.text(
          'mk-block-latex',
          singleDollar.group(1)!.trim(),
        );
        el.attributes['data-closed'] = 'true';
        return el;
      }

      if (_dollarMultiOpenPattern.hasMatch(firstLine)) {
        parser.advance();
        final lines = <String>[];
        var closed = false;
        while (!parser.isDone) {
          final line = parser.current.content;
          if (_dollarMultiOpenPattern.hasMatch(line)) {
            closed = true;
            parser.advance();
            break;
          }
          lines.add(line);
          parser.advance();
        }
        final el = md.Element.text('mk-block-latex', lines.join('\n').trim());
        el.attributes['data-closed'] = closed ? 'true' : 'false';
        return el;
      }
    }

    return null;
  }
}

class _FootnoteDefinitionBlockSyntax extends md.BlockSyntax {
  const _FootnoteDefinitionBlockSyntax();

  @override
  RegExp get pattern => _footnoteDefPattern;

  @override
  md.Node? parse(md.BlockParser parser) {
    final firstMatch = pattern.firstMatch(parser.current.content)!;
    final label = firstMatch.group(1)!;
    final bodyLines = <String>[];
    final firstRest = firstMatch.group(2)!.trimRight();
    if (firstRest.isNotEmpty) {
      bodyLines.add(firstRest);
    }
    parser.advance();

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim().isEmpty) {
        // Look ahead past consecutive blank lines: only consume them if an
        // indented continuation line follows.
        var offset = 1;
        md.Line? lookahead = parser.peek(offset);
        while (lookahead != null && lookahead.content.trim().isEmpty) {
          offset++;
          lookahead = parser.peek(offset);
        }
        if (lookahead != null &&
            _indentedContinuationPattern.hasMatch(lookahead.content)) {
          bodyLines.add('');
          parser.advance();
          continue;
        }
        break;
      }

      if (_indentedContinuationPattern.hasMatch(line)) {
        bodyLines.add(_stripFootnoteIndent(line));
        parser.advance();
        continue;
      }

      break;
    }

    final children = bodyLines.isEmpty
        ? const <md.Node>[]
        : parser.document.parseLines(bodyLines);
    final el = md.Element('mk-footnote-def', children);
    el.attributes['label'] = label;
    return el;
  }
}

class _HtmlBreakInlineSyntax extends md.InlineSyntax {
  _HtmlBreakInlineSyntax()
    : super(r'<br\s*/?>', startCharacter: 0x3C, caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}

class _HtmlImageInlineSyntax extends md.InlineSyntax {
  _HtmlImageInlineSyntax()
    : super(r'<img\b([^>]*?)/?>', startCharacter: 0x3C, caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final attrs = _parseHtmlAttributes(match.group(1) ?? '');
    final el = md.Element.empty('img');
    if (attrs.containsKey('src')) el.attributes['src'] = attrs['src']!;
    if (attrs.containsKey('alt')) el.attributes['alt'] = attrs['alt']!;
    if (attrs.containsKey('title')) el.attributes['title'] = attrs['title']!;
    parser.addNode(el);
    return true;
  }
}

class _HtmlOpenTagInlineSyntax extends md.InlineSyntax {
  _HtmlOpenTagInlineSyntax()
    : super(
        r'<(b|strong|i|em|u|s|del|sub|sup|kbd|a)(?:\s([^>]*))?>',
        startCharacter: 0x3C,
        caseSensitive: false,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tag = match.group(1)!.toLowerCase();
    final attrText = match.group(2) ?? '';
    final attrs = _parseHtmlAttributes(attrText);
    final el = md.Element.empty('mk-html-open');
    el.attributes['data-tag'] = tag;
    el.attributes['data-raw'] = match.group(0)!;
    if (tag == 'a') {
      if (attrs.containsKey('href')) el.attributes['href'] = attrs['href']!;
      if (attrs.containsKey('title')) el.attributes['title'] = attrs['title']!;
    }
    parser.addNode(el);
    return true;
  }
}

class _HtmlCloseTagInlineSyntax extends md.InlineSyntax {
  _HtmlCloseTagInlineSyntax()
    : super(
        r'</(b|strong|i|em|u|s|del|sub|sup|kbd|a)\s*>',
        startCharacter: 0x3C,
        caseSensitive: false,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.empty('mk-html-close');
    el.attributes['data-tag'] = match.group(1)!.toLowerCase();
    parser.addNode(el);
    return true;
  }
}

class _InlineParenLatexSyntax extends md.InlineSyntax {
  _InlineParenLatexSyntax() : super(r'\\\((.+?)\\\)', startCharacter: 0x5C);

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;
    final raw = match.group(1)!;
    // Refuse to swallow backtick code spans across an unclosed `\(`.
    if (raw.contains('`')) return false;
    final expr = raw.trim();
    if (expr.isEmpty) return false;
    parser.writeText();
    parser.addNode(md.Element.text('mk-inline-latex', expr));
    parser.consume(match.end - match.start);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => true;
}

class _InlineDoubleDollarLatexSyntax extends md.InlineSyntax {
  _InlineDoubleDollarLatexSyntax()
    : super(r'\$\$(.+?)\$\$', startCharacter: 0x24);

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    if (startMatchPos > 0 &&
        parser.source.codeUnitAt(startMatchPos - 1) == 0x5C) {
      return false;
    }
    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;
    final raw = match.group(1)!;
    // Refuse to swallow backtick code spans across an unclosed `$$`.
    if (raw.contains('`')) return false;
    final expr = raw.trim();
    if (expr.isEmpty) return false;
    parser.writeText();
    parser.addNode(md.Element.text('mk-inline-latex', expr));
    parser.consume(match.end - match.start);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => true;
}

class _InlineDollarLatexSyntax extends md.InlineSyntax {
  _InlineDollarLatexSyntax() : super(r'\$', startCharacter: 0x24);

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    final source = parser.source;
    if (startMatchPos >= source.length ||
        source.codeUnitAt(startMatchPos) != 0x24) {
      return false;
    }

    // Reject `$$`, escaped `\$`, or alphanumeric immediately preceding `$`.
    if (startMatchPos + 1 >= source.length ||
        source.codeUnitAt(startMatchPos + 1) == 0x24) {
      return false;
    }
    if (startMatchPos > 0) {
      final prev = source.codeUnitAt(startMatchPos - 1);
      if (prev == 0x5C || prev == 0x24 || _isAsciiWordChar(prev)) {
        return false;
      }
    }

    // Opening `$` cannot be followed by whitespace or newline.
    final first = source.codeUnitAt(startMatchPos + 1);
    if (first == 0x20 || first == 0x09 || first == 0x0A || first == 0x0D) {
      return false;
    }

    // Scan forward for a matching unescaped closing `$` on the same line,
    // refusing to cross backtick code spans.
    var i = startMatchPos + 1;
    while (i < source.length) {
      final code = source.codeUnitAt(i);
      if (code == 0x0A || code == 0x0D || code == 0x60) {
        return false;
      }
      if (code == 0x5C) {
        i += 2;
        continue;
      }
      if (code == 0x24) {
        // Closing `$` cannot be preceded by whitespace.
        final beforeClose = source.codeUnitAt(i - 1);
        if (beforeClose == 0x20 || beforeClose == 0x09) {
          return false;
        }
        // Reject closing `$$` or currency like `$5 and $10`.
        if (i + 1 < source.length) {
          final afterClose = source.codeUnitAt(i + 1);
          if (afterClose == 0x24 ||
              (afterClose >= 0x30 && afterClose <= 0x39)) {
            return false;
          }
        }
        final inner = source.substring(startMatchPos + 1, i);
        if (inner.isEmpty) return false;
        parser.writeText();
        parser.addNode(md.Element.text('mk-inline-latex', inner));
        parser.consume(i + 1 - startMatchPos);
        return true;
      }
      i++;
    }

    return false;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => true;
}

class _FootnoteReferenceInlineSyntax extends md.InlineSyntax {
  _FootnoteReferenceInlineSyntax()
    : super(r'\[\^([A-Za-z0-9_-]+)\](?!:)', startCharacter: 0x5B);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final el = md.Element.empty('mk-footnote-ref');
    el.attributes['label'] = match.group(1)!;
    parser.addNode(el);
    return true;
  }
}

// ---------------------------------------------------------------------------
// Helpers & patterns
// ---------------------------------------------------------------------------

class _HtmlInlineFrame {
  _HtmlInlineFrame({
    required this.tag,
    required this.attributes,
    required this.rawOpen,
  });

  final String? tag;
  final Map<String, String> attributes;
  final String rawOpen;
  final List<MarkdownInline> children = [];
}

final _fencedOpenPattern = RegExp(r'^( {0,3})(`{3,}|~{3,})(.*)$');
final _alertMarkerPattern = RegExp(
  r'^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][ \t]*',
  caseSensitive: false,
);
final _detailsOpenLinePattern = RegExp(
  r'^ {0,3}<details(?:\s([^>]*))?>(.*)$',
  caseSensitive: false,
);
final _detailsAnyTagPattern = RegExp(
  r'</?details(?:\s[^>]*)?>',
  caseSensitive: false,
);
final _openAttrPattern = RegExp(
  r'(?:^|\s)open(?:\s|=|$)',
  caseSensitive: false,
);
final _leadingSummaryTagPattern = RegExp(
  r'^\s*<summary(?:\s[^>]*)?>([\s\S]*?)</summary\s*>',
  caseSensitive: false,
);
final _standaloneInlineHtmlPattern = RegExp(
  r'^<(?:br|img|b|strong|i|em|u|s|del|sub|sup|kbd|a)(?:\s|/|>)',
  caseSensitive: false,
);

/// Whether [text] consists solely of HTML comments separated by whitespace.
///
/// A hand-written linear scan: the equivalent regular expression backtracks
/// catastrophically on a long run of comments followed by other text.
bool _isHtmlCommentsOnly(String text) {
  var index = 0;
  var sawComment = false;
  while (index < text.length) {
    if (!text.startsWith('<!--', index)) return false;
    final close = text.indexOf('-->', index + 4);
    if (close < 0) return false;
    sawComment = true;
    index = close + 3;
    while (index < text.length && text.codeUnitAt(index) <= 0x20) {
      index++;
    }
  }
  return sawComment;
}

final _blockLatexCombinedPattern = RegExp(r'^ {0,3}(?:\\\[|\$\$)');
final _blockLatexBracketOnlyPattern = RegExp(r'^ {0,3}\\\[');
final _bracketSingleLinePattern = RegExp(r'^ {0,3}\\\[(.*)\\\][ \t]*$');
final _bracketMultiOpenPattern = RegExp(r'^ {0,3}\\\[[ \t]*$');
final _bracketMultiClosePattern = RegExp(r'^(.*)\\\][ \t]*$');
final _dollarSingleLinePattern = RegExp(r'^ {0,3}\$\$(.+?)\$\$[ \t]*$');
final _dollarMultiOpenPattern = RegExp(r'^ {0,3}\$\$[ \t]*$');
final _footnoteDefPattern = RegExp(r'^ {0,3}\[\^([^\s\]]+)\]:[ \t]*(.*)$');
final _indentedContinuationPattern = RegExp(r'^(?: {2,}|\t)');
final _htmlAttrPattern = RegExp(
  r'''([A-Za-z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
);
final _htmlEntityPattern = RegExp(r'&(?:#(\d+)|#x([0-9a-fA-F]+)|([A-Za-z]+));');

const _namedHtmlEntities = <String, String>{
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00A0',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'hellip': '\u2026',
  'copy': '\u00A9',
  'reg': '\u00AE',
  'trade': '\u2122',
  'times': '\u00D7',
  'divide': '\u00F7',
  'laquo': '\u00AB',
  'raquo': '\u00BB',
  'lsquo': '\u2018',
  'rsquo': '\u2019',
  'ldquo': '\u201C',
  'rdquo': '\u201D',
};

const _blockTags = <String>{
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'pre',
  'blockquote',
  'ul',
  'ol',
  'table',
  'hr',
  'mk-details',
  'mk-block-latex',
  'mk-footnote-def',
};

bool _isBlockTag(String tag) => _blockTags.contains(tag);

bool _isAsciiWordChar(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A);
}

AlertKind? _parseAlertKind(String raw) {
  return switch (raw.toUpperCase()) {
    'NOTE' => AlertKind.note,
    'TIP' => AlertKind.tip,
    'IMPORTANT' => AlertKind.important,
    'WARNING' => AlertKind.warning,
    'CAUTION' => AlertKind.caution,
    _ => null,
  };
}

TableColumnAlign _parseTableAlign(md.Element cell) {
  final align = cell.attributes['align']?.toLowerCase();
  if (align == 'left') return TableColumnAlign.left;
  if (align == 'center') return TableColumnAlign.center;
  if (align == 'right') return TableColumnAlign.right;

  final style = cell.attributes['style']?.toLowerCase();
  if (style != null) {
    if (style.contains('text-align: left') ||
        style.contains('text-align:left')) {
      return TableColumnAlign.left;
    }
    if (style.contains('text-align: center') ||
        style.contains('text-align:center')) {
      return TableColumnAlign.center;
    }
    if (style.contains('text-align: right') ||
        style.contains('text-align:right')) {
      return TableColumnAlign.right;
    }
  }
  return TableColumnAlign.none;
}

String _canonicalHtmlTag(String tag) {
  return switch (tag) {
    'b' || 'strong' => 'strong',
    'i' || 'em' => 'em',
    's' || 'del' => 'del',
    _ => tag,
  };
}

Map<String, String> _parseHtmlAttributes(String attrText) {
  final result = <String, String>{};
  for (final match in _htmlAttrPattern.allMatches(attrText)) {
    final name = match.group(1)!.toLowerCase();
    final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    result[name] = value;
  }
  return result;
}

String _decodeHtmlEntities(String input) {
  if (!input.contains('&')) return input;
  return input.replaceAllMapped(_htmlEntityPattern, (match) {
    final dec = match.group(1);
    if (dec != null) {
      final code = int.tryParse(dec);
      if (code != null && code > 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    }
    final hex = match.group(2);
    if (hex != null) {
      final code = int.tryParse(hex, radix: 16);
      if (code != null && code > 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    }
    final name = match.group(3)!;
    return _namedHtmlEntities[name] ?? match.group(0)!;
  });
}

String _unescapeBackslashes(String input) {
  if (!input.contains(r'\')) return input;
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    if (input.codeUnitAt(i) == 0x5C && i + 1 < input.length) {
      final next = input.codeUnitAt(i + 1);
      if (_isAsciiPunctuation(next)) {
        buffer.writeCharCode(next);
        i++;
        continue;
      }
    }
    buffer.writeCharCode(input.codeUnitAt(i));
  }
  return buffer.toString();
}

bool _isAsciiPunctuation(int code) {
  return (code >= 0x21 && code <= 0x2F) ||
      (code >= 0x3A && code <= 0x40) ||
      (code >= 0x5B && code <= 0x60) ||
      (code >= 0x7B && code <= 0x7E);
}

String _stripLeadingSpaces(String line, int maxSpaces) {
  var removed = 0;
  while (removed < maxSpaces &&
      removed < line.length &&
      line.codeUnitAt(removed) == 0x20) {
    removed++;
  }
  return removed == 0 ? line : line.substring(removed);
}

String _stripFootnoteIndent(String line) {
  if (line.startsWith('\t')) return line.substring(1);
  return _stripLeadingSpaces(line, 4);
}

List<String> _trimBlankLines(String text) {
  final lines = text.split('\n');
  var start = 0;
  while (start < lines.length && lines[start].trim().isEmpty) {
    start++;
  }
  var end = lines.length;
  while (end > start && lines[end - 1].trim().isEmpty) {
    end--;
  }
  return start >= end ? const [] : lines.sublist(start, end);
}

String _trimSingleTrailingNewline(String text) {
  if (text.endsWith('\r\n')) return text.substring(0, text.length - 2);
  if (text.endsWith('\n')) return text.substring(0, text.length - 1);
  return text;
}

List<MarkdownInline> _trimLeadingSpace(List<MarkdownInline> inlines) {
  if (inlines.isEmpty) return inlines;
  final first = inlines.first;
  if (first is! TextInline) return inlines;
  final trimmed = first.text.trimLeft();
  if (trimmed == first.text) return inlines;
  if (trimmed.isEmpty) {
    return List.unmodifiable(inlines.sublist(1));
  }
  return List.unmodifiable([TextInline(trimmed), ...inlines.sublist(1)]);
}

/// Removes spaces and tabs at the start of every line and before every line
/// break of a block's inline content.
///
/// `package:markdown` keeps that whitespace in its text nodes (the extra
/// spaces of `-   item`, the indentation of a continuation line) and only
/// drops it when writing HTML. Flutter does not collapse whitespace, so
/// without this it shows up as indented or double-spaced text.
List<MarkdownInline> _trimLineEdges(List<MarkdownInline> inlines) {
  if (inlines.isEmpty) return inlines;
  final state = _LineEdgeState();
  final trimmed = _trimLineEdgesIn(inlines, state);
  // A soft break at either end is a leftover newline. A hard one is kept: a
  // paragraph holding only `<br>` is a deliberate spacer.
  bool isSoftBreak(MarkdownInline inline) =>
      inline is LineBreakInline && !inline.isHard;
  while (trimmed.isNotEmpty && isSoftBreak(trimmed.first)) {
    trimmed.removeAt(0);
  }
  while (trimmed.isNotEmpty && isSoftBreak(trimmed.last)) {
    trimmed.removeLast();
  }
  return List.unmodifiable(trimmed);
}

class _LineEdgeState {
  bool atLineStart = true;
}

List<MarkdownInline> _trimLineEdgesIn(
  List<MarkdownInline> inlines,
  _LineEdgeState state,
) {
  final result = <MarkdownInline>[];
  for (var i = 0; i < inlines.length; i++) {
    final inline = inlines[i];
    switch (inline) {
      case TextInline(:final text):
        var next = text;
        if (state.atLineStart) next = _trimLeftSpaces(next);
        final beforeBreak =
            i + 1 < inlines.length && inlines[i + 1] is LineBreakInline;
        if (beforeBreak) next = _trimRightSpaces(next);
        if (next.isEmpty) continue;
        state.atLineStart = false;
        result.add(identical(next, text) ? inline : TextInline(next));
      case LineBreakInline():
        state.atLineStart = true;
        result.add(inline);
      case EmphasisInline(:final children):
        result.add(EmphasisInline(children: _trimNested(children, state)));
      case StrongInline(:final children):
        result.add(StrongInline(children: _trimNested(children, state)));
      case StrikethroughInline(:final children):
        result.add(StrikethroughInline(children: _trimNested(children, state)));
      case UnderlineInline(:final children):
        result.add(UnderlineInline(children: _trimNested(children, state)));
      case SubscriptInline(:final children):
        result.add(SubscriptInline(children: _trimNested(children, state)));
      case SuperscriptInline(:final children):
        result.add(SuperscriptInline(children: _trimNested(children, state)));
      case KeyboardInline(:final children):
        result.add(KeyboardInline(children: _trimNested(children, state)));
      case LinkInline():
        result.add(
          LinkInline(
            destination: inline.destination,
            title: inline.title,
            isAutolink: inline.isAutolink,
            children: _trimNested(inline.children, state),
          ),
        );
      case InlineCodeInline() ||
          ImageInline() ||
          FootnoteRefInline() ||
          InlineLatexInline() ||
          CustomInline():
        state.atLineStart = false;
        result.add(inline);
    }
  }
  return result;
}

List<MarkdownInline> _trimNested(
  List<MarkdownInline> children,
  _LineEdgeState state,
) => List.unmodifiable(_trimLineEdgesIn(children, state));

String _trimLeftSpaces(String text) {
  var start = 0;
  while (start < text.length &&
      (text.codeUnitAt(start) == 0x20 || text.codeUnitAt(start) == 0x09)) {
    start++;
  }
  return start == 0 ? text : text.substring(start);
}

String _trimRightSpaces(String text) {
  var end = text.length;
  while (end > 0 &&
      (text.codeUnitAt(end - 1) == 0x20 || text.codeUnitAt(end - 1) == 0x09)) {
    end--;
  }
  return end == text.length ? text : text.substring(0, end);
}

List<MarkdownInline> _coalesceTextInlines(List<MarkdownInline> inlines) {
  if (inlines.length <= 1) return List.unmodifiable(inlines);
  final result = <MarkdownInline>[];
  StringBuffer? textBuffer;

  void flush() {
    if (textBuffer != null) {
      result.add(TextInline(textBuffer!.toString()));
      textBuffer = null;
    }
  }

  for (final inline in inlines) {
    if (inline is TextInline) {
      if (inline.text.isEmpty) continue;
      (textBuffer ??= StringBuffer()).write(inline.text);
    } else {
      flush();
      result.add(inline);
    }
  }
  flush();
  return List.unmodifiable(result);
}
