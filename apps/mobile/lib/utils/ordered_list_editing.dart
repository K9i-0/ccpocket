import 'package:flutter/widgets.dart';

final _listItemPattern = RegExp(
  r'^( *)(?:(\d{1,9})([.)])|([-*+]))([ \t]+)(.*)$',
);
final _fencePattern = RegExp(r'^ {0,3}(`{3,}|~{3,})');

/// Renumbers every ordered-list block intersecting [startOffset] and
/// [endOffset]. Each sibling sequence starts at 1 and nested sequences are
/// counted independently.
///
/// The returned value preserves the selection while accounting for number
/// markers whose digit count changed. Lists inside fenced code blocks are
/// intentionally ignored.
TextEditingValue renumberOrderedListsInRange(
  TextEditingValue value, {
  required int startOffset,
  required int endOffset,
  String? fenceReferenceText,
}) {
  if (value.text.isEmpty) return value;

  final lines = _linesOf(value.text);
  final rangeStart = startOffset.clamp(0, value.text.length);
  final rangeEnd = endOffset.clamp(rangeStart, value.text.length);
  final firstLine = _lineIndexAt(lines, rangeStart);
  final lastLine = _lineIndexAt(lines, rangeEnd);
  final fenceLines = _linesOf(fenceReferenceText ?? value.text);
  final fencedLines = _fencedLineIndexes(lines);
  if (fenceLines.length == lines.length) {
    fencedLines.addAll(_fencedLineIndexes(fenceLines));
  }
  final replacements = <_Replacement>[];

  for (final block in _listBlocks(lines, fencedLines)) {
    if (block.end < firstLine || block.start > lastLine) continue;
    replacements.addAll(_renumberBlock(lines, block.start, block.end));
  }

  return _applyReplacements(value, replacements);
}

/// Applies list continuation after a newline has already been inserted.
///
/// Returns `null` when the previous line is not a supported list item. An
/// empty top-level item exits the list; an empty nested item moves out one
/// level and continues the parent list.
TextEditingValue? completeListAfterNewline(TextEditingValue value) {
  final cursor = value.selection.baseOffset;
  if (!value.selection.isCollapsed || cursor < 1) return null;
  if (value.text[cursor - 1] != '\n') return null;

  final beforeNewline = value.text.substring(0, cursor - 1);
  final previousLineStart = beforeNewline.lastIndexOf('\n') + 1;
  final previousLine = beforeNewline.substring(previousLineStart);
  final lines = _linesOf(value.text);
  final previousLineIndex = _lineIndexAt(lines, cursor - 1);
  if (_fencedLineIndexes(lines).contains(previousLineIndex)) return null;
  final item = _parseListText(previousLine);
  if (item == null) return null;

  if (item.content.isNotEmpty) {
    final prefix = item.isOrdered
        ? '${item.indent}${item.number! + 1}${item.delimiter} '
        : '${item.indent}${item.bullet} ';
    return _insertAtCursor(value, prefix);
  }

  if (item.indent.isEmpty) {
    return _replaceEmptyItem(
      value,
      lineStart: previousLineStart,
      cursor: cursor,
      replacement: '',
    );
  }

  final parent = _findParentListItem(
    value.text,
    beforeLineOffset: previousLineStart,
    childIndent: item.indent.length,
  );
  if (parent == null) {
    return _replaceEmptyItem(
      value,
      lineStart: previousLineStart,
      cursor: cursor,
      replacement: '',
    );
  }

  final prefix = parent.isOrdered
      ? '${parent.indent}${parent.number! + 1}${parent.delimiter} '
      : '${parent.indent}${parent.bullet} ';
  final outdented = _replaceEmptyItem(
    value,
    lineStart: previousLineStart,
    cursor: cursor,
    replacement: prefix,
  );
  return renumberOrderedListsInRange(
    outdented,
    startOffset: previousLineStart,
    endOffset: previousLineStart + prefix.length,
  );
}

List<_Line> _linesOf(String text) {
  final lines = <_Line>[];
  var start = 0;
  for (var index = 0; index <= text.length; index++) {
    if (index == text.length || text.codeUnitAt(index) == 10) {
      lines.add(
        _Line(start: start, end: index, text: text.substring(start, index)),
      );
      start = index + 1;
    }
  }
  return lines;
}

int _lineIndexAt(List<_Line> lines, int offset) {
  for (var index = 0; index < lines.length; index++) {
    if (offset <= lines[index].end) return index;
  }
  return lines.length - 1;
}

Set<int> _fencedLineIndexes(List<_Line> lines) {
  final indexes = <int>{};
  String? fenceCharacter;
  var minimumFenceLength = 0;

  for (var index = 0; index < lines.length; index++) {
    final match = _fencePattern.firstMatch(lines[index].text);
    if (fenceCharacter == null) {
      if (match == null) continue;
      final marker = match.group(1)!;
      fenceCharacter = marker[0];
      minimumFenceLength = marker.length;
      indexes.add(index);
      continue;
    }

    indexes.add(index);
    final closingFence = RegExp(
      '^ {0,3}${RegExp.escape(fenceCharacter)}'
      '{$minimumFenceLength,}[ \\t]*\$',
    );
    if (closingFence.hasMatch(lines[index].text)) {
      fenceCharacter = null;
      minimumFenceLength = 0;
    }
  }
  return indexes;
}

List<_ListBlock> _listBlocks(List<_Line> lines, Set<int> fencedLines) {
  final blocks = <_ListBlock>[];
  var index = 0;
  while (index < lines.length) {
    final firstItem = fencedLines.contains(index)
        ? null
        : _parseListLine(lines[index]);
    if (firstItem == null) {
      index++;
      continue;
    }

    final rootIndent = firstItem.indent.length;
    var end = index;
    while (end + 1 < lines.length &&
        _belongsToListBlock(lines[end + 1], rootIndent, end + 1, fencedLines)) {
      end++;
    }
    blocks.add(_ListBlock(start: index, end: end));
    index = end + 1;
  }
  return blocks;
}

bool _belongsToListBlock(
  _Line line,
  int rootIndent,
  int lineIndex,
  Set<int> fencedLines,
) {
  if (fencedLines.contains(lineIndex) || line.text.trim().isEmpty) return false;
  final item = _parseListLine(line);
  if (item != null) return item.indent.length >= rootIndent;
  return _leadingSpaces(line.text) > rootIndent;
}

List<_Replacement> _renumberBlock(List<_Line> lines, int start, int end) {
  final replacements = <_Replacement>[];
  final counters = <int, _Counter>{};

  for (var index = start; index <= end; index++) {
    final line = lines[index];
    final item = _parseListLine(line);
    if (item == null) continue;
    counters.removeWhere((indent, _) => indent > item.indent.length);

    if (!item.isOrdered) {
      counters.remove(item.indent.length);
      continue;
    }

    final current = counters[item.indent.length];
    final number = current == null || current.delimiter != item.delimiter
        ? 1
        : current.nextNumber;
    counters[item.indent.length] = _Counter(
      nextNumber: number + 1,
      delimiter: item.delimiter,
    );

    final numberText = number.toString();
    if (item.numberText == numberText) continue;
    replacements.add(
      _Replacement(
        start: line.start + item.indent.length,
        end: line.start + item.indent.length + item.numberText!.length,
        text: numberText,
      ),
    );
  }
  return replacements;
}

_ParsedListItem? _parseListLine(_Line line) => _parseListText(line.text);

int _leadingSpaces(String line) {
  var count = 0;
  while (count < line.length && line.codeUnitAt(count) == 32) {
    count++;
  }
  return count;
}

_ParsedListItem? _parseListText(String line) {
  final match = _listItemPattern.firstMatch(line);
  if (match == null) return null;
  final numberText = match.group(2);
  return _ParsedListItem(
    indent: match.group(1)!,
    numberText: numberText,
    delimiter: match.group(3) ?? '',
    bullet: match.group(4) ?? '',
    content: match.group(6)!,
  );
}

_ParsedListItem? _findParentListItem(
  String text, {
  required int beforeLineOffset,
  required int childIndent,
}) {
  final lines = _linesOf(text.substring(0, beforeLineOffset));
  var parentIndentLimit = childIndent;
  for (var index = lines.length - 1; index >= 0; index--) {
    if (index == lines.length - 1 && lines[index].text.isEmpty) continue;
    final item = _parseListLine(lines[index]);
    if (item == null) {
      if (lines[index].text.trim().isEmpty ||
          _leadingSpaces(lines[index].text) == 0) {
        break;
      }
      parentIndentLimit = parentIndentLimit.clamp(
        0,
        _leadingSpaces(lines[index].text),
      );
      continue;
    }
    if (item.indent.length < parentIndentLimit) return item;
  }
  return null;
}

TextEditingValue _insertAtCursor(TextEditingValue value, String insertion) {
  final cursor = value.selection.baseOffset;
  return value.copyWith(
    text: value.text.replaceRange(cursor, cursor, insertion),
    selection: TextSelection.collapsed(offset: cursor + insertion.length),
    composing: TextRange.empty,
  );
}

TextEditingValue _replaceEmptyItem(
  TextEditingValue value, {
  required int lineStart,
  required int cursor,
  required String replacement,
}) => value.copyWith(
  text: value.text.replaceRange(lineStart, cursor, replacement),
  selection: TextSelection.collapsed(offset: lineStart + replacement.length),
  composing: TextRange.empty,
);

TextEditingValue _applyReplacements(
  TextEditingValue value,
  List<_Replacement> replacements,
) {
  if (replacements.isEmpty) return value;
  replacements.sort((a, b) => b.start.compareTo(a.start));

  var text = value.text;
  var baseOffset = value.selection.baseOffset;
  var extentOffset = value.selection.extentOffset;
  for (final replacement in replacements) {
    text = text.replaceRange(
      replacement.start,
      replacement.end,
      replacement.text,
    );
    baseOffset = _adjustOffset(baseOffset, replacement);
    extentOffset = _adjustOffset(extentOffset, replacement);
  }

  return value.copyWith(
    text: text,
    selection: TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      affinity: value.selection.affinity,
      isDirectional: value.selection.isDirectional,
    ),
    composing: TextRange.empty,
  );
}

int _adjustOffset(int offset, _Replacement replacement) {
  if (offset <= replacement.start) return offset;
  final delta = replacement.text.length - (replacement.end - replacement.start);
  if (offset >= replacement.end) return offset + delta;
  final relative = offset - replacement.start;
  return replacement.start + relative.clamp(0, replacement.text.length);
}

class _Line {
  final int start;
  final int end;
  final String text;

  const _Line({required this.start, required this.end, required this.text});
}

class _ListBlock {
  final int start;
  final int end;

  const _ListBlock({required this.start, required this.end});
}

class _ParsedListItem {
  final String indent;
  final String? numberText;
  final String delimiter;
  final String bullet;
  final String content;

  const _ParsedListItem({
    required this.indent,
    required this.numberText,
    required this.delimiter,
    required this.bullet,
    required this.content,
  });

  bool get isOrdered => numberText != null;
  int? get number => numberText == null ? null : int.parse(numberText!);
}

class _Counter {
  final int nextNumber;
  final String delimiter;

  const _Counter({required this.nextNumber, required this.delimiter});
}

class _Replacement {
  final int start;
  final int end;
  final String text;

  const _Replacement({
    required this.start,
    required this.end,
    required this.text,
  });
}
