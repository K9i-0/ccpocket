import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import '../ast/rendered_text.dart';

/// A model-anchored cursor position inside a registered Markdown document.
///
/// Offsets are UTF-16 code unit indices into [extractBlockRenderedText] for
/// `document.blocks[blockIndex]`.
@immutable
class MarkdownPosition {
  const MarkdownPosition({
    required this.documentId,
    required this.blockIndex,
    required this.offset,
  }) : assert(blockIndex >= 0),
       assert(offset >= 0);

  /// Identifier of the registered [MarkdownDocumentRef].
  final String documentId;

  /// Zero-based index of the top-level [MarkdownBlock] in the document.
  final int blockIndex;

  /// UTF-16 code unit offset inside the block's canonical rendered text.
  final int offset;

  MarkdownPosition copyWith({
    String? documentId,
    int? blockIndex,
    int? offset,
  }) {
    return MarkdownPosition(
      documentId: documentId ?? this.documentId,
      blockIndex: blockIndex ?? this.blockIndex,
      offset: offset ?? this.offset,
    );
  }

  /// Compares this position against [other].
  ///
  /// When the two positions belong to different documents, [documentOrder] (or
  /// [compareDocumentIds]) defines reading order; otherwise falls back to
  /// lexicographical comparison of [documentId].
  int compareTo(
    MarkdownPosition other, {
    Map<String, int>? documentOrder,
    int Function(String a, String b)? compareDocumentIds,
  }) {
    if (documentId != other.documentId) {
      if (compareDocumentIds != null) {
        final cmp = compareDocumentIds(documentId, other.documentId);
        if (cmp != 0) return cmp;
      } else if (documentOrder != null) {
        final orderA = documentOrder[documentId];
        final orderB = documentOrder[other.documentId];
        if (orderA != null && orderB != null && orderA != orderB) {
          return orderA.compareTo(orderB);
        }
      }
      return documentId.compareTo(other.documentId);
    }
    final blockCmp = blockIndex.compareTo(other.blockIndex);
    if (blockCmp != 0) return blockCmp;
    return offset.compareTo(other.offset);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownPosition &&
        other.documentId == documentId &&
        other.blockIndex == blockIndex &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(documentId, blockIndex, offset);

  @override
  String toString() =>
      'MarkdownPosition(documentId: $documentId, blockIndex: $blockIndex, '
      'offset: $offset)';
}

/// An active model-anchored selection between [base] and [extent].
@immutable
class MarkdownSelection {
  const MarkdownSelection({required this.base, required this.extent});

  /// Creates a collapsed (zero-length) selection at [position].
  const MarkdownSelection.collapsed(MarkdownPosition position)
    : base = position,
      extent = position;

  /// The anchor point where selection started.
  final MarkdownPosition base;

  /// The active moving endpoint of the selection.
  final MarkdownPosition extent;

  /// Whether [base] and [extent] point to the exact same position.
  bool get isCollapsed => base == extent;

  /// Whether both endpoints belong to the same document.
  bool get isSingleDocument => base.documentId == extent.documentId;

  /// Whether [extent] precedes [base] in reading order.
  bool isReversed({Map<String, int>? documentOrder}) {
    return base.compareTo(extent, documentOrder: documentOrder) > 0;
  }

  /// Returns the endpoints sorted in reading order as `(start, end)`.
  ({MarkdownPosition start, MarkdownPosition end}) normalized({
    Map<String, int>? documentOrder,
  }) {
    final cmp = base.compareTo(extent, documentOrder: documentOrder);
    return cmp <= 0 ? (start: base, end: extent) : (start: extent, end: base);
  }

  MarkdownSelection copyWith({
    MarkdownPosition? base,
    MarkdownPosition? extent,
  }) {
    return MarkdownSelection(
      base: base ?? this.base,
      extent: extent ?? this.extent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownSelection &&
        other.base == base &&
        other.extent == extent;
  }

  @override
  int get hashCode => Object.hash(base, extent);

  @override
  String toString() => 'MarkdownSelection(base: $base, extent: $extent)';
}

/// Registration entry associating a document ID, parsed AST, and reading order.
@immutable
class MarkdownDocumentRef {
  const MarkdownDocumentRef({
    required this.id,
    required this.document,
    this.order = 0,
  });

  /// Stable document identifier (e.g. message ID in a chat list).
  final String id;

  /// Parsed AST for this document.
  final MarkdownDocument document;

  /// Monotonic reading order among sibling documents in a selection scope.
  /// Smaller values precede larger values.
  final int order;

  MarkdownDocumentRef copyWith({
    String? id,
    MarkdownDocument? document,
    int? order,
  }) {
    return MarkdownDocumentRef(
      id: id ?? this.id,
      document: document ?? this.document,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownDocumentRef &&
        other.id == id &&
        other.document == document &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(id, document, order);

  @override
  String toString() =>
      'MarkdownDocumentRef(id: $id, order: $order, blocks: ${document.blocks.length})';
}

/// A slice of a single [MarkdownBlock] covered by a selection.
@immutable
class MarkdownSelectedBlock {
  const MarkdownSelectedBlock({
    required this.blockIndex,
    required this.block,
    required this.fullText,
    required this.startOffset,
    required this.endOffset,
  }) : assert(blockIndex >= 0),
       assert(startOffset >= 0),
       assert(endOffset >= startOffset),
       assert(endOffset <= fullText.length);

  final int blockIndex;
  final MarkdownBlock block;
  final String fullText;
  final int startOffset;
  final int endOffset;

  /// The selected substring of [fullText].
  String get selectedText => fullText.substring(startOffset, endOffset);

  /// Whether the entire rendered text of [block] is selected.
  bool get isFullBlock => startOffset == 0 && endOffset == fullText.length;

  /// Whether only part of [block] is selected.
  bool get isPartial => !isFullBlock;

  /// Whether this slice contains zero characters.
  bool get isEmpty => startOffset >= endOffset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownSelectedBlock &&
        other.blockIndex == blockIndex &&
        other.block == block &&
        other.fullText == fullText &&
        other.startOffset == startOffset &&
        other.endOffset == endOffset;
  }

  @override
  int get hashCode =>
      Object.hash(blockIndex, block, fullText, startOffset, endOffset);

  @override
  String toString() =>
      'MarkdownSelectedBlock(blockIndex: $blockIndex, '
      'range: $startOffset..$endOffset/${fullText.length})';
}

/// Selected blocks belonging to a single document.
@immutable
class MarkdownSelectedDocument {
  const MarkdownSelectedDocument({
    required this.documentId,
    required this.document,
    required this.blocks,
  });

  final String documentId;
  final MarkdownDocument document;
  final List<MarkdownSelectedBlock> blocks;

  bool get isEmpty => blocks.isEmpty;

  bool get isNotEmpty => blocks.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarkdownSelectedDocument ||
        other.documentId != documentId ||
        other.document != document ||
        other.blocks.length != blocks.length) {
      return false;
    }
    for (var i = 0; i < blocks.length; i++) {
      if (other.blocks[i] != blocks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(documentId, document, Object.hashAll(blocks));

  @override
  String toString() =>
      'MarkdownSelectedDocument(documentId: $documentId, blocks: ${blocks.length})';
}

/// Structured selection snapshot passed to [MarkdownSelectionFormatter]s.
@immutable
class MarkdownSelectedContent {
  const MarkdownSelectedContent({
    required this.selection,
    required this.documents,
  });

  /// Extracts a [MarkdownSelectedContent] snapshot for [selection] across the
  /// provided [documents].
  ///
  /// Documents are sorted by [MarkdownDocumentRef.order] (breaking ties by
  /// [MarkdownDocumentRef.id]). Out-of-bounds block indices and character
  /// offsets are clamped safely.
  factory MarkdownSelectedContent.extract({
    required MarkdownSelection selection,
    required Iterable<MarkdownDocumentRef> documents,
  }) {
    if (selection.isCollapsed) {
      return MarkdownSelectedContent(selection: selection, documents: const []);
    }

    final sortedDocs = documents.toList()
      ..sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
      });

    final orderMap = <String, int>{
      for (var i = 0; i < sortedDocs.length; i++) sortedDocs[i].id: i,
    };

    final (:start, :end) = selection.normalized(documentOrder: orderMap);
    final startDocIdx = orderMap[start.documentId];
    final endDocIdx = orderMap[end.documentId];
    if (startDocIdx == null || endDocIdx == null) {
      return MarkdownSelectedContent(selection: selection, documents: const []);
    }

    final selectedDocs = <MarkdownSelectedDocument>[];
    for (var docIdx = startDocIdx; docIdx <= endDocIdx; docIdx++) {
      final ref = sortedDocs[docIdx];
      final blocks = ref.document.blocks;
      if (blocks.isEmpty) continue;

      final firstBlock = docIdx == startDocIdx
          ? start.blockIndex.clamp(0, blocks.length - 1)
          : 0;
      final lastBlock = docIdx == endDocIdx
          ? end.blockIndex.clamp(0, blocks.length - 1)
          : blocks.length - 1;

      if (firstBlock > lastBlock) continue;

      final selectedBlocks = <MarkdownSelectedBlock>[];
      for (var bIdx = firstBlock; bIdx <= lastBlock; bIdx++) {
        final block = blocks[bIdx];
        final fullText = extractBlockRenderedText(block);
        final blockStart = (docIdx == startDocIdx && bIdx == firstBlock)
            ? start.offset.clamp(0, fullText.length)
            : 0;
        final blockEnd = (docIdx == endDocIdx && bIdx == lastBlock)
            ? end.offset.clamp(0, fullText.length)
            : fullText.length;

        if (blockEnd <= blockStart && fullText.isNotEmpty) {
          continue;
        }
        if (fullText.isEmpty && block is! ThematicBreakBlock) {
          continue;
        }
        if (fullText.isEmpty &&
            (docIdx == startDocIdx && bIdx == firstBlock ||
                docIdx == endDocIdx && bIdx == lastBlock)) {
          continue;
        }

        selectedBlocks.add(
          MarkdownSelectedBlock(
            blockIndex: bIdx,
            block: block,
            fullText: fullText,
            startOffset: blockStart,
            endOffset: math.max(blockStart, blockEnd),
          ),
        );
      }

      if (selectedBlocks.isNotEmpty) {
        selectedDocs.add(
          MarkdownSelectedDocument(
            documentId: ref.id,
            document: ref.document,
            blocks: List.unmodifiable(selectedBlocks),
          ),
        );
      }
    }

    return MarkdownSelectedContent(
      selection: selection,
      documents: List.unmodifiable(selectedDocs),
    );
  }

  final MarkdownSelection selection;
  final List<MarkdownSelectedDocument> documents;

  bool get isEmpty => documents.isEmpty || documents.every((d) => d.isEmpty);

  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarkdownSelectedContent ||
        other.selection != selection ||
        other.documents.length != documents.length) {
      return false;
    }
    for (var i = 0; i < documents.length; i++) {
      if (other.documents[i] != documents[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(selection, Object.hashAll(documents));

  @override
  String toString() =>
      'MarkdownSelectedContent(selection: $selection, documents: ${documents.length})';
}

/// Formats a [MarkdownSelectedContent] snapshot into a clipboard string
/// (e.g. plain text or reconstructed Markdown).
abstract interface class MarkdownSelectionFormatter {
  String format(MarkdownSelectedContent content);
}

/// Strategy for reconciling an active [MarkdownSelection] when a registered
/// document's AST updates (such as during streaming or live editing).
@immutable
abstract class MarkdownReconciliationPolicy {
  const MarkdownReconciliationPolicy();

  /// Preserves selection when [nextDocument] is an append-only extension of
  /// [previousDocument] up through the selected range.
  const factory MarkdownReconciliationPolicy.appendFastPath() =
      _AppendFastPathReconciliationPolicy;

  /// Re-anchors the selection by matching the selected text (and surrounding
  /// context) in [nextDocument], falling back to clearing when no match exists.
  const factory MarkdownReconciliationPolicy.contentAnchored({
    int contextLength,
  }) = _ContentAnchoredReconciliationPolicy;

  /// Clears the selection whenever the document changes.
  const factory MarkdownReconciliationPolicy.clearOnChange() =
      _ClearOnChangeReconciliationPolicy;

  /// Computes the updated selection after [documentId] changes from
  /// [previousDocument] to [nextDocument].
  ///
  /// Returns `null` when the selection should be cleared.
  MarkdownSelection? reconcile({
    required String documentId,
    required MarkdownDocument previousDocument,
    required MarkdownDocument nextDocument,
    required MarkdownSelection currentSelection,
  });
}

@immutable
final class _ClearOnChangeReconciliationPolicy
    extends MarkdownReconciliationPolicy {
  const _ClearOnChangeReconciliationPolicy();

  @override
  MarkdownSelection? reconcile({
    required String documentId,
    required MarkdownDocument previousDocument,
    required MarkdownDocument nextDocument,
    required MarkdownSelection currentSelection,
  }) {
    if (previousDocument == nextDocument) return currentSelection;
    if (currentSelection.base.documentId != documentId &&
        currentSelection.extent.documentId != documentId) {
      return currentSelection;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is _ClearOnChangeReconciliationPolicy;

  @override
  int get hashCode => (_ClearOnChangeReconciliationPolicy).hashCode;
}

@immutable
final class _AppendFastPathReconciliationPolicy
    extends MarkdownReconciliationPolicy {
  const _AppendFastPathReconciliationPolicy();

  @override
  MarkdownSelection? reconcile({
    required String documentId,
    required MarkdownDocument previousDocument,
    required MarkdownDocument nextDocument,
    required MarkdownSelection currentSelection,
  }) {
    if (previousDocument == nextDocument) return currentSelection;
    if (currentSelection.base.documentId != documentId &&
        currentSelection.extent.documentId != documentId) {
      return currentSelection;
    }
    return _tryAppendFastPath(
      documentId: documentId,
      previousDocument: previousDocument,
      nextDocument: nextDocument,
      currentSelection: currentSelection,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _AppendFastPathReconciliationPolicy;

  @override
  int get hashCode => (_AppendFastPathReconciliationPolicy).hashCode;
}

@immutable
final class _ContentAnchoredReconciliationPolicy
    extends MarkdownReconciliationPolicy {
  const _ContentAnchoredReconciliationPolicy({this.contextLength = 24})
    : assert(contextLength >= 0);

  final int contextLength;

  @override
  MarkdownSelection? reconcile({
    required String documentId,
    required MarkdownDocument previousDocument,
    required MarkdownDocument nextDocument,
    required MarkdownSelection currentSelection,
  }) {
    if (previousDocument == nextDocument) return currentSelection;
    final baseInDoc = currentSelection.base.documentId == documentId;
    final extentInDoc = currentSelection.extent.documentId == documentId;
    if (!baseInDoc && !extentInDoc) return currentSelection;

    // Fast path: unchanged prefix / append-only update keeps exact coordinates.
    final fast = _tryAppendFastPath(
      documentId: documentId,
      previousDocument: previousDocument,
      nextDocument: nextDocument,
      currentSelection: currentSelection,
    );
    if (fast != null) return fast;

    if (previousDocument.blocks.isEmpty || nextDocument.blocks.isEmpty) {
      return null;
    }

    final prevFlat = _FlattenedDocument.from(previousDocument);
    final nextFlat = _FlattenedDocument.from(nextDocument);
    if (nextFlat.text.isEmpty) return null;

    if (baseInDoc && extentInDoc) {
      final isReversed = currentSelection.isReversed();
      final (:start, :end) = currentSelection.normalized();

      final flatStart = prevFlat.toFlatOffset(start.blockIndex, start.offset);
      final flatEnd = prevFlat.toFlatOffset(end.blockIndex, end.offset);
      if (flatStart == null || flatEnd == null || flatEnd < flatStart) {
        return null;
      }

      if (flatStart == flatEnd) {
        final relocated = _relocatePoint(
          prevFlat: prevFlat.text,
          nextFlat: nextFlat.text,
          flatOffset: flatStart,
          contextLength: contextLength,
        );
        if (relocated == null) return null;
        final pos = nextFlat.toMarkdownPosition(documentId, relocated);
        return MarkdownSelection.collapsed(pos);
      }

      final needle = prevFlat.text.substring(flatStart, flatEnd);
      final prefix = prevFlat.text.substring(
        math.max(0, flatStart - contextLength),
        flatStart,
      );
      final suffix = prevFlat.text.substring(
        flatEnd,
        math.min(prevFlat.text.length, flatEnd + contextLength),
      );

      final match = _findBestRangeMatch(
        haystack: nextFlat.text,
        needle: needle,
        prefix: prefix,
        suffix: suffix,
        preferredOffset: flatStart,
      );
      if (match == null) return null;

      final newStart = nextFlat.toMarkdownPosition(documentId, match.start);
      final newEnd = nextFlat.toMarkdownPosition(documentId, match.end);
      return isReversed
          ? MarkdownSelection(base: newEnd, extent: newStart)
          : MarkdownSelection(base: newStart, extent: newEnd);
    }

    // Cross-document selection where only one endpoint is in [documentId].
    final endpoint = baseInDoc
        ? currentSelection.base
        : currentSelection.extent;
    final flatOffset = prevFlat.toFlatOffset(
      endpoint.blockIndex,
      endpoint.offset,
    );
    if (flatOffset == null) return null;

    final relocated = _relocatePoint(
      prevFlat: prevFlat.text,
      nextFlat: nextFlat.text,
      flatOffset: flatOffset,
      contextLength: contextLength,
    );
    if (relocated == null) return null;

    final newEndpoint = nextFlat.toMarkdownPosition(documentId, relocated);
    return baseInDoc
        ? currentSelection.copyWith(base: newEndpoint)
        : currentSelection.copyWith(extent: newEndpoint);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ContentAnchoredReconciliationPolicy &&
        other.contextLength == contextLength;
  }

  @override
  int get hashCode =>
      Object.hash(_ContentAnchoredReconciliationPolicy, contextLength);
}

MarkdownSelection? _tryAppendFastPath({
  required String documentId,
  required MarkdownDocument previousDocument,
  required MarkdownDocument nextDocument,
  required MarkdownSelection currentSelection,
}) {
  final prevBlocks = previousDocument.blocks;
  final nextBlocks = nextDocument.blocks;
  if (prevBlocks.isEmpty || nextBlocks.isEmpty) return null;

  final endpoints = <MarkdownPosition>[
    if (currentSelection.base.documentId == documentId) currentSelection.base,
    if (currentSelection.extent.documentId == documentId)
      currentSelection.extent,
  ];
  if (endpoints.isEmpty) return currentSelection;

  var maxBlockIdx = 0;
  var maxOffsetInMaxBlock = 0;
  for (final pos in endpoints) {
    if (pos.blockIndex >= prevBlocks.length ||
        pos.blockIndex >= nextBlocks.length) {
      return null;
    }
    if (pos.blockIndex > maxBlockIdx) {
      maxBlockIdx = pos.blockIndex;
      maxOffsetInMaxBlock = pos.offset;
    } else if (pos.blockIndex == maxBlockIdx &&
        pos.offset > maxOffsetInMaxBlock) {
      maxOffsetInMaxBlock = pos.offset;
    }
  }

  for (var i = 0; i <= maxBlockIdx; i++) {
    final prevText = extractBlockRenderedText(prevBlocks[i]);
    final nextText = extractBlockRenderedText(nextBlocks[i]);

    if (i < maxBlockIdx) {
      if (prevText != nextText) return null;
    } else {
      if (maxOffsetInMaxBlock > prevText.length ||
          maxOffsetInMaxBlock > nextText.length) {
        return null;
      }
      final isTrailingPrevBlock = i == prevBlocks.length - 1;
      if (isTrailingPrevBlock) {
        // Streaming commonly appends to the last block: verify that the text
        // up to the selected endpoint is unchanged and the block grew monotonically.
        if (!nextText.startsWith(prevText)) {
          return null;
        }
      } else {
        if (prevText != nextText) return null;
      }
    }
  }

  return currentSelection;
}

({int start, int end})? _findBestRangeMatch({
  required String haystack,
  required String needle,
  required String prefix,
  required String suffix,
  required int preferredOffset,
}) {
  if (needle.isEmpty) return null;

  var bestStart = -1;
  var bestScore = -1;
  var bestDistance = 1 << 30;

  var searchFrom = 0;
  while (searchFrom <= haystack.length - needle.length) {
    final idx = haystack.indexOf(needle, searchFrom);
    if (idx < 0) break;

    final score =
        _commonSuffixLength(haystack, idx, prefix) +
        _commonPrefixLength(haystack, idx + needle.length, suffix);
    final distance = (idx - preferredOffset).abs();

    if (score > bestScore || (score == bestScore && distance < bestDistance)) {
      bestScore = score;
      bestDistance = distance;
      bestStart = idx;
    }
    searchFrom = idx + 1;
  }

  if (bestStart >= 0) {
    return (start: bestStart, end: bestStart + needle.length);
  }

  // Secondary fallback: if block separators shifted (e.g. `\n` vs `\n\n`),
  // match with normalized whitespace and map back to haystack coordinates.
  return _findWhitespaceNormalizedMatch(
    haystack: haystack,
    needle: needle,
    preferredOffset: preferredOffset,
  );
}

({int start, int end})? _findWhitespaceNormalizedMatch({
  required String haystack,
  required String needle,
  required int preferredOffset,
}) {
  final normNeedle = _normalizeWhitespace(needle);
  if (normNeedle.text.isEmpty) return null;
  final normHaystack = _normalizeWhitespace(haystack);
  if (normHaystack.text.length < normNeedle.text.length) return null;

  var bestStart = -1;
  var bestEnd = -1;
  var bestDistance = 1 << 30;

  var searchFrom = 0;
  while (searchFrom <= normHaystack.text.length - normNeedle.text.length) {
    final idx = normHaystack.text.indexOf(normNeedle.text, searchFrom);
    if (idx < 0) break;

    final rawStart = normHaystack.indexMap[idx];
    final rawEndIdx = idx + normNeedle.text.length - 1;
    final rawEnd = normHaystack.indexMap[rawEndIdx] + 1;
    final distance = (rawStart - preferredOffset).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestStart = rawStart;
      bestEnd = rawEnd;
    }
    searchFrom = idx + 1;
  }

  if (bestStart < 0) return null;
  return (start: bestStart, end: bestEnd);
}

({String text, List<int> indexMap}) _normalizeWhitespace(String input) {
  final buffer = StringBuffer();
  final indexMap = <int>[];
  var inSpace = false;
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    final isSpace =
        code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;
    if (isSpace) {
      if (!inSpace && buffer.isNotEmpty) {
        buffer.writeCharCode(0x20);
        indexMap.add(i);
      }
      inSpace = true;
    } else {
      buffer.writeCharCode(code);
      indexMap.add(i);
      inSpace = false;
    }
  }
  var result = buffer.toString();
  if (result.endsWith(' ')) {
    result = result.substring(0, result.length - 1);
    indexMap.removeLast();
  }
  return (text: result, indexMap: indexMap);
}

int? _relocatePoint({
  required String prevFlat,
  required String nextFlat,
  required int flatOffset,
  required int contextLength,
}) {
  final effectiveContext = math.max(contextLength, 8);
  final prefix = prevFlat.substring(
    math.max(0, flatOffset - effectiveContext),
    flatOffset,
  );
  final suffix = prevFlat.substring(
    flatOffset,
    math.min(prevFlat.length, flatOffset + effectiveContext),
  );

  if (prefix.isNotEmpty && suffix.isNotEmpty) {
    final combined = '$prefix$suffix';
    final idx = _closestOccurrence(
      nextFlat,
      combined,
      flatOffset - prefix.length,
    );
    if (idx >= 0) return idx + prefix.length;
  }
  if (prefix.isNotEmpty) {
    final idx = _closestOccurrence(
      nextFlat,
      prefix,
      flatOffset - prefix.length,
    );
    if (idx >= 0) return idx + prefix.length;
  }
  if (suffix.isNotEmpty) {
    final idx = _closestOccurrence(nextFlat, suffix, flatOffset);
    if (idx >= 0) return idx;
  }
  return null;
}

int _closestOccurrence(String haystack, String needle, int preferred) {
  var best = -1;
  var bestDist = 1 << 30;
  var from = 0;
  while (from <= haystack.length - needle.length) {
    final idx = haystack.indexOf(needle, from);
    if (idx < 0) break;
    final dist = (idx - preferred).abs();
    if (dist < bestDist) {
      bestDist = dist;
      best = idx;
    }
    from = idx + 1;
  }
  return best;
}

int _commonSuffixLength(String haystack, int endOffset, String prefix) {
  var matched = 0;
  final maxLen = math.min(endOffset, prefix.length);
  while (matched < maxLen &&
      haystack.codeUnitAt(endOffset - 1 - matched) ==
          prefix.codeUnitAt(prefix.length - 1 - matched)) {
    matched++;
  }
  return matched;
}

int _commonPrefixLength(String haystack, int startOffset, String suffix) {
  var matched = 0;
  final maxLen = math.min(haystack.length - startOffset, suffix.length);
  while (matched < maxLen &&
      haystack.codeUnitAt(startOffset + matched) ==
          suffix.codeUnitAt(matched)) {
    matched++;
  }
  return matched;
}

class _BlockSpan {
  const _BlockSpan({
    required this.blockIndex,
    required this.start,
    required this.end,
  });

  final int blockIndex;
  final int start;
  final int end;
}

class _FlattenedDocument {
  const _FlattenedDocument({required this.text, required this.spans});

  factory _FlattenedDocument.from(MarkdownDocument document) {
    final buffer = StringBuffer();
    final spans = <_BlockSpan>[];
    for (var i = 0; i < document.blocks.length; i++) {
      if (i > 0) {
        buffer.write('\n\n');
      }
      final start = buffer.length;
      final blockText = extractBlockRenderedText(document.blocks[i]);
      buffer.write(blockText);
      spans.add(_BlockSpan(blockIndex: i, start: start, end: buffer.length));
    }
    return _FlattenedDocument(text: buffer.toString(), spans: spans);
  }

  final String text;
  final List<_BlockSpan> spans;

  int? toFlatOffset(int blockIndex, int offset) {
    if (blockIndex < 0 || blockIndex >= spans.length) return null;
    final span = spans[blockIndex];
    final clamped = offset.clamp(0, span.end - span.start);
    return span.start + clamped;
  }

  MarkdownPosition toMarkdownPosition(String documentId, int flatOffset) {
    final clamped = flatOffset.clamp(0, text.length);
    for (final span in spans) {
      if (clamped <= span.end) {
        final localOffset = (clamped - span.start).clamp(
          0,
          span.end - span.start,
        );
        return MarkdownPosition(
          documentId: documentId,
          blockIndex: span.blockIndex,
          offset: localOffset,
        );
      }
    }
    final last = spans.last;
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: last.blockIndex,
      offset: last.end - last.start,
    );
  }
}

/// Contract implemented by selectable text render objects (such as
/// `RenderSelectableParagraph`) to participate in `MarkdownSelectionController`.
abstract interface class MarkdownSelectionSurface {
  /// Identifier of the registered [MarkdownDocumentRef] owning this surface.
  String get documentId;

  /// Top-level block index in the owning document.
  int get blockIndex;

  /// Starting UTF-16 offset of this surface's text inside the owning block's
  /// canonical rendered text ([extractBlockRenderedText]).
  int get textOffsetInBlock;

  /// UTF-16 code unit length of the text rendered by this surface.
  int get textLength;

  /// Resolved [TextDirection] of this surface.
  TextDirection get textDirection;

  /// Bounding box in global logical coordinates, or `null` if not attached or
  /// not laid out yet.
  Rect? get globalBounds;

  /// Whether this surface currently hosts either start or end selection handle
  /// leader layers.
  bool get hasSelectionHandleLeaders;

  /// Returns `true` if [globalOffset] hits rendered text geometry on this
  /// surface (excluding empty background padding).
  bool hitsTextAtGlobal(Offset globalOffset);

  /// Maps [globalOffset] to the nearest model-anchored [MarkdownPosition]
  /// within this surface.
  MarkdownPosition positionForGlobalOffset(Offset globalOffset);

  /// Returns the local UTF-16 [TextRange] of the word at [localOffset].
  TextRange wordRangeAtLocal(int localOffset);

  /// Returns the local UTF-16 [TextRange] of the visual line at [localOffset].
  TextRange lineRangeAtLocal(int localOffset);

  /// Returns selection [TextBox]es in local coordinates for `[start, end)`.
  List<TextBox> boxesForLocalRange(int start, int end);

  /// Returns the caret [Rect] in local coordinates for [offset].
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  });

  /// Returns the caret [Rect] in global coordinates for [offset], or `null` if
  /// not attached or not laid out yet.
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  });

  /// Updates the active local highlight range, or `null` to clear highlights.
  void setSelectionHighlightRange(TextRange? range);

  /// Links selection handle [LayerLink]s to this surface at the requested local
  /// offsets so handle overlays track scrolling smoothly.
  void setSelectionHandleLayers({
    LayerLink? startHandleLayerLink,
    int? startHandleLocalOffset,
    LayerLink? endHandleLayerLink,
    int? endHandleLocalOffset,
  });

  /// Clears handle layer links from this surface if they match the provided
  /// links.
  void clearSelectionHandleLayersIfLinked({
    LayerLink? startHandleLayerLink,
    LayerLink? endHandleLayerLink,
  });
}

/// Convenience offset helpers for [MarkdownSelectionSurface] consumers.
extension MarkdownSelectionSurfaceExtensions on MarkdownSelectionSurface {
  /// Exclusive end offset of this surface within its owning block's rendered text.
  int get blockEndOffset => textOffsetInBlock + textLength;

  /// Converts a block-level range `[blockStart, blockEnd)` into a local
  /// [TextRange] clamped to this surface, or `null` if disjoint.
  TextRange? localRangeForBlockRange(int blockStart, int blockEnd) {
    final start = math.max(blockStart, textOffsetInBlock);
    final end = math.min(blockEnd, blockEndOffset);
    if (end <= start) return null;
    return TextRange(
      start: start - textOffsetInBlock,
      end: end - textOffsetInBlock,
    );
  }
}
