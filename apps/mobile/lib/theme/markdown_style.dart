import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:re_highlight/languages/apache.dart';
import 'package:re_highlight/languages/arduino.dart';
import 'package:re_highlight/languages/armasm.dart';
import 'package:re_highlight/languages/awk.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/clojure.dart';
import 'package:re_highlight/languages/cmake.dart';
import 'package:re_highlight/languages/coffeescript.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/crystal.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/d.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/delphi.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/dos.dart';
import 'package:re_highlight/languages/elixir.dart';
import 'package:re_highlight/languages/elm.dart';
import 'package:re_highlight/languages/erb.dart';
import 'package:re_highlight/languages/erlang.dart';
import 'package:re_highlight/languages/fortran.dart';
import 'package:re_highlight/languages/fsharp.dart';
import 'package:re_highlight/languages/gherkin.dart';
import 'package:re_highlight/languages/glsl.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/gradle.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/groovy.dart';
import 'package:re_highlight/languages/haml.dart';
import 'package:re_highlight/languages/handlebars.dart';
import 'package:re_highlight/languages/haskell.dart';
import 'package:re_highlight/languages/http.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/julia.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/latex.dart';
import 'package:re_highlight/languages/less.dart';
import 'package:re_highlight/languages/lisp.dart';
import 'package:re_highlight/languages/llvm.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/matlab.dart';
import 'package:re_highlight/languages/nginx.dart';
import 'package:re_highlight/languages/nix.dart';
import 'package:re_highlight/languages/objectivec.dart';
import 'package:re_highlight/languages/ocaml.dart';
import 'package:re_highlight/languages/perl.dart';
import 'package:re_highlight/languages/pgsql.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/powershell.dart';
import 'package:re_highlight/languages/prolog.dart';
import 'package:re_highlight/languages/properties.dart';
import 'package:re_highlight/languages/protobuf.dart';
import 'package:re_highlight/languages/puppet.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/qml.dart';
import 'package:re_highlight/languages/r.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/scheme.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/stylus.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/tcl.dart';
import 'package:re_highlight/languages/twig.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/verilog.dart';
import 'package:re_highlight/languages/vhdl.dart';
import 'package:re_highlight/languages/vim.dart';
import 'package:re_highlight/languages/vue.dart';
import 'package:re_highlight/languages/wasm.dart';
import 'package:re_highlight/languages/x86asm.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import 'app_theme.dart';
import 'code_text_style.dart';
import '../widgets/app_toast.dart';

final Highlight _reHighlight = _createReHighlight();
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

/// Highlights a fenced code block for `MarkdownBuilders.codeHighlighter`.
///
/// The spans are wrapped in one span carrying ccpocket's own code text style,
/// so the code looks the same whatever the Markdown theme's code style is.
List<InlineSpan> highlightCcpocketCodeBlock(
  BuildContext context,
  CodeBlock block,
  TextStyle _,
) {
  final buildWatch = !kReleaseMode ? (Stopwatch()..start()) : null;
  final baseStyle = _ccpocketCodeBaseStyle(context);
  final spans = highlightToTextSpans(
    context: context,
    source: block.code,
    baseStyle: baseStyle,
    language: normalizeCodeLanguage(block.language),
    isStreaming: !block.closed,
  );
  if (buildWatch != null) {
    buildWatch.stop();
    markdownPerformanceProbe
      ..codeBlockBuilds += 1
      ..codeBlockBuildMicros += buildWatch.elapsedMicroseconds;
  }
  return [TextSpan(style: baseStyle, children: spans)];
}

TextStyle _ccpocketCodeBaseStyle(BuildContext context) =>
    codeTextSettingsOf(context)
        .style(height: 1.45, color: Theme.of(context).colorScheme.onSurface);

/// Renders ccpocket's fenced code block frame (non-selectable language header
/// + copy button + horizontally scrollable selectable code). The code itself
/// is highlighted by [highlightCcpocketCodeBlock].
Widget buildCcpocketCodeBlock(
  BuildContext context,
  CodeBlock block,
  Widget codeContent,
  MarkdownThemeData markdownTheme,
) {
  final source = block.code.trimRight();
  if (source.isEmpty) return const SizedBox.shrink();

  final language = normalizeCodeLanguage(block.language);
  final displayLanguage = language ?? 'text';
  final hasExplicitLanguage = language != null;

  final appColors = Theme.of(context).extension<AppColors>()!;
  final baseStyle = _ccpocketCodeBaseStyle(context);

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
          child: codeContent,
        ),
      ],
    ),
  );
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
  final messenger = AppToast.maybeOf(context);
  if (messenger != null) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    messenger.show(l?.copied ?? 'Copied', duration: const Duration(seconds: 1));
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

  final normalizedLanguage = normalizeCodeLanguage(language);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cacheKey = _HighlightCacheKey(
    language: normalizedLanguage ?? 'text',
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

  if (normalizedLanguage == null ||
      source.isEmpty ||
      _reHighlight.getLanguage(normalizedLanguage) == null) {
    return finish([TextSpan(text: source, style: baseStyle)]);
  }

  try {
    final result = _reHighlight.highlight(
      code: source,
      language: normalizedLanguage,
    );
    if (result.errorRaised != null) {
      logger.warning(
        '[markdown] re_highlight raised error for language=$normalizedLanguage',
        result.errorRaised,
      );
      return finish([TextSpan(text: source, style: baseStyle)]);
    }

    final renderer = _FlatTextSpanRenderer(
      baseStyle: baseStyle,
      theme: isDark ? _darkCodeTheme : _lightCodeTheme,
    );
    result.render(renderer);
    final spans = renderer.buildSpans();
    if (spans.isEmpty || renderer.emittedLength != source.length) {
      return finish([TextSpan(text: source, style: baseStyle)]);
    }
    return finish(spans);
  } catch (error, stackTrace) {
    logger.warning(
      '[markdown] re_highlight failed for language=$normalizedLanguage',
      error,
      stackTrace,
    );
    return finish([TextSpan(text: source, style: baseStyle)]);
  }
}

Highlight _createReHighlight() {
  final highlight = Highlight()
    ..registerLanguages({
      'apache': langApache,
      'arduino': langArduino,
      'armasm': langArmasm,
      'awk': langAwk,
      'bash': langBash,
      'c': langC,
      'clojure': langClojure,
      'cmake': langCmake,
      'coffeescript': langCoffeescript,
      'cpp': langCpp,
      'crystal': langCrystal,
      'csharp': langCsharp,
      'css': langCss,
      'd': langD,
      'dart': langDart,
      'delphi': langDelphi,
      'diff': langDiff,
      'dockerfile': langDockerfile,
      'dos': langDos,
      'elixir': langElixir,
      'elm': langElm,
      'erb': langErb,
      'erlang': langErlang,
      'fortran': langFortran,
      'fsharp': langFsharp,
      'gherkin': langGherkin,
      'glsl': langGlsl,
      'go': langGo,
      'gradle': langGradle,
      'graphql': langGraphql,
      'groovy': langGroovy,
      'haml': langHaml,
      'handlebars': langHandlebars,
      'haskell': langHaskell,
      'http': langHttp,
      'ini': langIni,
      'java': langJava,
      'javascript': langJavascript,
      'json': langJson,
      'julia': langJulia,
      'kotlin': langKotlin,
      'latex': langLatex,
      'less': langLess,
      'lisp': langLisp,
      'llvm': langLlvm,
      'lua': langLua,
      'makefile': langMakefile,
      'markdown': langMarkdown,
      'matlab': langMatlab,
      'nginx': langNginx,
      'nix': langNix,
      'objectivec': langObjectivec,
      'ocaml': langOcaml,
      'perl': langPerl,
      'pgsql': langPgsql,
      'php': langPhp,
      'powershell': langPowershell,
      'prolog': langProlog,
      'properties': langProperties,
      'protobuf': langProtobuf,
      'puppet': langPuppet,
      'python': langPython,
      'qml': langQml,
      'r': langR,
      'ruby': langRuby,
      'rust': langRust,
      'scala': langScala,
      'scheme': langScheme,
      'scss': langScss,
      'shell': langShell,
      'sql': langSql,
      'stylus': langStylus,
      'swift': langSwift,
      'tcl': langTcl,
      'twig': langTwig,
      'typescript': langTypescript,
      'verilog': langVerilog,
      'vhdl': langVhdl,
      'vim': langVim,
      'vue': langVue,
      'wasm': langWasm,
      'x86asm': langX86Asm,
      'xml': langXml,
      'yaml': langYaml,
    })
    ..registerAliases(['sh', 'zsh'], 'bash')
    ..registerAliases(['ts', 'tsx', 'mts', 'cts'], 'typescript')
    ..registerAliases(['js', 'jsx', 'mjs', 'cjs'], 'javascript')
    ..registerAliases(['py'], 'python')
    ..registerAliases(['kt', 'kts'], 'kotlin')
    ..registerAliases(['rs'], 'rust')
    ..registerAliases(['yml'], 'yaml')
    ..registerAliases(['rb'], 'ruby')
    ..registerAliases(['cs'], 'csharp')
    ..registerAliases(['objc', 'mm'], 'objectivec')
    ..registerAliases(['toml'], 'ini')
    ..registerAliases(['html', 'htm', 'svg'], 'xml')
    ..registerAliases(['md'], 'markdown')
    ..registerAliases(['docker'], 'dockerfile')
    ..registerAliases(['patch'], 'diff')
    ..registerAliases(['proto'], 'protobuf')
    ..registerAliases(['gql'], 'graphql')
    ..registerAliases(['ps1', 'pwsh'], 'powershell')
    ..registerAliases(['tex'], 'latex');
  return highlight;
}

/// Renders a [HighlightResult] token tree into a flat, coalesced list of
/// [TextSpan]s in O(N) time while preserving exact character offsets and full
/// inherited [TextStyle]s for both `markdown_kit` `SelectableParagraph` and
/// `FilePeekCode` line splitting.
class _FlatTextSpanRenderer implements HighlightRenderer {
  _FlatTextSpanRenderer({required this.baseStyle, required this.theme})
    : _styleStack = <TextStyle>[baseStyle];

  final TextStyle baseStyle;
  final Map<String, TextStyle> theme;
  final List<TextStyle> _styleStack;
  final List<TextSpan> _spans = <TextSpan>[];
  final StringBuffer _buffer = StringBuffer();
  TextStyle? _bufferStyle;
  int _emittedLength = 0;

  int get emittedLength => _emittedLength;

  @override
  void openNode(DataNode node) {
    final parentStyle = _styleStack.last;
    final scopeStyle = _resolveScopeStyle(node.scope);
    _styleStack.add(
      scopeStyle != null ? parentStyle.merge(scopeStyle) : parentStyle,
    );
  }

  @override
  void closeNode(DataNode node) {
    if (_styleStack.length > 1) {
      _styleStack.removeLast();
    }
  }

  @override
  void addText(String text) {
    if (text.isEmpty) return;
    _emittedLength += text.length;
    final currentStyle = _styleStack.last;
    if (_buffer.isNotEmpty && _bufferStyle != currentStyle) {
      _flush();
    }
    _bufferStyle = currentStyle;
    _buffer.write(text);
  }

  List<TextSpan> buildSpans() {
    _flush();
    return _spans;
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    _spans.add(TextSpan(text: _buffer.toString(), style: _bufferStyle));
    _buffer.clear();
    _bufferStyle = null;
  }

  TextStyle? _resolveScopeStyle(String? scope) {
    if (scope == null || scope.isEmpty) return null;
    final direct = theme[scope];
    if (direct != null) return direct;
    // Highlight.js v11 emits dotted sub-scopes (e.g. `title.function_.invoke__`
    // or `keyword.control`). Walk up to the most specific registered prefix.
    var dot = scope.lastIndexOf('.');
    while (dot > 0) {
      final parentScope = scope.substring(0, dot);
      final match = theme[parentScope];
      if (match != null) return match;
      dot = parentScope.lastIndexOf('.');
    }
    return null;
  }
}

// Light syntax palette aligned with ccpocket's Graphite & Ember light theme
// (WCAG AA contrast on AppColors.light().codeBackground #F4F4F5).
const Map<String, TextStyle> _lightCodeTheme = {
  'keyword': TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.w600),
  'doctag': TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.w600),
  'meta-keyword': TextStyle(
    color: Color(0xFFC2410C),
    fontWeight: FontWeight.w600,
  ),
  'template-tag': TextStyle(color: Color(0xFFC2410C)),
  'template-variable': TextStyle(color: Color(0xFFC2410C)),
  'variable.language_': TextStyle(color: Color(0xFFC2410C)),
  'title': TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w500),
  'title.function_': TextStyle(
    color: Color(0xFF6D28D9),
    fontWeight: FontWeight.w500,
  ),
  'section': TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w600),
  'type': TextStyle(color: Color(0xFF0F766E)),
  'title.class_': TextStyle(
    color: Color(0xFF0F766E),
    fontWeight: FontWeight.w500,
  ),
  'class-title': TextStyle(
    color: Color(0xFF0F766E),
    fontWeight: FontWeight.w500,
  ),
  'built_in': TextStyle(color: Color(0xFF0F766E)),
  'string': TextStyle(color: Color(0xFF15803D)),
  'regexp': TextStyle(color: Color(0xFF15803D)),
  'meta-string': TextStyle(color: Color(0xFF15803D)),
  'number': TextStyle(color: Color(0xFF1D4ED8)),
  'literal': TextStyle(color: Color(0xFF1D4ED8)),
  'symbol': TextStyle(color: Color(0xFF1D4ED8)),
  'variable.constant_': TextStyle(color: Color(0xFF1D4ED8)),
  'bullet': TextStyle(color: Color(0xFF1D4ED8)),
  'attr': TextStyle(color: Color(0xFF92400E)),
  'attribute': TextStyle(color: Color(0xFF92400E)),
  'property': TextStyle(color: Color(0xFF92400E)),
  'name': TextStyle(color: Color(0xFF92400E)),
  'selector-tag': TextStyle(color: Color(0xFF92400E)),
  'selector-attr': TextStyle(color: Color(0xFF92400E)),
  'selector-class': TextStyle(color: Color(0xFF92400E)),
  'selector-id': TextStyle(color: Color(0xFF92400E)),
  'selector-pseudo': TextStyle(color: Color(0xFF92400E)),
  'meta': TextStyle(color: Color(0xFF0369A1)),
  'link': TextStyle(color: Color(0xFF0369A1)),
  'comment': TextStyle(color: Color(0xFF63636B), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xFF63636B), fontStyle: FontStyle.italic),
  'code': TextStyle(color: Color(0xFF63636B)),
  'formula': TextStyle(color: Color(0xFF63636B)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.w700),
  'addition': TextStyle(
    color: Color(0xFF166534),
    backgroundColor: Color(0xFFDCFCE7),
  ),
  'deletion': TextStyle(
    color: Color(0xFF991B1B),
    backgroundColor: Color(0xFFFEE2E2),
  ),
};

// Dark syntax palette aligned with ccpocket's Graphite & Ember dark theme
// (high contrast on AppColors.dark().codeBackground #161618).
const Map<String, TextStyle> _darkCodeTheme = {
  'keyword': TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.w600),
  'doctag': TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.w600),
  'meta-keyword': TextStyle(
    color: Color(0xFFFB923C),
    fontWeight: FontWeight.w600,
  ),
  'template-tag': TextStyle(color: Color(0xFFFB923C)),
  'template-variable': TextStyle(color: Color(0xFFFB923C)),
  'variable.language_': TextStyle(color: Color(0xFFFB923C)),
  'title': TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.w500),
  'title.function_': TextStyle(
    color: Color(0xFFC4B5FD),
    fontWeight: FontWeight.w500,
  ),
  'section': TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.w600),
  'type': TextStyle(color: Color(0xFF2DD4BF)),
  'title.class_': TextStyle(
    color: Color(0xFF2DD4BF),
    fontWeight: FontWeight.w500,
  ),
  'class-title': TextStyle(
    color: Color(0xFF2DD4BF),
    fontWeight: FontWeight.w500,
  ),
  'built_in': TextStyle(color: Color(0xFF2DD4BF)),
  'string': TextStyle(color: Color(0xFF86EFAC)),
  'regexp': TextStyle(color: Color(0xFF86EFAC)),
  'meta-string': TextStyle(color: Color(0xFF86EFAC)),
  'number': TextStyle(color: Color(0xFF60A5FA)),
  'literal': TextStyle(color: Color(0xFF60A5FA)),
  'symbol': TextStyle(color: Color(0xFF60A5FA)),
  'variable.constant_': TextStyle(color: Color(0xFF60A5FA)),
  'bullet': TextStyle(color: Color(0xFF60A5FA)),
  'attr': TextStyle(color: Color(0xFFFBBF24)),
  'attribute': TextStyle(color: Color(0xFFFBBF24)),
  'property': TextStyle(color: Color(0xFFFBBF24)),
  'name': TextStyle(color: Color(0xFFFBBF24)),
  'selector-tag': TextStyle(color: Color(0xFFFBBF24)),
  'selector-attr': TextStyle(color: Color(0xFFFBBF24)),
  'selector-class': TextStyle(color: Color(0xFFFBBF24)),
  'selector-id': TextStyle(color: Color(0xFFFBBF24)),
  'selector-pseudo': TextStyle(color: Color(0xFFFBBF24)),
  'meta': TextStyle(color: Color(0xFF38BDF8)),
  'link': TextStyle(color: Color(0xFF38BDF8)),
  'comment': TextStyle(color: Color(0xFFA1A1AA), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xFFA1A1AA), fontStyle: FontStyle.italic),
  'code': TextStyle(color: Color(0xFFA1A1AA)),
  'formula': TextStyle(color: Color(0xFFA1A1AA)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.w700),
  'addition': TextStyle(
    color: Color(0xFF86EFAC),
    backgroundColor: Color(0xFF14532D),
  ),
  'deletion': TextStyle(
    color: Color(0xFFFCA5A5),
    backgroundColor: Color(0xFF7F1D1D),
  ),
};

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
