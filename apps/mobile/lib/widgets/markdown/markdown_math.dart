import 'dart:collection';

import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/tex.dart' show SyntaxTree, TexParser;
import 'package:flutter/rendering.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:material_ui/material_ui.dart';

/// Typesets LaTeX math in chat Markdown with flutter_math_fork.
///
/// Experimental (#238). flutter_math_fork has had no code release since
/// 2025-05 and leaves fixes unmerged, so this stays only while the published
/// package keeps building. If a Flutter upgrade breaks it, do not fork it:
/// drop `inlineLatexBuilder` / `blockLatexBuilder` from `ccpocket_markdown.dart`,
/// delete this file and its test, and remove the dependency. markdown_kit then
/// shows its Unicode rendering again.
///
/// Both builders return `null` when the expression cannot be typeset (unknown
/// commands, a formula that is still streaming), which makes markdown_kit fall
/// back to its Unicode rendering instead of showing an error.

const int _maxCachedVerdicts = 500;

/// Whether an expression parses, most recently used last, so a formula the
/// typesetter rejects is not parsed again on every build.
///
/// Only the verdict is shared. A parsed tree keeps the `GlobalKey`s of the
/// widgets built from it, so two formulas on screen must never share one.
final LinkedHashMap<String, bool> _parseVerdicts =
    LinkedHashMap<String, bool>();

SyntaxTree? _parseMath(String expression) {
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

bool _canTypeset(String expression) {
  final source = expression.trim();
  if (source.isEmpty) return false;
  final cached = _parseVerdicts.remove(source);
  final verdict = cached ?? _parseMath(source) != null;
  _parseVerdicts[source] = verdict;
  if (_parseVerdicts.length > _maxCachedVerdicts) {
    _parseVerdicts.remove(_parseVerdicts.keys.first);
  }
  return verdict;
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
  late SyntaxTree? _tree = _parseMath(widget.expression);

  @override
  void didUpdateWidget(_TypesetMath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression) {
      _tree = _parseMath(widget.expression);
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
    // Math glyphs come from the bundled KaTeX fonts; only size and color carry
    // over from the surrounding text.
    final style = widget.style;
    return _MathDryBaseline(
      child: Math(
        ast: tree,
        mathStyle: widget.mathStyle,
        textStyle: TextStyle(
          fontSize: style.fontSize ?? 14.0,
          color: style.color ?? DefaultTextStyle.of(context).style.color,
        ),
        onErrorFallback: (_) => _fallback(),
      ),
    );
  }
}

/// [MarkdownBuilders.inlineLatexBuilder] for `\(...\)`.
InlineSpan? buildCcpocketInlineLatex(
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

/// [MarkdownBuilders.blockLatexBuilder] for `\[...\]`.
Widget? buildCcpocketBlockLatex(
  BuildContext context,
  BlockLatexBlock latex,
  MarkdownThemeData theme,
) {
  // An unclosed block is still streaming; typesetting it would flicker between
  // parse errors and partial formulas.
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

/// Answers dry baseline queries for a typeset formula.
///
/// flutter_math_fork's render objects implement dry layout but not
/// `computeDryBaseline`, so a baseline-aligned formula asserts as soon as an
/// ancestor measures intrinsics (every Markdown table does). The real baseline
/// is only known after layout, and a dry baseline has to give the same answer
/// every time it is asked, so this reports a fixed share of the dry height.
/// Only intrinsic measurement reads it; the laid-out formula sits on its real
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
