// Utilities for parsing and formatting slash-command messages that contain
// XML tags like <command-message>, <command-name>, and <command-args>.

final _commandNamePattern = RegExp(
  r'<command-name>\s*(.*?)\s*</command-name>',
  dotAll: true,
);
final _commandArgsPattern = RegExp(
  r'<command-args>\s*(.*?)\s*</command-args>',
  dotAll: true,
);

/// Parsed result of a command message.
class ParsedCommand {
  final String commandName;
  final String? args;

  const ParsedCommand({required this.commandName, this.args});

  /// CLI-style display: "/command args"
  String toDisplayText() {
    if (args != null && args!.isNotEmpty) {
      return '$commandName $args';
    }
    return commandName;
  }
}

/// Parse a command message containing XML tags.
/// Returns null if the text doesn't contain command XML tags.
ParsedCommand? parseCommandMessage(String text) {
  final nameMatch = _commandNamePattern.firstMatch(text);
  if (nameMatch == null) return null;
  final commandName = nameMatch.group(1)?.trim() ?? '';
  final argsMatch = _commandArgsPattern.firstMatch(text);
  final args = argsMatch?.group(1)?.trim();
  return ParsedCommand(commandName: commandName, args: args);
}

/// Strip command XML tags from text and return a clean display string.
/// If the text contains command tags, returns CLI-style "/command args".
/// Otherwise returns the original text unchanged.
String formatCommandText(String text) {
  final parsed = parseCommandMessage(text);
  if (parsed == null) return text;
  return parsed.toDisplayText();
}
