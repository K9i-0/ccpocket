import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Callback invoked when a file path is tapped.
typedef FilePathTapCallback = void Function(String filePath);

final filePathSuffixPerformanceProbe = FilePathSuffixPerformanceProbe();

class FilePathSuffixPerformanceProbe {
  var buildCount = 0;
  var buildMicros = 0;
  var cacheHits = 0;

  void reset() {
    buildCount = 0;
    buildMicros = 0;
    cacheHits = 0;
  }

  void record(Duration elapsed) {
    if (!kDebugMode) return;
    buildCount++;
    buildMicros += elapsed.inMicroseconds;
  }

  Map<String, Object?> summary() => {
    'buildCount': buildCount,
    'buildMs': _roundMs(buildMicros),
    'avgBuildMs': buildCount == 0 ? 0 : _roundMs(buildMicros / buildCount),
    'cacheHits': cacheHits,
  };

  double _roundMs(num micros) {
    return (micros / 1000 * 10).roundToDouble() / 10;
  }
}

/// Inline syntax that detects file paths in backtick-quoted inline code
/// by matching against a known set of project file paths.
///
/// Any backtick-enclosed text is checked against [knownPathSuffixes].
/// If it matches (exact or suffix), it is rendered as a tappable file link.
/// Otherwise [tryMatch] returns false and the built-in [CodeSyntax] renders
/// it as normal inline code.
class FilePathSyntax extends md.InlineSyntax {
  static final _suffixCache = Expando<_CachedFilePathSuffixes>(
    'file path suffixes',
  );

  final Set<String> _knownPathSuffixes;

  /// Creates a [FilePathSyntax] with a pre-built suffix set.
  ///
  /// Use [buildSuffixSet] to create the set from a list of project file paths.
  FilePathSyntax({Set<String> knownPathSuffixes = const {}})
    : _knownPathSuffixes = knownPathSuffixes,
      super(
        // Match any backtick-enclosed content (single line).
        r'`([^`\n]+)`',
        startCharacter: 0x60, // backtick
      );

  /// Builds a suffix set from a list of file paths for efficient lookup.
  ///
  /// For each path like `lib/models/messages.dart`, generates all suffixes:
  /// `lib/models/messages.dart`, `models/messages.dart`, `messages.dart`.
  static Set<String> buildSuffixSet(Iterable<String> filePaths) {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final suffixes = <String>{};
    for (final filePath in filePaths) {
      final parts = filePath
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();
      for (
        var end = 1;
        end < parts.length + (filePath.endsWith('/') ? 1 : 0);
        end++
      ) {
        for (var start = 0; start < end; start++) {
          final directory = parts.sublist(start, end).join('/');
          suffixes.add(directory);
          suffixes.add('$directory/');
        }
      }
      for (var i = 0; i < parts.length; i++) {
        suffixes.add(parts.sublist(i).join('/'));
      }
    }
    stopwatch?.stop();
    if (stopwatch != null) {
      filePathSuffixPerformanceProbe.record(stopwatch.elapsed);
    }
    return suffixes;
  }

  /// Returns suffixes cached by list identity and invalidated by content changes.
  static Set<String> cachedSuffixSet(List<String> filePaths) {
    final cached = _suffixCache[filePaths];
    if (cached != null && listEquals(cached.filePaths, filePaths)) {
      if (kDebugMode) filePathSuffixPerformanceProbe.cacheHits++;
      return cached.suffixes;
    }
    final next = _CachedFilePathSuffixes(
      filePaths: List.unmodifiable(filePaths),
      suffixes: Set.unmodifiable(buildSuffixSet(filePaths)),
    );
    _suffixCache[filePaths] = next;
    return next.suffixes;
  }

  static final _lineColPattern = RegExp(r'(:\d+){1,2}$');

  /// Strips trailing line:col suffixes like `:42` or `:42:10`.
  static String _stripLineCol(String text) {
    return text.replaceFirst(_lineColPattern, '');
  }

  /// Overrides [tryMatch] to return false early when the backtick content
  /// is not a known file path. This prevents the base class from calling
  /// [writeText] and returning true without consuming the match.
  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;

    if (parser.source.codeUnitAt(startMatchPos) != 0x60) return false;
    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;

    final raw = match[1]!;
    final stripped = _stripLineCol(raw);
    final matchesRaw = _knownPathSuffixes.contains(raw);
    final matchesStripped =
        !matchesRaw && _knownPathSuffixes.contains(stripped);

    final explicitPath =
        raw.startsWith('/') ||
        raw.startsWith('./') ||
        raw.startsWith('../') ||
        raw.endsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(raw);
    if (!matchesRaw && !matchesStripped && !explicitPath) return false;

    final path = raw;
    final el = md.Element('filePath', [md.Text(raw)]);
    el.attributes['path'] = path;

    parser.writeText();
    parser.addNode(el);
    parser.consume(match[0]!.length);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    // Not called — logic is in tryMatch.
    return false;
  }
}

class _CachedFilePathSuffixes {
  final List<String> filePaths;
  final Set<String> suffixes;

  const _CachedFilePathSuffixes({
    required this.filePaths,
    required this.suffixes,
  });
}

/// Inline syntax that detects bare file paths (without backticks) in text
/// by matching path-like patterns against the known project file list.
///
/// Matches sequences like `docs/install/index.html` or `README.ja.md`
/// that appear as plain text (not inside backticks). Must be added AFTER
/// [FilePathSyntax] in [inlineSyntaxes] so backtick-enclosed paths are
/// handled first.
class BareFilePathSyntax extends md.InlineSyntax {
  final Set<String> _knownPathSuffixes;

  BareFilePathSyntax({Set<String> knownPathSuffixes = const {}})
    : _knownPathSuffixes = knownPathSuffixes,
      // Path-like string: word chars / dots / slashes / hyphens,
      // must contain at least one dot (file extension).
      super(r'([\w][\w./-]*[\w/])');

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    startMatchPos ??= parser.pos;
    if (_knownPathSuffixes.isEmpty) return false;

    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;

    final text = match[1]!;
    if ((!text.contains('/') && !text.contains('.')) ||
        !_knownPathSuffixes.contains(text)) {
      return false;
    }

    final el = md.Element('filePath', [md.Text(text)]);
    el.attributes['path'] = text;

    parser.writeText();
    parser.addNode(el);
    parser.consume(match[0]!.length);
    return true;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;
}

/// Builds a tappable widget for file path elements.
class FilePathBuilder extends MarkdownElementBuilder {
  final FilePathTapCallback? onTap;

  FilePathBuilder({this.onTap});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final path = element.attributes['path'] ?? '';
    final displayText = element.textContent;
    final cs = Theme.of(context).colorScheme;

    final codeStyle = (preferredStyle ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      backgroundColor: Colors.transparent,
      color: cs.primary,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary.withValues(alpha: 0.4),
      decorationStyle: TextDecorationStyle.dotted,
    );

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(path) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 12,
            color: cs.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 3),
          Flexible(child: Text(displayText, style: codeStyle)),
        ],
      ),
    );
  }
}
