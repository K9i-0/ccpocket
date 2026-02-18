// Unified diff parser — converts raw `git diff` output into structured data.

enum DiffLineType { context, addition, deletion }

class DiffLine {
  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;

  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

class DiffHunk {
  final String header;
  final int oldStart;
  final int newStart;
  final List<DiffLine> lines;

  const DiffHunk({
    required this.header,
    required this.oldStart,
    required this.newStart,
    required this.lines,
  });

  /// Summary counts for the hunk.
  ({int added, int removed}) get stats {
    var added = 0;
    var removed = 0;
    for (final line in lines) {
      if (line.type == DiffLineType.addition) added++;
      if (line.type == DiffLineType.deletion) removed++;
    }
    return (added: added, removed: removed);
  }
}

class DiffFile {
  final String filePath;
  final List<DiffHunk> hunks;
  final bool isBinary;
  final bool isNewFile;
  final bool isDeleted;

  const DiffFile({
    required this.filePath,
    required this.hunks,
    this.isBinary = false,
    this.isNewFile = false,
    this.isDeleted = false,
  });

  /// Aggregate stats across all hunks.
  ({int added, int removed}) get stats {
    var added = 0;
    var removed = 0;
    for (final hunk in hunks) {
      final s = hunk.stats;
      added += s.added;
      removed += s.removed;
    }
    return (added: added, removed: removed);
  }
}

/// Regex for the hunk header: @@ -oldStart[,oldCount] +newStart[,newCount] @@
final _hunkHeaderRegex = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');

/// Parse unified diff text into a list of [DiffFile].
///
/// Handles:
/// - Standard `diff --git` format
/// - New / deleted files
/// - Binary file markers
/// - Multiple hunks per file
/// - Tool-result diffs (may lack `diff --git` header)
List<DiffFile> parseDiff(String diffText) {
  if (diffText.trim().isEmpty) return [];

  final lines = diffText.split('\n');

  // If the content has no `diff --git` header, treat it as a single-file diff
  // (common for tool_result content from Edit/FileEdit tools).
  if (!diffText.contains('diff --git')) {
    return [_parseSingleFileDiff(lines)];
  }

  final files = <DiffFile>[];
  var i = 0;

  while (i < lines.length) {
    // Find next `diff --git` header
    if (!lines[i].startsWith('diff --git ')) {
      i++;
      continue;
    }

    // Extract file path from `diff --git a/path b/path`
    final filePath = _extractFilePath(lines[i]);
    i++;

    var isBinary = false;
    var isNewFile = false;
    var isDeleted = false;

    // Skip metadata lines until we hit a hunk header or next diff
    while (i < lines.length && !lines[i].startsWith('diff --git ')) {
      if (lines[i].startsWith('Binary files')) {
        isBinary = true;
        i++;
        break;
      }
      if (lines[i].startsWith('new file mode')) {
        isNewFile = true;
      }
      if (lines[i].startsWith('deleted file mode')) {
        isDeleted = true;
      }
      if (lines[i].startsWith('@@')) break;
      i++;
    }

    if (isBinary) {
      files.add(
        DiffFile(
          filePath: filePath,
          hunks: const [],
          isBinary: true,
          isNewFile: isNewFile,
          isDeleted: isDeleted,
        ),
      );
      continue;
    }

    // Parse hunks
    final hunks = <DiffHunk>[];
    while (i < lines.length && !lines[i].startsWith('diff --git ')) {
      if (lines[i].startsWith('@@')) {
        final hunk = _parseHunk(lines, i);
        hunks.add(hunk.hunk);
        i = hunk.nextIndex;
      } else {
        i++;
      }
    }

    files.add(
      DiffFile(
        filePath: filePath,
        hunks: hunks,
        isNewFile: isNewFile,
        isDeleted: isDeleted,
      ),
    );
  }

  return files;
}

/// Parse a diff that lacks `diff --git` header (single-file tool result).
DiffFile _parseSingleFileDiff(List<String> lines) {
  var filePath = '';

  // Try to extract path from --- / +++ lines
  for (final line in lines) {
    if (line.startsWith('+++ b/')) {
      filePath = line.substring(6);
      break;
    }
    if (line.startsWith('+++ ') && !line.startsWith('+++ /dev/null')) {
      filePath = line.substring(4);
      break;
    }
  }

  final hunks = <DiffHunk>[];
  var i = 0;

  // Skip to first hunk header
  while (i < lines.length && !lines[i].startsWith('@@')) {
    i++;
  }

  while (i < lines.length) {
    if (lines[i].startsWith('@@')) {
      final hunk = _parseHunk(lines, i);
      hunks.add(hunk.hunk);
      i = hunk.nextIndex;
    } else {
      i++;
    }
  }

  // If no hunk headers found, treat all lines as a raw diff
  if (hunks.isEmpty && lines.isNotEmpty) {
    hunks.add(_parseRawDiffLines(lines));
  }

  return DiffFile(filePath: filePath, hunks: hunks);
}

/// Parse a single hunk starting at [startIndex].
({DiffHunk hunk, int nextIndex}) _parseHunk(
  List<String> lines,
  int startIndex,
) {
  final header = lines[startIndex];
  final match = _hunkHeaderRegex.firstMatch(header);
  final oldStart = match != null ? int.parse(match.group(1)!) : 1;
  final newStart = match != null ? int.parse(match.group(2)!) : 1;

  var oldLine = oldStart;
  var newLine = newStart;
  final diffLines = <DiffLine>[];
  var i = startIndex + 1;

  while (i < lines.length) {
    final line = lines[i];

    // Stop at next hunk or next file
    if (line.startsWith('@@') || line.startsWith('diff --git ')) break;

    if (line.startsWith('+')) {
      diffLines.add(
        DiffLine(
          type: DiffLineType.addition,
          content: line.substring(1),
          newLineNumber: newLine,
        ),
      );
      newLine++;
    } else if (line.startsWith('-')) {
      diffLines.add(
        DiffLine(
          type: DiffLineType.deletion,
          content: line.substring(1),
          oldLineNumber: oldLine,
        ),
      );
      oldLine++;
    } else if (line.startsWith(' ')) {
      final content = line.substring(1);
      diffLines.add(
        DiffLine(
          type: DiffLineType.context,
          content: content,
          oldLineNumber: oldLine,
          newLineNumber: newLine,
        ),
      );
      oldLine++;
      newLine++;
    } else if (line.startsWith(r'\')) {
      // "\ No newline at end of file" — skip
      i++;
      continue;
    } else if (line.isEmpty) {
      // Empty line — likely trailing newline, skip
      i++;
      continue;
    } else {
      // Unknown line format — treat as context
      diffLines.add(
        DiffLine(
          type: DiffLineType.context,
          content: line,
          oldLineNumber: oldLine,
          newLineNumber: newLine,
        ),
      );
      oldLine++;
      newLine++;
    }
    i++;
  }

  return (
    hunk: DiffHunk(
      header: header,
      oldStart: oldStart,
      newStart: newStart,
      lines: diffLines,
    ),
    nextIndex: i,
  );
}

/// Fallback: parse lines without hunk headers (raw +/- lines).
DiffHunk _parseRawDiffLines(List<String> lines) {
  var oldLine = 1;
  var newLine = 1;
  final diffLines = <DiffLine>[];

  for (final line in lines) {
    if (line.startsWith('+') && !line.startsWith('+++')) {
      diffLines.add(
        DiffLine(
          type: DiffLineType.addition,
          content: line.substring(1),
          newLineNumber: newLine,
        ),
      );
      newLine++;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      diffLines.add(
        DiffLine(
          type: DiffLineType.deletion,
          content: line.substring(1),
          oldLineNumber: oldLine,
        ),
      );
      oldLine++;
    } else if (!line.startsWith('---') && !line.startsWith('+++')) {
      diffLines.add(
        DiffLine(
          type: DiffLineType.context,
          content: line.startsWith(' ') ? line.substring(1) : line,
          oldLineNumber: oldLine,
          newLineNumber: newLine,
        ),
      );
      oldLine++;
      newLine++;
    }
  }

  return DiffHunk(header: '', oldStart: 1, newStart: 1, lines: diffLines);
}

/// Reconstruct unified diff text from selected hunks.
///
/// [files] is the full list of parsed diff files.
/// [selectedHunkKeys] contains keys in the format "$fileIdx:$hunkIdx".
/// Returns a valid unified diff string suitable for embedding in a code block.
/// Result of [reconstructDiff] containing @-mentions for fully selected files
/// and unified diff text for partially selected files.
class DiffSelection {
  /// File paths where all hunks are selected (use @mention).
  final List<String> mentions;

  /// Unified diff text for files with partial hunk selection.
  final String diffText;

  /// Original hunk keys for restoring selection state when re-entering
  /// the diff screen.
  final Set<String> selectedHunkKeys;

  const DiffSelection({
    required this.mentions,
    required this.diffText,
    this.selectedHunkKeys = const {},
  });

  bool get isEmpty => mentions.isEmpty && diffText.isEmpty;
}

DiffSelection reconstructDiff(
  List<DiffFile> files,
  Set<String> selectedHunkKeys,
) {
  if (selectedHunkKeys.isEmpty) {
    return const DiffSelection(mentions: [], diffText: '');
  }

  final mentions = <String>[];
  final buffer = StringBuffer();

  for (var fileIdx = 0; fileIdx < files.length; fileIdx++) {
    final file = files[fileIdx];

    // Collect selected hunk indices for this file.
    final selectedHunks = <int>[];
    for (var hunkIdx = 0; hunkIdx < file.hunks.length; hunkIdx++) {
      if (selectedHunkKeys.contains('$fileIdx:$hunkIdx')) {
        selectedHunks.add(hunkIdx);
      }
    }
    if (selectedHunks.isEmpty) continue;

    // If all hunks are selected, use @mention instead of diff text.
    if (selectedHunks.length == file.hunks.length && !file.isBinary) {
      mentions.add(file.filePath);
      continue;
    }

    // File header
    buffer.writeln('diff --git a/${file.filePath} b/${file.filePath}');
    if (file.isNewFile) buffer.writeln('new file mode 100644');
    if (file.isDeleted) buffer.writeln('deleted file mode 100644');

    if (file.isBinary) {
      buffer.writeln(
        'Binary files a/${file.filePath} and b/${file.filePath} differ',
      );
      continue;
    }

    buffer.writeln('--- a/${file.filePath}');
    buffer.writeln('+++ b/${file.filePath}');

    for (final hunkIdx in selectedHunks) {
      final hunk = file.hunks[hunkIdx];
      if (hunk.header.isNotEmpty) buffer.writeln(hunk.header);
      for (final line in hunk.lines) {
        final prefix = switch (line.type) {
          DiffLineType.addition => '+',
          DiffLineType.deletion => '-',
          DiffLineType.context => ' ',
        };
        buffer.writeln('$prefix${line.content}');
      }
    }
  }

  return DiffSelection(
    mentions: mentions,
    diffText: buffer.toString().trimRight(),
    selectedHunkKeys: Set<String>.from(selectedHunkKeys),
  );
}

// ─── Synthesize DiffFile from Edit/Write/MultiEdit tool input ────────────

/// Build a [DiffFile] from an Edit-family tool's `input` map.
///
/// Returns `null` for tools that are not edit-related or when input is
/// malformed.
DiffFile? synthesizeEditToolDiff(String toolName, Map<String, dynamic> input) {
  final filePath = (input['file_path'] ?? input['path'] ?? '') as String;

  return switch (toolName) {
    'Edit' => _synthesizeSingleEdit(filePath, input),
    'MultiEdit' => _synthesizeMultiEdit(filePath, input),
    'Write' => _synthesizeWrite(filePath, input),
    _ => null,
  };
}

DiffFile _synthesizeSingleEdit(String filePath, Map<String, dynamic> input) {
  final oldString = (input['old_string'] ?? '') as String;
  final newString = (input['new_string'] ?? '') as String;
  return DiffFile(
    filePath: filePath,
    hunks: [_buildHunkFromStrings(oldString, newString)],
  );
}

DiffFile _synthesizeMultiEdit(String filePath, Map<String, dynamic> input) {
  final edits = input['edits'];
  if (edits is! List) {
    return DiffFile(filePath: filePath, hunks: const []);
  }

  final hunks = <DiffHunk>[];
  for (final edit in edits) {
    if (edit is Map<String, dynamic>) {
      final oldString = (edit['old_string'] ?? '') as String;
      final newString = (edit['new_string'] ?? '') as String;
      hunks.add(_buildHunkFromStrings(oldString, newString));
    }
  }
  return DiffFile(filePath: filePath, hunks: hunks);
}

DiffFile _synthesizeWrite(String filePath, Map<String, dynamic> input) {
  final content = (input['content'] ?? '') as String;
  final lines = content.split('\n');
  final diffLines = <DiffLine>[];
  for (var i = 0; i < lines.length; i++) {
    diffLines.add(
      DiffLine(
        type: DiffLineType.addition,
        content: lines[i],
        newLineNumber: i + 1,
      ),
    );
  }
  return DiffFile(
    filePath: filePath,
    hunks: [DiffHunk(header: '', oldStart: 0, newStart: 1, lines: diffLines)],
    isNewFile: true,
  );
}

/// Build a single hunk from old/new strings.
DiffHunk _buildHunkFromStrings(String oldString, String newString) {
  final oldLines = oldString.isEmpty ? <String>[] : oldString.split('\n');
  final newLines = newString.isEmpty ? <String>[] : newString.split('\n');
  final diffLines = <DiffLine>[];

  var oldLineNum = 1;
  for (final line in oldLines) {
    diffLines.add(
      DiffLine(
        type: DiffLineType.deletion,
        content: line,
        oldLineNumber: oldLineNum++,
      ),
    );
  }
  var newLineNum = 1;
  for (final line in newLines) {
    diffLines.add(
      DiffLine(
        type: DiffLineType.addition,
        content: line,
        newLineNumber: newLineNum++,
      ),
    );
  }

  return DiffHunk(header: '', oldStart: 1, newStart: 1, lines: diffLines);
}

/// Reconstruct unified diff text from a [DiffFile].
///
/// Used to pass synthesized diff data to [DiffScreen].
String reconstructUnifiedDiff(DiffFile file) {
  final buffer = StringBuffer();
  if (file.isNewFile) {
    buffer.writeln('--- /dev/null');
  } else {
    buffer.writeln('--- a/${file.filePath}');
  }
  buffer.writeln('+++ b/${file.filePath}');
  for (final hunk in file.hunks) {
    if (hunk.header.isNotEmpty) buffer.writeln(hunk.header);
    for (final line in hunk.lines) {
      final prefix = switch (line.type) {
        DiffLineType.addition => '+',
        DiffLineType.deletion => '-',
        DiffLineType.context => ' ',
      };
      buffer.writeln('$prefix${line.content}');
    }
  }
  return buffer.toString().trimRight();
}

/// Extract file path from `diff --git a/path b/path`.
String _extractFilePath(String diffGitLine) {
  // Format: diff --git a/some/path b/some/path
  final parts = diffGitLine.split(' b/');
  if (parts.length >= 2) {
    return parts.last;
  }
  // Fallback: remove prefix
  return diffGitLine.replaceFirst('diff --git ', '').split(' ').last;
}
