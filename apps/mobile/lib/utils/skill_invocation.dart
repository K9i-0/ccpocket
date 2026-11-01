import '../models/messages.dart' show Provider;
import '../models/skill_trigger_style.dart';
import '../widgets/slash_command_sheet.dart';

/// Skill names that can be invoked with either `/` or `$`, plus the builtin
/// slash commands that must never be rewritten.
///
/// Claude invokes skills as `/name` (only at the start of a message), while
/// Codex mentions them as `$name` anywhere in the text. The composer accepts
/// both, and [convertSkillTriggers] rewrites them to the agent's native form
/// right before the message leaves the app.
class SkillTriggerCatalog {
  final Provider provider;

  /// Skill names without a trigger prefix.
  final Set<String> skillNames;

  const SkillTriggerCatalog({
    required this.provider,
    this.skillNames = const {},
  });

  /// Build the catalog from the completion items a session reported.
  factory SkillTriggerCatalog.fromCompletionItems(
    Provider provider,
    Iterable<SlashCommand> items,
  ) {
    final names = <String>{};
    if (provider == Provider.codex) {
      final reserved = fallbackCodexSlashCommands
          .map((c) => c.command.substring(1))
          .toSet();
      for (final item in items) {
        if (item.skillInfo == null || !item.command.startsWith(r'$')) continue;
        final name = item.command.substring(1);
        if (!reserved.contains(name)) names.add(name);
      }
    } else {
      for (final item in items) {
        if (isClaudeSkillCommand(item)) names.add(item.command.substring(1));
      }
    }
    return SkillTriggerCatalog(provider: provider, skillNames: names);
  }

  bool get isEmpty => skillNames.isEmpty;
}

/// Whether a Claude `/` command is a skill or custom command that may also be
/// typed as `$name`. Builtins such as `/compact` keep their slash form only.
bool isClaudeSkillCommand(SlashCommand command) {
  if (!command.command.startsWith('/')) return false;
  if (command.category != SlashCommandCategory.skill &&
      command.category != SlashCommandCategory.project) {
    return false;
  }
  final name = command.command.substring(1);
  return name.isNotEmpty && !knownCommands.containsKey(name);
}

/// The agent's own trigger for skills.
String nativeSkillTrigger(Provider provider) =>
    provider == Provider.codex ? r'$' : '/';

/// The trigger the composer inserts for a skill picked from completion.
String composerSkillTrigger(Provider provider, SkillTriggerStyle style) {
  return switch (style) {
    SkillTriggerStyle.slash => '/',
    SkillTriggerStyle.dollar => r'$',
    SkillTriggerStyle.both => nativeSkillTrigger(provider),
  };
}

/// Rewrite skill tokens typed with the other agent's trigger into the native
/// form for [catalog.provider].
///
/// Only names in [catalog] are rewritten, so prices (`$5`), environment
/// variables (`$HOME`), paths (`/usr/bin`) and builtin commands stay intact.
/// Text inside Markdown code spans and fences is left untouched.
String convertSkillTriggers(String text, SkillTriggerCatalog catalog) {
  if (text.isEmpty || catalog.isEmpty) return text;
  final native = nativeSkillTrigger(catalog.provider);
  final foreign = native == '/' ? r'$' : '/';
  if (!text.contains(foreign)) return text;

  final protected = _codeRanges(text);
  final buffer = StringBuffer();
  var cursor = 0;
  var rangeIndex = 0;
  var index = 0;
  while (index < text.length) {
    while (rangeIndex < protected.length && protected[rangeIndex].$2 <= index) {
      rangeIndex++;
    }
    if (rangeIndex < protected.length && protected[rangeIndex].$1 <= index) {
      index = protected[rangeIndex].$2;
      continue;
    }
    if (text[index] != foreign || !_isBoundaryBefore(text, index)) {
      index++;
      continue;
    }
    var end = index + 1;
    while (end < text.length && _isNameChar(text.codeUnitAt(end))) {
      end++;
    }
    final name = _trimTrailingSeparators(text.substring(index + 1, end));
    end = index + 1 + name.length;
    if (name.isEmpty ||
        !catalog.skillNames.contains(name) ||
        !_isBoundaryAfter(text, end)) {
      index++;
      continue;
    }
    buffer
      ..write(text.substring(cursor, index))
      ..write(native)
      ..write(name);
    cursor = end;
    index = end;
  }
  if (cursor == 0) return text;
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

/// Skill names follow Codex's mention charset (`[A-Za-z0-9_:-]`).
bool _isNameChar(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x5F ||
    c == 0x2D ||
    c == 0x3A;

String _trimTrailingSeparators(String name) {
  var end = name.length;
  while (end > 0 && (name[end - 1] == ':' || name[end - 1] == '-')) {
    end--;
  }
  return name.substring(0, end);
}

bool _isBoundaryBefore(String text, int index) {
  if (index == 0) return true;
  final previous = text[index - 1];
  // Non-ASCII text (e.g. Japanese) directly before a token is a word break.
  return _isNonAscii(previous) || RegExp(r'[\s(\[{,;]').hasMatch(previous);
}

bool _isNonAscii(String char) => char.codeUnitAt(0) > 0x7F;

/// A token ends at whitespace, non-ASCII text, closing punctuation, or a
/// sentence-ending mark that is not followed by more path-like characters
/// (`/foo.txt`).
bool _isBoundaryAfter(String text, int end) {
  if (end >= text.length) return true;
  final next = text[end];
  if (RegExp(r'\s').hasMatch(next) ||
      _isNonAscii(next) ||
      _closingPunctuation.contains(next)) {
    return true;
  }
  if (next == '.' || next == ':') {
    if (end + 1 >= text.length) return true;
    final after = text[end + 1];
    return RegExp(r'\s').hasMatch(after) || _isNonAscii(after);
  }
  return false;
}

const _closingPunctuation = {')', ']', '}', ',', ';', '!', '?', '"', "'"};

/// Ranges covered by fenced code blocks and inline code spans.
List<(int, int)> _codeRanges(String text) {
  final ranges = <(int, int)>[];
  var index = 0;
  while (index < text.length) {
    if (text.startsWith('```', index)) {
      final close = text.indexOf('```', index + 3);
      final end = close < 0 ? text.length : close + 3;
      ranges.add((index, end));
      index = end;
      continue;
    }
    if (text[index] == '`') {
      final close = text.indexOf('`', index + 1);
      final newline = text.indexOf('\n', index + 1);
      if (close > 0 && (newline < 0 || close < newline)) {
        ranges.add((index, close + 1));
        index = close + 1;
        continue;
      }
    }
    index++;
  }
  return ranges;
}
