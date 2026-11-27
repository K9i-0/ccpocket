import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';

/// Fixed-width families tried after `monospace` in the default code styles.
///
/// `monospace` is a generic name that Android and Linux resolve, but iOS,
/// macOS and Windows do not; without these, code there falls back to the
/// proportional system font.
const List<String> kMarkdownMonospaceFallback = <String>[
  'Menlo',
  'Consolas',
  'Courier New',
];

/// Styling for inline code spans (`CodeTextSpan`) and `<kbd>` keycaps.
@immutable
class MarkdownInlineCodeStyle {
  /// Creates an inline code style.
  const MarkdownInlineCodeStyle({
    this.fontFamily = 'monospace',
    this.fontFamilyFallback = kMarkdownMonospaceFallback,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.backgroundColor = const Color(0x14000000),
    this.borderColor,
    this.borderWidth = 0.0,
    this.borderRadius = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
  });

  /// Font family of the code text. When null, the surrounding text's family is
  /// kept.
  final String? fontFamily;

  /// Fallback font families tried when [fontFamily] lacks a glyph. When null,
  /// the surrounding text's fallbacks are kept.
  final List<String>? fontFamilyFallback;

  /// Font size of the code text in logical pixels. When null, 90% of the
  /// surrounding text's size is used.
  final double? fontSize;

  /// Font weight of the code text. When null, the surrounding text's weight is
  /// kept.
  final FontWeight? fontWeight;

  /// Color of the code text. When null, the surrounding text's color is kept.
  final Color? color;

  /// Fill color of the rounded background drawn behind the text. A fully
  /// transparent color draws no background.
  final Color backgroundColor;

  /// Color of the outline drawn around the background. When null, no outline is
  /// drawn.
  final Color? borderColor;

  /// Stroke width of the outline in logical pixels. No outline is drawn at `0`
  /// or when [borderColor] is null.
  final double borderWidth;

  /// Corner radius of the background and outline, in logical pixels.
  final double borderRadius;

  /// How far the background extends beyond the text's glyphs on each side.
  ///
  /// This only enlarges what is painted; it does not add space between the code
  /// and the text around it.
  final EdgeInsets padding;

  /// Resolves a [TextStyle] for inline code text merged onto [base].
  TextStyle resolveTextStyle(TextStyle base) {
    return base.copyWith(
      fontFamily: fontFamily ?? base.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? base.fontFamilyFallback,
      fontSize:
          fontSize ?? (base.fontSize != null ? base.fontSize! * 0.9 : null),
      fontWeight: fontWeight ?? base.fontWeight,
      color: color ?? base.color,
    );
  }

  /// Returns a copy of this style with the given fields replaced.
  MarkdownInlineCodeStyle copyWith({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    double? borderRadius,
    EdgeInsets? padding,
  }) {
    return MarkdownInlineCodeStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownInlineCodeStyle &&
        other.fontFamily == fontFamily &&
        listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
        other.fontSize == fontSize &&
        other.fontWeight == fontWeight &&
        other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding;
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontFamilyFallback == null ? null : Object.hashAll(fontFamilyFallback!),
    fontSize,
    fontWeight,
    color,
    backgroundColor,
    borderColor,
    borderWidth,
    borderRadius,
    padding,
  );
}

/// Styling for fenced and indented [CodeBlock] containers.
@immutable
class MarkdownCodeBlockStyle {
  /// Creates a code block style.
  const MarkdownCodeBlockStyle({
    this.backgroundColor = const Color(0xFFF6F8FA),
    this.borderColor = const Color(0xFFD0D7DE),
    this.borderWidth = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.padding = const EdgeInsets.all(12.0),
    this.textStyle = const TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: kMarkdownMonospaceFallback,
      fontSize: 13.0,
      height: 1.45,
      color: Color(0xFF1F2328),
    ),
    this.headerStyle = const TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFF57606A),
    ),
    this.headerBackgroundColor,
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 6.0,
    ),
  });

  /// Fill color of the code block container.
  final Color backgroundColor;

  /// Color of the container's outline and of the line under the language
  /// header.
  final Color borderColor;

  /// Width of the outline and of the line under the language header, in logical
  /// pixels. `0` draws neither.
  final double borderWidth;

  /// Corner radius of the container.
  final BorderRadius borderRadius;

  /// Space between the container's edges and the code.
  final EdgeInsets padding;

  /// Text style of the code. A syntax highlighter's spans are applied on top of
  /// it.
  final TextStyle textStyle;

  /// Text style of the language label shown above the code.
  final TextStyle headerStyle;

  /// Fill color of the language header. When null, the header shares the
  /// container's [backgroundColor].
  final Color? headerBackgroundColor;

  /// Space around the language label inside the header.
  final EdgeInsets headerPadding;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownCodeBlockStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    TextStyle? textStyle,
    TextStyle? headerStyle,
    Color? headerBackgroundColor,
    EdgeInsets? headerPadding,
  }) {
    return MarkdownCodeBlockStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      textStyle: textStyle ?? this.textStyle,
      headerStyle: headerStyle ?? this.headerStyle,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      headerPadding: headerPadding ?? this.headerPadding,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownCodeBlockStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.textStyle == textStyle &&
        other.headerStyle == headerStyle &&
        other.headerBackgroundColor == headerBackgroundColor &&
        other.headerPadding == headerPadding;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    borderWidth,
    borderRadius,
    padding,
    textStyle,
    headerStyle,
    headerBackgroundColor,
    headerPadding,
  );
}

/// Styling for standard [BlockquoteBlock] elements.
@immutable
class MarkdownBlockquoteStyle {
  /// Creates a blockquote style.
  const MarkdownBlockquoteStyle({
    this.barColor = const Color(0xFFD0D7DE),
    this.barWidth = 3.5,
    this.padding = const EdgeInsets.fromLTRB(12.0, 4.0, 8.0, 4.0),
    this.textStyle = const TextStyle(color: Color(0xFF57606A)),
    this.backgroundColor,
    this.borderRadius = BorderRadius.zero,
  });

  /// Color of the vertical bar on the start side of the quote.
  final Color barColor;

  /// Width of the vertical bar in logical pixels.
  final double barWidth;

  /// Space between the bar and container edges and the quoted content.
  ///
  /// The left and right values are swapped in right-to-left text, so the left
  /// value always sits beside the bar.
  final EdgeInsets padding;

  /// Text style merged over the surrounding text style for quoted content. When
  /// null, quoted text looks like the text around it.
  final TextStyle? textStyle;

  /// Fill color behind the quote. When null, no background is drawn.
  final Color? backgroundColor;

  /// Corner radius the quote, including its bar, is clipped to.
  final BorderRadius borderRadius;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownBlockquoteStyle copyWith({
    Color? barColor,
    double? barWidth,
    EdgeInsets? padding,
    TextStyle? textStyle,
    Color? backgroundColor,
    BorderRadius? borderRadius,
  }) {
    return MarkdownBlockquoteStyle(
      barColor: barColor ?? this.barColor,
      barWidth: barWidth ?? this.barWidth,
      padding: padding ?? this.padding,
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownBlockquoteStyle &&
        other.barColor == barColor &&
        other.barWidth == barWidth &&
        other.padding == padding &&
        other.textStyle == textStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(
    barColor,
    barWidth,
    padding,
    textStyle,
    backgroundColor,
    borderRadius,
  );
}

/// Styling for a single [AlertKind] variant of [AlertBlock].
@immutable
class MarkdownAlertStyle {
  /// Creates an alert style.
  const MarkdownAlertStyle({
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleStyle,
    this.borderWidth = 1.0,
    this.barWidth = 3.5,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.padding = const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 10.0),
    this.textStyle,
  });

  /// Color of the bar on the start side and of the icon beside the title.
  final Color accentColor;

  /// Fill color behind the alert.
  final Color backgroundColor;

  /// Color of the outline around the alert.
  final Color borderColor;

  /// Width of the outline in logical pixels. `0` draws no outline.
  final double borderWidth;

  /// Width of the accent bar on the start side, in logical pixels.
  final double barWidth;

  /// Corner radius of the alert.
  final BorderRadius borderRadius;

  /// Space between the alert's edges and its title and content.
  final EdgeInsets padding;

  /// Text style of the title line (`NOTE`, `TIP`, and so on).
  final TextStyle titleStyle;

  /// Text style merged over the surrounding text style for the alert's content.
  /// When null, the content looks like the text around it.
  final TextStyle? textStyle;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownAlertStyle copyWith({
    Color? accentColor,
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    double? barWidth,
    BorderRadius? borderRadius,
    EdgeInsets? padding,
    TextStyle? titleStyle,
    TextStyle? textStyle,
  }) {
    return MarkdownAlertStyle(
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      barWidth: barWidth ?? this.barWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      titleStyle: titleStyle ?? this.titleStyle,
      textStyle: textStyle ?? this.textStyle,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownAlertStyle &&
        other.accentColor == accentColor &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.barWidth == barWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.titleStyle == titleStyle &&
        other.textStyle == textStyle;
  }

  @override
  int get hashCode => Object.hash(
    accentColor,
    backgroundColor,
    borderColor,
    borderWidth,
    barWidth,
    borderRadius,
    padding,
    titleStyle,
    textStyle,
  );
}

/// Styling for GFM [TableBlock] elements.
@immutable
class MarkdownTableStyle {
  /// Creates a table style.
  const MarkdownTableStyle({
    this.borderColor = const Color(0xFFD0D7DE),
    this.borderWidth = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(6.0)),
    this.headerBackground = const Color(0xFFF6F8FA),
    this.headerTextStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14.0,
      height: 1.4,
      color: Color(0xFF1F2328),
    ),
    this.rowStripeColor = const Color(0x08000000),
    this.cellPadding = const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 8.0,
    ),
    this.minColumnWidth = 64.0,
    this.maxColumnWidth = 280.0,
  });

  /// Color of the table's outer border and grid lines.
  final Color borderColor;

  /// Width of the outer border and grid lines in logical pixels. `0` draws
  /// neither.
  final double borderWidth;

  /// Corner radius of the table's outer border.
  final BorderRadius borderRadius;

  /// Fill color of the header row.
  final Color headerBackground;

  /// Text style merged over the body text style for header cells.
  final TextStyle headerTextStyle;

  /// Fill color of every second body row (the second, fourth, and so on). When
  /// null, rows are not striped.
  final Color? rowStripeColor;

  /// Space between a cell's edges and its content.
  final EdgeInsets cellPadding;

  /// Narrowest a column can be, in logical pixels, including the horizontal
  /// [cellPadding].
  final double minColumnWidth;

  /// Widest a column can be, in logical pixels, including the horizontal
  /// [cellPadding]. Longer cell text wraps. A value below [minColumnWidth] is
  /// treated as [minColumnWidth].
  final double maxColumnWidth;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownTableStyle copyWith({
    Color? borderColor,
    double? borderWidth,
    BorderRadius? borderRadius,
    Color? headerBackground,
    TextStyle? headerTextStyle,
    Color? rowStripeColor,
    EdgeInsets? cellPadding,
    double? minColumnWidth,
    double? maxColumnWidth,
  }) {
    return MarkdownTableStyle(
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      headerBackground: headerBackground ?? this.headerBackground,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      rowStripeColor: rowStripeColor ?? this.rowStripeColor,
      cellPadding: cellPadding ?? this.cellPadding,
      minColumnWidth: minColumnWidth ?? this.minColumnWidth,
      maxColumnWidth: maxColumnWidth ?? this.maxColumnWidth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownTableStyle &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.headerBackground == headerBackground &&
        other.headerTextStyle == headerTextStyle &&
        other.rowStripeColor == rowStripeColor &&
        other.cellPadding == cellPadding &&
        other.minColumnWidth == minColumnWidth &&
        other.maxColumnWidth == maxColumnWidth;
  }

  @override
  int get hashCode => Object.hash(
    borderColor,
    borderWidth,
    borderRadius,
    headerBackground,
    headerTextStyle,
    rowStripeColor,
    cellPadding,
    minColumnWidth,
    maxColumnWidth,
  );
}

/// Styling for collapsible [HtmlDetailsBlock] elements.
@immutable
class MarkdownDetailsStyle {
  /// Creates a details style.
  const MarkdownDetailsStyle({
    this.backgroundColor,
    this.borderColor = const Color(0xFFD0D7DE),
    this.borderWidth = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 12.0,
      vertical: 10.0,
    ),
    this.bodyPadding = const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 12.0),
    this.summaryStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14.0,
      height: 1.4,
      color: Color(0xFF1F2328),
    ),
    this.iconColor = const Color(0xFF57606A),
    this.iconSize = 14.0,
  });

  /// Fill color behind the whole block. When null, no background is drawn.
  final Color? backgroundColor;

  /// Color of the outline and of the line between the summary and the expanded
  /// content.
  final Color borderColor;

  /// Width of the outline and of the line under the summary, in logical pixels.
  /// `0` draws neither.
  final double borderWidth;

  /// Corner radius of the block.
  final BorderRadius borderRadius;

  /// Space around the summary row, which is the area that toggles the block
  /// when tapped.
  final EdgeInsets headerPadding;

  /// Space around the content shown while the block is open.
  final EdgeInsets bodyPadding;

  /// Text style of the summary.
  final TextStyle summaryStyle;

  /// Color of the disclosure triangle beside the summary.
  final Color iconColor;

  /// Width and height of the disclosure triangle in logical pixels.
  final double iconSize;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownDetailsStyle copyWith({
    Color? backgroundColor,
    Color? borderColor,
    double? borderWidth,
    BorderRadius? borderRadius,
    EdgeInsets? headerPadding,
    EdgeInsets? bodyPadding,
    TextStyle? summaryStyle,
    Color? iconColor,
    double? iconSize,
  }) {
    return MarkdownDetailsStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      headerPadding: headerPadding ?? this.headerPadding,
      bodyPadding: bodyPadding ?? this.bodyPadding,
      summaryStyle: summaryStyle ?? this.summaryStyle,
      iconColor: iconColor ?? this.iconColor,
      iconSize: iconSize ?? this.iconSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownDetailsStyle &&
        other.backgroundColor == backgroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.headerPadding == headerPadding &&
        other.bodyPadding == bodyPadding &&
        other.summaryStyle == summaryStyle &&
        other.iconColor == iconColor &&
        other.iconSize == iconSize;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    borderColor,
    borderWidth,
    borderRadius,
    headerPadding,
    bodyPadding,
    summaryStyle,
    iconColor,
    iconSize,
  );
}

/// Styling for default LaTeX fallback rendering ([InlineLatexInline] and
/// [BlockLatexBlock]).
@immutable
class MarkdownLatexStyle {
  /// Creates a LaTeX fallback style.
  const MarkdownLatexStyle({
    this.inlineStyle = const TextStyle(
      fontFamily: 'serif',
      fontStyle: FontStyle.italic,
      fontSize: 15.0,
    ),
    this.blockStyle = const TextStyle(
      fontFamily: 'serif',
      fontStyle: FontStyle.italic,
      fontSize: 16.0,
      height: 1.5,
      color: Color(0xFF1F2328),
    ),
    this.blockBackgroundColor = const Color(0xFFF6F8FA),
    this.blockBorderColor = const Color(0xFFE1E4E8),
    this.blockBorderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.blockPadding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 12.0,
    ),
  });

  /// Text style merged over the surrounding text style for inline expressions.
  final TextStyle inlineStyle;

  /// Text style of a display (block) expression.
  final TextStyle blockStyle;

  /// Fill color behind a display expression. When null, no background is drawn.
  final Color? blockBackgroundColor;

  /// Color of the one-pixel outline around a display expression. When null, no
  /// outline is drawn.
  final Color? blockBorderColor;

  /// Corner radius of a display expression's background and outline.
  final BorderRadius blockBorderRadius;

  /// Space between a display expression and the edges of its container.
  final EdgeInsets blockPadding;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownLatexStyle copyWith({
    TextStyle? inlineStyle,
    TextStyle? blockStyle,
    Color? blockBackgroundColor,
    Color? blockBorderColor,
    BorderRadius? blockBorderRadius,
    EdgeInsets? blockPadding,
  }) {
    return MarkdownLatexStyle(
      inlineStyle: inlineStyle ?? this.inlineStyle,
      blockStyle: blockStyle ?? this.blockStyle,
      blockBackgroundColor: blockBackgroundColor ?? this.blockBackgroundColor,
      blockBorderColor: blockBorderColor ?? this.blockBorderColor,
      blockBorderRadius: blockBorderRadius ?? this.blockBorderRadius,
      blockPadding: blockPadding ?? this.blockPadding,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownLatexStyle &&
        other.inlineStyle == inlineStyle &&
        other.blockStyle == blockStyle &&
        other.blockBackgroundColor == blockBackgroundColor &&
        other.blockBorderColor == blockBorderColor &&
        other.blockBorderRadius == blockBorderRadius &&
        other.blockPadding == blockPadding;
  }

  @override
  int get hashCode => Object.hash(
    inlineStyle,
    blockStyle,
    blockBackgroundColor,
    blockBorderColor,
    blockBorderRadius,
    blockPadding,
  );
}

/// Styling for [FootnoteRefInline] references and [FootnoteDefinitionsBlock].
@immutable
class MarkdownFootnoteStyle {
  /// Creates a footnote style.
  const MarkdownFootnoteStyle({
    this.refStyle = const TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0969DA),
    ),
    this.labelStyle = const TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w600,
      color: Color(0xFF57606A),
    ),
    this.textStyle = const TextStyle(
      fontSize: 13.0,
      height: 1.45,
      color: Color(0xFF57606A),
    ),
    this.dividerColor = const Color(0xFFD0D7DE),
    this.dividerThickness = 1.0,
    this.itemSpacing = 6.0,
  });

  /// Text style merged over the surrounding text style for a footnote reference
  /// in running text.
  final TextStyle refStyle;

  /// Text style of the label shown before each footnote definition.
  final TextStyle labelStyle;

  /// Base text style of footnote definition content.
  final TextStyle textStyle;

  /// Color of the rule drawn above the footnote definitions.
  final Color dividerColor;

  /// Thickness of the rule above the footnote definitions, in logical pixels.
  /// `0` removes the rule.
  final double dividerThickness;

  /// Vertical gap between consecutive footnote definitions, in logical pixels.
  final double itemSpacing;

  /// Returns a copy of this style with the given fields replaced.
  MarkdownFootnoteStyle copyWith({
    TextStyle? refStyle,
    TextStyle? labelStyle,
    TextStyle? textStyle,
    Color? dividerColor,
    double? dividerThickness,
    double? itemSpacing,
  }) {
    return MarkdownFootnoteStyle(
      refStyle: refStyle ?? this.refStyle,
      labelStyle: labelStyle ?? this.labelStyle,
      textStyle: textStyle ?? this.textStyle,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      itemSpacing: itemSpacing ?? this.itemSpacing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownFootnoteStyle &&
        other.refStyle == refStyle &&
        other.labelStyle == labelStyle &&
        other.textStyle == textStyle &&
        other.dividerColor == dividerColor &&
        other.dividerThickness == dividerThickness &&
        other.itemSpacing == itemSpacing;
  }

  @override
  int get hashCode => Object.hash(
    refStyle,
    labelStyle,
    textStyle,
    dividerColor,
    dividerThickness,
    itemSpacing,
  );
}

/// Immutable theme data governing all Markdown block and inline rendering.
///
/// Built solely on `package:flutter/widgets.dart` with full value equality so
/// host apps can cache derived themes without triggering redundant rebuilds.
@immutable
class MarkdownThemeData {
  /// Creates a theme. The defaults make up the built-in light theme.
  const MarkdownThemeData({
    this.bodyStyle = _defaultBodyStyle,
    this.h1Style = _defaultH1Style,
    this.h2Style = _defaultH2Style,
    this.h3Style = _defaultH3Style,
    this.h4Style = _defaultH4Style,
    this.h5Style = _defaultH5Style,
    this.h6Style = _defaultH6Style,
    this.strongStyle = const TextStyle(fontWeight: FontWeight.w700),
    this.emphasisStyle = const TextStyle(fontStyle: FontStyle.italic),
    this.strikethroughStyle = const TextStyle(
      decoration: TextDecoration.lineThrough,
    ),
    this.underlineStyle = const TextStyle(decoration: TextDecoration.underline),
    this.linkStyle = const TextStyle(color: Color(0xFF0969DA)),
    this.linkHoverStyle = const TextStyle(
      color: Color(0xFF0969DA),
      decoration: TextDecoration.underline,
    ),
    this.inlineCodeStyle = const MarkdownInlineCodeStyle(),
    this.keyboardStyle = const MarkdownInlineCodeStyle(
      backgroundColor: Color(0xFFF6F8FA),
      borderColor: Color(0xFFD0D7DE),
      borderWidth: 1.0,
      borderRadius: 4.0,
      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
    ),
    this.codeBlockStyle = const MarkdownCodeBlockStyle(),
    this.blockquoteStyle = const MarkdownBlockquoteStyle(),
    this.alertStyles = _defaultLightAlertStyles,
    this.listBulletColor = const Color(0xFF57606A),
    this.listBulletSize = 5.5,
    this.listIndent = 22.0,
    this.listItemSpacing = 4.0,
    this.listCheckboxFillColor,
    this.listCheckboxCheckColor,
    this.tableStyle = const MarkdownTableStyle(),
    this.dividerColor = const Color(0xFFD0D7DE),
    this.dividerThickness = 1.0,
    this.detailsStyle = const MarkdownDetailsStyle(),
    this.latexStyle = const MarkdownLatexStyle(),
    this.footnoteStyle = const MarkdownFootnoteStyle(),
    this.selectionColor = const Color(0x4D0969DA),
    this.blockSpacing = 12.0,
  });

  /// Default light palette.
  factory MarkdownThemeData.fallback() => const MarkdownThemeData();

  /// Built-in dark palette using pure `widgets.dart` color tokens.
  factory MarkdownThemeData.dark() => const MarkdownThemeData(
    bodyStyle: TextStyle(fontSize: 15.0, height: 1.5, color: Color(0xFFE6EDF3)),
    h1Style: TextStyle(
      fontSize: 26.0,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: Color(0xFFE6EDF3),
    ),
    h2Style: TextStyle(
      fontSize: 22.0,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: Color(0xFFE6EDF3),
    ),
    h3Style: TextStyle(
      fontSize: 18.0,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: Color(0xFFE6EDF3),
    ),
    h4Style: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: Color(0xFFE6EDF3),
    ),
    h5Style: TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: Color(0xFFC9D1D9),
    ),
    h6Style: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: Color(0xFF8B949E),
    ),
    linkStyle: TextStyle(color: Color(0xFF58A6FF)),
    linkHoverStyle: TextStyle(
      color: Color(0xFF79C0FF),
      decoration: TextDecoration.underline,
    ),
    inlineCodeStyle: MarkdownInlineCodeStyle(
      color: Color(0xFFE6EDF3),
      backgroundColor: Color(0x26FFFFFF),
    ),
    keyboardStyle: MarkdownInlineCodeStyle(
      color: Color(0xFFE6EDF3),
      backgroundColor: Color(0xFF21262D),
      borderColor: Color(0xFF30363D),
      borderWidth: 1.0,
      borderRadius: 4.0,
      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
    ),
    codeBlockStyle: MarkdownCodeBlockStyle(
      backgroundColor: Color(0xFF161B22),
      borderColor: Color(0xFF30363D),
      textStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: kMarkdownMonospaceFallback,
        fontSize: 13.0,
        height: 1.45,
        color: Color(0xFFE6EDF3),
      ),
      headerStyle: TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B949E),
      ),
    ),
    blockquoteStyle: MarkdownBlockquoteStyle(
      barColor: Color(0xFF3B434B),
      textStyle: TextStyle(color: Color(0xFF8B949E)),
    ),
    alertStyles: _defaultDarkAlertStyles,
    listBulletColor: Color(0xFF8B949E),
    tableStyle: MarkdownTableStyle(
      borderColor: Color(0xFF30363D),
      headerBackground: Color(0xFF161B22),
      headerTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        height: 1.4,
        color: Color(0xFFE6EDF3),
      ),
      rowStripeColor: Color(0x0FFFFFFF),
    ),
    dividerColor: Color(0xFF30363D),
    detailsStyle: MarkdownDetailsStyle(
      borderColor: Color(0xFF30363D),
      summaryStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        height: 1.4,
        color: Color(0xFFE6EDF3),
      ),
      iconColor: Color(0xFF8B949E),
    ),
    latexStyle: MarkdownLatexStyle(
      blockStyle: TextStyle(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontSize: 16.0,
        height: 1.5,
        color: Color(0xFFE6EDF3),
      ),
      blockBackgroundColor: Color(0xFF161B22),
      blockBorderColor: Color(0xFF30363D),
    ),
    footnoteStyle: MarkdownFootnoteStyle(
      refStyle: TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        color: Color(0xFF58A6FF),
      ),
      labelStyle: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8B949E),
      ),
      textStyle: TextStyle(
        fontSize: 13.0,
        height: 1.45,
        color: Color(0xFF8B949E),
      ),
      dividerColor: Color(0xFF30363D),
    ),
    selectionColor: Color(0x5958A6FF),
  );

  static const _defaultBodyStyle = TextStyle(
    fontSize: 15.0,
    height: 1.5,
    color: Color(0xFF1F2328),
  );

  static const _defaultH1Style = TextStyle(
    fontSize: 26.0,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: Color(0xFF1F2328),
  );

  static const _defaultH2Style = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: Color(0xFF1F2328),
  );

  static const _defaultH3Style = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: Color(0xFF1F2328),
  );

  static const _defaultH4Style = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Color(0xFF1F2328),
  );

  static const _defaultH5Style = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Color(0xFF32383F),
  );

  static const _defaultH6Style = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Color(0xFF57606A),
  );

  static const Map<AlertKind, MarkdownAlertStyle> _defaultLightAlertStyles = {
    AlertKind.note: MarkdownAlertStyle(
      accentColor: Color(0xFF0969DA),
      backgroundColor: Color(0x120969DA),
      borderColor: Color(0x400969DA),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0969DA),
      ),
    ),
    AlertKind.tip: MarkdownAlertStyle(
      accentColor: Color(0xFF1A7F37),
      backgroundColor: Color(0x121A7F37),
      borderColor: Color(0x401A7F37),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A7F37),
      ),
    ),
    AlertKind.important: MarkdownAlertStyle(
      accentColor: Color(0xFF8250DF),
      backgroundColor: Color(0x128250DF),
      borderColor: Color(0x408250DF),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFF8250DF),
      ),
    ),
    AlertKind.warning: MarkdownAlertStyle(
      accentColor: Color(0xFF9A6700),
      backgroundColor: Color(0x149A6700),
      borderColor: Color(0x409A6700),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9A6700),
      ),
    ),
    AlertKind.caution: MarkdownAlertStyle(
      accentColor: Color(0xFFCF222E),
      backgroundColor: Color(0x12CF222E),
      borderColor: Color(0x40CF222E),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFFCF222E),
      ),
    ),
  };

  static const Map<AlertKind, MarkdownAlertStyle> _defaultDarkAlertStyles = {
    AlertKind.note: MarkdownAlertStyle(
      accentColor: Color(0xFF58A6FF),
      backgroundColor: Color(0x1A58A6FF),
      borderColor: Color(0x4D58A6FF),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFF58A6FF),
      ),
    ),
    AlertKind.tip: MarkdownAlertStyle(
      accentColor: Color(0xFF3FB950),
      backgroundColor: Color(0x1A3FB950),
      borderColor: Color(0x4D3FB950),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3FB950),
      ),
    ),
    AlertKind.important: MarkdownAlertStyle(
      accentColor: Color(0xFFA371F7),
      backgroundColor: Color(0x1AA371F7),
      borderColor: Color(0x4DA371F7),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFFA371F7),
      ),
    ),
    AlertKind.warning: MarkdownAlertStyle(
      accentColor: Color(0xFFD29922),
      backgroundColor: Color(0x1AD29922),
      borderColor: Color(0x4DD29922),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFFD29922),
      ),
    ),
    AlertKind.caution: MarkdownAlertStyle(
      accentColor: Color(0xFFF85149),
      backgroundColor: Color(0x1AF85149),
      borderColor: Color(0x4DF85149),
      titleStyle: TextStyle(
        fontSize: 13.0,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF85149),
      ),
    ),
  };

  /// Base text style of paragraphs, list items and table cells.
  final TextStyle bodyStyle;

  /// Text style of level 1 headings.
  final TextStyle h1Style;

  /// Text style of level 2 headings.
  final TextStyle h2Style;

  /// Text style of level 3 headings.
  final TextStyle h3Style;

  /// Text style of level 4 headings.
  final TextStyle h4Style;

  /// Text style of level 5 headings.
  final TextStyle h5Style;

  /// Text style of level 6 headings.
  final TextStyle h6Style;

  /// Text style merged over the surrounding text style for strong emphasis
  /// (`**text**`).
  final TextStyle strongStyle;

  /// Text style merged over the surrounding text style for emphasis (`*text*`).
  final TextStyle emphasisStyle;

  /// Text style merged over the surrounding text style for strikethrough
  /// (`~~text~~`).
  final TextStyle strikethroughStyle;

  /// Text style merged over the surrounding text style for underlined text
  /// (`<u>`).
  final TextStyle underlineStyle;

  /// Text style merged over the surrounding text style for links.
  final TextStyle linkStyle;

  /// Text style merged over a link's style while a mouse pointer hovers over
  /// it.
  final TextStyle linkHoverStyle;

  /// Style of inline code spans.
  final MarkdownInlineCodeStyle inlineCodeStyle;

  /// Style of `<kbd>` keycaps.
  final MarkdownInlineCodeStyle keyboardStyle;

  /// Style of fenced and indented code blocks.
  final MarkdownCodeBlockStyle codeBlockStyle;

  /// Style of blockquotes.
  final MarkdownBlockquoteStyle blockquoteStyle;

  /// Style of each kind of alert. Kinds missing from the map use the built-in
  /// light style; see [alertStyleFor].
  final Map<AlertKind, MarkdownAlertStyle> alertStyles;

  /// Color of bullets, ordered-list numbers and the outline of unchecked task
  /// checkboxes.
  final Color listBulletColor;

  /// Diameter of a bullet in logical pixels. It grows with the text scale.
  final double listBulletSize;

  /// Minimum width, in logical pixels, of the gutter that holds a list item's
  /// marker. The gutter widens when a marker needs more room, for example for a
  /// long ordinal.
  final double listIndent;

  /// Vertical gap, in logical pixels, between the items of a tight list and
  /// between the blocks inside one item. Loose lists use twice this gap between
  /// items.
  final double listItemSpacing;

  /// Fill color of a checked task checkbox. When null, [listBulletColor] is
  /// used.
  final Color? listCheckboxFillColor;

  /// Color of the check mark in a checked task checkbox. When null, black or
  /// white is chosen for contrast against the fill.
  final Color? listCheckboxCheckColor;

  /// Style of tables.
  final MarkdownTableStyle tableStyle;

  /// Color of thematic breaks (`---`).
  final Color dividerColor;

  /// Thickness of thematic breaks in logical pixels.
  final double dividerThickness;

  /// Style of collapsible `<details>` blocks.
  final MarkdownDetailsStyle detailsStyle;

  /// Style of LaTeX expressions when no LaTeX builder is supplied.
  final MarkdownLatexStyle latexStyle;

  /// Style of footnote references and definitions.
  final MarkdownFootnoteStyle footnoteStyle;

  /// Color of the selection highlight. A selection color set on the view or on
  /// its selection controller takes precedence.
  final Color selectionColor;

  /// Vertical gap between top-level blocks, in logical pixels. Blocks nested in
  /// a blockquote, alert or details block are spaced at three quarters of it.
  final double blockSpacing;

  /// Returns the heading [TextStyle] for heading [level] (`1`..`6`).
  TextStyle headingStyleForLevel(int level) {
    return switch (level) {
      1 => h1Style,
      2 => h2Style,
      3 => h3Style,
      4 => h4Style,
      5 => h5Style,
      _ => h6Style,
    };
  }

  /// Resolves the [MarkdownAlertStyle] for [kind], falling back to the
  /// built-in light style if a custom [alertStyles] map omits that kind.
  MarkdownAlertStyle alertStyleFor(AlertKind kind) {
    return alertStyles[kind] ?? _defaultLightAlertStyles[kind]!;
  }

  /// Returns a copy of this theme with the given fields replaced.
  MarkdownThemeData copyWith({
    TextStyle? bodyStyle,
    TextStyle? h1Style,
    TextStyle? h2Style,
    TextStyle? h3Style,
    TextStyle? h4Style,
    TextStyle? h5Style,
    TextStyle? h6Style,
    TextStyle? strongStyle,
    TextStyle? emphasisStyle,
    TextStyle? strikethroughStyle,
    TextStyle? underlineStyle,
    TextStyle? linkStyle,
    TextStyle? linkHoverStyle,
    MarkdownInlineCodeStyle? inlineCodeStyle,
    MarkdownInlineCodeStyle? keyboardStyle,
    MarkdownCodeBlockStyle? codeBlockStyle,
    MarkdownBlockquoteStyle? blockquoteStyle,
    Map<AlertKind, MarkdownAlertStyle>? alertStyles,
    Color? listBulletColor,
    double? listBulletSize,
    double? listIndent,
    double? listItemSpacing,
    Color? listCheckboxFillColor,
    Color? listCheckboxCheckColor,
    MarkdownTableStyle? tableStyle,
    Color? dividerColor,
    double? dividerThickness,
    MarkdownDetailsStyle? detailsStyle,
    MarkdownLatexStyle? latexStyle,
    MarkdownFootnoteStyle? footnoteStyle,
    Color? selectionColor,
    double? blockSpacing,
  }) {
    return MarkdownThemeData(
      bodyStyle: bodyStyle ?? this.bodyStyle,
      h1Style: h1Style ?? this.h1Style,
      h2Style: h2Style ?? this.h2Style,
      h3Style: h3Style ?? this.h3Style,
      h4Style: h4Style ?? this.h4Style,
      h5Style: h5Style ?? this.h5Style,
      h6Style: h6Style ?? this.h6Style,
      strongStyle: strongStyle ?? this.strongStyle,
      emphasisStyle: emphasisStyle ?? this.emphasisStyle,
      strikethroughStyle: strikethroughStyle ?? this.strikethroughStyle,
      underlineStyle: underlineStyle ?? this.underlineStyle,
      linkStyle: linkStyle ?? this.linkStyle,
      linkHoverStyle: linkHoverStyle ?? this.linkHoverStyle,
      inlineCodeStyle: inlineCodeStyle ?? this.inlineCodeStyle,
      keyboardStyle: keyboardStyle ?? this.keyboardStyle,
      codeBlockStyle: codeBlockStyle ?? this.codeBlockStyle,
      blockquoteStyle: blockquoteStyle ?? this.blockquoteStyle,
      alertStyles: alertStyles ?? this.alertStyles,
      listBulletColor: listBulletColor ?? this.listBulletColor,
      listBulletSize: listBulletSize ?? this.listBulletSize,
      listIndent: listIndent ?? this.listIndent,
      listItemSpacing: listItemSpacing ?? this.listItemSpacing,
      listCheckboxFillColor:
          listCheckboxFillColor ?? this.listCheckboxFillColor,
      listCheckboxCheckColor:
          listCheckboxCheckColor ?? this.listCheckboxCheckColor,
      tableStyle: tableStyle ?? this.tableStyle,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      detailsStyle: detailsStyle ?? this.detailsStyle,
      latexStyle: latexStyle ?? this.latexStyle,
      footnoteStyle: footnoteStyle ?? this.footnoteStyle,
      selectionColor: selectionColor ?? this.selectionColor,
      blockSpacing: blockSpacing ?? this.blockSpacing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownThemeData &&
        other.bodyStyle == bodyStyle &&
        other.h1Style == h1Style &&
        other.h2Style == h2Style &&
        other.h3Style == h3Style &&
        other.h4Style == h4Style &&
        other.h5Style == h5Style &&
        other.h6Style == h6Style &&
        other.strongStyle == strongStyle &&
        other.emphasisStyle == emphasisStyle &&
        other.strikethroughStyle == strikethroughStyle &&
        other.underlineStyle == underlineStyle &&
        other.linkStyle == linkStyle &&
        other.linkHoverStyle == linkHoverStyle &&
        other.inlineCodeStyle == inlineCodeStyle &&
        other.keyboardStyle == keyboardStyle &&
        other.codeBlockStyle == codeBlockStyle &&
        other.blockquoteStyle == blockquoteStyle &&
        mapEquals(other.alertStyles, alertStyles) &&
        other.listBulletColor == listBulletColor &&
        other.listBulletSize == listBulletSize &&
        other.listIndent == listIndent &&
        other.listItemSpacing == listItemSpacing &&
        other.listCheckboxFillColor == listCheckboxFillColor &&
        other.listCheckboxCheckColor == listCheckboxCheckColor &&
        other.tableStyle == tableStyle &&
        other.dividerColor == dividerColor &&
        other.dividerThickness == dividerThickness &&
        other.detailsStyle == detailsStyle &&
        other.latexStyle == latexStyle &&
        other.footnoteStyle == footnoteStyle &&
        other.selectionColor == selectionColor &&
        other.blockSpacing == blockSpacing;
  }

  @override
  int get hashCode => Object.hashAll([
    bodyStyle,
    h1Style,
    h2Style,
    h3Style,
    h4Style,
    h5Style,
    h6Style,
    strongStyle,
    emphasisStyle,
    strikethroughStyle,
    underlineStyle,
    linkStyle,
    linkHoverStyle,
    inlineCodeStyle,
    keyboardStyle,
    codeBlockStyle,
    blockquoteStyle,
    Object.hashAllUnordered(
      alertStyles.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    listBulletColor,
    listBulletSize,
    listIndent,
    listItemSpacing,
    listCheckboxFillColor,
    listCheckboxCheckColor,
    tableStyle,
    dividerColor,
    dividerThickness,
    detailsStyle,
    latexStyle,
    footnoteStyle,
    selectionColor,
    blockSpacing,
  ]);
}

/// Inherited theme providing [MarkdownThemeData] to descendant renderers.
class MarkdownTheme extends InheritedWidget {
  /// Creates a theme that applies [data] to the Markdown widgets below it.
  const MarkdownTheme({super.key, required this.data, required super.child});

  /// The theme data provided to descendants.
  final MarkdownThemeData data;

  /// Returns the nearest ancestor [MarkdownThemeData], or
  /// [MarkdownThemeData.fallback] when none is present.
  static MarkdownThemeData of(BuildContext context) {
    return maybeOf(context) ?? MarkdownThemeData.fallback();
  }

  /// Returns the nearest ancestor [MarkdownThemeData], or `null` if absent.
  static MarkdownThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MarkdownTheme>()?.data;
  }

  @override
  bool updateShouldNotify(MarkdownTheme oldWidget) => data != oldWidget.data;
}
