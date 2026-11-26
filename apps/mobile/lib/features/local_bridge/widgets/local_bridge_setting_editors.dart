import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// Result of an editor dialog. A null [value] resets the setting to its
/// default; a cancelled dialog returns no [SettingEdit] at all.
class SettingEdit {
  const SettingEdit(this.value);

  final Object? value;
}

/// Edits a single-line value (text, port, URL or secret).
class TextSettingDialog extends StatefulWidget {
  const TextSettingDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.description,
    this.numeric = false,
    this.obscure = false,
    this.canReset = true,
  });

  final String title;
  final String initialValue;
  final String? description;
  final bool numeric;
  final bool obscure;
  final bool canReset;

  @override
  State<TextSettingDialog> createState() => _TextSettingDialogState();
}

class _TextSettingDialogState extends State<TextSettingDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final Object value = widget.numeric ? (int.tryParse(text) ?? text) : text;
    Navigator.of(context).pop(SettingEdit(value));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.description != null) ...[
            Text(widget.description!),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const ValueKey('local_bridge_setting_field'),
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscure,
            keyboardType: widget.numeric ? TextInputType.number : null,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        if (widget.canReset)
          TextButton(
            key: const ValueKey('local_bridge_setting_reset_button'),
            onPressed: () => Navigator.of(context).pop(const SettingEdit(null)),
            child: Text(l.localBridgeSettingResetToDefault),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('local_bridge_setting_apply_button'),
          onPressed: _submit,
          child: Text(l.done),
        ),
      ],
    );
  }
}

/// Picks one of a fixed set of values.
class ChoiceSettingDialog extends StatelessWidget {
  const ChoiceSettingDialog({
    super.key,
    required this.title,
    required this.values,
    required this.current,
    required this.labelOf,
    this.description,
  });

  final String title;
  final String? description;
  final List<String> values;
  final String? current;
  final String Function(String value) labelOf;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      children: [
        if (description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(description!),
          ),
        for (final value in values)
          ListTile(
            key: ValueKey('local_bridge_setting_choice:$value'),
            leading: Icon(
              value == current
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
            ),
            title: Text(labelOf(value)),
            onTap: () => Navigator.of(context).pop(SettingEdit(value)),
          ),
      ],
    );
  }
}

/// Folders offered as a one-tap addition, with the reason they are useful.
class FolderSuggestion {
  const FolderSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.paths,
  });

  final String id;
  final String title;
  final String description;
  final List<String> paths;
}

/// Edits a list of folders. With [allowAll] the list can be replaced by
/// "any folder" (`["*"]`).
class FoldersSettingDialog extends StatefulWidget {
  const FoldersSettingDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.description,
    this.allowAll = false,
    this.allowEmpty = false,
    this.suggestions = const [],
    this.pickFolder,
  });

  final String title;
  final String? description;
  final List<String> initialValue;
  final bool allowAll;

  /// An empty list is a valid result; it resets the setting.
  final bool allowEmpty;
  final List<FolderSuggestion> suggestions;

  /// Folder picker; defaults to the native panel.
  final Future<String?> Function()? pickFolder;

  @override
  State<FoldersSettingDialog> createState() => _FoldersSettingDialogState();
}

class _FoldersSettingDialogState extends State<FoldersSettingDialog> {
  late bool _all = widget.initialValue.contains('*');
  late final List<String> _folders = [
    for (final folder in widget.initialValue)
      if (folder != '*') folder,
  ];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String? path) {
    final folder = path?.trim() ?? '';
    // The Bridge's list format separates folders with commas.
    if (folder.isEmpty || folder.contains(',') || _folders.contains(folder)) {
      return;
    }
    setState(() => _folders.add(folder));
  }

  void _addTyped() {
    _add(_controller.text);
    _controller.clear();
  }

  Future<void> _pick() async {
    final pick = widget.pickFolder ?? getDirectoryPath;
    _add(await pick());
  }

  void _apply() {
    final Object? value = _all
        ? const ['*']
        : (_folders.isEmpty ? null : [..._folders]);
    Navigator.of(context).pop(SettingEdit(value));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final canApply = _all || _folders.isNotEmpty || widget.allowEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.description != null) ...[
                Text(widget.description!, style: muted),
                const SizedBox(height: 8),
              ],
              if (widget.allowAll)
                SwitchListTile(
                  key: const ValueKey('local_bridge_folders_all_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.localBridgeAllowedDirsAll),
                  value: _all,
                  onChanged: (value) => setState(() => _all = value),
                ),
              if (!_all) ...[
                if (_folders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l.localBridgeFoldersEmpty,
                      key: const ValueKey('local_bridge_folders_empty'),
                      style: muted,
                    ),
                  ),
                for (final folder in _folders)
                  ListTile(
                    key: ValueKey('local_bridge_folder_row:$folder'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder),
                    trailing: IconButton(
                      key: ValueKey('local_bridge_folder_remove:$folder'),
                      tooltip: l.delete,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _folders.remove(folder)),
                    ),
                  ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('local_bridge_folder_pick_button'),
                    onPressed: _pick,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: Text(l.localBridgeChooseFolder),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('local_bridge_folder_field'),
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: l.localBridgeFolderPathLabel,
                          hintText: '/path/to/folder',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addTyped(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => OutlinedButton(
                        key: const ValueKey('local_bridge_folder_add_button'),
                        onPressed: _controller.text.trim().isEmpty
                            ? null
                            : _addTyped,
                        child: Text(l.add),
                      ),
                    ),
                  ],
                ),
                if (widget.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    l.localBridgeFolderSuggestionsTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final suggestion in widget.suggestions)
                    _FolderSuggestionRow(
                      suggestion: suggestion,
                      added: suggestion.paths.every(_folders.contains),
                      onAdd: () => suggestion.paths.forEach(_add),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('local_bridge_setting_reset_button'),
          onPressed: () => Navigator.of(context).pop(const SettingEdit(null)),
          child: Text(l.localBridgeSettingResetToDefault),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('local_bridge_setting_apply_button'),
          onPressed: canApply ? _apply : null,
          child: Text(l.done),
        ),
      ],
    );
  }
}

class _FolderSuggestionRow extends StatelessWidget {
  const _FolderSuggestionRow({
    required this.suggestion,
    required this.added,
    required this.onAdd,
  });

  final FolderSuggestion suggestion;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.title, style: theme.textTheme.bodyMedium),
                Text(suggestion.description, style: muted),
                Text(
                  suggestion.paths.join('  '),
                  style: muted?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (added)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                key: ValueKey(
                  'local_bridge_folder_suggestion_added:${suggestion.id}',
                ),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(l.localBridgeFolderSuggestionAdded, style: muted),
                ],
              ),
            )
          else
            OutlinedButton(
              key: ValueKey(
                'local_bridge_folder_suggestion_add:${suggestion.id}',
              ),
              onPressed: onAdd,
              child: Text(l.add),
            ),
        ],
      ),
    );
  }
}
