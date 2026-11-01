/// Splits markdown into top-level blocks that can be parsed independently.
///
/// Used while streaming so that completed blocks can keep their already
/// built widgets and only the trailing, still-growing block is re-parsed.
///
/// The split is conservative: a boundary is only placed at blank lines that
/// are outside fenced code blocks and whose following line clearly starts a
/// new top-level block. When unsure, text stays in the same block. Each
/// returned block keeps its trailing blank lines, so `blocks.join()` always
/// equals [text].
///
/// Returns a single block when the text contains constructs that can affect
/// other blocks or span blank lines (link reference / footnote definitions,
/// multi-paragraph HTML blocks).
List<String> splitMarkdownBlocks(String text) {
  if (text.isEmpty) return const [];
  if (_hasCrossBlockConstruct(text)) return [text];

  final lines = _splitLinesKeepingNewlines(text);
  final blocks = <String>[];
  final current = StringBuffer();

  _Fence? fence;
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
  }

  if (current.isNotEmpty) blocks.add(current.toString());
  return blocks;
}

final _referenceDefinition = RegExp(r'^ {0,3}\[[^\]]+\]:', multiLine: true);
final _spanningHtmlBlock = RegExp(
  r'^ {0,3}<(!--|\?|!\[CDATA\[|![A-Za-z]|(script|pre|style|textarea)([\s>]|$))',
  multiLine: true,
  caseSensitive: false,
);
final _listItem = RegExp(r'^ {0,3}([-*+]|\d{1,9}[.)])([ \t]|$)');
final _fenceOpen = RegExp(r'^([ \t]*)(`{3,}|~{3,})(.*)$');

bool _hasCrossBlockConstruct(String text) {
  return _referenceDefinition.hasMatch(text) ||
      _spanningHtmlBlock.hasMatch(text);
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
  final String char;
  final int length;
  final int indent;

  const _Fence(this.char, this.length, this.indent);

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
}

int _indentWidth(String whitespace) {
  var width = 0;
  for (final unit in whitespace.codeUnits) {
    width += unit == 0x09 ? 4 - (width % 4) : 1;
  }
  return width;
}
