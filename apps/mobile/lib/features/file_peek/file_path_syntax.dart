import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../theme/app_theme.dart';

/// Callback invoked when a file path is tapped.
typedef FilePathTapCallback = void Function(String filePath);

/// Inline syntax that detects file paths in backtick-quoted inline code
/// by matching against a known set of project file paths.
///
/// Any backtick-enclosed text is checked against [knownPathSuffixes].
/// If it matches (exact or suffix), it is rendered as a tappable file link.
/// Otherwise [tryMatch] returns false and the built-in [CodeSyntax] renders
/// it as normal inline code.
class FilePathSyntax extends md.InlineSyntax {
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
    final suffixes = <String>{};
    for (final filePath in filePaths) {
      final parts = filePath.split('/');
      for (var i = 0; i < parts.length; i++) {
        suffixes.add(parts.sublist(i).join('/'));
      }
    }
    return suffixes;
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
    if (_knownPathSuffixes.isEmpty) return false;

    final match = pattern.matchAsPrefix(parser.source, startMatchPos);
    if (match == null) return false;

    final raw = match[1]!;
    final stripped = _stripLineCol(raw);
    final matchesRaw = _knownPathSuffixes.contains(raw);
    final matchesStripped =
        !matchesRaw && _knownPathSuffixes.contains(stripped);

    if (!matchesRaw && !matchesStripped) return false;

    final path = matchesRaw ? raw : stripped;
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
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;

    final codeStyle = (preferredStyle ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: appColors.codeBackground,
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
