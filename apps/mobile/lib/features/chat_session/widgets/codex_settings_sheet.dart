import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../widgets/codex_effort_slider.dart';

class CodexSettingsSheet extends StatefulWidget {
  final List<String> models;
  final Map<String, List<ReasoningEffort>> modelEfforts;
  final Map<String, List<String>> modelServiceTiers;
  final String initialModel;
  final ReasoningEffort initialEffort;
  final CodexSpeed initialSpeed;
  final void Function(String model, ReasoningEffort effort) onModelChanged;
  final void Function(String model, ReasoningEffort effort) onEffortChanged;
  final ValueChanged<CodexSpeed> onSpeedChanged;

  const CodexSettingsSheet({
    super.key,
    required this.models,
    required this.modelEfforts,
    required this.modelServiceTiers,
    required this.initialModel,
    required this.initialEffort,
    required this.initialSpeed,
    required this.onModelChanged,
    required this.onEffortChanged,
    required this.onSpeedChanged,
  });

  @override
  State<CodexSettingsSheet> createState() => _CodexSettingsSheetState();
}

class _CodexSettingsSheetState extends State<CodexSettingsSheet> {
  late String _model = widget.initialModel;
  late ReasoningEffort _effort = widget.initialEffort;
  late CodexSpeed _speed = widget.initialSpeed;
  bool _showAdvanced = false;

  List<ReasoningEffort> get _efforts =>
      widget.modelEfforts[_model] ?? const [ReasoningEffort.none];

  bool get _supportsFast =>
      codexSupportsFast(_model, widget.modelServiceTiers, speed: _speed);

  void _selectEffort(ReasoningEffort effort) {
    if (effort == _effort) return;
    setState(() => _effort = effort);
    widget.onEffortChanged(_model, effort);
  }

  void _selectSpeed(CodexSpeed speed) {
    if (speed == _speed || (speed == CodexSpeed.fast && !_supportsFast)) return;
    setState(() => _speed = speed);
    widget.onSpeedChanged(speed);
  }

  void _selectModel(String model) {
    if (model == _model) return;
    final efforts = widget.modelEfforts[model] ?? const [ReasoningEffort.none];
    final nextEffort = preferredCodexEffort(efforts, current: _effort);
    final supportsFast = codexSupportsFast(model, widget.modelServiceTiers);
    final previousSpeed = _speed;
    final nextSpeed = supportsFast ? _speed : CodexSpeed.standard;
    setState(() {
      _model = model;
      _effort = nextEffort;
      _speed = nextSpeed;
    });
    widget.onModelChanged(model, nextEffort);
    if (nextSpeed != previousSpeed) widget.onSpeedChanged(nextSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: CodexSettingsPanel(
          model: _model,
          effort: _effort,
          speed: _speed,
          supportsFast: _supportsFast,
          onSpeedChanged: _selectSpeed,
          speedButtonKey: 'codex_speed_button',
          showAdvanced: _showAdvanced,
          advancedLabel: l.advanced,
          toggleButtonKey: 'codex_settings_advanced',
          onToggleMode: () => setState(() => _showAdvanced = !_showAdvanced),
          quickPanelKey: 'codex_settings_quick_panel',
          advancedPanelKey: 'codex_settings_advanced_panel',
          modelLabelKey: 'codex_settings_model_label',
          effortLabelKey: 'codex_settings_effort_label',
          advancedEffortBadgeKey: 'codex_effort_slider_advanced_value_badge',
          quickChild: CodexEffortSlider(
            efforts: _efforts,
            value: _effort,
            onChanged: _selectEffort,
            sliderKey: 'codex_effort_slider',
          ),
          advancedChild: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsRow(
                key: const ValueKey('codex_model_advanced'),
                label: l.model,
                value: codexModelDisplayName(_model),
                onTap: () => _showModelPicker(context),
              ),
              _SettingsRow(
                key: const ValueKey('codex_effort_advanced'),
                label: l.effort,
                value: _effort.label,
                onTap: () => _showEffortPicker(context),
              ),
              _SettingsRow(
                key: const ValueKey('codex_speed_advanced'),
                label: 'Speed',
                value: _speed.label,
                onTap: () => _showSpeedPicker(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context) {
    _showPicker<String>(
      context: context,
      title: AppLocalizations.of(context).model,
      values: widget.models,
      selected: _model,
      label: codexModelDisplayName,
      onSelected: _selectModel,
    );
  }

  void _showEffortPicker(BuildContext context) {
    _showPicker<ReasoningEffort>(
      context: context,
      title: AppLocalizations.of(context).effort,
      values: _efforts,
      selected: _effort,
      label: (effort) => effort.label,
      subtitle: (effort) => effort == ReasoningEffort.ultra
          ? 'Uses more usage and automatic task delegation'
          : null,
      onSelected: _selectEffort,
    );
  }

  void _showSpeedPicker(BuildContext context) {
    _showPicker<CodexSpeed>(
      context: context,
      title: 'Speed',
      values: [CodexSpeed.standard, if (_supportsFast) CodexSpeed.fast],
      selected: _speed,
      label: (speed) => speed.label,
      subtitle: (speed) =>
          speed == CodexSpeed.fast ? '1.5× speed, more usage' : 'Default speed',
      onSelected: _selectSpeed,
    );
  }

  void _showPicker<T>({
    required BuildContext context,
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    String? Function(T)? subtitle,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final value in values)
                    ListTile(
                      key: value is ReasoningEffort
                          ? ValueKey('codex_effort_${value.value}_option')
                          : value is CodexSpeed
                          ? ValueKey('codex_speed_${value.value}_option')
                          : null,
                      title: Text(label(value)),
                      subtitle: subtitle == null || subtitle(value) == null
                          ? null
                          : Text(subtitle(value)!),
                      trailing: value == selected
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(sheetContext);
                        onSelected(value);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}
