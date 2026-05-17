/// Score a file or directory path against an @-mention query.
///
/// Lower score = better match. Returns -1 if no match.
int scoreFileMentionPath(String path, String query) {
  final q = query.toLowerCase().trim();
  final lower = path.toLowerCase();
  final displayPath = lower.endsWith('/')
      ? lower.substring(0, lower.length - 1)
      : lower;
  final fileName = displayPath.split('/').last;
  final nameWithoutExt = fileName.split('.').first;

  if (q.isEmpty) return 1;
  if (nameWithoutExt == q) return 0;
  if (fileName.startsWith(q)) return 1;
  if (nameWithoutExt.startsWith(q)) return 1;
  if (fileName.contains(q)) return 2;
  if (displayPath.split('/').any((s) => s.startsWith(q))) return 3;
  if (displayPath.contains(q)) return 4;

  final compactQuery = _compactForFuzzyMatch(q);
  if (compactQuery.length < 2) return -1;

  final compactPath = _compactForFuzzyMatch(displayPath);
  final fuzzyScore = _subsequenceGapScore(compactPath, compactQuery);
  return fuzzyScore == null ? -1 : 5 + fuzzyScore;
}

String _compactForFuzzyMatch(String value) {
  return value.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

int? _subsequenceGapScore(String candidate, String query) {
  var searchFrom = 0;
  var previous = -1;
  var first = -1;
  var gapScore = 0;

  for (final unit in query.codeUnits) {
    var found = -1;
    for (var i = searchFrom; i < candidate.length; i++) {
      if (candidate.codeUnitAt(i) == unit) {
        found = i;
        break;
      }
    }
    if (found == -1) return null;

    if (first == -1) {
      first = found;
    } else {
      gapScore += found - previous - 1;
    }
    previous = found;
    searchFrom = found + 1;
  }

  return first + gapScore;
}
