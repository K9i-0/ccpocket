import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import 'app_theme.dart';

/// Handles tapping on markdown links by opening them in browser.
Future<void> handleMarkdownLink(String text, String? href, String title) async {
  if (href == null || href.isEmpty) return;

  final uri = Uri.tryParse(href);
  if (uri == null) return;

  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    logger.error('Failed to open URL: $href', e);
  }
}

MarkdownStyleSheet buildMarkdownStyle(BuildContext context) {
  final appColors = Theme.of(context).extension<AppColors>()!;
  final theme = Theme.of(context);
  final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: baseStyle,
    code: baseStyle.copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: appColors.codeBackground,
    ),
    codeblockDecoration: BoxDecoration(
      color: appColors.codeBackground,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: appColors.codeBorder),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: appColors.subtleText, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    listBullet: baseStyle.copyWith(fontSize: 14),
  );
}

// ---------------------------------------------------------------------------
// Color code preview: shows a colored circle next to HEX color codes
// ---------------------------------------------------------------------------

/// Inline syntax that matches HEX color codes in backtick-quoted inline code.
///
/// Matches patterns like `#f00`, `#FF5733`, `#FF5733AA` inside backticks and
/// emits a custom `colorCode` element so [ColorCodeBuilder] can render a
/// colored swatch next to the code text.
class ColorCodeSyntax extends md.InlineSyntax {
  // Match backtick-wrapped hex color: `#fff`, `#FF5733`, `#FF5733AA`
  // Negative lookbehind for backtick prevents matching inside fenced code.
  ColorCodeSyntax()
    : super(
        r'`(#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8}))`',
        startCharacter: 0x60, // backtick '`'
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final colorText = match[1]!; // e.g. "#FF5733"
    final el = md.Element('colorCode', [md.Text(colorText)]);
    el.attributes['color'] = colorText;
    parser.addNode(el);
    return true;
  }
}

/// Builds a widget for `colorCode` elements produced by [ColorCodeSyntax].
///
/// Renders a small colored circle followed by the color code text styled as
/// inline code.
class ColorCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final colorHex = element.attributes['color'] ?? '';
    final color = _parseHexColor(colorHex);
    if (color == null) return null;

    final appColors = Theme.of(context).extension<AppColors>()!;
    final codeStyle = (preferredStyle ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: appColors.codeBackground,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(colorHex, style: codeStyle),
      ],
    );
  }
}

/// Parses a HEX color string into a [Color].
///
/// Supports 3-digit (#RGB), 4-digit (#RGBA), 6-digit (#RRGGBB),
/// and 8-digit (#RRGGBBAA) formats.
Color? _parseHexColor(String hex) {
  if (!hex.startsWith('#')) return null;
  final h = hex.substring(1);
  switch (h.length) {
    case 3: // #RGB → #RRGGBB
      final r = h[0], g = h[1], b = h[2];
      return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
    case 4: // #RGBA → #RRGGBBAA
      final r = h[0], g = h[1], b = h[2], a = h[3];
      return Color(int.parse('$a$a$r$r$g$g$b$b', radix: 16));
    case 6: // #RRGGBB
      return Color(int.parse('FF$h', radix: 16));
    case 8: // #RRGGBBAA
      final rgb = h.substring(0, 6);
      final alpha = h.substring(6, 8);
      return Color(int.parse('$alpha$rgb', radix: 16));
    default:
      return null;
  }
}

/// Custom inline syntaxes for color code preview.
List<md.InlineSyntax> get colorCodeInlineSyntaxes => [ColorCodeSyntax()];

/// Custom element builders for color code preview.
Map<String, MarkdownElementBuilder> get colorCodeBuilders => {
  'colorCode': ColorCodeBuilder(),
};
