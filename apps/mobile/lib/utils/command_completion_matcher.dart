final _commandSegmentSeparator = RegExp(r'[:\-_/]+');
final _commandCompactSeparator = RegExp(r'[:\-_/\s]+');

/// Score a command-like completion candidate against a typed query.
///
/// Lower scores are better. Returns -1 when the candidate should not match.
/// Both [candidate] and [query] include the trigger character (`/`, `$`, `@`).
int commandCompletionScore(String candidate, String query) {
  if (candidate.isEmpty || query.isEmpty) return -1;
  final command = candidate.toLowerCase();
  final typed = query.toLowerCase();
  if (command[0] != typed[0]) return -1;

  final commandBody = command.substring(1);
  final queryBody = typed.substring(1);
  if (queryBody.isEmpty) return 0;

  if (command == typed) return 0;
  if (command.startsWith(typed)) return 10;
  if (commandBody.startsWith(queryBody)) return 11;

  final segments = commandBody
      .split(_commandSegmentSeparator)
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  if (segments.any((segment) => segment == queryBody)) return 20;
  if (segments.any((segment) => segment.startsWith(queryBody))) return 30;
  if (segments.any((segment) => segment.contains(queryBody))) return 40;

  final compact = commandBody.replaceAll(_commandCompactSeparator, '');
  if (compact.contains(queryBody)) return 45;

  final initials = segments.map((segment) => segment[0]).join();
  if (initials.startsWith(queryBody)) return 50;

  if (queryBody.length >= 3) {
    final subsequence = _subsequenceScore(compact, queryBody);
    if (subsequence >= 0) return 60 + subsequence;
  }

  return -1;
}

List<T> rankCommandCompletions<T>(
  Iterable<T> candidates,
  String query,
  String Function(T candidate) commandOf,
) {
  if (query.length <= 1) {
    return candidates
        .where(
          (candidate) =>
              commandCompletionScore(commandOf(candidate), query) >= 0,
        )
        .toList(growable: false);
  }

  final matches = <_CommandCompletionMatch<T>>[];
  var index = 0;
  for (final candidate in candidates) {
    final command = commandOf(candidate);
    final score = commandCompletionScore(command, query);
    if (score >= 0) {
      matches.add(
        _CommandCompletionMatch(
          candidate: candidate,
          command: command,
          score: score,
          index: index,
        ),
      );
    }
    index++;
  }

  matches.sort((a, b) {
    final score = a.score.compareTo(b.score);
    if (score != 0) return score;
    final length = a.command.length.compareTo(b.command.length);
    if (length != 0) return length;
    final lexical = a.command.compareTo(b.command);
    if (lexical != 0) return lexical;
    return a.index.compareTo(b.index);
  });
  return matches.map((match) => match.candidate).toList(growable: false);
}

int _subsequenceScore(String text, String query) {
  var textIndex = 0;
  var lastMatch = -1;
  var gapPenalty = 0;

  for (var queryIndex = 0; queryIndex < query.length; queryIndex++) {
    final queryUnit = query.codeUnitAt(queryIndex);
    var found = -1;
    while (textIndex < text.length) {
      if (text.codeUnitAt(textIndex) == queryUnit) {
        found = textIndex;
        textIndex++;
        break;
      }
      textIndex++;
    }
    if (found < 0) return -1;
    if (lastMatch >= 0) {
      gapPenalty += found - lastMatch - 1;
    }
    lastMatch = found;
  }

  return gapPenalty;
}

class _CommandCompletionMatch<T> {
  final T candidate;
  final String command;
  final int score;
  final int index;

  const _CommandCompletionMatch({
    required this.candidate,
    required this.command,
    required this.score,
    required this.index,
  });
}
