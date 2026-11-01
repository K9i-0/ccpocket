import 'dart:math' as math;

import '../../utils/diff_parser.dart';
import '../media_feedback/state/media_feedback_state.dart';

/// Lines kept in a comment excerpt. Longer ranges are still commented as a
/// whole ([CodeAnchor.lineCount]) but only the beginning is quoted.
const maxCodeExcerptLines = 40;

String diffLineText(DiffLine line) => switch (line.type) {
  DiffLineType.addition => '+${line.content}',
  DiffLineType.deletion => '-${line.content}',
  DiffLineType.context => ' ${line.content}',
};

FeedbackMedia codeFeedbackMedia({
  required String projectPath,
  required String filePath,
  required DiffSource source,
}) => FeedbackMedia(
  key: 'code:${source.name}:$projectPath:$filePath',
  label: filePath.split('/').last,
  isCode: true,
  path: filePath,
  projectPath: projectPath,
);

/// Anchor for hunk lines [first]..[last] (inclusive, any order).
CodeAnchor anchorForLines(
  DiffHunk hunk,
  int first,
  int last,
  DiffSource source,
) {
  final start = math.max(0, math.min(first, last));
  final end = math.min(hunk.lines.length - 1, math.max(first, last));
  final lines = hunk.lines.sublist(start, end + 1);
  final newNumbers = lines.map((l) => l.newLineNumber).whereType<int>();
  final side = newNumbers.isEmpty ? DiffSide.oldSide : DiffSide.newSide;
  final numbers = side == DiffSide.newSide
      ? newNumbers.toList()
      : lines.map((l) => l.oldLineNumber).whereType<int>().toList();
  return CodeAnchor(
    source: source,
    side: side,
    startLine: numbers.firstOrNull ?? 0,
    endLine: numbers.lastOrNull ?? 0,
    lineCount: lines.length,
    hunkHeader: hunk.header,
    excerpt: lines.take(maxCodeExcerptLines).map(diffLineText).join('\n'),
  );
}

typedef CodePlacement = ({int hunkIdx, int start, int end});

/// Finds where [anchor] is in the current diff of [file].
///
/// The excerpt must appear unchanged; among matches the one closest to the
/// original line number wins. Returns null when the commented lines changed
/// or disappeared, in which case the comment is shown as outdated.
CodePlacement? locateCodeAnchor(DiffFile file, CodeAnchor anchor) {
  final excerpt = anchor.excerpt.split('\n');
  CodePlacement? best;
  var bestDistance = 1 << 30;
  for (var h = 0; h < file.hunks.length; h++) {
    final lines = file.hunks[h].lines;
    final texts = lines.map(diffLineText).toList();
    for (var i = 0; i + anchor.lineCount <= texts.length; i++) {
      var matches = true;
      for (var j = 0; j < excerpt.length; j++) {
        if (texts[i + j] != excerpt[j]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      final range = lines.sublist(i, i + anchor.lineCount);
      final number = anchor.side == DiffSide.newSide
          ? range.map((l) => l.newLineNumber).whereType<int>().firstOrNull
          : range.map((l) => l.oldLineNumber).whereType<int>().firstOrNull;
      final distance = ((number ?? 0) - anchor.startLine).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = (hunkIdx: h, start: i, end: i + anchor.lineCount - 1);
      }
    }
  }
  return best;
}

class FileCodeComments {
  /// hunk index → index of the last commented line → comments shown below it.
  final Map<int, Map<int, List<MediaFeedback>>> placed;
  final List<MediaFeedback> outdated;
  const FileCodeComments(this.placed, this.outdated);
}

FileCodeComments layoutCodeComments(
  DiffFile file,
  Iterable<MediaFeedback> comments,
) {
  final placed = <int, Map<int, List<MediaFeedback>>>{};
  final outdated = <MediaFeedback>[];
  for (final comment in comments) {
    final anchor = comment.code;
    final placement = anchor == null ? null : locateCodeAnchor(file, anchor);
    if (placement == null) {
      outdated.add(comment);
      continue;
    }
    placed
        .putIfAbsent(placement.hunkIdx, () => {})
        .putIfAbsent(placement.end, () => [])
        .add(comment);
  }
  return FileCodeComments(placed, outdated);
}
