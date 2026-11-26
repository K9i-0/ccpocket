import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';
import 'markdown_theme.dart';

/// Produces the highlighted spans for a code block.
///
/// The spans' combined text must equal [CodeBlock.code] exactly, because
/// selection offsets are counted in that text; if it does not, the code is
/// shown unhighlighted. [baseStyle] is the theme's code text style. While a
/// reply is streaming, [CodeBlock.closed] is `false` for the block still being
/// written, which is the moment not to fill a cache keyed by source.
typedef MarkdownCodeHighlighter =
    List<InlineSpan> Function(
      BuildContext context,
      CodeBlock block,
      TextStyle baseStyle,
    );

/// Wraps the selectable [codeContent] widget for a [CodeBlock] (e.g. to add a
/// non-selectable language header, copy button, or custom frame).
///
/// Treat [codeContent] as opaque: place it, do not inspect or rebuild it. To
/// change how the code itself is drawn, use [MarkdownBuilders.codeHighlighter].
typedef MarkdownCodeBlockBuilder =
    Widget Function(
      BuildContext context,
      CodeBlock block,
      Widget codeContent,
      MarkdownThemeData theme,
    );

/// Customizes rendering of an inline code span (`` `code` ``).
///
/// May return a [CodeTextSpan], [TappableTextSpan], [TextSpan], or [WidgetSpan]
/// (including mixed spans such as a color swatch + text).
typedef MarkdownInlineCodeBuilder =
    InlineSpan Function(
      BuildContext context,
      String code,
      TextStyle style,
      MarkdownInlineCodeStyle codeStyle,
    );

/// Customizes rendering of a [LinkInline] with pre-built [labelSpans].
typedef MarkdownInlineLinkBuilder =
    InlineSpan Function(
      BuildContext context,
      LinkInline link,
      List<InlineSpan> labelSpans,
      TextStyle style,
      VoidCallback? onTap,
    );

/// Customizes rendering of an [ImageInline].
typedef MarkdownImageBuilder =
    Widget Function(
      BuildContext context,
      ImageInline image,
      MarkdownThemeData theme,
    );

/// Customizes rendering of a GFM [TableBlock].
typedef MarkdownTableBuilder =
    Widget Function(
      BuildContext context,
      TableBlock table,
      MarkdownThemeData theme,
    );

/// Customizes rendering of a GFM [AlertBlock] around its rendered [body].
typedef MarkdownAlertBuilder =
    Widget Function(
      BuildContext context,
      AlertBlock alert,
      Widget body,
      MarkdownThemeData theme,
    );

/// Customizes rendering of an inline LaTeX expression.
typedef MarkdownInlineLatexBuilder =
    InlineSpan Function(
      BuildContext context,
      InlineLatexInline latex,
      TextStyle style,
    );

/// Customizes rendering of a display-mode [BlockLatexBlock].
typedef MarkdownBlockLatexBuilder =
    Widget Function(
      BuildContext context,
      BlockLatexBlock latex,
      MarkdownThemeData theme,
    );

/// Customizes rendering of a [CustomInline] produced by an inline scanner rule.
typedef MarkdownCustomInlineBuilder =
    InlineSpan Function(
      BuildContext context,
      CustomInline inline,
      TextStyle style,
    );

/// Callback invoked when the user activates a Markdown hyperlink.
typedef MarkdownLinkTapCallback = void Function(String url, String title);

/// Immutable collection of pluggable builders and callbacks for
/// [MarkdownBlockRenderer].
@immutable
class MarkdownBuilders {
  const MarkdownBuilders({
    this.codeHighlighter,
    this.codeBlockBuilder,
    this.inlineCodeBuilder,
    this.inlineLinkBuilder,
    this.imageBuilder,
    this.tableBuilder,
    this.alertBuilder,
    this.inlineLatexBuilder,
    this.blockLatexBuilder,
    this.customInlineBuilder,
    this.onLinkTap,
  });

  final MarkdownCodeHighlighter? codeHighlighter;
  final MarkdownCodeBlockBuilder? codeBlockBuilder;
  final MarkdownInlineCodeBuilder? inlineCodeBuilder;
  final MarkdownInlineLinkBuilder? inlineLinkBuilder;
  final MarkdownImageBuilder? imageBuilder;
  final MarkdownTableBuilder? tableBuilder;
  final MarkdownAlertBuilder? alertBuilder;
  final MarkdownInlineLatexBuilder? inlineLatexBuilder;
  final MarkdownBlockLatexBuilder? blockLatexBuilder;
  final MarkdownCustomInlineBuilder? customInlineBuilder;
  final MarkdownLinkTapCallback? onLinkTap;

  MarkdownBuilders copyWith({
    MarkdownCodeHighlighter? codeHighlighter,
    MarkdownCodeBlockBuilder? codeBlockBuilder,
    MarkdownInlineCodeBuilder? inlineCodeBuilder,
    MarkdownInlineLinkBuilder? inlineLinkBuilder,
    MarkdownImageBuilder? imageBuilder,
    MarkdownTableBuilder? tableBuilder,
    MarkdownAlertBuilder? alertBuilder,
    MarkdownInlineLatexBuilder? inlineLatexBuilder,
    MarkdownBlockLatexBuilder? blockLatexBuilder,
    MarkdownCustomInlineBuilder? customInlineBuilder,
    MarkdownLinkTapCallback? onLinkTap,
  }) {
    return MarkdownBuilders(
      codeHighlighter: codeHighlighter ?? this.codeHighlighter,
      codeBlockBuilder: codeBlockBuilder ?? this.codeBlockBuilder,
      inlineCodeBuilder: inlineCodeBuilder ?? this.inlineCodeBuilder,
      inlineLinkBuilder: inlineLinkBuilder ?? this.inlineLinkBuilder,
      imageBuilder: imageBuilder ?? this.imageBuilder,
      tableBuilder: tableBuilder ?? this.tableBuilder,
      alertBuilder: alertBuilder ?? this.alertBuilder,
      inlineLatexBuilder: inlineLatexBuilder ?? this.inlineLatexBuilder,
      blockLatexBuilder: blockLatexBuilder ?? this.blockLatexBuilder,
      customInlineBuilder: customInlineBuilder ?? this.customInlineBuilder,
      onLinkTap: onLinkTap ?? this.onLinkTap,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownBuilders &&
        other.codeHighlighter == codeHighlighter &&
        other.codeBlockBuilder == codeBlockBuilder &&
        other.inlineCodeBuilder == inlineCodeBuilder &&
        other.inlineLinkBuilder == inlineLinkBuilder &&
        other.imageBuilder == imageBuilder &&
        other.tableBuilder == tableBuilder &&
        other.alertBuilder == alertBuilder &&
        other.inlineLatexBuilder == inlineLatexBuilder &&
        other.blockLatexBuilder == blockLatexBuilder &&
        other.customInlineBuilder == customInlineBuilder &&
        other.onLinkTap == onLinkTap;
  }

  @override
  int get hashCode => Object.hash(
    codeHighlighter,
    codeBlockBuilder,
    inlineCodeBuilder,
    inlineLinkBuilder,
    imageBuilder,
    tableBuilder,
    alertBuilder,
    inlineLatexBuilder,
    blockLatexBuilder,
    customInlineBuilder,
    onLinkTap,
  );
}
