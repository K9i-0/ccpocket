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
  // Content column of the list item the line being read can still belong to,
  // or null outside one. Used only to decide if a fence sits inside the item;
  // unlike [currentHasListItem] it is dropped as soon as a block that cannot
  // be item content starts.
  int? listContentIndent;
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
      fence = _Fence.tryOpen(content, containerIndent: 0);
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
      listContentIndent = null;
    }
    sawBlankAfterContent = false;
    currentHasContent = true;

    current.write(line);
    final itemIndent = _listItemContentIndent(content);
    if (itemIndent != null) {
      currentHasListItem = true;
      listContentIndent = itemIndent;
    } else if (_endsListItem(content)) {
      listContentIndent = null;
    }

    fence = _Fence.tryOpen(content, containerIndent: listContentIndent);
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
/// syntax that would otherwise flicker visually as tokens arrive.
///
/// Specifically holds (omits from the returned tail):
/// 1. Outside a fence/math block:
///    - A table header row until its delimiter row is complete.
///    - Inline syntax on the last line that is missing its closing half:
///      `**bold`, `~~strike`, a code span, `[label](destination`. The opener
///      must be within 300 characters of the end; older ones are literal.
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
/// Text without partial trailing syntax is returned unchanged. The result is
/// always a prefix of [text]; once the stream ends, parse the full text
/// without `isStreaming` so nothing stays held.
String sanitizeStreamingTail(
  String text, {
  bool bracketMath = true,
  bool dollarMath = true,
}) {
  if (text.isEmpty) return text;

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
  int? listContentIndent;
  // The last two complete lines outside fences and math, for spotting a
  // table whose delimiter row has not arrived yet.
  String? lastLine;
  String? lineBeforeLast;
  var lastLineStart = 0;
  var scanned = 0;

  for (final rawLine in _splitLinesKeepingNewlines(
    text.substring(0, trailingStart),
  )) {
    final content = _stripLineEnding(rawLine);
    final lineStart = scanned;
    scanned += rawLine.length;

    if (openFence != null) {
      if (openFence.isClosedBy(content)) {
        openFence = null;
        lastLine = lineBeforeLast = null;
        continue;
      }
      if (!openFence.isEndedByContainer(content)) continue;
      openFence = null;
    }
    if (openMath != null) {
      if (openMath.isClosedBy(content)) openMath = null;
      lastLine = lineBeforeLast = null;
      continue;
    }
    lineBeforeLast = lastLine;
    lastLine = content;
    lastLineStart = lineStart;

    final itemIndent = _listItemContentIndent(content);
    if (itemIndent != null) {
      listContentIndent = itemIndent;
    } else if (_endsListItem(content)) {
      listContentIndent = null;
    }
    openFence = _Fence.tryOpen(content, containerIndent: listContentIndent);
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

  if (_isPartialOpeningFenceLine(
        trailingLine,
        containerIndent: listContentIndent,
      ) ||
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
  var end = trailingBackslashes.isOdd ? text.length - 1 : text.length;

  // A table only becomes a table once its delimiter row is complete. Until
  // then its header would show as a line of raw pipes.
  final tableStart = _pendingTableStart(
    trailingLine: text.substring(trailingStart, end),
    trailingStart: trailingStart,
    lastLine: lastLine,
    lastLineStart: lastLineStart,
    lineBeforeLast: lineBeforeLast,
  );
  if (tableStart != null) return text.substring(0, tableStart);

  // Inline syntax still missing its closing half: `**bold`, `` `code ``,
  // `[label](url`. Hold from the opener so the markers never show raw.
  final inlineStart = _unfinishedInlineStart(
    text.substring(trailingStart, end),
  );
  if (inlineStart != null) {
    end = trailingStart + inlineStart;
    // Holding may have exposed a backslash as the last character.
    var backslashes = 0;
    for (var i = end - 1; i >= trailingStart; i--) {
      if (text.codeUnitAt(i) != 0x5C) break;
      backslashes++;
    }
    if (backslashes.isOdd) end--;
  }

  return text.substring(0, end);
}

final _pipeLine = RegExp(r'^ {0,3}\|');
final _partialDelimiterRow = RegExp(r'^[ \t|:\-]*$');

int? _pendingTableStart({
  required String trailingLine,
  required int trailingStart,
  required String? lastLine,
  required int lastLineStart,
  required String? lineBeforeLast,
}) {
  final previousIsBlank = lastLine == null || _isBlank(lastLine);
  // The header row itself is still being written.
  if (previousIsBlank && _pipeLine.hasMatch(trailingLine)) {
    return trailingStart;
  }
  // The header row is complete and the delimiter row is not.
  if (lastLine != null &&
      _pipeLine.hasMatch(lastLine) &&
      (lineBeforeLast == null || _isBlank(lineBeforeLast)) &&
      _partialDelimiterRow.hasMatch(trailingLine)) {
    return lastLineStart;
  }
  return null;
}

/// How far back an unfinished inline construct may start and still be held.
/// Past this the opener is taken as literal text; without a bound a stray
/// `**` would hide the rest of a long paragraph until its line ends.
const int _inlineHoldLimit = 300;

/// Index in [line] where inline syntax that is still missing its closing
/// half begins, or null when there is none.
int? _unfinishedInlineStart(String line) {
  final length = line.length;
  int? openStrong;
  int? openStrike;
  int? result;

  void hold(int index) {
    if (result == null || index < result!) result = index;
  }

  var i = 0;
  while (i < length) {
    final unit = line.codeUnitAt(i);
    if (unit == 0x5C) {
      i += 2;
      continue;
    }
    if (unit == 0x60) {
      var run = 1;
      while (i + run < length && line.codeUnitAt(i + run) == 0x60) {
        run++;
      }
      final close = _closingBacktickRun(line, i + run, run);
      if (close < 0) {
        hold(i);
        break;
      }
      i = close + run;
      continue;
    }
    final isPair = i + 1 < length && line.codeUnitAt(i + 1) == unit;
    if (unit == 0x2A && isPair) {
      openStrong = openStrong == null ? i : null;
      i += 2;
      continue;
    }
    if (unit == 0x7E && isPair) {
      openStrike = openStrike == null ? i : null;
      i += 2;
      continue;
    }
    // `[!` is an alert marker, never a link.
    if (unit == 0x5B && i + 1 < length && line.codeUnitAt(i + 1) == 0x21) {
      i += 2;
      continue;
    }
    if (unit == 0x5B) {
      final start = i > 0 && line.codeUnitAt(i - 1) == 0x21 ? i - 1 : i;
      final labelEnd = line.indexOf(']', i + 1);
      if (labelEnd < 0) {
        hold(start);
        break;
      }
      if (labelEnd + 1 == length) {
        // `[label]` with nothing after it yet: a `(` may still follow.
        hold(start);
        break;
      }
      if (line.codeUnitAt(labelEnd + 1) == 0x28) {
        final destinationEnd = line.indexOf(')', labelEnd + 2);
        if (destinationEnd < 0) {
          hold(start);
          break;
        }
        i = destinationEnd + 1;
        continue;
      }
      i = labelEnd + 1;
      continue;
    }
    i++;
  }

  if (openStrong != null) hold(openStrong);
  if (openStrike != null) hold(openStrike);
  // A lone `*` or `~` at the very end may be the first half of a pair.
  if (length > 0) {
    final last = line.codeUnitAt(length - 1);
    final previous = length > 1 ? line.codeUnitAt(length - 2) : null;
    final lone =
        (last == 0x2A || last == 0x7E) && previous != last && previous != 0x5C;
    if (lone && result == null) hold(length - 1);
  }

  final start = result;
  if (start == null || length - start > _inlineHoldLimit) return null;
  return start;
}

int _closingBacktickRun(String line, int from, int run) {
  var i = from;
  while (i < line.length) {
    if (line.codeUnitAt(i) != 0x60) {
      i++;
      continue;
    }
    var length = 1;
    while (i + length < line.length && line.codeUnitAt(i + length) == 0x60) {
      length++;
    }
    if (length == run) return i;
    i += length;
  }
  return -1;
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
final _listItemParts = RegExp(
  r'^( {0,3})([-*+]|\d{1,9}[.)])(?:( +)(?=[^ ])|[ \t]*$)',
);
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

/// Column where the content of the list item starting on [line] begins, or
/// null when [line] does not start one.
int? _listItemContentIndent(String line) {
  final match = _listItemParts.firstMatch(line);
  if (match == null) return null;
  if (!_listItem.hasMatch(line)) return null;
  final spaces = match.group(3)?.length ?? 1;
  // Five or more spaces after the marker start an indented code block inside
  // the item, whose content column is one past the marker.
  return match.group(1)!.length +
      match.group(2)!.length +
      (spaces >= 1 && spaces <= 4 ? spaces : 1);
}

/// Whether an unindented [line] starts a block that cannot be part of a list
/// item (a quote, heading, rule or raw HTML). A plain text line does not
/// count: it may be a lazy continuation of the item's paragraph.
bool _endsListItem(String line) => _nonItemBlockStart.hasMatch(line);

bool _isBlank(String line) => line.trim().isEmpty;

bool _isPartialOpeningFenceLine(String line, {required int? containerIndent}) {
  final indent = _indentWidth(_leadingWhitespace(line));
  final inContainer = containerIndent != null && indent >= containerIndent;
  if (!inContainer && indent > 3) return false;
  if (_partialFenceStart.hasMatch(line)) return true;
  final match = _fenceOpen.firstMatch(line);
  if (match == null) return false;
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
  const _Fence(this.char, this.length, this.indent, {this.containerIndent});

  final String char;
  final int length;
  final int indent;

  /// Content column of the list item the fence was opened in, or null when it
  /// is not inside one. Zero for `<details>`, which a line cannot leave by
  /// indentation.
  final int? containerIndent;

  /// At the top level a fence opens with at most three spaces of indentation;
  /// four or more make an indented code line whose backticks are just text.
  /// A fence indented at least to the content column of the open list item
  /// ([containerIndent]) belongs to that item, however deep that is.
  static _Fence? tryOpen(String line, {required int? containerIndent}) {
    final match = _fenceOpen.firstMatch(line);
    if (match == null) return null;
    final fenceIndent = _indentWidth(match.group(1)!);
    final inContainer =
        containerIndent != null && fenceIndent >= containerIndent;
    if (!inContainer && fenceIndent > 3) return null;
    final marker = match.group(2)!;
    final info = match.group(3)!;
    // Backtick fences may not have backticks in the info string.
    if (marker.startsWith('`') && info.contains('`')) return null;
    return _Fence(
      marker[0],
      marker.length,
      fenceIndent,
      containerIndent: inContainer ? containerIndent : null,
    );
  }

  /// Whether [line] leaves the list item this fence was opened in. A fence is
  /// closed by the end of its container even without a closing fence line.
  bool isEndedByContainer(String line) {
    final container = containerIndent;
    if (container == null || container == 0 || _isBlank(line)) return false;
    return _indentWidth(_leadingWhitespace(line)) < container;
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
