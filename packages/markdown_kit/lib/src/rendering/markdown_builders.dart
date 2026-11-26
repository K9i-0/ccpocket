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
typedef MarkdownCodeHighlighter = List<InlineSpan> Function(
  BuildContext context,
  CodeBlock block,
  TextStyle baseStyle,
);

/// Wraps the selectable [codeContent] widget for a [CodeBlock] (e.g. to add a
/// non-selectable language header, copy button, or custom frame).
///
/// Treat [codeContent] as opaque: place it, do not inspect or rebuild it. To
/// change how the code itself is drawn, use [MarkdownBuilders.codeHighlighter].
typedef MarkdownCodeBlockBuilder = Widget Function(
  BuildContext context,
  CodeBlock block,
  Widget codeContent,
  MarkdownThemeData theme,
);

/// Customizes rendering of an inline code span (`` `code` ``).
///
/// May return a [CodeTextSpan], [TappableTextSpan], [TextSpan], or [WidgetSpan]
/// (including mixed spans such as a color swatch + text).
typedef MarkdownInlineCodeBuilder = InlineSpan Function(
  BuildContext context,
  String code,
  TextStyle style,
  MarkdownInlineCodeStyle codeStyle,
);

/// Customizes rendering of a [LinkInline] with pre-built [labelSpans].
typedef MarkdownInlineLinkBuilder = InlineSpan Function(
  BuildContext context,
  LinkInline link,
  List<InlineSpan> labelSpans,
  TextStyle style,
  VoidCallback? onTap,
);

/// Customizes rendering of an [ImageInline].
typedef MarkdownImageBuilder = Widget Function(
  BuildContext context,
  ImageInline image,
  MarkdownThemeData theme,
);

/// Customizes rendering of a GFM [TableBlock].
typedef MarkdownTableBuilder = Widget Function(
  BuildContext context,
  TableBlock table,
  MarkdownThemeData theme,
);

/// Customizes rendering of a GFM [AlertBlock] around its rendered [body].
typedef MarkdownAlertBuilder = Widget Function(
  BuildContext context,
  AlertBlock alert,
  Widget body,
  MarkdownThemeData theme,
);

/// Customizes rendering of an inline LaTeX expression.
typedef MarkdownInlineLatexBuilder = InlineSpan Function(
  BuildContext context,
  InlineLatexInline latex,
  TextStyle style,
);

/// Customizes rendering of a display-mode [BlockLatexBlock].
typedef MarkdownBlockLatexBuilder = Widget Function(
  BuildContext context,
  BlockLatexBlock latex,
  MarkdownThemeData theme,
);

/// Customizes rendering of a [CustomInline] produced by an inline scanner rule.
typedef MarkdownCustomInlineBuilder = InlineSpan Function(
  BuildContext context,
  CustomInline inline,
  TextStyle style,
);

/// Callback invoked when the user activates a Markdown hyperlink.
typedef MarkdownLinkTapCallback = void Function(String url, String title);

/// Immutable collection of pluggable builders and callbacks that customize how
/// `MarkdownView` and `SliverMarkdownView` render a document.
@immutable
class MarkdownBuilders {
  /// Creates a set of builders. Every builder left null keeps the built-in
  /// rendering.
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

  /// Supplies syntax-highlighted spans for code blocks. When null, code is
  /// shown in the theme's code text style.
  final MarkdownCodeHighlighter? codeHighlighter;

  /// Wraps a code block's selectable code in a custom frame, replacing the
  /// built-in container and language header.
  final MarkdownCodeBlockBuilder? codeBlockBuilder;

  /// Builds the span for an inline code span. When null, the code is drawn with
  /// the theme's inline code style.
  final MarkdownInlineCodeBuilder? inlineCodeBuilder;

  /// Builds the span for a link. When null, the link is drawn with the theme's
  /// link style and calls [onLinkTap] when tapped.
  final MarkdownInlineLinkBuilder? inlineLinkBuilder;

  /// Builds the widget for an image. When null, `http` and `https` images are
  /// loaded from the network and any other source is shown as a small label
  /// with the alt text, or the source when there is no alt text.
  final MarkdownImageBuilder? imageBuilder;

  /// Builds the widget for a table, replacing the built-in table and its
  /// selectable cells.
  final MarkdownTableBuilder? tableBuilder;

  /// Builds the frame around an alert's content, replacing the built-in title,
  /// icon and colors.
  final MarkdownAlertBuilder? alertBuilder;

  /// Builds the span for an inline LaTeX expression. When null, the expression
  /// is shown as text with common commands replaced by Unicode symbols.
  final MarkdownInlineLatexBuilder? inlineLatexBuilder;

  /// Builds the widget for a display-mode LaTeX block. When null, the
  /// expression is shown as text with common commands replaced by Unicode
  /// symbols.
  final MarkdownBlockLatexBuilder? blockLatexBuilder;

  /// Builds the span for a [CustomInline]. When null, its [CustomInline.text]
  /// is shown as plain text.
  final MarkdownCustomInlineBuilder? customInlineBuilder;

  /// Called with a link's destination and title (an empty string when it has
  /// none) when the user taps it. When null, links do nothing when tapped; this
  /// package never opens a link by itself.
  final MarkdownLinkTapCallback? onLinkTap;

  /// Returns a copy of this set with the given builders replaced.
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
