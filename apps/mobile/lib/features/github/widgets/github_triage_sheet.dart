import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/workspace_pane_chrome.dart';
import '../triage_prompt.dart';

/// Where the composed `/triage ...` request goes.
enum GitHubTriageTarget {
  /// Starts a new session in the project; the agent and effort are chosen in
  /// the new session sheet that follows.
  newSession,

  /// Sent as the first message of the chat that opened the screen.
  currentSession,
}

/// Hands the composed prompt to its receiver. Returns whether it was accepted.
typedef GitHubTriageSubmit = Future<bool> Function(String prompt);

/// Asks what to do with [numbers] and passes the composed prompt to
/// [onSubmit]. The sheet closes with `true` once the prompt is accepted and
/// stays open with an error when it is not. Returns `null` when dismissed.
Future<bool?> showGitHubTriageSheet(
  BuildContext context, {
  required List<int> numbers,
  required GitHubTriageTarget target,
  required GitHubTriageSubmit onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: macOSModalBottomSheetConstraints(context),
    builder: (_) =>
        GitHubTriageSheet(numbers: numbers, target: target, onSubmit: onSubmit),
  );
}

class GitHubTriageSheet extends StatefulWidget {
  final List<int> numbers;
  final GitHubTriageTarget target;
  final GitHubTriageSubmit onSubmit;

  const GitHubTriageSheet({
    super.key,
    required this.numbers,
    required this.target,
    required this.onSubmit,
  });

  @override
  State<GitHubTriageSheet> createState() => _GitHubTriageSheetState();
}

class _GitHubTriageSheetState extends State<GitHubTriageSheet> {
  final _noteController = TextEditingController();
  TriagePreset _preset = TriagePreset.investigateAndMerge;
  bool _sending = false;
  bool _rejected = false;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() => setState(() {});

  Future<void> _submit() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _rejected = false;
    });
    final accepted = await widget.onSubmit(_prompt);
    if (!mounted) return;
    if (accepted) {
      Navigator.of(context).pop(true);
      return;
    }
    // Keep the request on screen so nothing the user composed is lost.
    setState(() {
      _sending = false;
      _rejected = true;
    });
  }

  String get _prompt => buildTriagePrompt(
    numbers: widget.numbers,
    preset: _preset,
    note: _noteController.text,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final startsNewSession = widget.target == GitHubTriageTarget.newSession;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.githubRequestTriage, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.numbers.map((number) => '#$number').join('  '),
              key: const ValueKey('github_triage_targets'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final preset in TriagePreset.values)
              _TriagePresetTile(
                preset: preset,
                selected: preset == _preset,
                onTap: () => setState(() => _preset = preset),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('github_triage_note_field'),
              controller: _noteController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l.githubTriageNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _prompt,
                key: const ValueKey('github_triage_preview'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              startsNewSession
                  ? l.githubTriageStartsNewSession
                  : l.githubTriageSendsToSession,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_rejected) ...[
              const SizedBox(height: 8),
              Text(
                l.githubTriageSendFailed,
                key: const ValueKey('github_triage_send_error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('github_triage_send_button'),
                onPressed: _sending ? null : () => unawaited(_submit()),
                icon: Icon(
                  startsNewSession ? Icons.arrow_forward : Icons.send,
                  size: 18,
                ),
                label: Text(startsNewSession ? l.githubTriageNext : l.send),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriagePresetTile extends StatelessWidget {
  final TriagePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _TriagePresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final (label, hint) = switch (preset) {
      TriagePreset.investigateAndMerge => (
        l.githubTriagePresetMerge,
        l.githubTriagePresetMergeHint,
      ),
      TriagePreset.handleAndRelease => (l.githubTriagePresetRelease, null),
      TriagePreset.contentOnly => (l.githubTriagePresetContentOnly, null),
      TriagePreset.checkResolvedAndClose => (l.githubTriagePresetClose, null),
    };
    return ListTile(
      key: ValueKey('github_triage_preset_${preset.name}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? colorScheme.primary : colorScheme.outline,
      ),
      title: Text(label),
      subtitle: hint == null ? null : Text(hint),
      onTap: onTap,
    );
  }
}
