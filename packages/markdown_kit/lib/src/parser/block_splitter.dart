/// Splits [text] into top-level Markdown chunks that can be parsed
/// independently without losing cross-block semantics.
///
/// Designed for streaming and incremental block caching: completed prefix
/// chunks remain byte-identical as new tokens arrive, so only the trailing
/// chunk needs to be re-parsed.
///
/// Invariants:
/// - `splitMarkdownBlocks(text).join() == text` for every input (including
///   every prefix of a streamed document).
/// - Each chunk keeps its trailing blank lines and exact line endings.
/// - Returns `[text]` (a single chunk) when the document contains cross-block
///   constructs such as link reference definitions, footnote definitions, or
///   multi-paragraph raw HTML blocks (`<!--`, `<pre>`, `<script>`, `<style>`,
///   `<textarea>`).
/// - Tracks fenced code blocks (```` ``` ```` / `~~~`), display math blocks
///   (`$$` / `\[`), and `<details>` HTML blocks so blank lines inside them
///   never trigger a premature split.
///
/// Pass [ignoreCrossBlockConstructs] to split even when such constructs are
/// present. The chunks then no longer parse to the same result as the whole
/// document (a reference link loses its definition), so this is only for
/// isolating a chunk the parser cannot handle.
///
/// [bracketMath] and [dollarMath] say whether `\[` and `$$` lines open display
/// math, and must match the options of the parser the chunks are meant for.
List<String> splitMarkdownBlocks(
  String text, {
  bool ignoreCrossBlockConstructs = false,
  bool bracketMath = true,
  bool dollarMath = true,
}) {
  if (text.isEmpty) return const [];

  final lines = _splitLinesKeepingNewlines(text);
  final blocks = <String>[];
  final current = StringBuffer();

  _Fence? fence;
  _BlockMathDelimiter? mathBlock;
  var detailsDepth = 0;
  var currentHasListItem = false;
  // Whether the line being read can still belong to a list item. Used only
  // to decide if a fence sits inside one; unlike [currentHasListItem] it is
  // dropped as soon as a block that cannot be item content starts.
  var listItemOpen = false;
  var currentHasContent = false;
  var sawBlankAfterContent = false;

  for (final line in lines) {
    final content = _stripLineEnding(line);

    if (fence != null) {
      if (fence.isClosedBy(content)) {
        current.write(line);
        fence = null;
        continue;
      }
      if (!fence.isEndedByContainer(content)) {
        current.write(line);
        continue;
      }
      // The list item holding the fence ended without a closing fence; this
      // line is ordinary content again.
      fence = null;
    }

    if (mathBlock != null) {
      current.write(line);
      if (mathBlock.isClosedBy(content)) mathBlock = null;
      continue;
    }

    if (detailsDepth > 0) {
      // A definition inside `<details>` is visible to the whole document.
      if (!ignoreCrossBlockConstructs &&
          _referenceDefinition.hasMatch(content)) {
        return [text];
      }
      current.write(line);
      fence = _Fence.tryOpen(content, inListItem: true);
      if (fence == null) {
        detailsDepth = _updateDetailsDepth(detailsDepth, content);
      }
      continue;
    }

    // Cross-block definitions and spanning raw HTML blocks disable splitting.
    // Only inspected outside fences, math blocks, and `<details>`.
    if (!ignoreCrossBlockConstructs && _hasCrossBlockConstruct(content)) {
      return [text];
    }

    if (_isBlank(content)) {
      current.write(line);
      if (currentHasContent) sawBlankAfterContent = true;
      continue;
    }

    if (sawBlankAfterContent &&
        _startsNewBlock(content, currentHasListItem: currentHasListItem)) {
      blocks.add(current.toString());
      current.clear();
      currentHasListItem = false;
      listItemOpen = false;
    }
    sawBlankAfterContent = false;
    currentHasContent = true;

    current.write(line);
    if (_isListItem(content)) {
      currentHasListItem = true;
      listItemOpen = true;
    } else if (_endsListItem(content)) {
      listItemOpen = false;
    }

    fence = _Fence.tryOpen(content, inListItem: listItemOpen);
    if (fence != null) continue;

    mathBlock = _BlockMathDelimiter.tryOpen(
      content,
      bracket: bracketMath,
      dollar: dollarMath,
    );
    if (mathBlock != null) continue;

    detailsDepth = _updateDetailsDepth(detailsDepth, content);
  }

  if (current.isNotEmpty) blocks.add(current.toString());
  return blocks;
}

/// Guards an in-progress streaming Markdown string against incomplete trailing
/// block syntax that would otherwise flicker visually as tokens arrive.
///
/// Specifically holds (omits from the returned tail):
/// 1. Outside a fence/math block:
///    - A trailing line with no newline yet that looks like a partial opening
///      fence (1-2 backticks/tildes, or 3+ backticks/tildes with an incomplete
///      info-string line).
///    - A trailing line with no newline yet that opens display math (`$$` or
///      `\[`) before its first newline arrives.
/// 2. Inside an open fenced code block:
///    - A trailing line with no newline yet containing a partial closing fence
///      run (`1 .. openingLength - 1` matching fence characters, optionally
///      indented), preventing stray `` ` `` / `` `` `` flicker at the bottom of
///      the code block before the closing fence completes.
///    - A final backslash with nothing after it yet (half of an escape, of
///      `\(`, or of a hard break).
/// 3. Inside an open display math block:
///    - A trailing line with no newline yet containing a partial closing
///      delimiter (`$` inside `$$`, or `\` inside `\[`).
///
/// Complete inputs ending in `\n` or without partial trailing syntax are
/// returned unchanged.
String sanitizeStreamingTail(
  String text, {
  bool bracketMath = true,
  bool dollarMath = true,
}) {
  if (text.isEmpty) return text;
  final lastCodeUnit = text.codeUnitAt(text.length - 1);
  // A newline terminates the last line, so no trailing line is mid-token.
  if (lastCodeUnit == 0x0A || lastCodeUnit == 0x0D) return text;

  final lastLineFeed = text.lastIndexOf('\n');
  final lastCarriageReturn = text.lastIndexOf('\r');
  final lastNewline = lastLineFeed > lastCarriageReturn
      ? lastLineFeed
      : lastCarriageReturn;
  final trailingStart = lastNewline + 1;
  final trailingLine = text.substring(trailingStart);

  // Scan completed lines (everything before trailingLine) to know whether we
  // are currently inside an open fenced code block or display math block.
  _Fence? openFence;
  _BlockMathDelimiter? openMath;
  var sawListItem = false;

  for (final rawLine in _splitLinesKeepingNewlines(
    text.substring(0, trailingStart),
  )) {
    final content = _stripLineEnding(rawLine);

    if (openFence != null) {
      if (openFence.isClosedBy(content)) {
        openFence = null;
        continue;
      }
      if (!openFence.isEndedByContainer(content)) continue;
      openFence = null;
    }
    if (openMath != null) {
      if (openMath.isClosedBy(content)) openMath = null;
      continue;
    }

    if (_isListItem(content)) {
      sawListItem = true;
    } else if (_endsListItem(content)) {
      sawListItem = false;
    }
    openFence = _Fence.tryOpen(content, inListItem: sawListItem);
    if (openFence != null) continue;
    openMath = _BlockMathDelimiter.tryOpen(
      content,
      bracket: bracketMath,
      dollar: dollarMath,
    );
  }

  if (openFence != null) {
    if (openFence.isPartialClosingRun(trailingLine)) {
      return text.substring(0, trailingStart);
    }
    return text;
  }

  if (openMath != null) {
    if (openMath.isPartialClosingRun(trailingLine)) {
      return text.substring(0, trailingStart);
    }
    return text;
  }

  if (_isPartialOpeningFenceLine(trailingLine, inListItem: sawListItem) ||
      _isPartialOpeningMathLine(
        trailingLine,
        bracket: bracketMath,
        dollar: dollarMath,
      )) {
    return text.substring(0, trailingStart);
  }

  // A backslash with nothing after it yet is half of an escape, of `\(`, or
  // of a hard break. Hold it until the next character says which: shown
  // alone it flickers, and `package:markdown` throws on a paragraph that
  // starts with `[` and ends with one.
  var trailingBackslashes = 0;
  for (var i = text.length - 1; i >= trailingStart; i--) {
    if (text.codeUnitAt(i) != 0x5C) break;
    trailingBackslashes++;
  }
  if (trailingBackslashes.isOdd) {
    return text.substring(0, text.length - 1);
  }

  return text;
}

// Also inside block quotes and list items, and with escaped brackets in the
// label. Matching too much only costs a split; matching too little separates
// a link from its definition.
final _referenceDefinition = RegExp(
  r'^[ \t]*(?:>[ \t]*)*(?:(?:[-*+]|\d{1,9}[.)])[ \t]+)?\[(?:[^\]\\]|\\.)+\]:',
);
final _spanningHtmlBlock = RegExp(
  r'^ {0,3}<(!--|\?|!\[CDATA\[|![A-Za-z]|(script|pre|style|textarea)([\s>]|$))',
  caseSensitive: false,
);
final _listItem = RegExp(r'^ {0,3}([-*+]|\d{1,9}[.)])([ \t]|$)');
final _nonItemBlockStart = RegExp(
  r'^(?:>|#{1,6}(?:[ \t]|$)|<|(?:[-*_][ \t]*){3,}$)',
);
final _fenceOpen = RegExp(r'^([ \t]*)(`{3,}|~{3,})(.*)$');
final _partialFenceStart = RegExp(r'^[ \t]*(`{1,2}|~{1,2})$');
final _detailsBlockOpenLine = RegExp(
  r'^ {0,3}<details(?:\s[^>]*)?>',
  caseSensitive: false,
);
final _detailsOpenTag = RegExp(r'<details(?:\s[^>]*)?>', caseSensitive: false);
final _detailsCloseTag = RegExp(r'</details\s*>', caseSensitive: false);
final _dollarMathOnlyLine = RegExp(r'^ {0,3}\$\$[ \t]*$');
final _bracketMathOnlyOpen = RegExp(r'^ {0,3}\\\[[ \t]*$');
final _bracketMathSingleLine = RegExp(r'^ {0,3}\\\[.*\\\][ \t]*$');
final _bracketMathCloseLine = RegExp(r'\\\][ \t]*$');
final _partialDollarClose = RegExp(r'^ {0,3}\$$');
final _partialBracketClose = RegExp(r'^ {0,3}\\$');

bool _hasCrossBlockConstruct(String line) {
  return _referenceDefinition.hasMatch(line) ||
      _spanningHtmlBlock.hasMatch(line);
}

bool _startsNewBlock(String line, {required bool currentHasListItem}) {
  // Indented lines may continue a list item or form an indented code block
  // that merges with the preceding one; keep them with the current block.
  if (line.startsWith(' ') || line.startsWith('\t')) return false;
  // A list item after a blank line continues a (loose) list.
  if (currentHasListItem && _isListItem(line)) return false;
  return true;
}

bool _isListItem(String line) => _listItem.hasMatch(line);

/// Whether an unindented [line] starts a block that cannot be part of a list
/// item (a quote, heading, rule or raw HTML). A plain text line does not
/// count: it may be a lazy continuation of the item's paragraph.
bool _endsListItem(String line) => _nonItemBlockStart.hasMatch(line);

bool _isBlank(String line) => line.trim().isEmpty;

bool _isPartialOpeningFenceLine(String line, {required bool inListItem}) {
  final partial = _partialFenceStart.firstMatch(line);
  if (partial != null) {
    return inListItem || _indentWidth(_leadingWhitespace(line)) <= 3;
  }
  final match = _fenceOpen.firstMatch(line);
  if (match == null) return false;
  if (!inListItem && _indentWidth(match.group(1)!) > 3) return false;
  final marker = match.group(2)!;
  final info = match.group(3)!;
  // Backtick fences cannot contain backticks in the info string (e.g. ```` ```foo` ````).
  if (marker.startsWith('`') && info.contains('`')) return false;
  return true;
}

bool _isPartialOpeningMathLine(
  String line, {
  required bool bracket,
  required bool dollar,
}) {
  return (dollar && _dollarMathOnlyLine.hasMatch(line)) ||
      (bracket && _bracketMathOnlyOpen.hasMatch(line));
}

String _leadingWhitespace(String line) {
  var end = 0;
  while (end < line.length &&
      (line.codeUnitAt(end) == 0x20 || line.codeUnitAt(end) == 0x09)) {
    end++;
  }
  return line.substring(0, end);
}

int _updateDetailsDepth(int depth, String line) {
  if (depth == 0 && !_detailsBlockOpenLine.hasMatch(line)) {
    return 0;
  }
  final lower = line.toLowerCase();
  if (!lower.contains('<details') && !lower.contains('</details')) {
    return depth;
  }
  final opens = _detailsOpenTag.allMatches(line).length;
  final closes = _detailsCloseTag.allMatches(line).length;
  final next = depth + opens - closes;
  return next < 0 ? 0 : next;
}

String _stripLineEnding(String line) {
  var end = line.length;
  if (end > 0 && line.codeUnitAt(end - 1) == 0x0A) end--;
  if (end > 0 && line.codeUnitAt(end - 1) == 0x0D) end--;
  return line.substring(0, end);
}

/// Splits at `\n`, `\r\n` and a lone `\r`, which the parser also treats as
/// a line ending.
List<String> _splitLinesKeepingNewlines(String text) {
  final lines = <String>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit == 0x0A) {
      lines.add(text.substring(start, i + 1));
      start = i + 1;
    } else if (unit == 0x0D) {
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) i++;
      lines.add(text.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < text.length) lines.add(text.substring(start));
  return lines;
}

class _Fence {
  const _Fence(this.char, this.length, this.indent, {required this.inListItem});

  final String char;
  final int length;
  final int indent;

  /// Whether the fence was opened as content of a list item (or `<details>`).
  final bool inListItem;

  /// At the top level a fence opens with at most three spaces of indentation;
  /// four or more make an indented code line whose backticks are just text.
  /// Inside a list item the fence sits at the item's content column, so any
  /// indentation is accepted there.
  static _Fence? tryOpen(String line, {required bool inListItem}) {
    final match = _fenceOpen.firstMatch(line);
    if (match == null) return null;
    if (!inListItem && _indentWidth(match.group(1)!) > 3) return null;
    final marker = match.group(2)!;
    final info = match.group(3)!;
    // Backtick fences may not have backticks in the info string.
    if (marker.startsWith('`') && info.contains('`')) return null;
    return _Fence(
      marker[0],
      marker.length,
      _indentWidth(match.group(1)!),
      inListItem: inListItem,
    );
  }

  /// Whether [line] leaves the list item this fence was opened in. A fence is
  /// closed by the end of its container even without a closing fence line.
  bool isEndedByContainer(String line) {
    if (!inListItem || indent == 0 || _isBlank(line)) return false;
    return _indentWidth(_leadingWhitespace(line)) < indent;
  }

  bool isClosedBy(String line) {
    final match = _fenceOpen.firstMatch(line);
    if (match == null) return false;
    final marker = match.group(2)!;
    if (marker[0] != char || marker.length < length) return false;
    if (match.group(3)!.trim().isNotEmpty) return false;
    final maxIndent = indent > 3 ? indent : 3;
    return _indentWidth(match.group(1)!) <= maxIndent;
  }

  /// Whether [line] is a partial closing fence run (`1 .. length - 1` matching
  /// characters with optional indentation) that has not yet completed.
  bool isPartialClosingRun(String line) {
    var i = 0;
    while (i < line.length) {
      final code = line.codeUnitAt(i);
      if (code != 0x20 && code != 0x09) break;
      i++;
    }
    if (i >= line.length) return false;

    final maxIndent = indent > 3 ? indent : 3;
    if (_indentWidth(line.substring(0, i)) > maxIndent) return false;

    final expected = char.codeUnitAt(0);
    var runLength = 0;
    while (i < line.length && line.codeUnitAt(i) == expected) {
      runLength++;
      i++;
    }
    if (i != line.length) return false;
    return runLength > 0 && runLength < length;
  }
}

enum _BlockMathKind { dollar, bracket }

class _BlockMathDelimiter {
  const _BlockMathDelimiter(this.kind);

  final _BlockMathKind kind;

  static _BlockMathDelimiter? tryOpen(
    String line, {
    required bool bracket,
    required bool dollar,
  }) {
    if (dollar && _dollarMathOnlyLine.hasMatch(line)) {
      return const _BlockMathDelimiter(_BlockMathKind.dollar);
    }
    if (bracket &&
        _bracketMathOnlyOpen.hasMatch(line) &&
        !_bracketMathSingleLine.hasMatch(line)) {
      return const _BlockMathDelimiter(_BlockMathKind.bracket);
    }
    return null;
  }

  bool isClosedBy(String line) {
    return switch (kind) {
      _BlockMathKind.dollar => _dollarMathOnlyLine.hasMatch(line),
      _BlockMathKind.bracket => _bracketMathCloseLine.hasMatch(line),
    };
  }

  bool isPartialClosingRun(String line) {
    return switch (kind) {
      _BlockMathKind.dollar => _partialDollarClose.hasMatch(line),
      _BlockMathKind.bracket => _partialBracketClose.hasMatch(line),
    };
  }
}

int _indentWidth(String whitespace) {
  var width = 0;
  for (final unit in whitespace.codeUnits) {
    width += unit == 0x09 ? 4 - (width % 4) : 1;
  }
  return width;
}
