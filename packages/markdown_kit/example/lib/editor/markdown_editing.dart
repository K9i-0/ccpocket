import 'package:flutter/services.dart';

// Editing commands for Markdown source: what the toolbar buttons and the
// Enter and Tab keys do. Each one takes the current text and selection and
// returns the next, so they can be tested without a text field.

/// A line prefix the toolbar can switch on and off.
enum LineStyle {
  /// `- item`
  bullet,

  /// `1. item`
  ordered,

  /// `- [ ] item`
  task,

  /// `> quote`
  quote,
}

/// Wraps the selection in [marker] (`**`, `*`, `` ` `` or `~~`), or removes
/// the marker when the selection already has it.
///
/// With nothing selected, inserts an empty pair and leaves the caret inside.
TextEditingValue toggleInline(TextEditingValue value, String marker) {
  final text = value.text;
  final selection = _normalized(value);
  var start = selection.start;
  var end = selection.end;

  // Selection that includes its own markers: `**bold**` selected whole.
  final selected = text.substring(start, end);
  if (selected.length >= marker.length * 2 &&
      _hasMarker(selected, marker, atStart: true) &&
      _hasMarker(selected, marker, atStart: false)) {
    final inner = selected.substring(
      marker.length,
      selected.length - marker.length,
    );
    return _replace(value, start, end, inner, selectFrom: 0);
  }

  // Selection just inside the markers: `bold` selected in `**bold**`.
  if (_hasMarker(text.substring(0, start), marker, atStart: false) &&
      _hasMarker(text.substring(end), marker, atStart: true)) {
    start -= marker.length;
    end += marker.length;
    return _replace(value, start, end, selected, selectFrom: 0);
  }

  return _replace(
    value,
    start,
    end,
    '$marker$selected$marker',
    selectFrom: marker.length,
    selectLength: selected.length,
  );
}

/// Whether [text] starts (or ends) with [marker] as a marker of its own, so
/// that `*` is not found in the `**` of bold text.
bool _hasMarker(String text, String marker, {required bool atStart}) {
  if (atStart ? !text.startsWith(marker) : !text.endsWith(marker)) {
    return false;
  }
  if (marker.length != 1) return true;
  final unit = marker.codeUnitAt(0);
  var run = 0;
  if (atStart) {
    while (run < text.length && text.codeUnitAt(run) == unit) {
      run++;
    }
  } else {
    while (run < text.length &&
        text.codeUnitAt(text.length - 1 - run) == unit) {
      run++;
    }
  }
  // `*` is emphasis on its own or as the third of `***`.
  return run.isOdd;
}

/// Turns the selection into a link and selects the address to type over.
TextEditingValue insertLink(TextEditingValue value) {
  final selection = _normalized(value);
  final selected = value.text.substring(selection.start, selection.end);
  final label = selected.isEmpty ? 'text' : selected;
  const address = 'https://';
  final replaced = _replace(
    value,
    selection.start,
    selection.end,
    '[$label]($address)',
  );
  final from = selected.isEmpty
      ? selection.start + 1
      : selection.start + label.length + 3;
  final length = selected.isEmpty ? label.length : address.length;
  return replaced.copyWith(
    selection: TextSelection(baseOffset: from, extentOffset: from + length),
  );
}

/// Puts the selected lines in a fenced code block, or starts an empty one.
TextEditingValue insertCodeBlock(TextEditingValue value) {
  final text = value.text;
  final selection = _normalized(value);
  final start = _lineStart(text, selection.start);
  final end = _lineEnd(text, selection.end);
  final body = text.substring(start, end);
  final before = start > 0 && !text.substring(0, start).endsWith('\n\n')
      ? '\n'
      : '';
  final after = end < text.length && !text.substring(end).startsWith('\n\n')
      ? '\n'
      : '';
  final replaced = _replace(value, start, end, '$before```\n$body\n```$after');
  // After the opening fence, where the language goes.
  final caret = start + before.length + 3;
  return replaced.copyWith(selection: TextSelection.collapsed(offset: caret));
}

/// Cycles the heading level of the line the caret is on: none, `#`, `##`,
/// `###`, none.
TextEditingValue cycleHeading(TextEditingValue value) {
  final text = value.text;
  final caret = _normalized(value).start;
  final start = _lineStart(text, caret);
  final end = _lineEnd(text, caret);
  final line = text.substring(start, end);
  final match = _heading.firstMatch(line)!;
  final level = (match.group(1) ?? match.group(2))?.length ?? 0;
  final body = line.substring(match.end);
  final next = level >= 3 ? 0 : level + 1;
  final prefix = next == 0 ? '' : '${'#' * next} ';
  final replaced = _replace(value, start, end, '$prefix$body');
  final column = (caret - start - match.end).clamp(0, body.length);
  return replaced.copyWith(
    selection: TextSelection.collapsed(offset: start + prefix.length + column),
  );
}

/// Makes every selected line a [style] line, or removes [style] when they all
/// are one already.
TextEditingValue toggleLineStyle(TextEditingValue value, LineStyle style) {
  final text = value.text;
  final selection = _normalized(value);
  final start = _lineStart(text, selection.start);
  var endAnchor = selection.end;
  // A selection that ends at the start of a line does not include that line.
  if (!selection.isCollapsed && _lineStart(text, endAnchor) == endAnchor) {
    endAnchor--;
  }
  final end = _lineEnd(text, endAnchor);
  final lines = text.substring(start, end).split('\n');

  bool has(String line) {
    final marker = _linePrefix.firstMatch(line)!;
    return switch (style) {
      LineStyle.bullet =>
        marker.group(3) != null &&
            marker.group(4) == null &&
            marker.group(5) == null,
      LineStyle.ordered => marker.group(4) != null,
      LineStyle.task => marker.group(5) != null,
      LineStyle.quote => marker.group(2) != null,
    };
  }

  final content = [
    for (final line in lines)
      if (line.trim().isNotEmpty) line,
  ];
  final remove = content.isNotEmpty && content.every(has);

  final result = <String>[];
  var number = 1;
  var caretShift = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty && lines.length > 1) {
      result.add(line);
      continue;
    }
    final match = _linePrefix.firstMatch(line)!;
    final indent = match.group(1)!;
    final quote = match.group(2) ?? '';
    final body = line.substring(match.end);
    final String next;
    if (style == LineStyle.quote) {
      final list = line.substring(indent.length + quote.length, match.end);
      next = remove ? '$indent$list$body' : '$indent> $list$body';
    } else if (remove) {
      next = '$indent$quote$body';
    } else {
      final marker = switch (style) {
        LineStyle.bullet => '- ',
        LineStyle.ordered => '${number++}. ',
        LineStyle.task => '- [ ] ',
        LineStyle.quote => '',
      };
      next = '$indent$quote$marker$body';
    }
    if (i == 0) caretShift = next.length - line.length;
    result.add(next);
  }

  final replacement = result.join('\n');
  final replaced = _replace(value, start, end, replacement);
  if (selection.isCollapsed) {
    final caret = (selection.start + caretShift).clamp(
      start,
      start + replacement.length,
    );
    return replaced.copyWith(selection: TextSelection.collapsed(offset: caret));
  }
  return replaced.copyWith(
    selection: TextSelection(
      baseOffset: start,
      extentOffset: start + replacement.length,
    ),
  );
}

/// Moves the selected lines one level in, or out with [outdent]. With only a
/// caret outside a list, inserts two spaces instead.
TextEditingValue indentLines(TextEditingValue value, {bool outdent = false}) {
  final text = value.text;
  final selection = _normalized(value);
  final start = _lineStart(text, selection.start);
  final firstLine = text.substring(start, _lineEnd(text, selection.start));
  final inList = _linePrefix.firstMatch(firstLine)!.group(3) != null;

  if (selection.isCollapsed && !inList && !outdent) {
    return _replace(
      value,
      selection.start,
      selection.end,
      '  ',
    ).copyWith(selection: TextSelection.collapsed(offset: selection.start + 2));
  }

  var endAnchor = selection.end;
  if (!selection.isCollapsed && _lineStart(text, endAnchor) == endAnchor) {
    endAnchor--;
  }
  final end = _lineEnd(text, endAnchor);
  final lines = text.substring(start, end).split('\n');
  final result = <String>[];
  var firstShift = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final String next;
    if (outdent) {
      var cut = 0;
      while (cut < 2 && cut < line.length && line.codeUnitAt(cut) == 0x20) {
        cut++;
      }
      next = line.substring(cut);
    } else {
      next = line.isEmpty ? line : '  $line';
    }
    if (i == 0) firstShift = next.length - line.length;
    result.add(next);
  }
  final replacement = result.join('\n');
  final replaced = _replace(value, start, end, replacement);
  if (selection.isCollapsed) {
    final caret = selection.start + firstShift;
    return replaced.copyWith(
      selection: TextSelection.collapsed(offset: caret < start ? start : caret),
    );
  }
  return replaced.copyWith(
    selection: TextSelection(
      baseOffset: start,
      extentOffset: start + replacement.length,
    ),
  );
}

/// What pressing Enter should give instead of a bare line break, or null to
/// leave [next] as typed.
///
/// [previous] and [next] are the values before and after the key. On a list
/// item or quote line the new line gets the same marker (the next number for
/// an ordered list, an unchecked box for a task). On an item that is still
/// empty, the marker is removed instead, which ends the list.
TextEditingValue? continueOnEnter(
  TextEditingValue previous,
  TextEditingValue next,
) {
  if (next.composing.isValid || !next.selection.isCollapsed) return null;
  final caret = next.selection.baseOffset;
  final before = _normalized(previous);
  if (caret != before.start + 1) return null;
  final text = next.text;
  if (text.length != previous.text.length - (before.end - before.start) + 1 ||
      text.codeUnitAt(caret - 1) != 0x0A) {
    return null;
  }

  final lineStart = _lineStart(text, caret - 1);
  final line = text.substring(lineStart, caret - 1);
  if (_insideFence(text, lineStart)) {
    // Code keeps its indentation and nothing else.
    final indent = _leadingSpace.firstMatch(line)!.group(0)!;
    if (indent.isEmpty) return null;
    return _replace(next, caret, caret, indent).copyWith(
      selection: TextSelection.collapsed(offset: caret + indent.length),
    );
  }

  final match = _linePrefix.firstMatch(line)!;
  final indent = match.group(1)!;
  final quote = match.group(2) ?? '';
  final hasList = match.group(3) != null;
  if (quote.isEmpty && !hasList) {
    return null;
  }

  final body = line.substring(match.end);
  if (body.trim().isEmpty) {
    // An empty item: Enter ends the list instead of adding another.
    return _replace(
      next,
      lineStart,
      caret,
      '',
    ).copyWith(selection: TextSelection.collapsed(offset: lineStart));
  }

  final String marker;
  if (!hasList) {
    marker = '';
  } else if (match.group(5) != null) {
    marker = '${match.group(3)!.substring(0, 1)} [ ] ';
  } else if (match.group(4) != null) {
    final number = int.parse(match.group(4)!);
    final delimiter = match.group(3)!.contains(')') ? ')' : '.';
    marker = '${number + 1}$delimiter ';
  } else {
    marker = '${match.group(3)!.substring(0, 1)} ';
  }
  final prefix = '$indent$quote$marker';
  return _replace(
    next,
    caret,
    caret,
    prefix,
  ).copyWith(selection: TextSelection.collapsed(offset: caret + prefix.length));
}

/// Applies [continueOnEnter] as the user types. Works for a hardware Enter
/// key and for the one on a software keyboard alike, since both arrive as an
/// inserted line break.
class MarkdownEnterFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const MarkdownEnterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => continueOnEnter(oldValue, newValue) ?? newValue;
}

/// Line and column of the caret, both starting at 1.
({int line, int column}) caretLineAndColumn(TextEditingValue value) {
  final offset = value.selection.isValid
      ? value.selection.extentOffset.clamp(0, value.text.length)
      : 0;
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < offset; i++) {
    if (value.text.codeUnitAt(i) == 0x0A) {
      line++;
      lineStart = i + 1;
    }
  }
  return (line: line, column: offset - lineStart + 1);
}

/// Number of words in [text], counting a run of non-space characters as one.
int countWords(String text) {
  var words = 0;
  var inWord = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final space =
        unit == 0x20 || (unit >= 0x09 && unit <= 0x0D) || unit == 0x3000;
    if (!space && !inWord) words++;
    inWord = !space;
  }
  return words;
}

final _leadingSpace = RegExp(r'^[ \t]*');
final _heading = RegExp(r'^(?:(#{1,6})[ \t]+|(#{1,6})$)?');

/// Groups: 1 indentation, 2 quote markers, 3 list marker with its spaces,
/// 4 the number of an ordered item, 5 the task box.
final _linePrefix = RegExp(
  r'^([ \t]*)((?:>[ \t]?)+)?((?:[-*+]|(\d{1,9})[.)])[ \t]+(\[[ xX]\][ \t]+)?)?',
);
final _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,})');

bool _insideFence(String text, int offset) {
  String? open;
  var start = 0;
  while (start < offset) {
    var end = text.indexOf('\n', start);
    if (end < 0 || end > offset) end = offset;
    final match = _fenceLine.firstMatch(text.substring(start, end));
    if (match != null) {
      final marker = match.group(1)!;
      if (open == null) {
        open = marker;
      } else if (marker[0] == open[0] && marker.length >= open.length) {
        open = null;
      }
    }
    start = end + 1;
  }
  return open != null;
}

TextSelection _normalized(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid) {
    return TextSelection.collapsed(offset: value.text.length);
  }
  final length = value.text.length;
  return TextSelection(
    baseOffset: selection.start.clamp(0, length),
    extentOffset: selection.end.clamp(0, length),
  );
}

int _lineStart(String text, int offset) {
  if (offset <= 0) return 0;
  return text.lastIndexOf('\n', offset - 1) + 1;
}

int _lineEnd(String text, int offset) {
  final end = text.indexOf('\n', offset);
  return end < 0 ? text.length : end;
}

/// Replaces `[start, end)` with [replacement]. The new selection covers
/// [selectLength] characters from [selectFrom] inside the replacement, or all
/// of it from there when [selectLength] is omitted.
TextEditingValue _replace(
  TextEditingValue value,
  int start,
  int end,
  String replacement, {
  int? selectFrom,
  int? selectLength,
}) {
  final text = value.text.replaceRange(start, end, replacement);
  final from = start + (selectFrom ?? replacement.length);
  final to = selectFrom == null
      ? from
      : from + (selectLength ?? replacement.length - selectFrom);
  return TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: from, extentOffset: to),
  );
}
