import 'package:flutter/widgets.dart';

// Syntax colouring for the source pane.
//
// This is a light, line-by-line scan written for the editor: it colours what
// a writer looks for (headings, markers, code, links) and does not try to
// agree with the parser on every edge case. The preview is what shows how the
// text really parses.

/// What a stretch of source is, for colouring.
enum SyntaxKind {
  /// Ordinary text.
  plain,

  /// Punctuation that is syntax rather than content: `#`, `**`, `>`.
  marker,

  /// The text of a heading.
  heading,

  /// A list marker or task box.
  listMarker,

  /// Inline code.
  code,

  /// A line inside a fenced block.
  codeBlock,

  /// `**strong**`
  strong,

  /// `*emphasis*`
  emphasis,

  /// `~~struck~~`
  strike,

  /// The label of a link or image.
  linkLabel,

  /// The address of a link or image.
  linkAddress,
}

/// Colours of the source pane.
@immutable
class SyntaxPalette {
  /// Creates a palette.
  const SyntaxPalette({
    required this.marker,
    required this.heading,
    required this.listMarker,
    required this.code,
    required this.codeBackground,
    required this.link,
  });

  /// For a light background.
  static const light = SyntaxPalette(
    marker: Color(0xFF8C959F),
    heading: Color(0xFF0550AE),
    listMarker: Color(0xFFCF222E),
    code: Color(0xFF116329),
    codeBackground: Color(0x14818B98),
    link: Color(0xFF0969DA),
  );

  /// For a dark background.
  static const dark = SyntaxPalette(
    marker: Color(0xFF6E7681),
    heading: Color(0xFF79C0FF),
    listMarker: Color(0xFFFF7B72),
    code: Color(0xFF7EE787),
    codeBackground: Color(0x266E7681),
    link: Color(0xFF58A6FF),
  );

  /// Syntax punctuation.
  final Color marker;

  /// Heading text.
  final Color heading;

  /// List markers and task boxes.
  final Color listMarker;

  /// Code.
  final Color code;

  /// Behind inline code.
  final Color codeBackground;

  /// Link labels.
  final Color link;

  /// The style [kind] adds on top of the base text style.
  TextStyle? styleFor(SyntaxKind kind) => switch (kind) {
    SyntaxKind.plain => null,
    SyntaxKind.marker => TextStyle(color: marker),
    SyntaxKind.heading => TextStyle(
      color: heading,
      fontWeight: FontWeight.w700,
    ),
    SyntaxKind.listMarker => TextStyle(
      color: listMarker,
      fontWeight: FontWeight.w700,
    ),
    SyntaxKind.code => TextStyle(color: code, backgroundColor: codeBackground),
    SyntaxKind.codeBlock => TextStyle(color: code),
    SyntaxKind.strong => const TextStyle(fontWeight: FontWeight.w700),
    SyntaxKind.emphasis => const TextStyle(fontStyle: FontStyle.italic),
    SyntaxKind.strike => const TextStyle(
      decoration: TextDecoration.lineThrough,
    ),
    SyntaxKind.linkLabel => TextStyle(color: link),
    SyntaxKind.linkAddress => TextStyle(
      color: marker,
      decoration: TextDecoration.underline,
    ),
  };
}

/// A stretch of source of one [kind]. Plain text between tokens has none.
@immutable
class SyntaxToken {
  /// Creates a token covering `[start, end)`.
  const SyntaxToken(this.start, this.end, this.kind);

  /// First code unit.
  final int start;

  /// One past the last code unit.
  final int end;

  /// What the stretch is.
  final SyntaxKind kind;

  @override
  String toString() => 'SyntaxToken($start, $end, ${kind.name})';
}

/// Scans Markdown [source] into tokens, in order and without overlap.
List<SyntaxToken> scanMarkdown(String source) => MarkdownScanner().scan(source);

/// Scans Markdown source line by line, remembering the lines it has seen.
///
/// A keystroke changes one line, so scanning the text again mostly looks up
/// lines scanned before. Without this the scan of a long document costs more
/// than parsing it for the preview.
class MarkdownScanner {
  final Map<String, List<SyntaxToken>> _lines = {};

  /// Scans [source] into tokens, in order and without overlap.
  List<SyntaxToken> scan(String source) {
    final tokens = <SyntaxToken>[];
    final seen = <String, List<SyntaxToken>>{};
    String? fence;
    var lineStart = 0;

    while (lineStart <= source.length) {
      var lineEnd = source.indexOf('\n', lineStart);
      if (lineEnd < 0) lineEnd = source.length;
      if (lineEnd > lineStart) {
        final line = source.substring(lineStart, lineEnd);
        // Only a line that starts like a fence can open or close one.
        final fenceMatch = _mayBeFence(line) ? _fence.firstMatch(line) : null;
        if (fence != null) {
          final closes =
              fenceMatch != null &&
              fenceMatch.group(1)![0] == fence[0] &&
              fenceMatch.group(1)!.length >= fence.length &&
              fenceMatch.group(2)!.trim().isEmpty;
          tokens.add(
            SyntaxToken(
              lineStart,
              lineEnd,
              closes ? SyntaxKind.marker : SyntaxKind.codeBlock,
            ),
          );
          if (closes) fence = null;
        } else if (fenceMatch != null) {
          fence = fenceMatch.group(1);
          tokens.add(SyntaxToken(lineStart, lineEnd, SyntaxKind.marker));
        } else {
          // Tokens of a line are kept relative to its start.
          var relative = seen[line];
          if (relative == null) {
            relative = _lines[line];
            if (relative == null) {
              relative = <SyntaxToken>[];
              _scanLine(line, 0, relative);
            }
            seen[line] = relative;
          }
          for (final token in relative) {
            tokens.add(
              SyntaxToken(
                lineStart + token.start,
                lineStart + token.end,
                token.kind,
              ),
            );
          }
        }
      }
      lineStart = lineEnd + 1;
    }

    // Keep the lines of this text only, so the memory follows the document.
    _lines
      ..clear()
      ..addAll(seen);
    return tokens;
  }
}

bool _mayBeFence(String line) {
  for (var i = 0; i < line.length && i < 4; i++) {
    final unit = line.codeUnitAt(i);
    if (unit == 0x60 || unit == 0x7E) return true;
    if (unit != 0x20) return false;
  }
  return false;
}

void _scanLine(String line, int offset, List<SyntaxToken> tokens) {
  final heading = _heading.firstMatch(line);
  if (heading != null) {
    final hashes = heading.group(1)!.length + heading.start;
    tokens.add(SyntaxToken(offset, offset + hashes, SyntaxKind.marker));
    if (hashes < line.length) {
      tokens.add(
        SyntaxToken(offset + hashes, offset + line.length, SyntaxKind.heading),
      );
    }
    return;
  }
  if (_rule.hasMatch(line)) {
    tokens.add(SyntaxToken(offset, offset + line.length, SyntaxKind.marker));
    return;
  }

  var position = 0;
  final quote = _quote.firstMatch(line);
  if (quote != null) {
    tokens.add(SyntaxToken(offset, offset + quote.end, SyntaxKind.marker));
    position = quote.end;
  }
  final item = _listItem.matchAsPrefix(line, position);
  if (item != null && item.end > item.start) {
    final markerStart = item.start + item.group(1)!.length;
    tokens.add(
      SyntaxToken(
        offset + markerStart,
        offset + item.end,
        SyntaxKind.listMarker,
      ),
    );
    position = item.end;
  }

  for (final match in _inline.allMatches(line, position)) {
    final start = offset + match.start;
    final end = offset + match.end;
    if (match.group(1) != null) {
      tokens.add(SyntaxToken(start, end, SyntaxKind.code));
    } else if (match.group(2) != null) {
      _wrapped(tokens, start, end, 2, SyntaxKind.strong);
    } else if (match.group(3) != null) {
      _wrapped(tokens, start, end, 2, SyntaxKind.strike);
    } else if (match.group(4) != null) {
      _wrapped(tokens, start, end, 1, SyntaxKind.emphasis);
    } else if (match.group(5) != null) {
      final label = match.group(5)!;
      final labelStart = start + match.group(0)!.indexOf('[') + 1;
      final labelEnd = labelStart + label.length;
      tokens
        ..add(SyntaxToken(start, labelStart, SyntaxKind.marker))
        ..add(SyntaxToken(labelStart, labelEnd, SyntaxKind.linkLabel))
        ..add(SyntaxToken(labelEnd, labelEnd + 2, SyntaxKind.marker));
      if (end - 1 > labelEnd + 2) {
        tokens.add(SyntaxToken(labelEnd + 2, end - 1, SyntaxKind.linkAddress));
      }
      tokens.add(SyntaxToken(end - 1, end, SyntaxKind.marker));
    } else {
      // An HTML tag or a backslash escape.
      tokens.add(SyntaxToken(start, end, SyntaxKind.marker));
    }
  }
}

void _wrapped(
  List<SyntaxToken> tokens,
  int start,
  int end,
  int markerLength,
  SyntaxKind kind,
) {
  tokens
    ..add(SyntaxToken(start, start + markerLength, SyntaxKind.marker))
    ..add(SyntaxToken(start + markerLength, end - markerLength, kind))
    ..add(SyntaxToken(end - markerLength, end, SyntaxKind.marker));
}

final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
final _heading = RegExp(r'^ {0,3}(#{1,6})(?=[ \t]|$)');
final _rule = RegExp(r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$');
final _quote = RegExp(r'^[ \t]*(?:>[ \t]?)+');
final _listItem = RegExp(
  r'([ \t]*)(?:[-*+]|\d{1,9}[.)])(?:[ \t]+\[[ xX]\])?(?=[ \t]|$)',
);

/// Groups: 1 code span, 2 strong, 3 strike, 4 emphasis, 5 link label.
final _inline = RegExp(
  r'(`+[^`\n]+?`+)'
  r'|(\*\*(?=\S)[^\n]+?(?<=\S)\*\*|__(?=\S)[^\n]+?(?<=\S)__)'
  r'|(~~(?=\S)[^\n]+?(?<=\S)~~)'
  r'|((?<![*\w])\*(?=[^\s*])[^*\n]+?(?<=\S)\*(?!\*)|(?<![_\w])_(?=[^\s_])[^_\n]+?(?<=\S)_(?!\w))'
  r'|!?\[([^\]\n]*)\]\([^)\n]*\)'
  r'|</?[A-Za-z][^>\n]*>'
  r'|\\[!-/:-@\[-`{-~]',
);

/// A [TextEditingController] that colours Markdown syntax as it is typed.
class MarkdownEditingController extends TextEditingController {
  /// Creates a controller with [text], coloured with [palette].
  MarkdownEditingController({super.text, required this._palette});

  /// Colours of the syntax.
  SyntaxPalette get palette => _palette;
  SyntaxPalette _palette;
  set palette(SyntaxPalette value) {
    if (identical(value, _palette)) return;
    _palette = value;
    notifyListeners();
  }

  // Moving the caret rebuilds the span but not the scan.
  final _scanner = MarkdownScanner();
  String? _scanned;
  List<SyntaxToken> _tokens = const [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    if (!identical(source, _scanned)) {
      _tokens = _scanner.scan(source);
      _scanned = source;
    }

    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final children = <TextSpan>[];

    void add(int start, int end, TextStyle? tokenStyle) {
      if (start >= end) return;
      // The text an input method is still composing is underlined.
      if (composing.isValid && start < composing.end && end > composing.start) {
        final from = start > composing.start ? start : composing.start;
        final to = end < composing.end ? end : composing.end;
        add(start, from, tokenStyle);
        children.add(
          TextSpan(
            text: source.substring(from, to),
            style: (tokenStyle ?? const TextStyle()).merge(
              const TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        );
        if (to < end) {
          children.add(
            TextSpan(text: source.substring(to, end), style: tokenStyle),
          );
        }
        return;
      }
      children.add(
        TextSpan(text: source.substring(start, end), style: tokenStyle),
      );
    }

    var position = 0;
    for (final token in _tokens) {
      add(position, token.start, null);
      add(token.start, token.end, _palette.styleFor(token.kind));
      position = token.end;
    }
    add(position, source.length, null);

    return TextSpan(style: style, children: children);
  }
}
