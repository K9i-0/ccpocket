import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../selection/selection_model.dart';
import 'markdown_theme.dart';

/// A [TextSpan] tagged as inline code so [RenderSelectableParagraph] paints a
/// smooth rounded background pill (and optional border) per line fragment
/// without using `WidgetSpan` or fragmenting paragraph wrapping.
@immutable
class CodeTextSpan extends TextSpan {
  const CodeTextSpan({
    super.text,
    super.children,
    super.style,
    this.codeStyle,
    super.recognizer,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  });

  /// Optional per-span override for pill background, border, radius, and
  /// padding. Falls back to [RenderSelectableParagraph.inlineCodeStyle].
  final MarkdownInlineCodeStyle? codeStyle;

  @override
  RenderComparison compareTo(InlineSpan other) {
    final base = super.compareTo(other);
    if (other is! CodeTextSpan) {
      return RenderComparison.layout;
    }
    if (codeStyle == other.codeStyle) {
      return base;
    }
    return base.index >= RenderComparison.paint.index
        ? base
        : RenderComparison.paint;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return super == other &&
        other is CodeTextSpan &&
        other.codeStyle == codeStyle;
  }

  @override
  int get hashCode => Object.hash(super.hashCode, CodeTextSpan, codeStyle);
}

/// A [TextSpan] supporting range-based tap and hover styling inside
/// [RenderSelectableParagraph], even when wrapping nested child spans
/// (such as bold, italic, or [CodeTextSpan] children).
///
/// Unlike attaching a [TapGestureRecognizer] directly on [TextSpan.recognizer],
/// [TappableTextSpan] owns no gesture recognizers and resolves pointer hits
/// against exact line glyph boxes (`getBoxesForSelection`) inside
/// [RenderSelectableParagraph].
@immutable
class TappableTextSpan extends TextSpan {
  const TappableTextSpan({
    super.text,
    super.children,
    super.style,
    this.onTap,
    this.hoverStyle,
    MouseCursor? mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  }) : super(
         mouseCursor:
             mouseCursor ?? (onTap != null ? SystemMouseCursors.click : null),
       );

  /// Callback invoked on primary click/tap within this span's rendered glyph
  /// boxes.
  final VoidCallback? onTap;

  /// Optional [TextStyle] merged onto this span (and its descendant
  /// [TextSpan]s) while hovered with a pointer device.
  final TextStyle? hoverStyle;

  @override
  RenderComparison compareTo(InlineSpan other) {
    final base = super.compareTo(other);
    if (other is! TappableTextSpan) {
      return RenderComparison.layout;
    }
    if (hoverStyle != other.hoverStyle) {
      return base.index >= RenderComparison.paint.index
          ? base
          : RenderComparison.paint;
    }
    return base;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return super == other &&
        other is TappableTextSpan &&
        other.onTap == onTap &&
        other.hoverStyle == hoverStyle;
  }

  @override
  int get hashCode =>
      Object.hash(super.hashCode, TappableTextSpan, onTap, hoverStyle);
}

/// A contiguous mapping segment between canonical rendered-text UTF-16 offsets
/// (`rendered_text.dart`) and Flutter `TextPainter` UTF-16 offsets (where each
/// [PlaceholderSpan] / [WidgetSpan] occupies 1 `\uFFFC` code unit).
@immutable
class OffsetSegment {
  const OffsetSegment({
    required this.canonicalStart,
    required this.canonicalEnd,
    required this.painterStart,
    required this.painterEnd,
    required this.isOneToOne,
  }) : assert(canonicalStart >= 0),
       assert(canonicalEnd >= canonicalStart),
       assert(painterStart >= 0),
       assert(painterEnd >= painterStart),
       assert(
         !isOneToOne ||
             (canonicalEnd - canonicalStart) == (painterEnd - painterStart),
       );

  final int canonicalStart;
  final int canonicalEnd;
  final int painterStart;
  final int painterEnd;
  final bool isOneToOne;

  int get canonicalLength => canonicalEnd - canonicalStart;
  int get painterLength => painterEnd - painterStart;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OffsetSegment &&
        other.canonicalStart == canonicalStart &&
        other.canonicalEnd == canonicalEnd &&
        other.painterStart == painterStart &&
        other.painterEnd == painterEnd &&
        other.isOneToOne == isOneToOne;
  }

  @override
  int get hashCode => Object.hash(
    canonicalStart,
    canonicalEnd,
    painterStart,
    painterEnd,
    isOneToOne,
  );

  @override
  String toString() =>
      'OffsetSegment(c:[$canonicalStart,$canonicalEnd) <-> '
      'p:[$painterStart,$painterEnd), 1:1=$isOneToOne)';
}

/// Bidirectional UTF-16 offset mapping between canonical selection coordinates
/// and `TextPainter` coordinates.
///
/// Guarantees that selection highlights, caret rects, word/line boundaries,
/// and copied slices never drift when a paragraph contains [WidgetSpan]s
/// (`\uFFFC`) such as inline images, color swatches, or formatted LaTeX spans.
@immutable
class TextOffsetMapping {
  const TextOffsetMapping({
    required this.canonicalLength,
    required this.painterLength,
    required this.segments,
  }) : assert(canonicalLength >= 0),
       assert(painterLength >= 0);

  /// Fast-path identity mapping when canonical offsets equal painter offsets
  /// 1-to-1.
  const TextOffsetMapping.identity(int length)
    : assert(length >= 0),
      canonicalLength = length,
      painterLength = length,
      segments = const [];

  final int canonicalLength;
  final int painterLength;
  final List<OffsetSegment> segments;

  /// Whether canonical and painter offsets are identical everywhere.
  bool get isIdentity => segments.isEmpty && canonicalLength == painterLength;

  /// Maps a canonical caret [offset] with [affinity] into painter coordinates.
  int canonicalCaretToPainter(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    final c = offset.clamp(0, canonicalLength);
    if (isIdentity) return c;
    if (c == 0) return 0;
    if (c == canonicalLength) return painterLength;

    if (affinity == TextAffinity.upstream) {
      for (var i = segments.length - 1; i >= 0; i--) {
        final s = segments[i];
        if (s.canonicalStart < c && c <= s.canonicalEnd) {
          return _mapCanonicalInSegment(s, c, preferEnd: true);
        }
      }
    } else {
      for (final s in segments) {
        if (s.canonicalStart <= c && c < s.canonicalEnd) {
          return _mapCanonicalInSegment(s, c, preferEnd: false);
        }
      }
    }

    // Fallback when all segments have zero canonical length.
    for (final s in segments) {
      if (c <= s.canonicalEnd) {
        return s.painterStart;
      }
    }
    return painterLength;
  }

  /// Maps a canonical selection range `[start, end)` into painter coordinates
  /// `(start, end)`.
  ({int start, int end}) canonicalRangeToPainterRange(int start, int end) {
    final cStart = start.clamp(0, canonicalLength);
    final cEnd = end.clamp(cStart, canonicalLength);
    if (isIdentity) return (start: cStart, end: cEnd);
    if (cEnd <= cStart) {
      final p = canonicalCaretToPainter(cStart);
      return (start: p, end: p);
    }

    var pStart = painterLength;
    for (final s in segments) {
      if (s.canonicalLength == 0) continue;
      if (cStart < s.canonicalEnd) {
        if (s.isOneToOne) {
          pStart = s.painterStart + math.max(0, cStart - s.canonicalStart);
        } else {
          pStart = s.painterStart;
        }
        break;
      }
    }

    var pEnd = 0;
    for (var i = segments.length - 1; i >= 0; i--) {
      final s = segments[i];
      if (s.canonicalLength == 0) continue;
      if (s.canonicalStart < cEnd) {
        if (s.isOneToOne) {
          pEnd =
              s.painterStart +
              math.min(s.canonicalLength, cEnd - s.canonicalStart);
        } else {
          pEnd = s.painterEnd;
        }
        break;
      }
    }

    if (pEnd < pStart) {
      return (start: pStart, end: pStart);
    }
    return (start: pStart, end: pEnd);
  }

  /// Maps a painter [offset] into canonical coordinates.
  int painterToCanonical(int offset) {
    final p = offset.clamp(0, painterLength);
    if (isIdentity) return p;
    if (p == 0) return 0;
    if (p == painterLength) return canonicalLength;

    for (final s in segments) {
      if (s.painterStart <= p && p < s.painterEnd) {
        if (s.isOneToOne) {
          return s.canonicalStart + (p - s.painterStart);
        }
        if (p == s.painterStart || s.painterLength == 0) {
          return s.canonicalStart;
        }
        final ratio = (p - s.painterStart) / s.painterLength;
        return s.canonicalStart + (ratio * s.canonicalLength).round();
      }
    }
    return canonicalLength;
  }

  /// Maps a painter range `[start, end)` into canonical coordinates.
  TextRange painterRangeToCanonicalRange(int start, int end) {
    final pStart = start.clamp(0, painterLength);
    final pEnd = end.clamp(pStart, painterLength);
    if (isIdentity) return TextRange(start: pStart, end: pEnd);
    if (pEnd <= pStart) {
      final c = painterToCanonical(pStart);
      return TextRange(start: c, end: c);
    }

    var cStart = canonicalLength;
    for (final s in segments) {
      if (s.painterLength == 0) continue;
      if (pStart < s.painterEnd) {
        if (s.isOneToOne) {
          cStart = s.canonicalStart + math.max(0, pStart - s.painterStart);
        } else {
          cStart = s.canonicalStart;
        }
        break;
      }
    }

    var cEnd = 0;
    for (var i = segments.length - 1; i >= 0; i--) {
      final s = segments[i];
      if (s.painterLength == 0) continue;
      if (s.painterStart < pEnd) {
        if (s.isOneToOne) {
          cEnd =
              s.canonicalStart +
              math.min(s.painterLength, pEnd - s.painterStart);
        } else {
          cEnd = s.canonicalEnd;
        }
        break;
      }
    }

    if (cEnd < cStart) {
      return TextRange(start: cStart, end: cStart);
    }
    return TextRange(start: cStart, end: cEnd);
  }

  int _mapCanonicalInSegment(
    OffsetSegment s,
    int c, {
    required bool preferEnd,
  }) {
    if (s.isOneToOne) {
      return s.painterStart + (c - s.canonicalStart);
    }
    if (c <= s.canonicalStart) return s.painterStart;
    if (c >= s.canonicalEnd) return s.painterEnd;
    if (s.canonicalLength == 0) {
      return preferEnd ? s.painterEnd : s.painterStart;
    }
    final delta = c - s.canonicalStart;
    if (delta * 2 <= s.canonicalLength) {
      return s.painterStart;
    }
    return s.painterEnd;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextOffsetMapping &&
        other.canonicalLength == canonicalLength &&
        other.painterLength == painterLength &&
        listEquals(other.segments, segments);
  }

  @override
  int get hashCode =>
      Object.hash(canonicalLength, painterLength, Object.hashAll(segments));
}

/// Incrementally builds a [TextOffsetMapping] while translating AST inline
/// nodes into Flutter [InlineSpan]s.
class TextOffsetMappingBuilder {
  final List<OffsetSegment> _segments = [];
  int _canonicalCursor = 0;
  int _painterCursor = 0;
  bool _hasNonIdentity = false;

  int get canonicalLength => _canonicalCursor;
  int get painterLength => _painterCursor;

  /// Appends a 1-to-1 text segment of [length] UTF-16 code units.
  void addOneToOne(int length) {
    if (length <= 0) return;
    if (_segments.isNotEmpty && _segments.last.isOneToOne) {
      final prev = _segments.removeLast();
      _segments.add(
        OffsetSegment(
          canonicalStart: prev.canonicalStart,
          canonicalEnd: prev.canonicalEnd + length,
          painterStart: prev.painterStart,
          painterEnd: prev.painterEnd + length,
          isOneToOne: true,
        ),
      );
    } else {
      _segments.add(
        OffsetSegment(
          canonicalStart: _canonicalCursor,
          canonicalEnd: _canonicalCursor + length,
          painterStart: _painterCursor,
          painterEnd: _painterCursor + length,
          isOneToOne: true,
        ),
      );
    }
    _canonicalCursor += length;
    _painterCursor += length;
  }

  /// Appends an atomic (non-1:1) segment mapping [canonicalLength] canonical
  /// code units to [painterLength] painter code units (e.g. a [WidgetSpan]
  /// `\uFFFC` representing an image's alt text).
  void addAtomic({required int canonicalLength, required int painterLength}) {
    if (canonicalLength == 0 && painterLength == 0) return;
    _hasNonIdentity = true;
    _segments.add(
      OffsetSegment(
        canonicalStart: _canonicalCursor,
        canonicalEnd: _canonicalCursor + canonicalLength,
        painterStart: _painterCursor,
        painterEnd: _painterCursor + painterLength,
        isOneToOne: false,
      ),
    );
    _canonicalCursor += canonicalLength;
    _painterCursor += painterLength;
  }

  /// Automatically aligns an arbitrary [InlineSpan] (for example returned by a
  /// custom builder) against its [canonicalText].
  ///
  /// Handles three cases cleanly:
  /// 1. Exact 1:1 text match (no `PlaceholderSpan`s) -> 1:1 segment.
  /// 2. Decorative `WidgetSpan`(s) interleaved with the exact [canonicalText]
  ///    (such as a color swatch `WidgetSpan` followed by `#FF5733`) -> splits
  ///    out zero-canonical `\uFFFC` segments while keeping text 1:1!
  /// 3. Replaced content (such as a `WidgetSpan` chip or Unicode LaTeX) ->
  ///    single atomic segment.
  void addBuiltSpan({required String canonicalText, required InlineSpan span}) {
    final painterText = extractPainterPlainText(span);
    if (painterText == canonicalText && !painterText.contains('\uFFFC')) {
      addOneToOne(canonicalText.length);
      return;
    }

    if (painterText.contains('\uFFFC') &&
        painterText.replaceAll('\uFFFC', '') == canonicalText) {
      var runStart = 0;
      for (var i = 0; i < painterText.length; i++) {
        if (painterText.codeUnitAt(i) == 0xFFFC) {
          if (i > runStart) {
            addOneToOne(i - runStart);
          }
          addAtomic(canonicalLength: 0, painterLength: 1);
          runStart = i + 1;
        }
      }
      if (runStart < painterText.length) {
        addOneToOne(painterText.length - runStart);
      }
      return;
    }

    addAtomic(
      canonicalLength: canonicalText.length,
      painterLength: painterText.length,
    );
  }

  /// Finalizes the [TextOffsetMapping], collapsing to
  /// [TextOffsetMapping.identity] whenever all segments are 1-to-1.
  TextOffsetMapping build() {
    if (!_hasNonIdentity && _canonicalCursor == _painterCursor) {
      return TextOffsetMapping.identity(_canonicalCursor);
    }
    return TextOffsetMapping(
      canonicalLength: _canonicalCursor,
      painterLength: _painterCursor,
      segments: List<OffsetSegment>.unmodifiable(_segments),
    );
  }
}

/// Extracts the exact UTF-16 string that Flutter's `TextPainter` produces for
/// [span], emitting `\uFFFC` for every [PlaceholderSpan].
String extractPainterPlainText(InlineSpan span) {
  final buffer = StringBuffer();
  void visit(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text != null) {
        buffer.write(node.text);
      }
      final children = node.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    } else if (node is PlaceholderSpan) {
      buffer.write('\uFFFC');
    }
  }

  visit(span);
  return buffer.toString();
}

/// A `widgets.dart`-only rich text paragraph widget backed by
/// [RenderSelectableParagraph] (`extends RenderParagraph implements
/// MarkdownSelectionSurface`).
///
/// Supports:
/// - Model-anchored selection highlights & `LeaderLayer` handle anchoring.
/// - Canonical-to-painter offset mapping for [WidgetSpan]s (`\uFFFC`).
/// - Per-line rounded pill painting for [CodeTextSpan].
/// - Range-based tap, desktop hover styling, cursor switching, and automatic
///   hover invalidation on exit, layout change, or ancestor scroll for
///   [TappableTextSpan].
class SelectableParagraph extends StatefulWidget {
  const SelectableParagraph({
    super.key,
    required this.documentId,
    required this.blockIndex,
    required this.textOffsetInBlock,
    required this.text,
    this.canonicalLength,
    this.offsetMapping,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.softWrap = true,
    this.overflow = TextOverflow.clip,
    this.textScaler,
    this.maxLines,
    this.locale,
    this.strutStyle,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
    this.selectionColor = const Color(0x4D0969DA),
    this.inlineCodeStyle = const MarkdownInlineCodeStyle(),
    this.selectable = true,
    this.onSurfaceAttach,
    this.onSurfaceDetach,
  });

  final String documentId;
  final int blockIndex;
  final int textOffsetInBlock;
  final InlineSpan text;

  /// Canonical UTF-16 length inside the owning block's rendered text. Defaults
  /// to [offsetMapping.canonicalLength] or the painter plain-text length.
  final int? canonicalLength;

  /// Optional explicit mapping between canonical offsets and `TextPainter`
  /// offsets. When omitted, defaults to an identity mapping of the painter
  /// length (or an atomic mapping when [canonicalLength] differs).
  final TextOffsetMapping? offsetMapping;

  final TextAlign textAlign;
  final TextDirection? textDirection;
  final bool softWrap;
  final TextOverflow overflow;

  /// Optional explicit [TextScaler]. When `null`, inherits
  /// [MediaQuery.textScalerOf] so system Dynamic Type / font scaling applies.
  final TextScaler? textScaler;
  final int? maxLines;
  final Locale? locale;
  final StrutStyle? strutStyle;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color selectionColor;
  final MarkdownInlineCodeStyle inlineCodeStyle;
  final bool selectable;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach;

  @override
  State<SelectableParagraph> createState() => _SelectableParagraphState();
}

class _SelectableParagraphState extends State<SelectableParagraph> {
  final GlobalKey _richTextKey = GlobalKey();
  final List<ScrollPosition> _scrollPositions = [];
  MouseCursor _cursor = MouseCursor.defer;

  MouseCursor get _defaultCursor =>
      widget.selectable ? SystemMouseCursors.text : MouseCursor.defer;

  RenderSelectableParagraph? get _renderParagraph {
    final renderObject = _richTextKey.currentContext?.findRenderObject();
    return renderObject is RenderSelectableParagraph ? renderObject : null;
  }

  @override
  void initState() {
    super.initState();
    _cursor = _defaultCursor;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollPositions();
  }

  @override
  void didUpdateWidget(covariant SelectableParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectable != widget.selectable &&
        (_cursor == SystemMouseCursors.text || _cursor == MouseCursor.defer)) {
      _cursor = _defaultCursor;
    }
  }

  @override
  void deactivate() {
    _detachScrollPositions();
    super.deactivate();
  }

  @override
  void dispose() {
    _detachScrollPositions();
    super.dispose();
  }

  void _attachScrollPositions() {
    _detachScrollPositions();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        position.addListener(_handleScroll);
        _scrollPositions.add(position);
      }
      return true;
    });
  }

  void _detachScrollPositions() {
    for (final position in _scrollPositions) {
      position.removeListener(_handleScroll);
    }
    _scrollPositions.clear();
  }

  void _handleScroll() {
    _clearHover();
  }

  void _handleHover(PointerHoverEvent event) {
    final renderObject = _renderParagraph;
    if (renderObject == null) return;
    final hoveredCursor = renderObject.updateHoverAtLocal(event.localPosition);
    final nextCursor = hoveredCursor ?? _defaultCursor;
    if (nextCursor != _cursor) {
      setState(() {
        _cursor = nextCursor;
      });
    }
  }

  void _handleExit(PointerExitEvent event) {
    _clearHover();
  }

  void _clearHover() {
    _renderParagraph?.clearHover();
    final nextCursor = _defaultCursor;
    if (nextCursor != _cursor && mounted) {
      setState(() {
        _cursor = nextCursor;
      });
    }
  }

  void _handleRenderObjectHoverCleared() {
    final nextCursor = _defaultCursor;
    if (nextCursor == _cursor) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_cursor != _defaultCursor &&
          (_renderParagraph?.hoveredSpanIndex == null)) {
        setState(() {
          _cursor = _defaultCursor;
        });
      }
    });
  }

  TextOffsetMapping _resolveMapping() {
    final explicit = widget.offsetMapping;
    if (explicit != null) return explicit;
    final painterLen = extractPainterPlainText(widget.text).length;
    final canonicalLen = widget.canonicalLength ?? painterLen;
    if (canonicalLen == painterLen) {
      return TextOffsetMapping.identity(canonicalLen);
    }
    return TextOffsetMapping(
      canonicalLength: canonicalLen,
      painterLength: painterLen,
      segments: [
        OffsetSegment(
          canonicalStart: 0,
          canonicalEnd: canonicalLen,
          painterStart: 0,
          painterEnd: painterLen,
          isOneToOne: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapping = _resolveMapping();
    final effectiveTextScaler =
        widget.textScaler ?? MediaQuery.textScalerOf(context);
    final richText = _SelectableRichText(
      key: _richTextKey,
      text: widget.text,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      textScaler: effectiveTextScaler,
      maxLines: widget.maxLines,
      locale: widget.locale,
      strutStyle: widget.strutStyle,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectionColor: widget.selectionColor,
      documentId: widget.documentId,
      blockIndex: widget.blockIndex,
      textOffsetInBlock: widget.textOffsetInBlock,
      offsetMapping: mapping,
      inlineCodeStyle: widget.inlineCodeStyle,
      selectable: widget.selectable,
      onSurfaceAttach: widget.onSurfaceAttach,
      onSurfaceDetach: widget.onSurfaceDetach,
      onHoverCleared: _handleRenderObjectHoverCleared,
    );

    return MouseRegion(
      cursor: _cursor,
      onHover: _handleHover,
      onExit: _handleExit,
      child: richText,
    );
  }
}

/// Internal [RichText] subclass so Flutter's `WidgetSpan` child extraction and
/// `find.text(..., findRichText: true)` / `find.bySubtype<RichText>()` work
/// natively while creating [RenderSelectableParagraph].
class _SelectableRichText extends RichText {
  _SelectableRichText({
    super.key,
    required super.text,
    super.textAlign,
    super.textDirection,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    required Color selectionColor,
    required this.documentId,
    required this.blockIndex,
    required this.textOffsetInBlock,
    required this.offsetMapping,
    required this.inlineCodeStyle,
    required this.selectable,
    required this.onSurfaceAttach,
    required this.onSurfaceDetach,
    required this.onHoverCleared,
  }) : super(selectionColor: selectionColor);

  final String documentId;
  final int blockIndex;
  final int textOffsetInBlock;
  final TextOffsetMapping offsetMapping;
  final MarkdownInlineCodeStyle inlineCodeStyle;
  final bool selectable;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach;
  final ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach;
  final VoidCallback onHoverCleared;

  @override
  RenderSelectableParagraph createRenderObject(BuildContext context) {
    return RenderSelectableParagraph(
      text,
      textAlign: textAlign,
      textDirection: textDirection ?? Directionality.of(context),
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      locale: locale ?? Localizations.maybeLocaleOf(context),
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      highlightColor: selectionColor ?? const Color(0x4D0969DA),
      documentId: documentId,
      blockIndex: blockIndex,
      textOffsetInBlock: textOffsetInBlock,
      offsetMapping: offsetMapping,
      inlineCodeStyle: inlineCodeStyle,
      selectable: selectable,
      onSurfaceAttach: onSurfaceAttach,
      onSurfaceDetach: onSurfaceDetach,
      onHoverCleared: onHoverCleared,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSelectableParagraph renderObject,
  ) {
    renderObject
      ..updateSurfaceIdentity(
        documentId: documentId,
        blockIndex: blockIndex,
        textOffsetInBlock: textOffsetInBlock,
        selectable: selectable,
        onSurfaceAttach: onSurfaceAttach,
        onSurfaceDetach: onSurfaceDetach,
      )
      ..updateTextAndMapping(text: text, offsetMapping: offsetMapping)
      ..textAlign = textAlign
      ..textDirection = textDirection ?? Directionality.of(context)
      ..softWrap = softWrap
      ..overflow = overflow
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..locale = locale ?? Localizations.maybeLocaleOf(context)
      ..strutStyle = strutStyle
      ..textWidthBasis = textWidthBasis
      ..textHeightBehavior = textHeightBehavior
      ..highlightColor = selectionColor ?? const Color(0x4D0969DA)
      ..inlineCodeStyle = inlineCodeStyle
      ..onHoverCleared = onHoverCleared;
  }
}

/// Custom [RenderParagraph] implementing [MarkdownSelectionSurface], inline
/// code pill painting, selection highlight & `LeaderLayer` handle anchoring,
/// canonical-to-painter offset mapping, and range-based tap/hover handling.
class RenderSelectableParagraph extends RenderParagraph
    implements MarkdownSelectionSurface {
  RenderSelectableParagraph(
    super.text, {
    required super.textDirection,
    super.textAlign,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    required Color highlightColor,
    required String documentId,
    required int blockIndex,
    required int textOffsetInBlock,
    required TextOffsetMapping offsetMapping,
    required MarkdownInlineCodeStyle inlineCodeStyle,
    bool selectable = true,
    ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach,
    ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach,
    this.onHoverCleared,
  }) : _highlightColor = highlightColor,
       _documentId = documentId,
       _blockIndex = blockIndex,
       _textOffsetInBlock = textOffsetInBlock,
       _offsetMapping = offsetMapping,
       _inlineCodeStyle = inlineCodeStyle,
       _selectable = selectable,
       _onSurfaceAttach = onSurfaceAttach,
       _onSurfaceDetach = onSurfaceDetach,
       super(selectionColor: highlightColor) {
    _baseText = text;
    _tapRecognizer = TapGestureRecognizer(debugOwner: this)
      ..onTap = _handleTapConfirmed
      ..onTapCancel = _handleTapCancelled;
    _rebuildSpanMetadata();
  }

  late InlineSpan _baseText;
  Color _highlightColor;
  String _documentId;
  int _blockIndex;
  int _textOffsetInBlock;
  TextOffsetMapping _offsetMapping;
  MarkdownInlineCodeStyle _inlineCodeStyle;
  bool _selectable;
  ValueChanged<MarkdownSelectionSurface>? _onSurfaceAttach;
  ValueChanged<MarkdownSelectionSurface>? _onSurfaceDetach;

  /// Callback notified when hover is cleared internally (e.g. layout or text
  /// change) so the enclosing [SelectableParagraph] can reset its cursor.
  VoidCallback? onHoverCleared;

  bool _surfaceRegistered = false;
  TextRange? _selectionHighlightRange;
  LayerLink? _startHandleLayerLink;
  int? _startHandleLocalOffset;
  LayerLink? _endHandleLayerLink;
  int? _endHandleLocalOffset;

  final List<_CodeRange> _codeRanges = [];
  final List<_TappableRange> _tappableRanges = [];
  int? _hoveredSpanIndex;
  BoxConstraints? _lastLayoutConstraints;

  late final TapGestureRecognizer _tapRecognizer;
  VoidCallback? _pendingTapCallback;

  /// The canonical, un-hovered [InlineSpan] supplied to this render object.
  InlineSpan get baseText => _baseText;

  /// Active canonical-to-painter offset mapping.
  TextOffsetMapping get offsetMapping => _offsetMapping;

  /// Index of the currently hovered [TappableTextSpan] range, or `null`.
  int? get hoveredSpanIndex => _hoveredSpanIndex;

  /// Active canonical highlight range, or `null` when unselected.
  TextRange? get selectionHighlightRange => _selectionHighlightRange;

  /// Inline code pill ranges extracted from [baseText] (in painter offsets).
  @visibleForTesting
  int get codeRangeCount => _codeRanges.length;

  /// Tappable inline ranges extracted from [baseText] (in painter offsets).
  @visibleForTesting
  int get tappableRangeCount => _tappableRanges.length;

  Color get highlightColor => _highlightColor;
  set highlightColor(Color value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    selectionColor = value;
    if (_selectionHighlightRange != null) {
      markNeedsPaint();
    }
  }

  MarkdownInlineCodeStyle get inlineCodeStyle => _inlineCodeStyle;
  set inlineCodeStyle(MarkdownInlineCodeStyle value) {
    if (_inlineCodeStyle == value) return;
    _inlineCodeStyle = value;
    if (_codeRanges.isNotEmpty) {
      markNeedsPaint();
    }
  }

  /// Updates document registration metadata, detaching and re-attaching
  /// cleanly whenever surface identity (`documentId`, `blockIndex`,
  /// `textOffsetInBlock`), `selectable`, or controller callbacks change while
  /// attached.
  void updateSurfaceIdentity({
    required String documentId,
    required int blockIndex,
    required int textOffsetInBlock,
    required bool selectable,
    required ValueChanged<MarkdownSelectionSurface>? onSurfaceAttach,
    required ValueChanged<MarkdownSelectionSurface>? onSurfaceDetach,
  }) {
    final docChanged = _documentId != documentId;
    final blockIndexChanged = _blockIndex != blockIndex;
    final textOffsetChanged = _textOffsetInBlock != textOffsetInBlock;
    final selectableChanged = _selectable != selectable;
    final attachCleared = onSurfaceAttach == null;
    final controllerSwitched =
        _onSurfaceAttach != onSurfaceAttach &&
        _onSurfaceDetach != onSurfaceDetach;

    final shouldDetach =
        docChanged ||
        blockIndexChanged ||
        textOffsetChanged ||
        (selectableChanged && !selectable) ||
        attachCleared ||
        controllerSwitched;

    if (attached && _surfaceRegistered && shouldDetach) {
      _onSurfaceDetach?.call(this);
      _surfaceRegistered = false;
    }

    _documentId = documentId;
    _blockIndex = blockIndex;
    _textOffsetInBlock = textOffsetInBlock;
    _selectable = selectable;
    _onSurfaceAttach = onSurfaceAttach;
    _onSurfaceDetach = onSurfaceDetach;

    if (attached &&
        _selectable &&
        !_surfaceRegistered &&
        _onSurfaceAttach != null) {
      _onSurfaceAttach?.call(this);
      _surfaceRegistered = true;
    }
  }

  /// Atomically updates the logical [text] and [offsetMapping] without
  /// discarding hover state unnecessarily when content is unchanged.
  void updateTextAndMapping({
    required InlineSpan text,
    required TextOffsetMapping offsetMapping,
  }) {
    final mappingChanged = _offsetMapping != offsetMapping;
    _offsetMapping = offsetMapping;

    if (identical(text, _baseText)) {
      if (mappingChanged &&
          (_selectionHighlightRange != null || hasSelectionHandleLeaders)) {
        markNeedsPaint();
      }
      return;
    }

    final comparison = _baseText.compareTo(text);
    _baseText = text;
    _rebuildSpanMetadata();

    if (comparison == RenderComparison.identical) {
      // Visual spans are identical, though tap callbacks may have refreshed.
      if (_hoveredSpanIndex != null &&
          _hoveredSpanIndex! >= _tappableRanges.length) {
        _hoveredSpanIndex = null;
        super.text = _baseText;
        onHoverCleared?.call();
      } else if (mappingChanged &&
          (_selectionHighlightRange != null || hasSelectionHandleLeaders)) {
        markNeedsPaint();
      }
      return;
    }

    // Content or style changed: invalidate any stale hover and apply new span.
    if (_hoveredSpanIndex != null) {
      _hoveredSpanIndex = null;
      onHoverCleared?.call();
    }
    super.text = _baseText;
    if (mappingChanged) {
      markNeedsPaint();
    }
  }

  void _rebuildSpanMetadata() {
    _codeRanges.clear();
    _tappableRanges.clear();
    var cursor = 0;

    void walk(InlineSpan span) {
      final start = cursor;
      if (span is TextSpan) {
        if (span.text != null) {
          cursor += span.text!.length;
        }
        final children = span.children;
        if (children != null) {
          for (final child in children) {
            walk(child);
          }
        }
      } else if (span is PlaceholderSpan) {
        cursor += 1;
      }
      final end = cursor;
      if (end > start) {
        if (span is CodeTextSpan) {
          _codeRanges.add(
            _CodeRange(start: start, end: end, codeStyle: span.codeStyle),
          );
        }
        if (span is TappableTextSpan) {
          // Post-order recording ensures innermost nested TappableTextSpan
          // wins hit tests first.
          _tappableRanges.add(
            _TappableRange(start: start, end: end, span: span),
          );
        }
      }
    }

    walk(_baseText);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_selectable && !_surfaceRegistered) {
      _onSurfaceAttach?.call(this);
      _surfaceRegistered = _onSurfaceAttach != null;
    }
  }

  @override
  void detach() {
    _pendingTapCallback = null;
    if (_surfaceRegistered) {
      _onSurfaceDetach?.call(this);
      _surfaceRegistered = false;
    }
    super.detach();
  }

  @override
  void dispose() {
    _pendingTapCallback = null;
    _tapRecognizer.dispose();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing =>
      hasSelectionHandleLeaders || super.alwaysNeedsCompositing;

  @override
  void performLayout() {
    if (_lastLayoutConstraints != null &&
        _lastLayoutConstraints != constraints &&
        _hoveredSpanIndex != null) {
      _hoveredSpanIndex = null;
      super.text = _baseText;
      onHoverCleared?.call();
    }
    _lastLayoutConstraints = constraints;
    super.performLayout();
  }

  // ---------------------------------------------------------------------------
  // Range-based hover & tap handling for TappableTextSpan
  // ---------------------------------------------------------------------------

  /// Updates desktop hover state for [localPosition] and returns the
  /// [MouseCursor] for the hovered [TappableTextSpan], or `null` when not
  /// hovering any tappable span.
  MouseCursor? updateHoverAtLocal(Offset localPosition) {
    final hitIndex = _hitTestTappableIndex(localPosition);
    if (hitIndex != _hoveredSpanIndex) {
      _hoveredSpanIndex = hitIndex;
      _syncHoverText();
    }
    if (hitIndex == null) return null;
    return _tappableRanges[hitIndex].span.mouseCursor;
  }

  /// Clears any active hover styling immediately (e.g. on pointer exit or
  /// ancestor scroll).
  void clearHover() {
    if (_hoveredSpanIndex == null) return;
    _hoveredSpanIndex = null;
    _syncHoverText();
  }

  void _syncHoverText() {
    final index = _hoveredSpanIndex;
    if (index == null || index >= _tappableRanges.length) {
      if (!identical(super.text, _baseText)) {
        super.text = _baseText;
      }
      return;
    }
    final target = _tappableRanges[index].span;
    final hoverStyle = target.hoverStyle;
    if (hoverStyle == null) {
      if (!identical(super.text, _baseText)) {
        super.text = _baseText;
      }
      return;
    }
    super.text = _cloneWithHoverStyle(_baseText, target, hoverStyle, false);
  }

  InlineSpan _cloneWithHoverStyle(
    InlineSpan span,
    TappableTextSpan target,
    TextStyle hoverStyle,
    bool insideTarget,
  ) {
    final nowInside = insideTarget || identical(span, target);
    if (span is! TextSpan) {
      // Preserve WidgetSpan / PlaceholderSpan instances verbatim so child
      // render object alignment is untouched.
      return span;
    }

    final children = span.children;
    List<InlineSpan>? clonedChildren;
    if (children != null) {
      var anyChanged = false;
      clonedChildren = List<InlineSpan>.generate(children.length, (i) {
        final orig = children[i];
        final next = _cloneWithHoverStyle(orig, target, hoverStyle, nowInside);
        if (!identical(orig, next)) anyChanged = true;
        return next;
      });
      if (!anyChanged && !nowInside) {
        return span;
      }
    } else if (!nowInside) {
      return span;
    }

    final mergedStyle = nowInside
        ? _mergeHoverStyle(span.style, hoverStyle)
        : span.style;

    if (span is CodeTextSpan) {
      return CodeTextSpan(
        text: span.text,
        children: clonedChildren,
        style: mergedStyle,
        codeStyle: span.codeStyle,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }

    if (span is TappableTextSpan) {
      return TappableTextSpan(
        text: span.text,
        children: clonedChildren,
        style: mergedStyle,
        onTap: span.onTap,
        hoverStyle: span.hoverStyle,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }

    return TextSpan(
      text: span.text,
      children: clonedChildren,
      style: mergedStyle,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  TextStyle _mergeHoverStyle(TextStyle? base, TextStyle hover) {
    if (base == null) return hover;
    final merged = base.merge(hover);
    if (base.decoration != null &&
        base.decoration != TextDecoration.none &&
        hover.decoration != null &&
        hover.decoration != TextDecoration.none &&
        base.decoration != hover.decoration) {
      return merged.copyWith(
        decoration: TextDecoration.combine([
          base.decoration!,
          hover.decoration!,
        ]),
      );
    }
    return merged;
  }

  int? _hitTestTappableIndex(Offset localPosition) {
    if (!hasSize || _tappableRanges.isEmpty) return null;
    if (!(Offset.zero & size).contains(localPosition)) return null;

    for (var i = 0; i < _tappableRanges.length; i++) {
      final range = _tappableRanges[i];
      final boxes = getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      for (final box in boxes) {
        if (box.toRect().contains(localPosition)) {
          return i;
        }
      }
    }
    return null;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
    if (event is PointerDownEvent && _tappableRanges.isNotEmpty) {
      final isPrimary =
          event.buttons == 0 || (event.buttons & kPrimaryButton) != 0;
      if (!isPrimary) return;
      final hitIndex = _hitTestTappableIndex(event.localPosition);
      if (hitIndex != null) {
        final callback = _tappableRanges[hitIndex].span.onTap;
        if (callback != null) {
          _pendingTapCallback = callback;
          _tapRecognizer.addPointer(event);
        }
      }
    }
  }

  void _handleTapConfirmed() {
    final callback = _pendingTapCallback;
    _pendingTapCallback = null;
    callback?.call();
  }

  void _handleTapCancelled() {
    _pendingTapCallback = null;
  }

  // ---------------------------------------------------------------------------
  // Painting: inline code pills -> selection highlights -> text -> handle links
  // ---------------------------------------------------------------------------

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_codeRanges.isNotEmpty) {
      _paintInlineCodePills(context.canvas, offset);
    }
    if (_selectionHighlightRange != null) {
      _paintSelectionHighlights(context.canvas, offset);
    }

    super.paint(context, offset);

    if (_startHandleLayerLink != null && _startHandleLocalOffset != null) {
      final rect = caretRectForLocalOffset(
        _startHandleLocalOffset!,
        affinity: TextAffinity.downstream,
      );
      context.addLayer(
        LeaderLayer(
          link: _startHandleLayerLink!,
          offset: offset + rect.bottomLeft,
        ),
      );
    }
    if (_endHandleLayerLink != null &&
        _endHandleLocalOffset != null &&
        _endHandleLayerLink != _startHandleLayerLink) {
      final rect = caretRectForLocalOffset(
        _endHandleLocalOffset!,
        affinity: TextAffinity.upstream,
      );
      context.addLayer(
        LeaderLayer(
          link: _endHandleLayerLink!,
          offset: offset + rect.bottomLeft,
        ),
      );
    }
  }

  void _paintInlineCodePills(Canvas canvas, Offset offset) {
    for (final range in _codeRanges) {
      final style = range.codeStyle ?? _inlineCodeStyle;
      final boxes = getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
        boxHeightStyle: ui.BoxHeightStyle.tight,
      );
      if (boxes.isEmpty) continue;

      final lineRects = _mergeLineBoxes(boxes);
      final radius = Radius.circular(style.borderRadius);

      for (final rawRect in lineRects) {
        if (rawRect.width <= 0 || rawRect.height <= 0) continue;
        final padded = Rect.fromLTRB(
          rawRect.left - style.padding.left,
          rawRect.top - style.padding.top,
          rawRect.right + style.padding.right,
          rawRect.bottom + style.padding.bottom,
        ).shift(offset);

        final rrect = RRect.fromRectAndRadius(padded, radius);
        if (style.backgroundColor.a > 0) {
          final bgPaint = Paint()
            ..color = style.backgroundColor
            ..style = PaintingStyle.fill;
          canvas.drawRRect(rrect, bgPaint);
        }
        if (style.borderColor != null && style.borderWidth > 0) {
          final borderPaint = Paint()
            ..color = style.borderColor!
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.borderWidth;
          canvas.drawRRect(rrect, borderPaint);
        }
      }
    }
  }

  List<Rect> _mergeLineBoxes(List<TextBox> boxes) {
    final merged = <Rect>[];
    for (final box in boxes) {
      final rect = box.toRect();
      if (rect.isEmpty) continue;
      if (merged.isEmpty) {
        merged.add(rect);
        continue;
      }
      final prev = merged.last;
      final verticalOverlap =
          math.min(prev.bottom, rect.bottom) - math.max(prev.top, rect.top);
      final minHeight = math.min(prev.height, rect.height);
      final sameLine = minHeight > 0 && verticalOverlap >= minHeight * 0.5;
      final horizontallyAdjacent =
          (rect.left - prev.right).abs() <= 2.0 ||
          (prev.left - rect.right).abs() <= 2.0 ||
          (rect.left <= prev.right && rect.right >= prev.left);

      if (sameLine && horizontallyAdjacent) {
        merged[merged.length - 1] = prev.expandToInclude(rect);
      } else {
        merged.add(rect);
      }
    }
    return merged;
  }

  void _paintSelectionHighlights(Canvas canvas, Offset offset) {
    final range = _selectionHighlightRange;
    if (range == null || !range.isValid || range.isCollapsed) return;

    final boxes = boxesForLocalRange(range.start, range.end);
    if (boxes.isEmpty) return;

    final paint = Paint()
      ..color = _highlightColor
      ..style = PaintingStyle.fill;

    for (final box in boxes) {
      final rect = box.toRect().shift(offset);
      if (rect.width > 0 && rect.height > 0) {
        canvas.drawRect(rect, paint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MarkdownSelectionSurface implementation
  // ---------------------------------------------------------------------------

  @override
  String get documentId => _documentId;

  @override
  int get blockIndex => _blockIndex;

  @override
  int get textOffsetInBlock => _textOffsetInBlock;

  @override
  int get textLength => _offsetMapping.canonicalLength;

  @override
  Rect? get globalBounds {
    if (!attached || !hasSize) return null;
    return MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
  }

  @override
  bool get hasSelectionHandleLeaders =>
      (_startHandleLayerLink != null && _startHandleLocalOffset != null) ||
      (_endHandleLayerLink != null && _endHandleLocalOffset != null);

  @override
  bool hitsTextAtGlobal(Offset globalOffset) {
    if (!attached || !hasSize || _offsetMapping.painterLength == 0) {
      return false;
    }
    final local = globalToLocal(globalOffset);
    if (!(Offset.zero & size).contains(local)) {
      return false;
    }
    final boxes = getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: _offsetMapping.painterLength),
    );
    for (final box in boxes) {
      if (box.toRect().contains(local)) {
        return true;
      }
    }
    return false;
  }

  @override
  MarkdownPosition positionForGlobalOffset(Offset globalOffset) {
    if (!attached || !hasSize || textLength == 0) {
      return MarkdownPosition(
        documentId: _documentId,
        blockIndex: _blockIndex,
        offset: _textOffsetInBlock,
      );
    }
    final local = globalToLocal(globalOffset);
    final painterPos = getPositionForOffset(local);
    final localCanonical = _offsetMapping.painterToCanonical(painterPos.offset);
    return MarkdownPosition(
      documentId: _documentId,
      blockIndex: _blockIndex,
      offset: _textOffsetInBlock + localCanonical,
    );
  }

  @override
  TextRange wordRangeAtLocal(int localOffset) {
    if (!hasSize || textLength == 0 || _offsetMapping.painterLength == 0) {
      return const TextRange(start: 0, end: 0);
    }
    final clamped = localOffset.clamp(0, textLength);
    final maxIdx = math.max<int>(0, _offsetMapping.painterLength - 1);
    final painterOffset = _offsetMapping
        .canonicalCaretToPainter(clamped)
        .clamp(0, maxIdx);
    final word = getWordBoundary(TextPosition(offset: painterOffset));
    return _offsetMapping.painterRangeToCanonicalRange(word.start, word.end);
  }

  @override
  TextRange lineRangeAtLocal(int localOffset) {
    if (!hasSize || textLength == 0 || _offsetMapping.painterLength == 0) {
      return const TextRange(start: 0, end: 0);
    }
    final clamped = localOffset.clamp(0, textLength);
    final painterOffset = _offsetMapping.canonicalCaretToPainter(clamped);
    final pos = TextPosition(offset: painterOffset);
    final caretOffset = getOffsetForCaret(pos, Rect.zero);
    final caretHeight = getFullHeightForCaret(pos);
    final effectiveHeight = caretHeight > 0
        ? caretHeight
        : _fallbackLineHeight();
    final maxY = math.max<double>(0.0, size.height - 0.5);
    final lineMidY = math.min<double>(
      math.max<double>(0.0, caretOffset.dy + effectiveHeight * 0.5),
      maxY,
    );
    final leftOffset = getPositionForOffset(Offset(0.0, lineMidY)).offset;
    final rightOffset = getPositionForOffset(
      Offset(size.width + 1.0, lineMidY),
    ).offset;
    final lineStart = math.min(leftOffset, rightOffset);
    final lineEnd = math.max(leftOffset, rightOffset);
    return _offsetMapping.painterRangeToCanonicalRange(lineStart, lineEnd);
  }

  @override
  List<TextBox> boxesForLocalRange(int start, int end) {
    if (!hasSize || textLength == 0) return const [];
    final clampedStart = start.clamp(0, textLength);
    final clampedEnd = end.clamp(clampedStart, textLength);
    if (clampedEnd <= clampedStart) return const [];

    final mapped = _offsetMapping.canonicalRangeToPainterRange(
      clampedStart,
      clampedEnd,
    );
    if (mapped.end <= mapped.start) return const [];
    return getBoxesForSelection(
      TextSelection(baseOffset: mapped.start, extentOffset: mapped.end),
    );
  }

  @override
  Rect caretRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    final fallbackHeight = _fallbackLineHeight();
    if (!hasSize) {
      return Rect.fromLTWH(0.0, 0.0, 1.0, fallbackHeight);
    }
    final painterOffset = _offsetMapping.canonicalCaretToPainter(
      offset,
      affinity: affinity,
    );
    final position = TextPosition(offset: painterOffset, affinity: affinity);
    final caretOffset = getOffsetForCaret(position, Rect.zero);
    final caretHeight = getFullHeightForCaret(position);
    final effectiveHeight = caretHeight > 0 ? caretHeight : fallbackHeight;
    return Rect.fromLTWH(caretOffset.dx, caretOffset.dy, 1.0, effectiveHeight);
  }

  @override
  Rect? globalRectForLocalOffset(
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    if (!attached || !hasSize) return null;
    final localRect = caretRectForLocalOffset(offset, affinity: affinity);
    return MatrixUtils.transformRect(getTransformTo(null), localRect);
  }

  @override
  void setSelectionHighlightRange(TextRange? range) {
    final normalized = (range == null || !range.isValid || range.isCollapsed)
        ? null
        : TextRange(
            start: range.start.clamp(0, textLength),
            end: range.end.clamp(0, textLength),
          );
    if (_selectionHighlightRange == normalized) return;
    _selectionHighlightRange = normalized;
    markNeedsPaint();
  }

  @override
  void setSelectionHandleLayers({
    LayerLink? startHandleLayerLink,
    int? startHandleLocalOffset,
    LayerLink? endHandleLayerLink,
    int? endHandleLocalOffset,
  }) {
    final hadLeaders = hasSelectionHandleLeaders;
    final nextStartOffset = startHandleLocalOffset?.clamp(0, textLength);
    final nextEndOffset = endHandleLocalOffset?.clamp(0, textLength);

    if (_startHandleLayerLink == startHandleLayerLink &&
        _startHandleLocalOffset == nextStartOffset &&
        _endHandleLayerLink == endHandleLayerLink &&
        _endHandleLocalOffset == nextEndOffset) {
      return;
    }

    _startHandleLayerLink = startHandleLayerLink;
    _startHandleLocalOffset = nextStartOffset;
    _endHandleLayerLink = endHandleLayerLink;
    _endHandleLocalOffset = nextEndOffset;

    if (hadLeaders != hasSelectionHandleLeaders) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  void clearSelectionHandleLayersIfLinked({
    LayerLink? startHandleLayerLink,
    LayerLink? endHandleLayerLink,
  }) {
    final hadLeaders = hasSelectionHandleLeaders;
    var changed = false;

    if (startHandleLayerLink != null &&
        _startHandleLayerLink == startHandleLayerLink) {
      _startHandleLayerLink = null;
      _startHandleLocalOffset = null;
      changed = true;
    }
    if (endHandleLayerLink != null &&
        _endHandleLayerLink == endHandleLayerLink) {
      _endHandleLayerLink = null;
      _endHandleLocalOffset = null;
      changed = true;
    }

    if (!changed) return;
    if (hadLeaders != hasSelectionHandleLeaders) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  double _fallbackLineHeight() {
    final fontSize = _baseText.style?.fontSize ?? 15.0;
    final heightMultiplier = _baseText.style?.height ?? 1.3;
    return math.max(1.0, fontSize * heightMultiplier);
  }
}

class _CodeRange {
  const _CodeRange({
    required this.start,
    required this.end,
    required this.codeStyle,
  });

  final int start;
  final int end;
  final MarkdownInlineCodeStyle? codeStyle;
}

class _TappableRange {
  const _TappableRange({
    required this.start,
    required this.end,
    required this.span,
  });

  final int start;
  final int end;
  final TappableTextSpan span;
}
