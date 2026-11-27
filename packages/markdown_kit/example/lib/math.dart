import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart' show SyntaxTree, TexParser;
import 'package:markdown_kit/markdown_kit.dart';

// Typesetting LaTeX with flutter_math_fork.
//
// markdown_kit parses `\(...\)` and `\[...\]` and, without a builder, shows
// them as Unicode text. These two builders typeset them instead. Both return
// `null` when a formula cannot be typeset, which keeps the Unicode rendering
// for that formula rather than showing an error.
//
// Pass them to a view:
//
//     MarkdownBuilders(
//       inlineLatexBuilder: buildInlineMath,
//       blockLatexBuilder: buildBlockMath,
//     )

/// [MarkdownBuilders.inlineLatexBuilder]: typesets `\(...\)` in the line.
InlineSpan? buildInlineMath(
  BuildContext context,
  InlineLatexInline latex,
  TextStyle style,
) {
  if (!_canTypeset(latex.expression)) return null;
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: _TypesetMath(
      expression: latex.expression,
      mathStyle: MathStyle.text,
      style: style,
    ),
  );
}

/// [MarkdownBuilders.blockLatexBuilder]: typesets `\[...\]` on its own line,
/// scrolling sideways when the formula is wider than the view.
Widget? buildBlockMath(
  BuildContext context,
  BlockLatexBlock latex,
  MarkdownThemeData theme,
) {
  // An unclosed block is still streaming. Typesetting it would flicker
  // between parse errors and partial formulas.
  if (!latex.closed) return null;
  if (!_canTypeset(latex.expression)) return null;
  final latexStyle = theme.latexStyle;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: latexStyle.blockBackgroundColor,
      border: latexStyle.blockBorderColor != null
          ? Border.all(color: latexStyle.blockBorderColor!)
          : null,
      borderRadius: latexStyle.blockBorderRadius,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: latexStyle.blockPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth:
                (constraints.maxWidth - latexStyle.blockPadding.horizontal)
                    .clamp(0.0, double.infinity),
          ),
          child: Center(
            child: _TypesetMath(
              expression: latex.expression,
              mathStyle: MathStyle.display,
              style: latexStyle.blockStyle,
            ),
          ),
        ),
      ),
    ),
  );
}

SyntaxTree? _parse(String expression) {
  try {
    return SyntaxTree(
      greenRoot: TexParser(
        expression.trim(),
        const TexParserSettings(),
      ).parse(),
    );
  } on Object {
    return null;
  }
}

/// Whether an expression parses. Builders run on every build, so the verdict
/// is remembered.
///
/// Only the verdict is shared, never the parsed tree: flutter_math_fork keeps
/// the `GlobalKey`s of the widgets built from a tree inside it, so two
/// formulas on screen that shared one would collide.
final Map<String, bool> _verdicts = <String, bool>{};

bool _canTypeset(String expression) {
  final source = expression.trim();
  if (source.isEmpty) return false;
  if (_verdicts.length > 500) _verdicts.clear();
  return _verdicts[source] ??= _parse(source) != null;
}

/// One typeset formula, holding its own parsed tree.
class _TypesetMath extends StatefulWidget {
  const _TypesetMath({
    required this.expression,
    required this.mathStyle,
    required this.style,
  });

  final String expression;
  final MathStyle mathStyle;
  final TextStyle style;

  @override
  State<_TypesetMath> createState() => _TypesetMathState();
}

class _TypesetMathState extends State<_TypesetMath> {
  late SyntaxTree? _tree = _parse(widget.expression);

  @override
  void didUpdateWidget(_TypesetMath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _tree = _parse(widget.expression);
    }
  }

  Widget _fallback() => Text(
    formatLatexFallback(widget.expression),
    style: widget.style,
    textScaler: TextScaler.noScaling,
  );

  @override
  Widget build(BuildContext context) {
    final tree = _tree;
    if (tree == null) return _fallback();
    final style = widget.style;
    return _MathDryBaseline(
      child: Math(
        ast: tree,
        mathStyle: widget.mathStyle,
        // Glyphs come from the KaTeX fonts flutter_math_fork bundles; only
        // size and color carry over from the surrounding text.
        textStyle: TextStyle(
          fontSize: style.fontSize ?? 14.0,
          color: style.color ?? DefaultTextStyle.of(context).style.color,
        ),
        onErrorFallback: (_) => _fallback(),
      ),
    );
  }
}

/// Answers dry baseline queries for a typeset formula.
///
/// flutter_math_fork 0.7.4 implements dry layout but not `computeDryBaseline`,
/// so a baseline-aligned formula asserts as soon as an ancestor measures
/// intrinsics, which every Markdown table does. The real baseline is only
/// known after layout, and a dry baseline has to give the same answer every
/// time it is asked, so this reports a fixed share of the dry height. Only
/// intrinsic measurement reads it; the laid-out formula sits on its real
/// baseline.
class _MathDryBaseline extends SingleChildRenderObjectWidget {
  const _MathDryBaseline({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMathDryBaseline();
}

class _RenderMathDryBaseline extends RenderProxyBox {
  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    return child.getDryLayout(constraints).height * 0.8;
  }
}
