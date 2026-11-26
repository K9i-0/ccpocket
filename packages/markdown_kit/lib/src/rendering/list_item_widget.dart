import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Visual marker type painted in the hanging gutter of a
/// [MarkdownListItemWidget].
enum MarkdownListMarkerKind { bullet, ordered, taskUnchecked, taskChecked }

/// Hanging-indent list item whose marker (bullet, ordinal number, or task
/// checkbox) is painted directly onto the [Canvas] so markers are never part
/// of selectable text or copied clipboard output.
///
/// The marker aligns vertically with the child's first-line alphabetic baseline
/// (falling back to the line-height midpoint if the child has no text baseline).
class MarkdownListItemWidget extends SingleChildRenderObjectWidget {
  const MarkdownListItemWidget({
    super.key,
    required this.markerKind,
    required this.markerColor,
    required this.bulletSize,
    required this.indent,
    required this.markerTextStyle,
    this.checkboxFillColor,
    this.checkboxCheckColor,
    this.ordinalText,
    this.nestingDepth = 0,
    this.textDirection,
    this.textScaler,
    required Widget super.child,
  });

  final MarkdownListMarkerKind markerKind;
  final Color markerColor;
  final double bulletSize;
  final double indent;
  final TextStyle markerTextStyle;
  final Color? checkboxFillColor;
  final Color? checkboxCheckColor;
  final String? ordinalText;
  final int nestingDepth;
  final TextDirection? textDirection;
  final TextScaler? textScaler;

  @override
  RenderMarkdownListItem createRenderObject(BuildContext context) {
    return RenderMarkdownListItem(
      markerKind: markerKind,
      markerColor: markerColor,
      checkboxFillColor: checkboxFillColor,
      checkboxCheckColor: checkboxCheckColor,
      bulletSize: bulletSize,
      indent: indent,
      markerTextStyle: markerTextStyle,
      ordinalText: ordinalText,
      nestingDepth: nestingDepth,
      textDirection: textDirection ?? Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMarkdownListItem renderObject,
  ) {
    renderObject
      ..markerKind = markerKind
      ..markerColor = markerColor
      ..checkboxFillColor = checkboxFillColor
      ..checkboxCheckColor = checkboxCheckColor
      ..bulletSize = bulletSize
      ..indent = indent
      ..markerTextStyle = markerTextStyle
      ..ordinalText = ordinalText
      ..nestingDepth = nestingDepth
      ..textDirection = textDirection ?? Directionality.of(context)
      ..textScaler = textScaler ?? MediaQuery.textScalerOf(context);
  }
}

/// Render object for [MarkdownListItemWidget] that lays out a hanging gutter
/// and paints the non-selectable marker directly on the [Canvas].
class RenderMarkdownListItem extends RenderShiftedBox {
  RenderMarkdownListItem({
    required MarkdownListMarkerKind markerKind,
    required Color markerColor,
    Color? checkboxFillColor,
    Color? checkboxCheckColor,
    required double bulletSize,
    required double indent,
    required TextStyle markerTextStyle,
    String? ordinalText,
    int nestingDepth = 0,
    required TextDirection textDirection,
    TextScaler textScaler = TextScaler.noScaling,
    RenderBox? child,
  }) : _markerKind = markerKind,
       _markerColor = markerColor,
       _checkboxFillColor = checkboxFillColor,
       _checkboxCheckColor = checkboxCheckColor,
       _bulletSize = bulletSize,
       _indent = indent,
       _markerTextStyle = markerTextStyle,
       _ordinalText = ordinalText,
       _nestingDepth = nestingDepth,
       _textDirection = textDirection,
       _textScaler = textScaler,
       super(child);

  MarkdownListMarkerKind _markerKind;
  MarkdownListMarkerKind get markerKind => _markerKind;
  set markerKind(MarkdownListMarkerKind value) {
    if (_markerKind == value) return;
    _markerKind = value;
    _disposeOrdinalPainter();
    markNeedsLayout();
  }

  Color _markerColor;
  Color get markerColor => _markerColor;
  set markerColor(Color value) {
    if (_markerColor == value) return;
    _markerColor = value;
    _disposeOrdinalPainter();
    markNeedsPaint();
  }

  Color? _checkboxFillColor;
  Color? get checkboxFillColor => _checkboxFillColor;
  set checkboxFillColor(Color? value) {
    if (_checkboxFillColor == value) return;
    _checkboxFillColor = value;
    markNeedsPaint();
  }

  Color? _checkboxCheckColor;
  Color? get checkboxCheckColor => _checkboxCheckColor;
  set checkboxCheckColor(Color? value) {
    if (_checkboxCheckColor == value) return;
    _checkboxCheckColor = value;
    markNeedsPaint();
  }

  double _bulletSize;
  double get bulletSize => _bulletSize;
  set bulletSize(double value) {
    if (_bulletSize == value) return;
    _bulletSize = value;
    markNeedsPaint();
  }

  double _indent;
  double get indent => _indent;
  set indent(double value) {
    if (_indent == value) return;
    _indent = value;
    markNeedsLayout();
  }

  TextStyle _markerTextStyle;
  TextStyle get markerTextStyle => _markerTextStyle;
  set markerTextStyle(TextStyle value) {
    if (_markerTextStyle == value) return;
    _markerTextStyle = value;
    _disposeOrdinalPainter();
    markNeedsLayout();
  }

  String? _ordinalText;
  String? get ordinalText => _ordinalText;
  set ordinalText(String? value) {
    if (_ordinalText == value) return;
    _ordinalText = value;
    _disposeOrdinalPainter();
    markNeedsLayout();
  }

  int _nestingDepth;
  int get nestingDepth => _nestingDepth;
  set nestingDepth(int value) {
    if (_nestingDepth == value) return;
    _nestingDepth = value;
    markNeedsPaint();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _disposeOrdinalPainter();
    markNeedsLayout();
  }

  TextScaler _textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    _disposeOrdinalPainter();
    markNeedsLayout();
  }

  TextPainter? _ordinalPainter;
  double _gutterWidth = 0.0;
  double? _childBaseline;

  static const double _ordinalGap = 6.0;

  void _disposeOrdinalPainter() {
    _ordinalPainter?.dispose();
    _ordinalPainter = null;
  }

  @override
  void dispose() {
    _disposeOrdinalPainter();
    super.dispose();
  }

  TextPainter _ensureOrdinalPainter() {
    final existing = _ordinalPainter;
    if (existing != null) return existing;
    final painter = TextPainter(
      text: TextSpan(
        text: _ordinalText ?? '1.',
        style: _markerTextStyle.copyWith(color: _markerColor),
      ),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: 1,
    )..layout();
    _ordinalPainter = painter;
    return painter;
  }

  double _computeGutterWidth() {
    if (_markerKind == MarkdownListMarkerKind.ordered) {
      final painter = _ensureOrdinalPainter();
      return math.max(_indent, painter.width + _ordinalGap);
    }
    return _indent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final gutter = _computeGutterWidth();
    final childWidth = child?.getMinIntrinsicWidth(height) ?? 0.0;
    return gutter + childWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final gutter = _computeGutterWidth();
    final childWidth = child?.getMaxIntrinsicWidth(height) ?? 0.0;
    return gutter + childWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final gutter = _computeGutterWidth();
    final innerWidth = width.isFinite ? math.max(0.0, width - gutter) : width;
    final childHeight = child?.getMinIntrinsicHeight(innerWidth) ?? 0.0;
    return math.max(childHeight, _fallbackMarkerHeight());
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final gutter = _computeGutterWidth();
    final innerWidth = width.isFinite ? math.max(0.0, width - gutter) : width;
    final childHeight = child?.getMaxIntrinsicHeight(innerWidth) ?? 0.0;
    return math.max(childHeight, _fallbackMarkerHeight());
  }

  double _fallbackMarkerHeight() {
    final fontSize = _markerTextStyle.fontSize ?? 15.0;
    final lineHeight = fontSize * (_markerTextStyle.height ?? 1.4);
    return lineHeight;
  }

  @override
  void performLayout() {
    _gutterWidth = _computeGutterWidth();
    final currentChild = child;
    if (currentChild == null) {
      _childBaseline = null;
      size = constraints.constrain(Size(_gutterWidth, _fallbackMarkerHeight()));
      return;
    }

    final maxChildWidth = constraints.maxWidth.isFinite
        ? math.max(0.0, constraints.maxWidth - _gutterWidth)
        : double.infinity;
    final minChildWidth = constraints.minWidth > _gutterWidth
        ? constraints.minWidth - _gutterWidth
        : 0.0;

    final childConstraints = BoxConstraints(
      minWidth: math.min(minChildWidth, maxChildWidth),
      maxWidth: maxChildWidth,
      minHeight: 0.0,
      maxHeight: constraints.maxHeight,
    );

    currentChild.layout(childConstraints, parentUsesSize: true);
    _childBaseline = currentChild.getDistanceToBaseline(
      TextBaseline.alphabetic,
      onlyReal: true,
    );

    final totalWidth = constraints.maxWidth.isFinite
        ? math.max(_gutterWidth + currentChild.size.width, constraints.minWidth)
        : _gutterWidth + currentChild.size.width;
    final totalHeight = math.max(
      currentChild.size.height,
      _fallbackMarkerHeight(),
    );

    size = constraints.constrain(Size(totalWidth, totalHeight));

    final childParentData = currentChild.parentData! as BoxParentData;
    childParentData.offset = _textDirection == TextDirection.ltr
        ? Offset(_gutterWidth, 0.0)
        : Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final currentChild = child;
    final baseline = _childBaseline ?? (_fallbackMarkerHeight() * 0.78);

    final gutterLeft = _textDirection == TextDirection.ltr
        ? offset.dx
        : offset.dx + size.width - _gutterWidth;

    switch (_markerKind) {
      case MarkdownListMarkerKind.bullet:
        _paintBullet(context.canvas, gutterLeft, offset.dy, baseline);
      case MarkdownListMarkerKind.ordered:
        _paintOrdinal(context.canvas, gutterLeft, offset.dy, baseline);
      case MarkdownListMarkerKind.taskUnchecked:
        _paintCheckbox(context.canvas, gutterLeft, offset.dy, baseline, false);
      case MarkdownListMarkerKind.taskChecked:
        _paintCheckbox(context.canvas, gutterLeft, offset.dy, baseline, true);
    }

    if (currentChild != null) {
      final childParentData = currentChild.parentData! as BoxParentData;
      context.paintChild(currentChild, offset + childParentData.offset);
    }
  }

  void _paintBullet(
    Canvas canvas,
    double gutterLeft,
    double top,
    double baseline,
  ) {
    final fontSize = _markerTextStyle.fontSize ?? 15.0;
    final centerY = top + baseline - (fontSize * 0.34);
    final centerX = gutterLeft + (_gutterWidth * 0.45);
    final radius = _bulletSize * 0.5;
    final depthMod = _nestingDepth % 3;

    if (depthMod == 0) {
      final paint = Paint()
        ..color = _markerColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    } else if (depthMod == 1) {
      final paint = Paint()
        ..color = _markerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    } else {
      final paint = Paint()
        ..color = _markerColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: _bulletSize * 0.85,
          height: _bulletSize * 0.85,
        ),
        paint,
      );
    }
  }

  void _paintOrdinal(
    Canvas canvas,
    double gutterLeft,
    double top,
    double baseline,
  ) {
    final painter = _ensureOrdinalPainter();
    final ordinalBaseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final dx = _textDirection == TextDirection.ltr
        ? gutterLeft + math.max(0.0, _gutterWidth - painter.width - _ordinalGap)
        : gutterLeft + _ordinalGap;
    final dy = top + baseline - ordinalBaseline;
    painter.paint(canvas, Offset(dx, dy));
  }

  void _paintCheckbox(
    Canvas canvas,
    double gutterLeft,
    double top,
    double baseline,
    bool checked,
  ) {
    final fontSize = _markerTextStyle.fontSize ?? 15.0;
    final boxSize = (fontSize * 0.92).clamp(12.0, 18.0);
    final centerY = top + baseline - (fontSize * 0.34);
    final centerX = gutterLeft + (_gutterWidth * 0.45);
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: boxSize,
      height: boxSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.0));

    if (checked) {
      final fillColor = _checkboxFillColor ?? _markerColor;
      final checkColor =
          _checkboxCheckColor ??
          (fillColor.computeLuminance() > 0.5
              ? const Color(0xFF000000)
              : const Color(0xFFFFFFFF));

      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, fillPaint);

      final checkPaint = Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(rect.left + boxSize * 0.22, rect.top + boxSize * 0.52)
        ..lineTo(rect.left + boxSize * 0.43, rect.top + boxSize * 0.72)
        ..lineTo(rect.left + boxSize * 0.78, rect.top + boxSize * 0.28);
      canvas.drawPath(path, checkPaint);
    } else {
      final strokePaint = Paint()
        ..color = _markerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawRRect(rrect, strokePaint);
    }
  }
}
