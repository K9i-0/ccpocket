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
List<String> splitMarkdownBlocks(
  String text, {
  bool ignoreCrossBlockConstructs = false,
}) {
  if (text.isEmpty) return const [];

  final lines = _splitLinesKeepingNewlines(text);
  final blocks = <String>[];
  final current = StringBuffer();

  _Fence? fence;
  _BlockMathDelimiter? mathBlock;
  var detailsDepth = 0;
  var currentHasListItem = false;
  var currentHasContent = false;
  var sawBlankAfterContent = false;

  for (final line in lines) {
    final content = _stripLineEnding(line);

    if (fence != null) {
      current.write(line);
      if (fence.isClosedBy(content)) fence = null;
      continue;
    }

    if (mathBlock != null) {
      current.write(line);
      if (mathBlock.isClosedBy(content)) mathBlock = null;
      continue;
    }

    if (detailsDepth > 0) {
      current.write(line);
      fence = _Fence.tryOpen(content);
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
    }
    sawBlankAfterContent = false;
    currentHasContent = true;

    current.write(line);
    if (_isListItem(content)) currentHasListItem = true;

    fence = _Fence.tryOpen(content);
    if (fence != null) continue;

    mathBlock = _BlockMathDelimiter.tryOpen(content);
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
/// 3. Inside an open display math block:
///    - A trailing line with no newline yet containing a partial closing
///      delimiter (`$` inside `$$`, or `\` inside `\[`).
///
/// Complete inputs ending in `\n` or without partial trailing syntax are
/// returned unchanged.
String sanitizeStreamingTail(String text) {
  if (text.isEmpty) return text;
  final lastCodeUnit = text.codeUnitAt(text.length - 1);
  // A newline terminates the last line, so no trailing line is mid-token.
  if (lastCodeUnit == 0x0A || lastCodeUnit == 0x0D) return text;

  final lastNewline = text.lastIndexOf('\n');
  final trailingStart = lastNewline + 1;
  final trailingLine = text.substring(trailingStart);

  // Scan completed lines (everything before trailingLine) to know whether we
  // are currently inside an open fenced code block or display math block.
  _Fence? openFence;
  _BlockMathDelimiter? openMath;

  var lineStart = 0;
  while (lineStart < trailingStart) {
    final nl = text.indexOf('\n', lineStart);
    final rawLine = text.substring(lineStart, nl + 1);
    final content = _stripLineEnding(rawLine);
    lineStart = nl + 1;

    if (openFence != null) {
      if (openFence.isClosedBy(content)) openFence = null;
      continue;
    }
    if (openMath != null) {
      if (openMath.isClosedBy(content)) openMath = null;
      continue;
    }

    openFence = _Fence.tryOpen(content);
    if (openFence != null) continue;
    openMath = _BlockMathDelimiter.tryOpen(content);
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

  if (_isPartialOpeningFenceLine(trailingLine) ||
      _isPartialOpeningMathLine(trailingLine)) {
    return text.substring(0, trailingStart);
  }

  return text;
}

final _referenceDefinition = RegExp(r'^ {0,3}\[[^\]]+\]:');
final _spanningHtmlBlock = RegExp(
  r'^ {0,3}<(!--|\?|!\[CDATA\[|![A-Za-z]|(script|pre|style|textarea)([\s>]|$))',
  caseSensitive: false,
);
final _listItem = RegExp(r'^ {0,3}([-*+]|\d{1,9}[.)])([ \t]|$)');
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

bool _isBlank(String line) => line.trim().isEmpty;

bool _isPartialOpeningFenceLine(String line) {
  if (_partialFenceStart.hasMatch(line)) return true;
  final match = _fenceOpen.firstMatch(line);
  if (match == null) return false;
  final marker = match.group(2)!;
  final info = match.group(3)!;
  // Backtick fences cannot contain backticks in the info string (e.g. ```` ```foo` ````).
  if (marker.startsWith('`') && info.contains('`')) return false;
  return true;
}

bool _isPartialOpeningMathLine(String line) {
  return _dollarMathOnlyLine.hasMatch(line) ||
      _bracketMathOnlyOpen.hasMatch(line);
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

List<String> _splitLinesKeepingNewlines(String text) {
  final lines = <String>[];
  var start = 0;
  while (true) {
    final newline = text.indexOf('\n', start);
    if (newline < 0) {
      if (start < text.length) lines.add(text.substring(start));
      return lines;
    }
    lines.add(text.substring(start, newline + 1));
    start = newline + 1;
  }
}

class _Fence {
  const _Fence(this.char, this.length, this.indent);

  final String char;
  final int length;
  final int indent;

  /// Opens on any indentation: over-detecting a fence only prevents splits.
  static _Fence? tryOpen(String line) {
    final match = _fenceOpen.firstMatch(line);
    if (match == null) return null;
    final marker = match.group(2)!;
    final info = match.group(3)!;
    // Backtick fences may not have backticks in the info string.
    if (marker.startsWith('`') && info.contains('`')) return null;
    return _Fence(marker[0], marker.length, _indentWidth(match.group(1)!));
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

  static _BlockMathDelimiter? tryOpen(String line) {
    if (_dollarMathOnlyLine.hasMatch(line)) {
      return const _BlockMathDelimiter(_BlockMathKind.dollar);
    }
    if (_bracketMathOnlyOpen.hasMatch(line) &&
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
