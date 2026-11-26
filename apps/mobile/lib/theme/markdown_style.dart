import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:markdown_kit/markdown_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:syntax_highlight/syntax_highlight.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'code_text_style.dart';

final _syntaxHighlight = _SyntaxHighlightRegistry();
final markdownPerformanceProbe = MarkdownPerformanceProbe();
final _highlightCache = _HighlightSpanCache(maxEntries: 80);

// Single-slot cache for actively streaming (unclosed) code blocks so incremental
// token updates never thrash the shared 80-entry completed-block LRU cache.
_HighlightCacheKey? _streamingHighlightKey;
List<TextSpan>? _streamingHighlightSpans;

const _maxHighlightedCodeBlockChars = 6000;

@visibleForTesting
int get highlightCacheLengthForTesting => _highlightCache.length;

@visibleForTesting
void resetHighlightCacheForTesting() {
  _highlightCache.clear();
  _streamingHighlightKey = null;
  _streamingHighlightSpans = null;
}

class MarkdownPerformanceProbe {
  var codeBlockBuilds = 0;
  var codeBlockBuildMicros = 0;
  var highlightCalls = 0;
  var highlightMicros = 0;
  var highlightCacheHits = 0;
  var highlightSkipped = 0;
  var streamingBlockBuilds = 0;
  var streamingBlockReuses = 0;

  void reset() {
    codeBlockBuilds = 0;
    codeBlockBuildMicros = 0;
    highlightCalls = 0;
    highlightMicros = 0;
    highlightCacheHits = 0;
    highlightSkipped = 0;
    streamingBlockBuilds = 0;
    streamingBlockReuses = 0;
  }

  Map<String, Object?> summary() {
    return {
      'codeBlockBuilds': codeBlockBuilds,
      'codeBlockBuildMs': _roundMs(codeBlockBuildMicros),
      'avgCodeBlockBuildMs': codeBlockBuilds == 0
          ? 0
          : _roundMs(codeBlockBuildMicros / codeBlockBuilds),
      'highlightCalls': highlightCalls,
      'highlightMs': _roundMs(highlightMicros),
      'avgHighlightMs': highlightCalls == 0
          ? 0
          : _roundMs(highlightMicros / highlightCalls),
      'highlightCacheHits': highlightCacheHits,
      'highlightSkipped': highlightSkipped,
      'streamingBlockBuilds': streamingBlockBuilds,
      'streamingBlockReuses': streamingBlockReuses,
    };
  }

  double _roundMs(num micros) {
    return (micros / 1000 * 10).roundToDouble() / 10;
  }
}

Future<void> initializeMarkdownSyntaxHighlight() async {
  await _syntaxHighlight.initialize();
}

/// Handles tapping on markdown links by opening them in browser.
Future<void> handleMarkdownLink(String url, String title) async {
  if (url.isEmpty) return;

  final uri = Uri.tryParse(url);
  if (uri == null) return;

  await launchMarkdownUri(uri);
}

/// Opens a markdown URI and reports whether the platform accepted it.
Future<bool> launchMarkdownUri(Uri uri) async {
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logger.warning('Failed to open URL: $uri');
    }
    return launched;
  } catch (error, stackTrace) {
    logger.error('Failed to open URL: $uri', error, stackTrace);
    return false;
  }
}

final Expando<_CachedMarkdownTheme> _markdownThemeCache =
    Expando<_CachedMarkdownTheme>('ccpocket markdown theme');

/// Builds and caches a [MarkdownThemeData] from the current `material_ui`
/// [ThemeData], [AppColors], and [CodeTextSettings].
MarkdownThemeData buildMarkdownTheme(BuildContext context) {
  final theme = Theme.of(context);
  final appColors = theme.extension<AppColors>()!;
  final codeSettings = codeTextSettingsOf(context);

  final cached = _markdownThemeCache[theme];
  if (cached != null &&
      cached.appColors == appColors &&
      cached.codeFamily == codeSettings.family &&
      cached.codeFontSize == codeSettings.fontSize) {
    return cached.data;
  }

  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();
  final inlineCodeBackground = cs.onSurface.withValues(
    alpha: isDark ? 0.09 : 0.07,
  );
  final codeBaseStyle = codeSettings.style(
    color: baseStyle.color,
    fontWeight: FontWeight.w500,
  );
  final codeBlockTextStyle = codeSettings.style(
    height: 1.45,
    color: cs.onSurface,
  );
  final selectionColor =
      theme.textSelectionTheme.selectionColor ??
      cs.primary.withValues(alpha: 0.40);
  final defaultPalette = isDark
      ? MarkdownThemeData.dark()
      : MarkdownThemeData.fallback();

  final data = MarkdownThemeData(
    bodyStyle: baseStyle,
    h1Style: theme.textTheme.headlineSmall ?? defaultPalette.h1Style,
    h2Style: theme.textTheme.titleLarge ?? defaultPalette.h2Style,
    h3Style: theme.textTheme.titleMedium ?? defaultPalette.h3Style,
    h4Style: theme.textTheme.bodyLarge ?? defaultPalette.h4Style,
    h5Style: theme.textTheme.bodyLarge ?? defaultPalette.h5Style,
    h6Style: theme.textTheme.bodyLarge ?? defaultPalette.h6Style,
    strongStyle: baseStyle.copyWith(fontWeight: FontWeight.w700),
    emphasisStyle: const TextStyle(fontStyle: FontStyle.italic),
    strikethroughStyle: const TextStyle(decoration: TextDecoration.lineThrough),
    underlineStyle: const TextStyle(decoration: TextDecoration.underline),
    linkStyle: const TextStyle(color: Colors.blue),
    linkHoverStyle: const TextStyle(
      color: Colors.blue,
      decoration: TextDecoration.underline,
    ),
    inlineCodeStyle: MarkdownInlineCodeStyle(
      fontFamily: codeBaseStyle.fontFamily,
      fontFamilyFallback: codeBaseStyle.fontFamilyFallback,
      fontSize: codeBaseStyle.fontSize,
      fontWeight: FontWeight.w500,
      color: baseStyle.color,
      backgroundColor: inlineCodeBackground,
      borderRadius: 4.0,
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.0),
    ),
    keyboardStyle: MarkdownInlineCodeStyle(
      fontFamily: codeBaseStyle.fontFamily,
      fontFamilyFallback: codeBaseStyle.fontFamilyFallback,
      fontSize: codeBaseStyle.fontSize,
      fontWeight: FontWeight.w500,
      color: baseStyle.color,
      backgroundColor: appColors.codeBackground,
      borderColor: appColors.codeBorder,
      borderWidth: 1.0,
      borderRadius: 4.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
    ),
    codeBlockStyle: MarkdownCodeBlockStyle(
      backgroundColor: appColors.codeBackground,
      borderColor: appColors.codeBorder,
      borderWidth: 1.0,
      borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      textStyle: codeBlockTextStyle,
      headerStyle: codeBlockTextStyle.copyWith(
        fontSize: 11.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.0,
        color: appColors.subtleText,
      ),
    ),
    blockquoteStyle: MarkdownBlockquoteStyle(
      barColor: appColors.subtleText,
      barWidth: 3.0,
      padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
      textStyle: baseStyle,
    ),
    alertStyles: defaultPalette.alertStyles,
    listBulletColor: baseStyle.color ?? cs.onSurface,
    listCheckboxFillColor: cs.primary,
    listCheckboxCheckColor: cs.onPrimary,
    listIndent: 24.0,
    listItemSpacing: 4.0,
    tableStyle: MarkdownTableStyle(
      borderColor: theme.dividerColor,
      borderWidth: 1.0,
      borderRadius: const BorderRadius.all(Radius.circular(6.0)),
      headerBackground: appColors.codeBackground,
      headerTextStyle: baseStyle.copyWith(fontWeight: FontWeight.w600),
      rowStripeColor: cs.onSurface.withValues(alpha: isDark ? 0.04 : 0.025),
      cellPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    ),
    dividerColor: theme.dividerColor,
    dividerThickness: 1.0,
    detailsStyle: MarkdownDetailsStyle(
      borderColor: appColors.codeBorder,
      borderWidth: 1.0,
      summaryStyle: baseStyle.copyWith(fontWeight: FontWeight.w600),
      iconColor: appColors.subtleText,
    ),
    latexStyle: MarkdownLatexStyle(
      inlineStyle: baseStyle.copyWith(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
      ),
      blockStyle: baseStyle.copyWith(
        fontFamily: 'serif',
        fontStyle: FontStyle.italic,
        fontSize: (baseStyle.fontSize ?? 14.0) + 1.0,
      ),
      blockBackgroundColor: appColors.codeBackground,
      blockBorderColor: appColors.codeBorder,
    ),
    footnoteStyle: MarkdownFootnoteStyle(
      refStyle: TextStyle(
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        color: cs.primary,
      ),
      labelStyle: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        color: appColors.subtleText,
      ),
      textStyle: baseStyle.copyWith(
        fontSize: (baseStyle.fontSize ?? 14.0) - 1.0,
        color: appColors.subtleText,
      ),
      dividerColor: theme.dividerColor,
    ),
    selectionColor: selectionColor,
    blockSpacing: 8.0,
  );

  _markdownThemeCache[theme] = _CachedMarkdownTheme(
    appColors: appColors,
    codeFamily: codeSettings.family,
    codeFontSize: codeSettings.fontSize,
    data: data,
  );
  return data;
}

class _CachedMarkdownTheme {
  const _CachedMarkdownTheme({
    required this.appColors,
    required this.codeFamily,
    required this.codeFontSize,
    required this.data,
  });

  final AppColors appColors;
  final Object codeFamily;
  final double codeFontSize;
  final MarkdownThemeData data;
}

/// Normalizes common fenced-code language aliases to canonical highlight keys.
String? normalizeCodeLanguage(String? language) {
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

/// Renders ccpocket's fenced code block frame (non-selectable language header
/// + copy button + horizontally scrollable selectable code with syntax
/// highlighting).
Widget buildCcpocketCodeBlock(
  BuildContext context,
  CodeBlock block,
  Widget codeContent,
  MarkdownThemeData markdownTheme,
) {
  final buildWatch = !kReleaseMode ? (Stopwatch()..start()) : null;
  final source = block.code.trimRight();
  if (source.isEmpty) return const SizedBox.shrink();

  final language = normalizeCodeLanguage(block.language);
  final displayLanguage = language ?? 'text';
  final hasExplicitLanguage = language != null;

  final appColors = Theme.of(context).extension<AppColors>()!;
  final baseStyle = codeTextSettingsOf(context)
      .style(height: 1.45, color: Theme.of(context).colorScheme.onSurface);
  final highlightedSpans = highlightToTextSpans(
    context: context,
    source: block.code,
    baseStyle: baseStyle,
    language: language,
    isStreaming: !block.closed,
  );
  if (buildWatch != null) {
    buildWatch.stop();
    markdownPerformanceProbe
      ..codeBlockBuilds += 1
      ..codeBlockBuildMicros += buildWatch.elapsedMicroseconds;
  }

  final Widget effectiveCodeContent;
  if (codeContent is SelectableParagraph) {
    final safeSpans = _spansTextLength(highlightedSpans) == block.code.length
        ? highlightedSpans
        : <TextSpan>[TextSpan(text: block.code, style: baseStyle)];
    effectiveCodeContent = SelectableParagraph(
      documentId: codeContent.documentId,
      blockIndex: codeContent.blockIndex,
      textOffsetInBlock: codeContent.textOffsetInBlock,
      canonicalLength: codeContent.canonicalLength,
      offsetMapping: codeContent.offsetMapping,
      text: TextSpan(style: baseStyle, children: safeSpans),
      textAlign: codeContent.textAlign,
      textDirection: codeContent.textDirection,
      softWrap: codeContent.softWrap,
      overflow: codeContent.overflow,
      textScaler: codeContent.textScaler,
      maxLines: codeContent.maxLines,
      locale: codeContent.locale,
      strutStyle: codeContent.strutStyle,
      textWidthBasis: codeContent.textWidthBasis,
      textHeightBehavior: codeContent.textHeightBehavior,
      selectionColor: codeContent.selectionColor,
      inlineCodeStyle: codeContent.inlineCodeStyle,
      selectable: codeContent.selectable,
      onSurfaceAttach: codeContent.onSurfaceAttach,
      onSurfaceDetach: codeContent.onSurfaceDetach,
    );
  } else {
    effectiveCodeContent = codeContent;
  }

  return Container(
    key: ValueKey(
      'code_block_container_${displayLanguage}_${source.length}_${source.hashCode}',
    ),
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: appColors.codeBackground,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: appColors.codeBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CodeBlockToolbar(
          displayLanguage: displayLanguage,
          hasExplicitLanguage: hasExplicitLanguage,
          baseStyle: baseStyle,
          source: source,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: effectiveCodeContent,
        ),
      ],
    ),
  );
}

int _spansTextLength(List<TextSpan> spans) {
  var total = 0;
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      total += span.text?.length ?? 0;
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          visit(child);
        }
      }
    }
  }

  for (final span in spans) {
    visit(span);
  }
  return total;
}

class _CodeBlockToolbar extends StatefulWidget {
  const _CodeBlockToolbar({
    required this.displayLanguage,
    required this.hasExplicitLanguage,
    required this.baseStyle,
    required this.source,
  });

  final String displayLanguage;
  final bool hasExplicitLanguage;
  final TextStyle baseStyle;
  final String source;

  @override
  State<_CodeBlockToolbar> createState() => _CodeBlockToolbarState();
}

class _CodeBlockToolbarState extends State<_CodeBlockToolbar> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    _copyCodeBlock(context, widget.source);
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final isDark = theme.brightness == Brightness.dark;
    final headerBackground = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.035 : 0.03,
    );
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: headerBackground,
        border: Border(bottom: BorderSide(color: appColors.codeBorder)),
      ),
      child: Row(
        children: [
          if (widget.hasExplicitLanguage)
            Text(
              widget.displayLanguage,
              key: ValueKey('code_block_language_${widget.displayLanguage}'),
              style: widget.baseStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                height: 1.0,
                color: appColors.subtleText,
              ),
            ),
          const Spacer(),
          IconButton(
            key: ValueKey('code_block_copy_button_${widget.displayLanguage}'),
            tooltip: _copied ? (l?.copied ?? 'Copied') : (l?.copy ?? 'Copy'),
            onPressed: _handleCopy,
            visualDensity: VisualDensity.compact,
            style: const ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
            iconSize: 15,
            color: _copied ? colorScheme.primary : appColors.subtleText,
            icon: Icon(_copied ? Icons.check : Icons.content_copy_rounded),
          ),
        ],
      ),
    );
  }
}

void _copyCodeBlock(BuildContext context, String source) {
  Clipboard.setData(ClipboardData(text: source));
  HapticFeedback.lightImpact();
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l?.copied ?? 'Copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

List<TextSpan> highlightToTextSpans({
  required BuildContext context,
  required String source,
  required TextStyle baseStyle,
  required String? language,
  bool isStreaming = false,
}) {
  if (source.length > _maxHighlightedCodeBlockChars) {
    if (!kReleaseMode) markdownPerformanceProbe.highlightSkipped += 1;
    return [TextSpan(text: source, style: baseStyle)];
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cacheKey = _HighlightCacheKey(
    language: language ?? 'text',
    source: source,
    brightness: isDark ? Brightness.dark : Brightness.light,
    fontFamily: baseStyle.fontFamily,
    fontSize: baseStyle.fontSize,
    textColor: baseStyle.color,
  );

  if (isStreaming) {
    if (_streamingHighlightKey == cacheKey &&
        _streamingHighlightSpans != null) {
      if (!kReleaseMode) markdownPerformanceProbe.highlightCacheHits += 1;
      return _streamingHighlightSpans!;
    }
  } else {
    final cached = _highlightCache.get(cacheKey);
    if (cached != null) {
      if (!kReleaseMode) markdownPerformanceProbe.highlightCacheHits += 1;
      return cached;
    }
  }

  final watch = !kReleaseMode ? (Stopwatch()..start()) : null;
  List<TextSpan> finish(List<TextSpan> spans) {
    if (watch != null) {
      watch.stop();
      markdownPerformanceProbe
        ..highlightCalls += 1
        ..highlightMicros += watch.elapsedMicroseconds;
    }
    if (isStreaming) {
      _streamingHighlightKey = cacheKey;
      _streamingHighlightSpans = spans;
    } else {
      _highlightCache.put(cacheKey, spans);
    }
    return spans;
  }

  if (language == null) {
    return finish([TextSpan(text: source, style: baseStyle)]);
  }

  TextSpan? editorStyleSpan;
  try {
    // Temporary fallback until syntax_highlight merges
    // https://github.com/serverpod/syntax_highlight/pull/21.
    editorStyleSpan = _syntaxHighlight.highlight(
      context: context,
      source: source,
      language: language,
    );
  } catch (error, stackTrace) {
    logger.warning(
      '[markdown] syntax_highlight failed for language=$language',
      error,
      stackTrace,
    );
  }
  if (editorStyleSpan != null) {
    return finish([editorStyleSpan]);
  }

  hl.Result? result;
  try {
    result = hl.highlight.parse(source, language: language);
  } catch (_) {
    result = null;
  }

  if (result == null || result.nodes == null || result.nodes!.isEmpty) {
    return finish([TextSpan(text: source, style: baseStyle)]);
  }

  return finish(
    _nodesToTextSpans(
      context: context,
      nodes: result.nodes!,
      baseStyle: baseStyle,
    ),
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

class _HighlightCacheKey {
  final String language;
  final String source;
  final Brightness brightness;
  final String? fontFamily;
  final double? fontSize;
  final Color? textColor;

  const _HighlightCacheKey({
    required this.language,
    required this.source,
    required this.brightness,
    required this.fontFamily,
    required this.fontSize,
    required this.textColor,
  });

  @override
  bool operator ==(Object other) {
    return other is _HighlightCacheKey &&
        other.language == language &&
        other.source == source &&
        other.brightness == brightness &&
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.textColor == textColor;
  }

  @override
  int get hashCode => Object.hash(
    language,
    source,
    brightness,
    fontFamily,
    fontSize,
    textColor,
  );
}

class _HighlightSpanCache {
  final int maxEntries;
  final Map<_HighlightCacheKey, List<TextSpan>> _entries = {};

  _HighlightSpanCache({required this.maxEntries});

  int get length => _entries.length;

  List<TextSpan>? get(_HighlightCacheKey key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  void put(_HighlightCacheKey key, List<TextSpan> value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
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
Color? parseHexColor(String hex) {
  if (!hex.startsWith('#')) return null;
  final h = hex.substring(1);
  if (!_hexDigitsOnly.hasMatch(h)) return null;
  switch (h.length) {
    case 3: // #RGB -> #RRGGBB
      final r = h[0], g = h[1], b = h[2];
      return Color(int.parse('FF$r$r$g$g$b$b', radix: 16));
    case 4: // #RGBA -> #RRGGBBAA
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

final RegExp _hexDigitsOnly = RegExp(r'^[0-9a-fA-F]+$');

/// Fast post-parse inline rule that autolinks bare `http(s)://` URLs whose
/// host has no dot, such as `http://localhost:3013/dashboard`.
///
/// The GFM autolink extension requires a dotted domain, so local dev server
/// URLs stay plain text without this. Dotted hosts are left to GFM autolinks.
class SingleLabelHostAutolinkRule extends MarkdownInlineRule {
  const SingleLabelHostAutolinkRule();

  static final RegExp _pattern = RegExp(
    r'https?://[a-z0-9](?:[-a-z0-9]*[a-z0-9])?(?![-\w]|\.[-\w])'
    // Do not link just the prefix of user-info or an invalid port.
    r'(?::\d{1,5})?(?![:@\w-])(?:[/?#][^\s<]*)?',
    caseSensitive: false,
  );

  static const Set<int> _triggerUnits = {0x68 /* h */, 0x48 /* H */};
  static const Set<String> _validPrecedingChars = {
    '\n',
    ' ',
    '*',
    '_',
    '~',
    '(',
    '>',
  };
  static final RegExp _trailingPunctuation = RegExp(r'[?!.,:*_~]+$');

  @override
  Set<int> get triggerCodeUnits => _triggerUnits;

  @override
  MarkdownInlineMatch? matchAt(String text, int index) {
    if (index > 0) {
      final precededBy = String.fromCharCode(text.codeUnitAt(index - 1));
      if (!_validPrecedingChars.contains(precededBy)) return null;
    }
    final match = _pattern.matchAsPrefix(text, index);
    if (match == null) return null;

    final url = _trimTrailing(match[0]!);
    if (url.isEmpty) return null;

    return MarkdownInlineMatch(
      end: index + url.length,
      inline: LinkInline(
        destination: url,
        children: [TextInline(url)],
        isAutolink: true,
      ),
    );
  }

  /// Drops trailing punctuation and unbalanced closing parentheses, matching
  /// the GFM autolink rules.
  static String _trimTrailing(String url) {
    var text = url;
    while (true) {
      final trimmed = text.replaceFirst(_trailingPunctuation, '');
      if (trimmed.endsWith(')') &&
          ')'.allMatches(trimmed).length > '('.allMatches(trimmed).length) {
        text = trimmed.substring(0, trimmed.length - 1);
        continue;
      }
      if (trimmed == text) return text;
      text = trimmed;
    }
  }

  @override
  bool operator ==(Object other) => other is SingleLabelHostAutolinkRule;

  @override
  int get hashCode => (SingleLabelHostAutolinkRule).hashCode;
}

/// Inline scanner rules that autolink URLs the GFM extension misses.
const List<MarkdownInlineRule> localhostAutolinkInlineRules = [
  SingleLabelHostAutolinkRule(),
];
