import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Underlines the markdown link under the mouse pointer.
///
/// `flutter_markdown` builds link spans internally and offers no per-link
/// hover hook, and a custom `a` builder would split links out of the
/// paragraph. Instead this hit-tests the rendered text, finds the contiguous
/// range that shares the hovered link's gesture recognizer, and paints an
/// underline over it without rebuilding the markdown.
class LinkHoverUnderline extends StatefulWidget {
  final Widget child;

  const LinkHoverUnderline({super.key, required this.child});

  @override
  State<LinkHoverUnderline> createState() => LinkHoverUnderlineState();
}

class LinkHoverUnderlineState extends State<LinkHoverUnderline> {
  List<Rect> _rects = const [];
  Color? _color;
  ScrollPosition? _scrollPosition;
  BoxConstraints? _constraints;

  @visibleForTesting
  List<Rect> get underlineRects => _rects;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_clearHover);
      _scrollPosition = position;
      position?.addListener(_clearHover);
    }
    _rects = const [];
  }

  void _clearHover() {
    if (_rects.isNotEmpty) _update(const [], _color);
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_clearHover);
    super.dispose();
  }

  @override
  void didUpdateWidget(LinkHoverUnderline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Text may have been re-laid out (e.g. streaming), so drop stale rects.
    _rects = const [];
  }

  void _update(List<Rect> rects, Color? color) {
    if (listEquals(rects, _rects) && color == _color) return;
    setState(() {
      _rects = rects;
      _color = color;
    });
  }

  void _onHover(PointerHoverEvent event) {
    final root = context.findRenderObject();
    if (root is! RenderBox) return;
    final result = BoxHitTestResult();
    root.hitTest(result, position: event.localPosition);
    for (final entry in result.path) {
      final target = entry.target;
      final hovered = switch (target) {
        RenderParagraph() => _hoveredLink(
          text: target.text,
          localPosition: target.globalToLocal(event.position),
          positionAt: target.getPositionForOffset,
          boxesFor: target.getBoxesForSelection,
        ),
        RenderEditable() => _hoveredLink(
          text: target.text,
          localPosition: target.globalToLocal(event.position),
          positionAt: (local) =>
              target.getPositionForPoint(target.localToGlobal(local)),
          boxesFor: target.getBoxesForSelection,
        ),
        _ => null,
      };
      if (hovered == null) continue;
      final transform = (target as RenderBox).getTransformTo(root);
      _update([
        for (final box in hovered.boxes)
          MatrixUtils.transformRect(transform, box.toRect()),
      ], hovered.color);
      return;
    }
    _update(const [], _color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_constraints != constraints) {
          _constraints = constraints;
          _rects = const [];
        }
        return MouseRegion(
          opaque: false,
          onHover: _onHover,
          onExit: (_) => _update(const [], _color),
          child: NotificationListener<ScrollNotification>(
            // Rects are in this widget's coordinates; scrolling content inside
            // the child (e.g. a scrollable Markdown) would leave them behind.
            onNotification: (_) {
              if (_rects.isNotEmpty) _update(const [], _color);
              return false;
            },
            child: CustomPaint(
              foregroundPainter: _UnderlinePainter(
                rects: _rects,
                color: _color ?? Theme.of(context).colorScheme.primary,
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class _HoveredLink {
  final List<TextBox> boxes;
  final Color? color;

  const _HoveredLink(this.boxes, this.color);
}

_HoveredLink? _hoveredLink({
  required InlineSpan? text,
  required Offset localPosition,
  required TextPosition Function(Offset) positionAt,
  required List<TextBox> Function(TextSelection) boxesFor,
}) {
  if (text == null) return null;
  final position = positionAt(localPosition);
  // Fast path: most hover moves are over plain text.
  final span = text.getSpanForPosition(position);
  if (span is! TextSpan || span.recognizer is! TapGestureRecognizer) {
    return null;
  }
  // An upstream caret at a span boundary belongs to the preceding character.
  final offset = position.affinity == TextAffinity.upstream
      ? position.offset - 1
      : position.offset;
  final range = _linkRangeAt(text, offset);
  if (range == null) return null;
  final boxes = boxesFor(
    TextSelection(baseOffset: range.start, extentOffset: range.end),
  );
  // positionAt snaps to the nearest character, so confirm the pointer is
  // actually over the link and not past the end of a line.
  final isInside = boxes.any(
    (box) => box.toRect().inflate(1).contains(localPosition),
  );
  if (!isInside) return null;
  return _HoveredLink(boxes, range.color);
}

class _LinkRange {
  final int start;
  final int end;
  final Color? color;

  const _LinkRange(this.start, this.end, this.color);
}

/// Returns the text range sharing the link recognizer at [offset], if any.
_LinkRange? _linkRangeAt(InlineSpan root, int offset) {
  final pieces = <({int start, int end, TextSpan span})>[];
  var cursor = 0;
  root.visitChildren((span) {
    if (span is TextSpan) {
      final length = span.text?.length ?? 0;
      if (length > 0) {
        pieces.add((start: cursor, end: cursor + length, span: span));
      }
      cursor += length;
    } else if (span is PlaceholderSpan) {
      cursor += 1;
    }
    return true;
  });

  // A position at a span boundary belongs to the character after it.
  final hit = pieces.where((p) => p.start <= offset && offset < p.end);
  if (hit.isEmpty) return null;
  final recognizer = hit.first.span.recognizer;
  if (recognizer is! TapGestureRecognizer) return null;

  final index = pieces.indexOf(hit.first);
  var first = index;
  var last = index;
  while (first > 0 &&
      pieces[first - 1].span.recognizer == recognizer &&
      pieces[first - 1].end == pieces[first].start) {
    first--;
  }
  while (last < pieces.length - 1 &&
      pieces[last + 1].span.recognizer == recognizer &&
      pieces[last + 1].start == pieces[last].end) {
    last++;
  }
  return _LinkRange(
    pieces[first].start,
    pieces[last].end,
    hit.first.span.style?.color,
  );
}

class _UnderlinePainter extends CustomPainter {
  final List<Rect> rects;
  final Color color;

  const _UnderlinePainter({required this.rects, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (rects.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final rect in rects) {
      final y = rect.bottom - 1.5;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) =>
      !listEquals(rects, oldDelegate.rects) || color != oldDelegate.color;
}
