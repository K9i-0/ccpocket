import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../ast/markdown_ast.dart';

/// Styling for inline code spans (`CodeTextSpan`) and `<kbd>` keycaps.
@immutable
class MarkdownInlineCodeStyle {
  const MarkdownInlineCodeStyle({
    this.fontFamily = 'monospace',
    this.fontFamilyFallback,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.backgroundColor = const Color(0x14000000),
    this.borderColor,
    this.borderWidth = 0.0,
    this.borderRadius = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
  });

  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
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
  const MarkdownCodeBlockStyle({
    this.backgroundColor = const Color(0xFFF6F8FA),
    this.borderColor = const Color(0xFFD0D7DE),
    this.borderWidth = 1.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.padding = const EdgeInsets.all(12.0),
    this.textStyle = const TextStyle(
      fontFamily: 'monospace',
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

  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final TextStyle textStyle;
  final TextStyle headerStyle;
  final Color? headerBackgroundColor;
  final EdgeInsets headerPadding;

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
  const MarkdownBlockquoteStyle({
    this.barColor = const Color(0xFFD0D7DE),
    this.barWidth = 3.5,
    this.padding = const EdgeInsets.fromLTRB(12.0, 4.0, 8.0, 4.0),
    this.textStyle = const TextStyle(color: Color(0xFF57606A)),
    this.backgroundColor,
    this.borderRadius = BorderRadius.zero,
  });

  final Color barColor;
  final double barWidth;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final BorderRadius borderRadius;

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

  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double barWidth;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final TextStyle titleStyle;
  final TextStyle? textStyle;

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

  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final Color headerBackground;
  final TextStyle headerTextStyle;
  final Color? rowStripeColor;
  final EdgeInsets cellPadding;
  final double minColumnWidth;
  final double maxColumnWidth;

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

  final Color? backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius borderRadius;
  final EdgeInsets headerPadding;
  final EdgeInsets bodyPadding;
  final TextStyle summaryStyle;
  final Color iconColor;
  final double iconSize;

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

  final TextStyle inlineStyle;
  final TextStyle blockStyle;
  final Color? blockBackgroundColor;
  final Color? blockBorderColor;
  final BorderRadius blockBorderRadius;
  final EdgeInsets blockPadding;

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

  final TextStyle refStyle;
  final TextStyle labelStyle;
  final TextStyle textStyle;
  final Color dividerColor;
  final double dividerThickness;
  final double itemSpacing;

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

  final TextStyle bodyStyle;
  final TextStyle h1Style;
  final TextStyle h2Style;
  final TextStyle h3Style;
  final TextStyle h4Style;
  final TextStyle h5Style;
  final TextStyle h6Style;
  final TextStyle strongStyle;
  final TextStyle emphasisStyle;
  final TextStyle strikethroughStyle;
  final TextStyle underlineStyle;
  final TextStyle linkStyle;
  final TextStyle linkHoverStyle;
  final MarkdownInlineCodeStyle inlineCodeStyle;
  final MarkdownInlineCodeStyle keyboardStyle;
  final MarkdownCodeBlockStyle codeBlockStyle;
  final MarkdownBlockquoteStyle blockquoteStyle;
  final Map<AlertKind, MarkdownAlertStyle> alertStyles;
  final Color listBulletColor;
  final double listBulletSize;
  final double listIndent;
  final double listItemSpacing;
  final Color? listCheckboxFillColor;
  final Color? listCheckboxCheckColor;
  final MarkdownTableStyle tableStyle;
  final Color dividerColor;
  final double dividerThickness;
  final MarkdownDetailsStyle detailsStyle;
  final MarkdownLatexStyle latexStyle;
  final MarkdownFootnoteStyle footnoteStyle;
  final Color selectionColor;
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
  const MarkdownTheme({super.key, required this.data, required super.child});

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
