import 'package:flutter/foundation.dart';
import 'package:markdown_kit/markdown_kit.dart';

/// Callback invoked when a file path is tapped.
typedef FilePathTapCallback = void Function(String filePath);

/// [CustomInline.kind] emitted by [BareFilePathRule] for matched project paths.
const String kFilePathInlineKind = 'filePath';

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
    if (kReleaseMode) return;
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

/// Helper utilities for detecting file paths in backtick-quoted inline code
/// and bare text by matching against a known set of project file paths.
abstract final class FilePathSyntax {
  static final _suffixCache = Expando<_CachedFilePathSuffixes>(
    'file path suffixes',
  );

  static final _lineColPattern = RegExp(r'(:\d+){1,2}$');
  static final _windowsDrivePrefix = RegExp(r'^[A-Za-z]:[\\/]');

  /// Builds a suffix set from a list of file paths for efficient lookup.
  ///
  /// For each path like `lib/models/messages.dart`, generates all suffixes:
  /// `lib/models/messages.dart`, `models/messages.dart`, `messages.dart`.
  static Set<String> buildSuffixSet(Iterable<String> filePaths) {
    final stopwatch = !kReleaseMode ? (Stopwatch()..start()) : null;
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
      if (!kReleaseMode) filePathSuffixPerformanceProbe.cacheHits++;
      return cached.suffixes;
    }
    final next = _CachedFilePathSuffixes(
      filePaths: List.unmodifiable(filePaths),
      suffixes: Set.unmodifiable(buildSuffixSet(filePaths)),
    );
    _suffixCache[filePaths] = next;
    return next.suffixes;
  }

  /// Strips trailing line:col suffixes like `:42` or `:42:10`.
  static String stripLineCol(String text) {
    return text.replaceFirst(_lineColPattern, '');
  }

  /// Whether a backtick inline-code string [raw] represents a tappable file
  /// path (matching [knownPathSuffixes], optionally after stripping `:line:col`,
  /// or an explicit path prefix/suffix).
  static bool isBacktickFilePath(String raw, Set<String> knownPathSuffixes) {
    if (raw.isEmpty || raw.contains('\n')) return false;
    if (knownPathSuffixes.contains(raw)) return true;
    final stripped = stripLineCol(raw);
    if (stripped != raw && knownPathSuffixes.contains(stripped)) return true;
    return raw.startsWith('/') ||
        raw.startsWith('./') ||
        raw.startsWith('../') ||
        raw.endsWith('/') ||
        _windowsDrivePrefix.hasMatch(raw);
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

/// Fast post-parse inline rule that detects bare file paths (without backticks)
/// in plain text by matching path-like words at boundaries against
/// [knownPathSuffixes].
class BareFilePathRule extends MarkdownInlineRule {
  const BareFilePathRule({this.knownPathSuffixes = const {}});

  final Set<String> knownPathSuffixes;

  @override
  bool mayMatch(String text) {
    if (knownPathSuffixes.isEmpty || text.length < 2) return false;
    for (var i = 0; i < text.length; i++) {
      final cu = text.codeUnitAt(i);
      if (cu == 0x2E /* . */ || cu == 0x2F /* / */ ) {
        return true;
      }
    }
    return false;
  }

  @override
  MarkdownInlineMatch? matchAt(String text, int index) {
    if (knownPathSuffixes.isEmpty) return null;
    if (!_isWordChar(text.codeUnitAt(index))) return null;
    if (index > 0 && _isPathTokenChar(text.codeUnitAt(index - 1))) {
      return null;
    }

    var end = index + 1;
    var hasDotOrSlash = false;
    while (end < text.length) {
      final cu = text.codeUnitAt(end);
      if (_isPathTokenChar(cu)) {
        if (cu == 0x2E || cu == 0x2F) hasDotOrSlash = true;
        end++;
      } else {
        break;
      }
    }

    // Match must end on a word char or '/', not a trailing '.' or '-'.
    while (end > index) {
      final last = text.codeUnitAt(end - 1);
      if (_isWordChar(last) || last == 0x2F) break;
      end--;
    }

    if (!hasDotOrSlash || end - index < 2) return null;

    final candidate = text.substring(index, end);
    if ((!candidate.contains('/') && !candidate.contains('.')) ||
        !knownPathSuffixes.contains(candidate)) {
      return null;
    }

    return MarkdownInlineMatch(
      end: end,
      inline: CustomInline(
        kind: kFilePathInlineKind,
        text: candidate,
        data: {'path': candidate},
      ),
    );
  }

  static bool _isWordChar(int cu) {
    return (cu >= 0x30 && cu <= 0x39) || // 0-9
        (cu >= 0x41 && cu <= 0x5A) || // A-Z
        (cu >= 0x61 && cu <= 0x7A) || // a-z
        cu == 0x5F; // _
  }

  static bool _isPathTokenChar(int cu) {
    return _isWordChar(cu) ||
        cu == 0x2E || // .
        cu == 0x2F || // /
        cu == 0x2D; // -
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BareFilePathRule &&
        (identical(other.knownPathSuffixes, knownPathSuffixes) ||
            setEquals(other.knownPathSuffixes, knownPathSuffixes));
  }

  @override
  int get hashCode => Object.hash(BareFilePathRule, knownPathSuffixes.length);
}
