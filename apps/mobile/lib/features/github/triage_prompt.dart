// The instruction text is read by the Japanese triage skill, not by the user.
// ignore_for_file: altive_lints_plugin/avoid_hardcoded_japanese

import '../../models/messages.dart' show Provider;
import '../../utils/skill_invocation.dart';

/// Name of the project skill that handles the request.
const triageSkillName = 'triage';

/// What the agent is asked to do with the selected items.
enum TriagePreset {
  /// The skill's own default for pull requests; adds no instruction.
  investigateAndMerge(''),
  handleAndRelease('対応してリリースまで'),
  contentOnly('内容だけ教えて'),
  checkResolvedAndClose('解決済みか確認してコメントしてクローズ');

  /// Instruction appended after the item numbers.
  final String instruction;
  const TriagePreset(this.instruction);
}

/// Builds `/triage <n1> <n2> ... <preset instruction> <free text>`.
///
/// Returns an empty string when no item is selected.
String buildTriagePrompt({
  required Iterable<int> numbers,
  TriagePreset preset = TriagePreset.investigateAndMerge,
  String note = '',
}) {
  final targets = numbers.toList();
  if (targets.isEmpty) return '';
  final trimmedNote = note.trim();
  return [
    '/$triageSkillName',
    ...targets.map((number) => '$number'),
    if (preset.instruction.isNotEmpty) preset.instruction,
    if (trimmedNote.isNotEmpty) trimmedNote,
  ].join(' ');
}

/// Rewrites the `/triage` trigger for the agent that will start the session
/// (`$triage` for Codex).
///
/// A running session converts triggers from its own skill list when a message
/// is sent. A session that does not exist yet has no list, so the one skill
/// this prompt invokes is named explicitly.
String triagePromptForProvider(String prompt, Provider provider) =>
    convertSkillTriggers(
      prompt,
      SkillTriggerCatalog(
        provider: provider,
        skillNames: const {triageSkillName},
      ),
    );
