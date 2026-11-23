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
  });

  final String title;
  final List<String> values;
  final String? current;
  final String Function(String value) labelOf;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text(title),
      children: [
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

/// Edits a list of folders. With [allowAll] the list can be replaced by
/// "any folder" (`["*"]`).
class FoldersSettingDialog extends StatefulWidget {
  const FoldersSettingDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.allowAll = false,
    this.pickFolder,
  });

  final String title;
  final List<String> initialValue;
  final bool allowAll;

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

  Future<void> _pick() async {
    final pick = widget.pickFolder ?? getDirectoryPath;
    _add(await pick());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canApply = _all || _folders.isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.allowAll)
              SwitchListTile(
                key: const ValueKey('local_bridge_folders_all_toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.localBridgeAllowedDirsAll),
                value: _all,
                onChanged: (value) => setState(() => _all = value),
              ),
            if (!_all) ...[
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
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
                          onPressed: () =>
                              setState(() => _folders.remove(folder)),
                        ),
                      ),
                  ],
                ),
              ),
              TextField(
                key: const ValueKey('local_bridge_folder_field'),
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '/path/to/folder',
                  suffixIcon: IconButton(
                    key: const ValueKey('local_bridge_folder_add_button'),
                    tooltip: l.add,
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () {
                      _add(_controller.text);
                      _controller.clear();
                    },
                  ),
                ),
                onSubmitted: (value) {
                  _add(value);
                  _controller.clear();
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('local_bridge_folder_pick_button'),
                  onPressed: _pick,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: Text(l.localBridgeAddFolder),
                ),
              ),
            ],
          ],
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
          onPressed: canApply
              ? () =>
                    Navigator.of(context)
                        .pop(SettingEdit(_all ? const ['*'] : [..._folders]))
              : null,
          child: Text(l.done),
        ),
      ],
    );
  }
}
