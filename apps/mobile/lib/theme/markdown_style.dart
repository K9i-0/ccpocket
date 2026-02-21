import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:markdown/markdown.dart' as md;
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import 'app_theme.dart';

final _syntaxHighlight = _SyntaxHighlightRegistry();

Future<void> initializeMarkdownSyntaxHighlight() async {
  await _syntaxHighlight.initialize();
}

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

/// Builds fenced code blocks with language-aware syntax highlighting.
class FencedCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // flutter_markdown keeps an internal inline stack for `pre > code > text`.
    // Returning a placeholder here ensures that stack is drained correctly
    // before the block-level widget is produced in visitElementAfterWithContext.
    return const SizedBox.shrink();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final codeElement = element.children
        ?.whereType<md.Element>()
        .cast<md.Element?>()
        .firstWhere((child) => child?.tag == 'code', orElse: () => null);

    final source = (codeElement?.textContent ?? element.textContent)
        .trimRight();
    if (source.isEmpty) return const SizedBox.shrink();

    final className = codeElement?.attributes['class'] ?? '';
    final language = _normalizeLanguage(_extractFenceLanguage(className));
    final displayLanguage = language ?? 'text';
    final hasExplicitLanguage = language != null;

    final appColors = Theme.of(context).extension<AppColors>()!;
    final baseStyle = (preferredStyle ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.45,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Container(
      key: ValueKey('code_block_container_${displayLanguage}_$source'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: appColors.codeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appColors.codeBorder),
      ),
      child: GestureDetector(
        key: ValueKey('code_block_copy_target_$displayLanguage'),
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _copyCodeBlock(context, source),
        child: Stack(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(
                12,
                hasExplicitLanguage ? 20 : 12,
                12,
                12,
              ),
              child: SelectableText.rich(
                TextSpan(
                  style: baseStyle,
                  children: _highlightToTextSpans(
                    context: context,
                    source: source,
                    baseStyle: baseStyle,
                    language: language,
                  ),
                ),
              ),
            ),
            if (hasExplicitLanguage)
              Positioned(
                top: 6,
                right: 8,
                child: Text(
                  displayLanguage,
                  key: ValueKey('code_block_language_$displayLanguage'),
                  style: baseStyle.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.2,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void _copyCodeBlock(BuildContext context, String source) {
  Clipboard.setData(ClipboardData(text: source));
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context).copied),
      duration: const Duration(seconds: 1),
    ),
  );
}

String? _extractFenceLanguage(String className) {
  if (className.isEmpty) return null;
  for (final token in className.split(' ')) {
    if (token.startsWith('language-') && token.length > 9) {
      return token.substring(9);
    }
    if (token.startsWith('lang-') && token.length > 5) {
      return token.substring(5);
    }
  }
  return null;
}

String? _normalizeLanguage(String? language) {
  if (language == null || language.isEmpty) return null;
  switch (language.toLowerCase()) {
    case 'ts':
      return 'typescript';
    case 'js':
      return 'javascript';
    case 'py':
      return 'python';
    case 'kt':
      return 'kotlin';
    case 'rs':
      return 'rust';
    case 'sh':
    case 'zsh':
      return 'bash';
    case 'yml':
      return 'yaml';
    case 'objc':
      return 'objectivec';
    case 'plain':
    case 'plaintext':
    case 'text':
      return null;
    default:
      return language.toLowerCase();
  }
}

List<TextSpan> _highlightToTextSpans({
  required BuildContext context,
  required String source,
  required TextStyle baseStyle,
  required String? language,
}) {
  if (language == null) {
    return [TextSpan(text: source, style: baseStyle)];
  }

  final editorStyleSpan = _syntaxHighlight.highlight(
    context: context,
    source: source,
    language: language,
  );
  if (editorStyleSpan != null) {
    return [editorStyleSpan];
  }

  hl.Result? result;
  try {
    result = hl.highlight.parse(source, language: language);
  } catch (_) {
    result = null;
  }

  if (result == null || result.nodes == null || result.nodes!.isEmpty) {
    return [TextSpan(text: source, style: baseStyle)];
  }

  return _nodesToTextSpans(
    context: context,
    nodes: result.nodes!,
    baseStyle: baseStyle,
  );
}

List<TextSpan> _nodesToTextSpans({
  required BuildContext context,
  required List<hl.Node> nodes,
  required TextStyle baseStyle,
}) {
  final spans = <TextSpan>[];
  for (final node in nodes) {
    if (node.value != null) {
      spans.add(
        TextSpan(
          text: node.value,
          style: _styleForHighlightClass(context, baseStyle, node.className),
        ),
      );
      continue;
    }
    if (node.children != null && node.children!.isNotEmpty) {
      spans.add(
        TextSpan(
          style: _styleForHighlightClass(context, baseStyle, node.className),
          children: _nodesToTextSpans(
            context: context,
            nodes: node.children!,
            baseStyle: baseStyle,
          ),
        ),
      );
    }
  }
  return spans;
}

TextStyle _styleForHighlightClass(
  BuildContext context,
  TextStyle baseStyle,
  String? className,
) {
  if (className == null || className.isEmpty) return baseStyle;

  final cs = Theme.of(context).colorScheme;
  final appColors = Theme.of(context).extension<AppColors>()!;
  final token = className.toLowerCase();

  if (token.contains('comment') || token.contains('quote')) {
    return baseStyle.copyWith(
      color: appColors.subtleText,
      fontStyle: FontStyle.italic,
    );
  }
  if (token.contains('string') ||
      token.contains('regexp') ||
      token.contains('subst')) {
    return baseStyle.copyWith(color: cs.tertiary);
  }
  if (token.contains('number') ||
      token.contains('literal') ||
      token.contains('symbol')) {
    return baseStyle.copyWith(color: cs.secondary);
  }
  if (token.contains('keyword') ||
      token.contains('selector-tag') ||
      token.contains('doctag')) {
    return baseStyle.copyWith(color: cs.primary, fontWeight: FontWeight.w600);
  }
  if (token.contains('title') ||
      token.contains('function') ||
      token.contains('class') ||
      token.contains('type') ||
      token.contains('built_in')) {
    return baseStyle.copyWith(color: cs.primary, fontWeight: FontWeight.w600);
  }
  if (token.contains('attr') ||
      token.contains('attribute') ||
      token.contains('variable') ||
      token.contains('name') ||
      token.contains('params')) {
    return baseStyle.copyWith(color: cs.onSurface);
  }
  if (token.contains('meta') || token.contains('bullet')) {
    return baseStyle.copyWith(color: cs.secondary, fontWeight: FontWeight.w500);
  }
  return baseStyle;
}

class _SyntaxHighlightRegistry {
  static const _supportedLanguages = <String>[
    'css',
    'dart',
    'go',
    'html',
    'java',
    'javascript',
    'json',
    'kotlin',
    'python',
    'rust',
    'sql',
    'swift',
    'typescript',
    'yaml',
  ];

  final Map<String, Highlighter> _light = {};
  final Map<String, Highlighter> _dark = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await Highlighter.initialize(_supportedLanguages);
    final lightTheme = await HighlighterTheme.loadLightTheme();
    final darkTheme = await HighlighterTheme.loadDarkTheme();
    for (final language in _supportedLanguages) {
      _light[language] = Highlighter(language: language, theme: lightTheme);
      _dark[language] = Highlighter(language: language, theme: darkTheme);
    }
    _initialized = true;
  }

  TextSpan? highlight({
    required BuildContext context,
    required String source,
    required String language,
  }) {
    if (!_initialized) return null;
    final normalized = _syntaxLanguage(language);
    if (normalized == null) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlighter = isDark ? _dark[normalized] : _light[normalized];
    return highlighter?.highlight(source);
  }

  String? _syntaxLanguage(String language) {
    switch (language) {
      case 'js':
        return 'javascript';
      case 'ts':
        return 'typescript';
      case 'py':
        return 'python';
      case 'kt':
        return 'kotlin';
      case 'rs':
        return 'rust';
      case 'yml':
        return 'yaml';
      case 'dart':
      case 'go':
      case 'html':
      case 'java':
      case 'javascript':
      case 'json':
      case 'kotlin':
      case 'python':
      case 'rust':
      case 'sql':
      case 'swift':
      case 'typescript':
      case 'yaml':
      case 'css':
        return language;
      default:
        return null;
    }
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
Map<String, MarkdownElementBuilder> get markdownBuilders => {
  'colorCode': ColorCodeBuilder(),
  'pre': FencedCodeBlockBuilder(),
};
