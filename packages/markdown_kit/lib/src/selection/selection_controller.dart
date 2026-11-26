import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../ast/rendered_text.dart';
import 'selection_formatter.dart';
import 'selection_model.dart';

/// Resolved surface and screen-space geometry for the logical start and end
/// endpoints of an active selection.
///
/// Either endpoint may be `null` when its corresponding text surface has been
/// scrolled off-screen and unmounted while the other endpoint remains visible.
@immutable
class MarkdownHandleEndpoints {
  /// Creates a snapshot of handle endpoints.
  const MarkdownHandleEndpoints({
    this.startSurface,
    this.endSurface,
    this.startLocalOffset,
    this.endLocalOffset,
    this.startGlobal,
    this.endGlobal,
    this.startLineHeight,
    this.endLineHeight,
  });

  /// The mounted text surface containing the start of the selection, or null
  /// when that text is not currently mounted.
  final MarkdownSelectionSurface? startSurface;

  /// The mounted text surface containing the end of the selection, or null when
  /// that text is not currently mounted.
  final MarkdownSelectionSurface? endSurface;

  /// UTF-16 offset of the selection start within [startSurface]'s own text.
  final int? startLocalOffset;

  /// UTF-16 offset of the selection end within [endSurface]'s own text.
  final int? endLocalOffset;

  /// Where the start handle is anchored, in global coordinates: the bottom-left
  /// corner of the caret at the selection start.
  final Offset? startGlobal;

  /// Where the end handle is anchored, in global coordinates: the bottom-left
  /// corner of the caret at the selection end.
  final Offset? endGlobal;

  /// Height of the caret at the selection start, in logical pixels.
  final double? startLineHeight;

  /// Height of the caret at the selection end, in logical pixels.
  final double? endLineHeight;

  /// Whether the start of the selection is on a mounted surface, so its handle
  /// can be shown.
  bool get hasStart =>
      startSurface != null && startLocalOffset != null && startGlobal != null;

  /// Whether the end of the selection is on a mounted surface, so its handle
  /// can be shown.
  bool get hasEnd =>
      endSurface != null && endLocalOffset != null && endGlobal != null;

  /// Whether at least one endpoint can show a handle.
  bool get hasAny => hasStart || hasEnd;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownHandleEndpoints &&
        other.startSurface == startSurface &&
        other.endSurface == endSurface &&
        other.startLocalOffset == startLocalOffset &&
        other.endLocalOffset == endLocalOffset &&
        other.startGlobal == startGlobal &&
        other.endGlobal == endGlobal &&
        other.startLineHeight == startLineHeight &&
        other.endLineHeight == endLineHeight;
  }

  @override
  int get hashCode => Object.hash(
    startSurface,
    endSurface,
    startLocalOffset,
    endLocalOffset,
    startGlobal,
    endGlobal,
    startLineHeight,
    endLineHeight,
  );
}

/// Model-anchored selection controller managing one or more Markdown documents
/// and their currently mounted [MarkdownSelectionSurface]s.
///
/// Selection state is stored as AST coordinates ([MarkdownSelection]) rather
/// than render-object references, so selections survive virtualized list
/// disposal/remounting and live streaming updates via [reconciliationPolicy].
class MarkdownSelectionController extends ChangeNotifier {
  /// Creates a selection controller.
  ///
  /// [plainTextFormatter] defaults to a [MarkdownPlainTextFormatter] and
  /// [markupFormatter] to a [MarkdownMarkupFormatter].
  MarkdownSelectionController({
    this.allowCrossDocumentSelection = true,
    this.reconciliationPolicy =
        const MarkdownReconciliationPolicy.contentAnchored(),
    MarkdownSelectionFormatter? plainTextFormatter,
    MarkdownSelectionFormatter? markupFormatter,
    this.selectionColor,
  }) : plainTextFormatter =
           plainTextFormatter ?? const MarkdownPlainTextFormatter(),
       markupFormatter = markupFormatter ?? const MarkdownMarkupFormatter();

  /// Whether a single selection may span across multiple registered documents.
  ///
  /// When `false` (for example in a chat message list), extending or moving a
  /// selection handle is strictly clamped to the anchor document's start and
  /// end boundaries, and [selectAll] selects only the anchor document.
  final bool allowCrossDocumentSelection;

  /// Policy used to preserve or relocate selection when a document updates.
  final MarkdownReconciliationPolicy reconciliationPolicy;

  /// Formatter used by [getText].
  final MarkdownSelectionFormatter plainTextFormatter;

  /// Formatter used by [getMarkdown].
  final MarkdownSelectionFormatter markupFormatter;

  /// Optional default highlight color used by selection surfaces and scopes.
  final Color? selectionColor;

  final Map<String, MarkdownDocumentRef> _documents =
      <String, MarkdownDocumentRef>{};
  final Set<MarkdownSelectionSurface> _surfaces = <MarkdownSelectionSurface>{};

  List<MarkdownDocumentRef>? _sortedDocumentsCache;
  Map<String, int>? _documentOrderCache;

  MarkdownSelection? _selection;
  bool _toolbarWanted = false;
  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _surfaces.clear();
    _documents.clear();
    _invalidateDocumentOrderCache();
    super.dispose();
  }

  /// Whether at least one document is registered.
  bool get hasDocuments => _documents.isNotEmpty;

  /// Registered documents sorted in reading order.
  List<MarkdownDocumentRef> get documents => _sortedDocuments();

  /// Currently mounted selectable surfaces participating in this controller.
  Set<MarkdownSelectionSurface> get mountedSurfaces =>
      Set<MarkdownSelectionSurface>.unmodifiable(_surfaces);

  /// Active model-anchored selection, or `null` when nothing is selected.
  MarkdownSelection? get selection => _selection;

  /// Whether there is an active non-collapsed selection.
  bool get hasSelection => _selection != null && !_selection!.isCollapsed;

  /// Whether the active selection's extent precedes its base in reading order.
  bool get isSelectionReversed {
    final sel = _selection;
    if (sel == null) return false;
    return sel.isReversed(documentOrder: _documentOrderMap());
  }

  /// Whether the selection context menu / toolbar is currently requested.
  bool get toolbarWanted => _toolbarWanted && hasSelection;

  set toolbarWanted(bool value) {
    final next = value && hasSelection;
    if (_toolbarWanted == next) return;
    _toolbarWanted = next;
    notifyListeners();
  }

  /// Returns the registered [MarkdownDocumentRef] for [documentId], if any.
  MarkdownDocumentRef? documentForId(String documentId) =>
      _documents[documentId];

  /// Returns the normalized `(start, end)` endpoints in reading order, or
  /// `null` if no selection is active.
  ({MarkdownPosition start, MarkdownPosition end})? get normalizedSelection {
    final sel = _selection;
    if (sel == null) return null;
    return sel.normalized(documentOrder: _documentOrderMap());
  }

  /// Registers or updates a document, reconciling any active selection through
  /// [reconciliationPolicy].
  void putDocument(MarkdownDocumentRef ref) {
    if (_disposed) return;
    final previous = _documents[ref.id];
    if (previous == ref) return;

    _documents[ref.id] = ref;
    _invalidateDocumentOrderCache();

    var selectionChanged = false;
    if (previous != null && _selection != null) {
      final reconciled = reconciliationPolicy.reconcile(
        documentId: ref.id,
        previousDocument: previous.document,
        nextDocument: ref.document,
        currentSelection: _selection!,
      );
      final clamped = reconciled == null ? null : _clampSelection(reconciled);
      if (clamped != _selection) {
        _selection = clamped;
        if (!hasSelection) {
          _toolbarWanted = false;
        }
        selectionChanged = true;
      }
    } else if (_selection != null &&
        (_selection!.base.documentId == ref.id ||
            _selection!.extent.documentId == ref.id)) {
      final clamped = _clampSelection(_selection!);
      if (clamped != _selection) {
        _selection = clamped;
        if (!hasSelection) {
          _toolbarWanted = false;
        }
        selectionChanged = true;
      }
    }

    if (selectionChanged || _selection != null) {
      _syncAllSurfaceHighlights();
    }
    if (selectionChanged) {
      notifyListeners();
    }
  }

  /// Unregisters a document by [documentId].
  ///
  /// Clears the active selection if either endpoint belonged to [documentId].
  void removeDocument(String documentId) {
    if (_disposed) return;
    if (_documents.remove(documentId) == null) return;
    _invalidateDocumentOrderCache();

    final sel = _selection;
    if (sel != null &&
        (sel.base.documentId == documentId ||
            sel.extent.documentId == documentId)) {
      _selection = null;
      _toolbarWanted = false;
      _syncAllSurfaceHighlights();
      notifyListeners();
    }
  }

  /// Registers a mounted [MarkdownSelectionSurface] and syncs its highlight.
  void registerSurface(MarkdownSelectionSurface surface) {
    if (_disposed) return;
    if (!_surfaces.add(surface)) {
      _syncSurfaceHighlight(surface);
      return;
    }
    _syncSurfaceHighlight(surface);
    if (hasSelection) {
      _notifySurfaceChange();
    }
  }

  /// Unregisters a surface when unmounted/disposed without clearing selection.
  void unregisterSurface(MarkdownSelectionSurface surface) {
    if (_disposed) return;
    if (!_surfaces.remove(surface)) return;
    if (hasSelection) {
      _notifySurfaceChange();
    }
  }

  bool _surfaceNotifyScheduled = false;

  /// Surfaces attach and detach while the frame is being built and laid out.
  /// Notifying right then would make any listener that rebuilds throw
  /// "setState() called during build", so wait for the frame to finish.
  void _notifySurfaceChange() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_surfaceNotifyScheduled) return;
    _surfaceNotifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _surfaceNotifyScheduled = false;
      if (_disposed) return;
      notifyListeners();
    });
  }

  /// Programmatically updates [selection] and optional [toolbarWanted].
  void setSelection(MarkdownSelection? nextSelection, {bool? toolbarWanted}) {
    final clamped = nextSelection == null
        ? null
        : _clampSelection(nextSelection);
    final nextToolbar =
        (toolbarWanted ?? _toolbarWanted) &&
        clamped != null &&
        !clamped.isCollapsed;
    if (clamped == _selection && nextToolbar == _toolbarWanted) {
      return;
    }
    _selection = clamped;
    _toolbarWanted = nextToolbar;
    _syncAllSurfaceHighlights();
    notifyListeners();
  }

  /// Returns `true` if [global] hits rendered text on any mounted surface.
  bool hitsSelectableContent(Offset global) {
    for (final surface in _surfaces) {
      if (surface.hitsTextAtGlobal(global)) {
        return true;
      }
    }
    return false;
  }

  /// Starts a collapsed selection at the nearest text position to [global].
  ///
  /// Always replaces any prior selection (even across documents when
  /// [allowCrossDocumentSelection] is `false`).
  bool startAtGlobal(Offset global) {
    final surface = _surfaceForGlobal(global);
    if (surface == null) return false;

    final pos = _clampPosition(surface.positionForGlobalOffset(global));
    _selection = MarkdownSelection.collapsed(pos);
    _toolbarWanted = false;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Selects the word containing [global].
  ///
  /// Replaces any prior selection cleanly.
  bool selectWordAtGlobal(Offset global) {
    final surface = _surfaceForGlobal(global);
    if (surface == null) return false;

    final pos = surface.positionForGlobalOffset(global);
    var localOffset = (pos.offset - surface.textOffsetInBlock).clamp(
      0,
      surface.textLength,
    );
    // The surface reports the nearest caret, which sits after the glyph when
    // the pointer is on its trailing half. The word lookup wants the glyph
    // under the pointer, so step back onto it. Testing the glyph's own box
    // (rather than comparing against the caret) holds for wrapped lines and
    // for right-to-left and mixed-direction text alike.
    if (localOffset > 0) {
      final origin = surface.globalBounds?.topLeft;
      // The previous glyph may span several code units (emoji).
      final blockText = _blockText(surface.documentId, surface.blockIndex);
      final blockOffset = surface.textOffsetInBlock + localOffset;
      final previous = blockText != null && blockOffset <= blockText.length
          ? math.max(
              0,
              _previousGraphemeOffset(blockText, blockOffset) -
                  surface.textOffsetInBlock,
            )
          : localOffset - 1;
      if (origin != null) {
        for (final box in surface.boxesForLocalRange(previous, localOffset)) {
          final glyph = box.toRect().shift(origin);
          if (global.dx >= glyph.left &&
              global.dx <= glyph.right &&
              global.dy >= glyph.top &&
              global.dy <= glyph.bottom) {
            localOffset = previous;
            break;
          }
        }
      }
    }
    final wordRange = surface.wordRangeAtLocal(localOffset);

    MarkdownSelection next;
    if (wordRange.isValid && !wordRange.isCollapsed) {
      final startOffset =
          surface.textOffsetInBlock +
          wordRange.start.clamp(0, surface.textLength);
      final endOffset =
          surface.textOffsetInBlock +
          wordRange.end.clamp(0, surface.textLength);
      next = MarkdownSelection(
        base: MarkdownPosition(
          documentId: surface.documentId,
          blockIndex: surface.blockIndex,
          offset: startOffset,
        ),
        extent: MarkdownPosition(
          documentId: surface.documentId,
          blockIndex: surface.blockIndex,
          offset: endOffset,
        ),
      );
    } else if (surface.textLength > 0) {
      final startLocal = localOffset >= surface.textLength
          ? surface.textLength - 1
          : localOffset;
      final endLocal = math.min(startLocal + 1, surface.textLength);
      next = MarkdownSelection(
        base: MarkdownPosition(
          documentId: surface.documentId,
          blockIndex: surface.blockIndex,
          offset: surface.textOffsetInBlock + startLocal,
        ),
        extent: MarkdownPosition(
          documentId: surface.documentId,
          blockIndex: surface.blockIndex,
          offset: surface.textOffsetInBlock + endLocal,
        ),
      );
    } else {
      next = MarkdownSelection.collapsed(pos);
    }

    _selection = _clampSelection(next);
    _toolbarWanted = false;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Selects the entire top-level block containing [global].
  bool selectBlockAtGlobal(Offset global) {
    final surface = _surfaceForGlobal(global);
    if (surface == null) return false;

    final blockLength =
        _blockLength(surface.documentId, surface.blockIndex) ??
        surface.blockEndOffset;
    final next = MarkdownSelection(
      base: MarkdownPosition(
        documentId: surface.documentId,
        blockIndex: surface.blockIndex,
        offset: 0,
      ),
      extent: MarkdownPosition(
        documentId: surface.documentId,
        blockIndex: surface.blockIndex,
        offset: blockLength,
      ),
    );
    _selection = _clampSelection(next);
    _toolbarWanted = false;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Extends the active selection's [MarkdownSelection.extent] to [global].
  ///
  /// When [allowCrossDocumentSelection] is `false`, strictly clamps to the
  /// anchor document's start/end boundaries.
  bool extendToGlobal(Offset global) {
    final current = _selection;
    if (current == null) return false;

    final restrictDocId = allowCrossDocumentSelection
        ? null
        : current.base.documentId;
    final nextExtent = _positionForGlobal(
      global,
      restrictDocumentId: restrictDocId,
    );
    if (nextExtent == null) return false;

    final next = _clampSelection(
      MarkdownSelection(base: current.base, extent: nextExtent),
    );
    if (next == current) return false;

    _selection = next;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Extends from an initial [anchor] range (word or block) to [global],
  /// snapping the moving endpoint to word ([word] == `true`) or block
  /// ([word] == `false`) boundaries while preserving the full [anchor] range.
  bool extendGranular(
    MarkdownSelection anchor,
    Offset global, {
    required bool word,
  }) {
    final order = _documentOrderMap();
    final (:start, :end) = anchor.normalized(documentOrder: order);
    final restrictDocId = allowCrossDocumentSelection ? null : start.documentId;

    final targetRange = _granularRangeForGlobal(
      global,
      word: word,
      restrictDocumentId: restrictDocId,
    );
    if (targetRange == null) return false;

    MarkdownSelection next;
    if (targetRange.start.compareTo(start, documentOrder: order) < 0) {
      // Extending backward before anchor: base at anchor.end, extent at target.start.
      next = MarkdownSelection(base: end, extent: targetRange.start);
    } else if (targetRange.end.compareTo(end, documentOrder: order) > 0) {
      // Extending forward past anchor: base at anchor.start, extent at target.end.
      next = MarkdownSelection(base: start, extent: targetRange.end);
    } else {
      next = MarkdownSelection(base: start, extent: end);
    }

    final clamped = _clampSelection(next);
    if (clamped == _selection) return false;

    _selection = clamped;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Moves either the logical start (`isStart == true`) or logical end
  /// (`isStart == false`) endpoint of the active selection to [global].
  ///
  /// When [allowCrossDocumentSelection] is `false`, strictly clamps to the
  /// fixed endpoint's document boundaries. Prevents collapsing to zero length
  /// when dragged directly onto the opposite endpoint; dragging past the
  /// opposite endpoint cleanly flips the selection.
  bool moveSelectionEdgeToGlobal(Offset global, {required bool isStart}) {
    final current = _selection;
    if (current == null) return false;

    final order = _documentOrderMap();
    final (:start, :end) = current.normalized(documentOrder: order);
    final fixed = isStart ? end : start;
    final restrictDocId = allowCrossDocumentSelection ? null : fixed.documentId;

    final nextPos = _positionForGlobal(
      global,
      restrictDocumentId: restrictDocId,
    );
    if (nextPos == null || nextPos == fixed) return false;

    final next = _clampSelection(
      MarkdownSelection(base: fixed, extent: nextPos),
    );
    if (next == current) return false;

    _selection = next;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Selects all text in [documentId], the anchor document (when
  /// [allowCrossDocumentSelection] is `false`), or across all registered
  /// documents (when [allowCrossDocumentSelection] is `true`).
  bool selectAll({String? documentId}) {
    final sortedDocs = _sortedDocuments();
    if (sortedDocs.isEmpty) {
      return _selectAllFromMountedSurfaces(documentId: documentId);
    }

    if (documentId != null) {
      return _selectFullDocument(documentId);
    }

    if (!allowCrossDocumentSelection) {
      final targetDocId = _resolveSingleTargetDocumentId(sortedDocs);
      if (targetDocId == null) return false;
      return _selectFullDocument(targetDocId);
    }

    MarkdownPosition? firstPos;
    MarkdownPosition? lastPos;
    for (final ref in sortedDocs) {
      final start = _documentStartPosition(ref.id);
      final end = _documentEndPosition(ref.id);
      if (start != null && end != null && start != end) {
        firstPos ??= start;
        lastPos = end;
      }
    }
    if (firstPos == null || lastPos == null) return false;

    _selection = MarkdownSelection(base: firstPos, extent: lastPos);
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  /// Clears the active selection and all mounted surface highlights.
  void clear() {
    if (_selection == null && !_toolbarWanted) return;
    _selection = null;
    _toolbarWanted = false;
    for (final surface in _surfaces) {
      surface.setSelectionHighlightRange(null);
    }
    notifyListeners();
  }

  /// Extends the selection extent by one grapheme cluster.
  bool extendByCharacter({required bool forward}) {
    final current = _selection;
    if (current == null) return false;

    final nextExtent = _stepCharacter(current.extent, forward: forward);
    if (nextExtent == null || nextExtent == current.extent) return false;

    return _applyExtendedExtent(current.base, nextExtent);
  }

  /// Extends the selection extent by one word.
  bool extendByWord({required bool forward}) {
    final current = _selection;
    if (current == null) return false;

    final nextExtent = _stepWord(current.extent, forward: forward);
    if (nextExtent == null || nextExtent == current.extent) return false;

    return _applyExtendedExtent(current.base, nextExtent);
  }

  /// Extends the selection extent to the start or end of the current visual
  /// line (falling back to logical line breaks when off-screen).
  bool extendToLineBreak({required bool forward}) {
    final current = _selection;
    if (current == null) return false;

    final extent = current.extent;
    final surface = _surfaceForPosition(extent, preferUpstream: !forward);
    MarkdownPosition? nextExtent;
    if (surface != null) {
      final local = (extent.offset - surface.textOffsetInBlock).clamp(
        0,
        surface.textLength,
      );
      final lineRange = surface.lineRangeAtLocal(local);
      if (lineRange.isValid) {
        final targetLocal = forward ? lineRange.end : lineRange.start;
        nextExtent = MarkdownPosition(
          documentId: extent.documentId,
          blockIndex: extent.blockIndex,
          offset:
              surface.textOffsetInBlock +
              targetLocal.clamp(0, surface.textLength),
        );
      }
    }

    if (nextExtent == null) {
      final text = _blockText(extent.documentId, extent.blockIndex);
      if (text == null) return false;
      final clamped = extent.offset.clamp(0, text.length);
      if (forward) {
        final nl = text.indexOf('\n', clamped);
        nextExtent = extent.copyWith(offset: nl >= 0 ? nl : text.length);
      } else {
        final nl = clamped > 0 ? text.lastIndexOf('\n', clamped - 1) : -1;
        nextExtent = extent.copyWith(offset: nl >= 0 ? nl + 1 : 0);
      }
    }

    if (nextExtent == extent) return false;
    return _applyExtendedExtent(current.base, nextExtent);
  }

  /// Extends the selection extent vertically to the adjacent visual line.
  bool extendToAdjacentLine({required bool forward}) {
    final current = _selection;
    if (current == null) return false;

    final extent = current.extent;
    final restrictDocId = allowCrossDocumentSelection
        ? null
        : current.base.documentId;

    final surface = _surfaceForPosition(extent, preferUpstream: false);
    if (surface != null) {
      final local = (extent.offset - surface.textOffsetInBlock).clamp(
        0,
        surface.textLength,
      );
      final caretRect = surface.globalRectForLocalOffset(local);
      if (caretRect != null && caretRect.height > 0) {
        final probeY = forward
            ? caretRect.bottom + caretRect.height * 0.5
            : caretRect.top - caretRect.height * 0.5;
        final candidate = _positionForGlobal(
          Offset(caretRect.center.dx, probeY),
          restrictDocumentId: restrictDocId,
        );
        if (candidate != null && candidate != extent) {
          return _applyExtendedExtent(current.base, candidate);
        }
      }
    }

    // Off-screen or inter-block fallback: jump to adjacent block boundary.
    final adjacent = _adjacentSelectableBlock(
      extent,
      forward: forward,
      restrictDocumentId: restrictDocId,
    );
    if (adjacent == null) return false;
    final nextExtent = MarkdownPosition(
      documentId: adjacent.documentId,
      blockIndex: adjacent.blockIndex,
      offset: forward ? 0 : adjacent.text.length,
    );
    return _applyExtendedExtent(current.base, nextExtent);
  }

  /// Extends the selection extent to the start or end of the document
  /// (or scope when [allowCrossDocumentSelection] is `true`).
  bool extendToDocumentBoundary({required bool forward}) {
    final current = _selection;
    if (current == null) return false;

    MarkdownPosition? target;
    if (!allowCrossDocumentSelection) {
      target = forward
          ? _documentEndPosition(current.base.documentId)
          : _documentStartPosition(current.base.documentId);
    } else {
      final sorted = _sortedDocuments();
      if (sorted.isNotEmpty) {
        if (forward) {
          for (var i = sorted.length - 1; i >= 0; i--) {
            target = _documentEndPosition(sorted[i].id);
            if (target != null) break;
          }
        } else {
          for (final ref in sorted) {
            target = _documentStartPosition(ref.id);
            if (target != null) break;
          }
        }
      }
    }

    if (target == null || target == current.extent) return false;
    return _applyExtendedExtent(current.base, target);
  }

  /// Computes surface and global geometry for the start and end selection
  /// handles, or `null` when no non-collapsed selection has a mounted endpoint.
  MarkdownHandleEndpoints? selectionHandleEndpoints() {
    if (!hasSelection) return null;
    final (:start, :end) = normalizedSelection!;

    final startResolved = _resolveEndpoint(start, preferUpstream: false);
    final endResolved = _resolveEndpoint(end, preferUpstream: true);

    if (startResolved == null && endResolved == null) {
      return null;
    }

    return MarkdownHandleEndpoints(
      startSurface: startResolved?.surface,
      endSurface: endResolved?.surface,
      startLocalOffset: startResolved?.localOffset,
      endLocalOffset: endResolved?.localOffset,
      startGlobal: startResolved?.caretRect.bottomLeft,
      endGlobal: endResolved?.caretRect.bottomLeft,
      startLineHeight: startResolved?.caretRect.height,
      endLineHeight: endResolved?.caretRect.height,
    );
  }

  /// Returns global-coordinate selection highlight rectangles across all
  /// currently mounted surfaces in reading order.
  List<Rect> globalSelectionRects() {
    if (!hasSelection) return const [];
    final rects = <Rect>[];
    for (final surface in _sortedMountedSurfaces()) {
      final range = _highlightRangeForSurface(surface);
      if (range == null || range.isCollapsed) continue;
      final bounds = surface.globalBounds;
      if (bounds == null) continue;
      final boxes = surface.boxesForLocalRange(range.start, range.end);
      if (boxes.isNotEmpty) {
        for (final box in boxes) {
          rects.add(box.toRect().shift(bounds.topLeft));
        }
      } else {
        final startRect = surface.globalRectForLocalOffset(
          range.start,
          affinity: TextAffinity.downstream,
        );
        final endRect = surface.globalRectForLocalOffset(
          range.end,
          affinity: TextAffinity.upstream,
        );
        if (startRect != null && endRect != null) {
          rects.add(startRect.expandToInclude(endRect));
        }
      }
    }
    return rects;
  }

  /// Returns the global caret [Rect] for either [MarkdownSelection.base]
  /// (`base == true`) or [MarkdownSelection.extent] (`base == false`).
  Rect? selectionEndpointGlobalRect({required bool base}) {
    final sel = _selection;
    if (sel == null) return null;
    final pos = base ? sel.base : sel.extent;
    final order = _documentOrderMap();
    final isEnd =
        !sel.isCollapsed && pos == sel.normalized(documentOrder: order).end;
    final resolved = _resolveEndpoint(pos, preferUpstream: isEnd);
    return resolved?.caretRect;
  }

  /// Computes the bounding union of mounted surfaces (scoped to the anchor
  /// document when [allowCrossDocumentSelection] is `false`), or `null` when
  /// unmounted blocks exist beyond mounted bounds.
  Rect? mountedHostBounds({bool respectCrossDocumentLimit = true}) {
    final restrictDocId =
        respectCrossDocumentLimit &&
            !allowCrossDocumentSelection &&
            _selection != null
        ? _selection!.base.documentId
        : null;

    Rect? union;
    for (final surface in _surfaces) {
      if (restrictDocId != null && surface.documentId != restrictDocId) {
        continue;
      }
      final bounds = surface.globalBounds;
      if (bounds == null) continue;
      union = union == null ? bounds : union.expandToInclude(bounds);
    }
    return union;
  }

  /// Extracts a structured [MarkdownSelectedContent] snapshot of the active
  /// selection from registered documents.
  MarkdownSelectedContent selectedContent() {
    final sel = _selection;
    if (sel == null || sel.isCollapsed) {
      return MarkdownSelectedContent(
        selection:
            sel ??
            const MarkdownSelection.collapsed(
              MarkdownPosition(documentId: '', blockIndex: 0, offset: 0),
            ),
        documents: const [],
      );
    }
    return MarkdownSelectedContent.extract(
      selection: sel,
      documents: _documents.values,
    );
  }

  /// Returns the active selection formatted as plain text via
  /// [plainTextFormatter].
  String getText() => plainTextFormatter.format(selectedContent());

  /// Returns the active selection formatted as Markdown via [markupFormatter].
  String getMarkdown() => markupFormatter.format(selectedContent());

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _invalidateDocumentOrderCache() {
    _sortedDocumentsCache = null;
    _documentOrderCache = null;
  }

  List<MarkdownDocumentRef> _sortedDocuments() {
    final cached = _sortedDocumentsCache;
    if (cached != null) return cached;
    final sorted = _documents.values.toList()
      ..sort((a, b) {
        final orderCmp = a.order.compareTo(b.order);
        return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
      });
    final unmodifiable = List<MarkdownDocumentRef>.unmodifiable(sorted);
    _sortedDocumentsCache = unmodifiable;
    return unmodifiable;
  }

  Map<String, int> _documentOrderMap() {
    final cached = _documentOrderCache;
    if (cached != null) return cached;
    final sorted = _sortedDocuments();
    final map = <String, int>{
      for (var i = 0; i < sorted.length; i++) sorted[i].id: i,
    };
    _documentOrderCache = map;
    return map;
  }

  List<MarkdownSelectionSurface> _sortedMountedSurfaces() {
    final order = _documentOrderMap();
    final list = _surfaces.toList()
      ..sort((a, b) {
        if (a.documentId != b.documentId) {
          final oa = order[a.documentId];
          final ob = order[b.documentId];
          if (oa != null && ob != null && oa != ob) {
            return oa.compareTo(ob);
          }
          return a.documentId.compareTo(b.documentId);
        }
        final blockCmp = a.blockIndex.compareTo(b.blockIndex);
        if (blockCmp != 0) return blockCmp;
        return a.textOffsetInBlock.compareTo(b.textOffsetInBlock);
      });
    return list;
  }

  String? _blockText(String documentId, int blockIndex) {
    final ref = _documents[documentId];
    if (ref == null) return null;
    if (blockIndex < 0 || blockIndex >= ref.document.blocks.length) {
      return null;
    }
    return extractBlockRenderedText(ref.document.blocks[blockIndex]);
  }

  int? _blockLength(String documentId, int blockIndex) =>
      _blockText(documentId, blockIndex)?.length;

  MarkdownPosition _clampPosition(MarkdownPosition pos) {
    final ref = _documents[pos.documentId];
    if (ref == null || ref.document.blocks.isEmpty) {
      return pos;
    }
    final blockIndex = pos.blockIndex.clamp(0, ref.document.blocks.length - 1);
    final textLen = extractBlockRenderedText(ref.document.blocks[blockIndex])
        .length;
    final offset = pos.offset.clamp(0, textLen);
    return MarkdownPosition(
      documentId: pos.documentId,
      blockIndex: blockIndex,
      offset: offset,
    );
  }

  MarkdownSelection _clampSelection(MarkdownSelection sel) {
    final base = _clampPosition(sel.base);
    var extent = _clampPosition(sel.extent);
    if (!allowCrossDocumentSelection && extent.documentId != base.documentId) {
      final order = _documentOrderMap();
      final cmp = extent.compareTo(base, documentOrder: order);
      extent = cmp < 0
          ? (_documentStartPosition(base.documentId) ?? base)
          : (_documentEndPosition(base.documentId) ?? base);
    }
    return MarkdownSelection(base: base, extent: extent);
  }

  MarkdownPosition? _documentStartPosition(String documentId) {
    final ref = _documents[documentId];
    if (ref != null && ref.document.blocks.isNotEmpty) {
      for (var i = 0; i < ref.document.blocks.length; i++) {
        final text = extractBlockRenderedText(ref.document.blocks[i]);
        if (text.isNotEmpty) {
          return MarkdownPosition(
            documentId: documentId,
            blockIndex: i,
            offset: 0,
          );
        }
      }
      return MarkdownPosition(documentId: documentId, blockIndex: 0, offset: 0);
    }

    // Fallback to mounted surfaces if document AST isn't registered yet.
    final docSurfaces = _sortedMountedSurfaces()
        .where((s) => s.documentId == documentId)
        .toList();
    if (docSurfaces.isEmpty) return null;
    final first = docSurfaces.first;
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: first.blockIndex,
      offset: first.textOffsetInBlock,
    );
  }

  MarkdownPosition? _documentEndPosition(String documentId) {
    final ref = _documents[documentId];
    if (ref != null && ref.document.blocks.isNotEmpty) {
      for (var i = ref.document.blocks.length - 1; i >= 0; i--) {
        final text = extractBlockRenderedText(ref.document.blocks[i]);
        if (text.isNotEmpty) {
          return MarkdownPosition(
            documentId: documentId,
            blockIndex: i,
            offset: text.length,
          );
        }
      }
      return MarkdownPosition(
        documentId: documentId,
        blockIndex: ref.document.blocks.length - 1,
        offset: 0,
      );
    }

    final docSurfaces = _sortedMountedSurfaces()
        .where((s) => s.documentId == documentId)
        .toList();
    if (docSurfaces.isEmpty) return null;
    final last = docSurfaces.last;
    return MarkdownPosition(
      documentId: documentId,
      blockIndex: last.blockIndex,
      offset: last.blockEndOffset,
    );
  }

  bool _selectFullDocument(String documentId) {
    final start = _documentStartPosition(documentId);
    final end = _documentEndPosition(documentId);
    if (start == null || end == null || start == end) return false;
    _selection = MarkdownSelection(base: start, extent: end);
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  bool _selectAllFromMountedSurfaces({String? documentId}) {
    final surfaces = _sortedMountedSurfaces();
    if (surfaces.isEmpty) return false;
    final filtered = documentId != null
        ? surfaces.where((s) => s.documentId == documentId).toList()
        : (!allowCrossDocumentSelection
              ? surfaces
                    .where(
                      (s) =>
                          s.documentId ==
                          (_selection?.base.documentId ??
                              surfaces.first.documentId),
                    )
                    .toList()
              : surfaces);
    if (filtered.isEmpty) return false;
    final first = filtered.first;
    final last = filtered.last;
    final start = MarkdownPosition(
      documentId: first.documentId,
      blockIndex: first.blockIndex,
      offset: first.textOffsetInBlock,
    );
    final end = MarkdownPosition(
      documentId: last.documentId,
      blockIndex: last.blockIndex,
      offset: last.blockEndOffset,
    );
    if (start == end) return false;
    _selection = MarkdownSelection(base: start, extent: end);
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  String? _resolveSingleTargetDocumentId(List<MarkdownDocumentRef> sortedDocs) {
    if (_selection != null &&
        _documents.containsKey(_selection!.base.documentId)) {
      return _selection!.base.documentId;
    }
    if (sortedDocs.length == 1) {
      return sortedDocs.single.id;
    }
    final mountedDocIds = <String>{
      for (final s in _surfaces)
        if (_documents.containsKey(s.documentId)) s.documentId,
    };
    if (mountedDocIds.length == 1) {
      return mountedDocIds.single;
    }
    for (final ref in sortedDocs) {
      if (mountedDocIds.contains(ref.id)) {
        return ref.id;
      }
    }
    return sortedDocs.first.id;
  }

  MarkdownSelectionSurface? _surfaceForGlobal(
    Offset global, {
    String? restrictDocumentId,
  }) {
    MarkdownSelectionSurface? best;
    var bestDy = double.infinity;
    var bestDx = double.infinity;

    for (final surface in _surfaces) {
      if (restrictDocumentId != null &&
          surface.documentId != restrictDocumentId) {
        continue;
      }
      if (surface.hitsTextAtGlobal(global)) {
        return surface;
      }
      final bounds = surface.globalBounds;
      if (bounds == null) continue;
      final dy = _axisDistance(global.dy, bounds.top, bounds.bottom);
      final dx = _axisDistance(global.dx, bounds.left, bounds.right);
      if (dy < bestDy - 1e-3 || ((dy - bestDy).abs() <= 1e-3 && dx < bestDx)) {
        bestDy = dy;
        bestDx = dx;
        best = surface;
      }
    }
    return best;
  }

  MarkdownPosition? _positionForGlobal(
    Offset global, {
    String? restrictDocumentId,
  }) {
    final order = _documentOrderMap();

    if (restrictDocumentId != null) {
      final anyHit = _surfaceForGlobal(global);
      if (anyHit != null && anyHit.documentId != restrictDocumentId) {
        final hitBounds = anyHit.globalBounds;
        final isActuallyOnOtherDoc =
            anyHit.hitsTextAtGlobal(global) ||
            (hitBounds != null &&
                global.dy >= hitBounds.top &&
                global.dy <= hitBounds.bottom);
        if (isActuallyOnOtherDoc) {
          final cmp = _compareDocumentIds(
            anyHit.documentId,
            restrictDocumentId,
            order,
          );
          if (cmp < 0) {
            return _documentStartPosition(restrictDocumentId);
          }
          if (cmp > 0) {
            return _documentEndPosition(restrictDocumentId);
          }
        }
      }

      final docSurfaces = _sortedMountedSurfaces()
          .where(
            (s) => s.documentId == restrictDocumentId && s.globalBounds != null,
          )
          .toList();
      if (docSurfaces.isEmpty) {
        // The anchor document scrolled completely off-screen; decide start vs
        // end by comparing its reading order against mounted sibling surfaces.
        if (anyHit != null) {
          final cmp = _compareDocumentIds(
            anyHit.documentId,
            restrictDocumentId,
            order,
          );
          if (cmp < 0) return _documentStartPosition(restrictDocumentId);
          if (cmp > 0) return _documentEndPosition(restrictDocumentId);
        }
        return null;
      }

      var minTop = double.infinity;
      var maxBottom = double.negativeInfinity;
      for (final s in docSurfaces) {
        final b = s.globalBounds!;
        if (b.top < minTop) minTop = b.top;
        if (b.bottom > maxBottom) maxBottom = b.bottom;
      }

      final firstMounted = docSurfaces.first;
      final lastMounted = docSurfaces.last;
      final docStart = _documentStartPosition(restrictDocumentId);
      final docEnd = _documentEndPosition(restrictDocumentId);

      if (global.dy < minTop &&
          docStart != null &&
          firstMounted.blockIndex == docStart.blockIndex &&
          firstMounted.textOffsetInBlock == docStart.offset) {
        return docStart;
      }
      if (global.dy > maxBottom &&
          docEnd != null &&
          lastMounted.blockIndex == docEnd.blockIndex &&
          lastMounted.blockEndOffset >= docEnd.offset) {
        return docEnd;
      }

      final surface = _surfaceForGlobal(
        global,
        restrictDocumentId: restrictDocumentId,
      );
      if (surface == null) return null;
      return _clampPosition(surface.positionForGlobalOffset(global));
    }

    // Cross-document selection allowed: check global boundaries first.
    final allSurfaces = _sortedMountedSurfaces()
        .where((s) => s.globalBounds != null)
        .toList();
    if (allSurfaces.isEmpty) return null;

    var minTop = double.infinity;
    var maxBottom = double.negativeInfinity;
    for (final s in allSurfaces) {
      final b = s.globalBounds!;
      if (b.top < minTop) minTop = b.top;
      if (b.bottom > maxBottom) maxBottom = b.bottom;
    }

    final sortedDocs = _sortedDocuments();
    if (sortedDocs.isNotEmpty) {
      final firstDocStart = _documentStartPosition(sortedDocs.first.id);
      if (global.dy < minTop &&
          firstDocStart != null &&
          allSurfaces.first.documentId == firstDocStart.documentId &&
          allSurfaces.first.blockIndex == firstDocStart.blockIndex &&
          allSurfaces.first.textOffsetInBlock == firstDocStart.offset) {
        return firstDocStart;
      }
      final lastDocEnd = _documentEndPosition(sortedDocs.last.id);
      if (global.dy > maxBottom &&
          lastDocEnd != null &&
          allSurfaces.last.documentId == lastDocEnd.documentId &&
          allSurfaces.last.blockIndex == lastDocEnd.blockIndex &&
          allSurfaces.last.blockEndOffset >= lastDocEnd.offset) {
        return lastDocEnd;
      }
    }

    final surface = _surfaceForGlobal(global);
    if (surface == null) return null;
    return _clampPosition(surface.positionForGlobalOffset(global));
  }

  ({MarkdownPosition start, MarkdownPosition end})? _granularRangeForGlobal(
    Offset global, {
    required bool word,
    String? restrictDocumentId,
  }) {
    final pos = _positionForGlobal(
      global,
      restrictDocumentId: restrictDocumentId,
    );
    if (pos == null) return null;

    if (!word) {
      final len = _blockLength(pos.documentId, pos.blockIndex);
      if (len != null) {
        return (start: pos.copyWith(offset: 0), end: pos.copyWith(offset: len));
      }
    }

    final surface =
        _surfaceForPosition(pos, preferUpstream: false) ??
        _surfaceForGlobal(global, restrictDocumentId: restrictDocumentId);
    if (surface == null ||
        surface.documentId != pos.documentId ||
        surface.blockIndex != pos.blockIndex) {
      return (start: pos, end: pos);
    }

    if (!word) {
      return (
        start: MarkdownPosition(
          documentId: surface.documentId,
          blockIndex: surface.blockIndex,
          offset: surface.textOffsetInBlock,
        ),
        end: MarkdownPosition(
          documentId: surface.documentId,
          blockIndex: surface.blockIndex,
          offset: surface.blockEndOffset,
        ),
      );
    }

    final local = (pos.offset - surface.textOffsetInBlock).clamp(
      0,
      surface.textLength,
    );
    final wordRange = surface.wordRangeAtLocal(local);
    if (!wordRange.isValid || wordRange.isCollapsed) {
      return (start: pos, end: pos);
    }
    return (
      start: MarkdownPosition(
        documentId: surface.documentId,
        blockIndex: surface.blockIndex,
        offset:
            surface.textOffsetInBlock +
            wordRange.start.clamp(0, surface.textLength),
      ),
      end: MarkdownPosition(
        documentId: surface.documentId,
        blockIndex: surface.blockIndex,
        offset:
            surface.textOffsetInBlock +
            wordRange.end.clamp(0, surface.textLength),
      ),
    );
  }

  int _compareDocumentIds(String a, String b, Map<String, int> order) {
    if (a == b) return 0;
    final oa = order[a];
    final ob = order[b];
    if (oa != null && ob != null && oa != ob) {
      return oa.compareTo(ob);
    }
    return a.compareTo(b);
  }

  double _axisDistance(double value, double minVal, double maxVal) {
    if (value < minVal) return minVal - value;
    if (value > maxVal) return value - maxVal;
    return 0.0;
  }

  bool _applyExtendedExtent(MarkdownPosition base, MarkdownPosition extent) {
    final next = _clampSelection(MarkdownSelection(base: base, extent: extent));
    if (next == _selection) return false;
    _selection = next;
    _syncAllSurfaceHighlights();
    notifyListeners();
    return true;
  }

  MarkdownPosition? _stepCharacter(
    MarkdownPosition pos, {
    required bool forward,
  }) {
    final restrictDocId = allowCrossDocumentSelection
        ? null
        : (_selection?.base.documentId ?? pos.documentId);
    final text = _blockText(pos.documentId, pos.blockIndex);
    if (text == null) return null;

    final offset = pos.offset.clamp(0, text.length);
    if (forward) {
      if (offset < text.length) {
        final nextOffset = _nextGraphemeOffset(text, offset);
        return pos.copyWith(offset: nextOffset);
      }
      final nextBlock = _adjacentSelectableBlock(
        pos,
        forward: true,
        restrictDocumentId: restrictDocId,
      );
      if (nextBlock == null) return pos;
      return MarkdownPosition(
        documentId: nextBlock.documentId,
        blockIndex: nextBlock.blockIndex,
        offset: 0,
      );
    } else {
      if (offset > 0) {
        final prevOffset = _previousGraphemeOffset(text, offset);
        return pos.copyWith(offset: prevOffset);
      }
      final prevBlock = _adjacentSelectableBlock(
        pos,
        forward: false,
        restrictDocumentId: restrictDocId,
      );
      if (prevBlock == null) return pos;
      return MarkdownPosition(
        documentId: prevBlock.documentId,
        blockIndex: prevBlock.blockIndex,
        offset: prevBlock.text.length,
      );
    }
  }

  MarkdownPosition? _stepWord(MarkdownPosition pos, {required bool forward}) {
    final restrictDocId = allowCrossDocumentSelection
        ? null
        : (_selection?.base.documentId ?? pos.documentId);
    final text = _blockText(pos.documentId, pos.blockIndex);
    if (text == null) return null;

    final offset = pos.offset.clamp(0, text.length);
    if (forward) {
      if (offset < text.length) {
        var i = offset;
        while (i < text.length && _isWhitespace(text.codeUnitAt(i))) {
          i++;
        }
        if (i < text.length) {
          final isWord = _isWordCodeUnit(text.codeUnitAt(i));
          while (i < text.length &&
              !_isWhitespace(text.codeUnitAt(i)) &&
              _isWordCodeUnit(text.codeUnitAt(i)) == isWord) {
            i++;
          }
        }
        return pos.copyWith(offset: i);
      }
      final nextBlock = _adjacentSelectableBlock(
        pos,
        forward: true,
        restrictDocumentId: restrictDocId,
      );
      if (nextBlock == null) return pos;
      return MarkdownPosition(
        documentId: nextBlock.documentId,
        blockIndex: nextBlock.blockIndex,
        offset: 0,
      );
    } else {
      if (offset > 0) {
        var i = offset;
        while (i > 0 && _isWhitespace(text.codeUnitAt(i - 1))) {
          i--;
        }
        if (i > 0) {
          final isWord = _isWordCodeUnit(text.codeUnitAt(i - 1));
          while (i > 0 &&
              !_isWhitespace(text.codeUnitAt(i - 1)) &&
              _isWordCodeUnit(text.codeUnitAt(i - 1)) == isWord) {
            i--;
          }
        }
        return pos.copyWith(offset: i);
      }
      final prevBlock = _adjacentSelectableBlock(
        pos,
        forward: false,
        restrictDocumentId: restrictDocId,
      );
      if (prevBlock == null) return pos;
      return MarkdownPosition(
        documentId: prevBlock.documentId,
        blockIndex: prevBlock.blockIndex,
        offset: prevBlock.text.length,
      );
    }
  }

  ({String documentId, int blockIndex, String text})? _adjacentSelectableBlock(
    MarkdownPosition pos, {
    required bool forward,
    String? restrictDocumentId,
  }) {
    final sorted = _sortedDocuments();
    final order = _documentOrderMap();
    final startDocIdx = order[pos.documentId];
    if (startDocIdx == null) return null;

    final step = forward ? 1 : -1;
    var docIdx = startDocIdx;
    var blockIdx = pos.blockIndex + step;

    while (docIdx >= 0 && docIdx < sorted.length) {
      final ref = sorted[docIdx];
      if (restrictDocumentId != null && ref.id != restrictDocumentId) {
        return null;
      }
      final blocks = ref.document.blocks;
      while (blockIdx >= 0 && blockIdx < blocks.length) {
        final text = extractBlockRenderedText(blocks[blockIdx]);
        if (text.isNotEmpty) {
          return (documentId: ref.id, blockIndex: blockIdx, text: text);
        }
        blockIdx += step;
      }
      docIdx += step;
      if (docIdx >= 0 && docIdx < sorted.length) {
        final nextRef = sorted[docIdx];
        if (restrictDocumentId != null && nextRef.id != restrictDocumentId) {
          return null;
        }
        blockIdx = forward ? 0 : nextRef.document.blocks.length - 1;
      }
    }
    return null;
  }

  int _nextGraphemeOffset(String text, int offset) {
    if (offset >= text.length) return text.length;
    final range = CharacterRange.at(text, offset);
    if (range.moveNext()) {
      return range.stringBeforeLength + range.current.length;
    }
    return math.min(offset + 1, text.length);
  }

  int _previousGraphemeOffset(String text, int offset) {
    if (offset <= 0) return 0;
    final range = CharacterRange.at(text, offset);
    if (range.moveBack()) {
      return range.stringBeforeLength;
    }
    return math.max(offset - 1, 0);
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;

  bool _isWordCodeUnit(int codeUnit) {
    if ((codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
        codeUnit == 0x5F) {
      return true;
    }
    if (codeUnit < 0x80) return false;
    // General, CJK and full-width punctuation end a word like ASCII
    // punctuation does.
    if ((codeUnit >= 0x2000 && codeUnit <= 0x206F) ||
        (codeUnit >= 0x3000 && codeUnit <= 0x303F) ||
        (codeUnit >= 0xFF00 && codeUnit <= 0xFF0F) ||
        (codeUnit >= 0xFF1A && codeUnit <= 0xFF20) ||
        (codeUnit >= 0xFF3B && codeUnit <= 0xFF40) ||
        (codeUnit >= 0xFF5B && codeUnit <= 0xFF65)) {
      return false;
    }
    return true;
  }

  MarkdownSelectionSurface? _surfaceForPosition(
    MarkdownPosition pos, {
    required bool preferUpstream,
  }) {
    final matching = _sortedMountedSurfaces()
        .where(
          (s) =>
              s.documentId == pos.documentId && s.blockIndex == pos.blockIndex,
        )
        .toList();
    if (matching.isEmpty) return null;

    if (preferUpstream) {
      for (final s in matching) {
        if (pos.offset > s.textOffsetInBlock &&
            pos.offset <= s.blockEndOffset) {
          return s;
        }
      }
      for (final s in matching) {
        if (pos.offset >= s.textOffsetInBlock &&
            pos.offset <= s.blockEndOffset) {
          return s;
        }
      }
      // Position falls on a separator between surfaces (e.g. `\n` or `\t`):
      // pick the nearest preceding surface.
      MarkdownSelectionSurface? preceding;
      for (final s in matching) {
        if (s.blockEndOffset <= pos.offset) {
          preceding = s;
        }
      }
      return preceding ?? matching.first;
    } else {
      for (final s in matching) {
        if (pos.offset >= s.textOffsetInBlock &&
            pos.offset < s.blockEndOffset) {
          return s;
        }
      }
      for (final s in matching) {
        if (pos.offset >= s.textOffsetInBlock &&
            pos.offset <= s.blockEndOffset) {
          return s;
        }
      }
      // Position falls on a separator between surfaces: pick the nearest
      // following surface.
      for (final s in matching) {
        if (s.textOffsetInBlock >= pos.offset) {
          return s;
        }
      }
      return matching.last;
    }
  }

  ({MarkdownSelectionSurface surface, int localOffset, Rect caretRect})?
  _resolveEndpoint(MarkdownPosition pos, {required bool preferUpstream}) {
    final surface = _surfaceForPosition(pos, preferUpstream: preferUpstream);
    if (surface == null) return null;
    final localOffset = (pos.offset - surface.textOffsetInBlock).clamp(
      0,
      surface.textLength,
    );
    final affinity = preferUpstream
        ? TextAffinity.upstream
        : TextAffinity.downstream;
    final caretRect = surface.globalRectForLocalOffset(
      localOffset,
      affinity: affinity,
    );
    if (caretRect == null) return null;
    return (surface: surface, localOffset: localOffset, caretRect: caretRect);
  }

  TextRange? _highlightRangeForSurface(MarkdownSelectionSurface surface) {
    final sel = _selection;
    if (sel == null || sel.isCollapsed) return null;

    final order = _documentOrderMap();
    final (:start, :end) = sel.normalized(documentOrder: order);

    final cmpStart = _compareDocumentIds(
      surface.documentId,
      start.documentId,
      order,
    );
    final cmpEnd = _compareDocumentIds(
      surface.documentId,
      end.documentId,
      order,
    );
    if (cmpStart < 0 || cmpEnd > 0) return null;

    if (cmpStart > 0 && cmpEnd < 0) {
      return surface.textLength > 0
          ? TextRange(start: 0, end: surface.textLength)
          : null;
    }

    if (cmpStart == 0 && surface.blockIndex < start.blockIndex) {
      return null;
    }
    if (cmpEnd == 0 && surface.blockIndex > end.blockIndex) {
      return null;
    }

    final blockStart = (cmpStart == 0 && surface.blockIndex == start.blockIndex)
        ? start.offset
        : 0;
    final blockEnd = (cmpEnd == 0 && surface.blockIndex == end.blockIndex)
        ? end.offset
        : surface.blockEndOffset;

    return surface.localRangeForBlockRange(blockStart, blockEnd);
  }

  void _syncSurfaceHighlight(MarkdownSelectionSurface surface) {
    surface.setSelectionHighlightRange(_highlightRangeForSurface(surface));
  }

  void _syncAllSurfaceHighlights() {
    for (final surface in _surfaces) {
      _syncSurfaceHighlight(surface);
    }
  }
}
