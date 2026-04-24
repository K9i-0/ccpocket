import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/terminal_app.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/workspace_pane_chrome.dart';

const _kCustomKey = '__custom__';

/// Shows a bottom sheet for configuring the external terminal app.
Future<void> showTerminalAppBottomSheet({
  required BuildContext context,
  required TerminalAppConfig current,
  required ValueChanged<TerminalAppConfig> onChanged,
  required VoidCallback onClear,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _TerminalAppSheetContent(
      current: current,
      onChanged: (config) {
        onChanged(config);
        Navigator.pop(ctx);
      },
      onClear: () {
        onClear();
        Navigator.pop(ctx);
      },
    ),
  );
}

class _TerminalAppSheetContent extends StatefulWidget {
  final TerminalAppConfig current;
  final ValueChanged<TerminalAppConfig> onChanged;
  final VoidCallback onClear;

  const _TerminalAppSheetContent({
    required this.current,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_TerminalAppSheetContent> createState() =>
      _TerminalAppSheetContentState();
}

class _TerminalAppSheetContentState extends State<_TerminalAppSheetContent> {
  late String? _selectedPresetId;
  late bool _isCustom;
  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _sshUserCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _selectedPresetId = c.presetId;
    _isCustom = c.presetId == null && c.isConfigured;
    _nameCtrl = TextEditingController(text: c.customName ?? '');
    _urlCtrl = TextEditingController(text: c.customUrlTemplate ?? '');
    _sshUserCtrl = TextEditingController(text: c.sshUser ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _sshUserCtrl.dispose();
    super.dispose();
  }

  void _selectPreset(String id) {
    setState(() {
      _selectedPresetId = id;
      _isCustom = false;
    });
  }

  void _selectCustom() {
    setState(() {
      _selectedPresetId = null;
      _isCustom = true;
    });
  }

  void _save() {
    if (_isCustom) {
      widget.onChanged(
        TerminalAppConfig(
          customName: _nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : null,
          customUrlTemplate: _urlCtrl.text.trim(),
          sshUser: _sshUserCtrl.text.trim().isNotEmpty
              ? _sshUserCtrl.text.trim()
              : null,
        ),
      );
    } else if (_selectedPresetId != null) {
      widget.onChanged(
        TerminalAppConfig(
          presetId: _selectedPresetId,
          sshUser: _sshUserCtrl.text.trim().isNotEmpty
              ? _sshUserCtrl.text.trim()
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: appColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.terminal, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.terminalApp,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (widget.current.isConfigured)
                  TextButton(onPressed: widget.onClear, child: Text(l.none)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Preset list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                RadioGroup<String>(
                  groupValue: _isCustom
                      ? _kCustomKey
                      : (_selectedPresetId ?? ''),
                  onChanged: (v) {
                    if (v == _kCustomKey) {
                      _selectCustom();
                    } else if (v != null) {
                      _selectPreset(v);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Presets
                      for (final preset in kTerminalAppPresets)
                        RadioListTile<String>(
                          value: preset.id,
                          title: Text(preset.name),
                          secondary: const Icon(Icons.terminal, size: 20),
                        ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      // Custom option
                      RadioListTile<String>(
                        value: _kCustomKey,
                        title: Text(l.terminalAppCustom),
                        secondary: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ),
                ),
                // Custom fields
                if (_isCustom) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: l.terminalAppName,
                            hintText: 'My Terminal',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlCtrl,
                          decoration: InputDecoration(
                            labelText: l.terminalUrlTemplate,
                            hintText:
                                'myapp://connect?host={{host}}&user={{user}}',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l.terminalUrlTemplateHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // SSH User field (always visible when something is selected)
                if (_selectedPresetId != null || _isCustom) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _sshUserCtrl,
                      decoration: InputDecoration(
                        labelText: l.terminalSshUser,
                        hintText: l.terminalSshUserHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Experimental note
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.terminalAppExperimentalNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Save button
          if (_selectedPresetId != null || _isCustom) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_isCustom && _urlCtrl.text.trim().isEmpty)
                      ? null
                      : _save,
                  child: Text(l.save),
                ),
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}
