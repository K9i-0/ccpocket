import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import 'codex_effort_slider.dart';

/// Fallback Claude models when the Bridge has not delivered a list yet.
/// Claude Code aliases always resolve to the current model of each family.
const defaultClaudeModelOptions = <ClaudeModelOption>[
  ClaudeModelOption(value: 'default', displayName: 'Default'),
  ClaudeModelOption(value: 'opus', displayName: 'Opus'),
  ClaudeModelOption(value: 'sonnet', displayName: 'Sonnet'),
  ClaudeModelOption(value: 'haiku', displayName: 'Haiku'),
];

const _legacyClaudeEfforts = <ClaudeEffort>[
  ClaudeEffort.low,
  ClaudeEffort.medium,
  ClaudeEffort.high,
  ClaudeEffort.max,
];

Map<String, List<ClaudeEffort>> normalizeClaudeModelEfforts(
  Map<String, List<String>> raw,
) {
  return raw.map((model, values) {
    final efforts = values
        .map(claudeEffortByValue)
        .whereType<ClaudeEffort>()
        .toList(growable: false);
    return MapEntry(model, efforts);
  });
}

/// Effort levels available for [model]. Unknown models fall back to every
/// level, and Bridges without metadata to the legacy levels.
List<ClaudeEffort> claudeEffortsForModel(
  String? model,
  Map<String, List<ClaudeEffort>> modelEfforts,
) {
  if (model != null && modelEfforts.containsKey(model)) {
    return modelEfforts[model] ?? const [];
  }
  return modelEfforts.isEmpty ? _legacyClaudeEfforts : ClaudeEffort.values;
}

/// Keep [current] when the model supports it, otherwise prefer High.
ClaudeEffort? preferredClaudeEffort(
  List<ClaudeEffort> efforts, {
  ClaudeEffort? current,
}) {
  if (efforts.isEmpty) return current;
  if (current != null && efforts.contains(current)) return current;
  return efforts.contains(ClaudeEffort.high)
      ? ClaudeEffort.high
      : efforts.first;
}

String claudeModelLabel(List<ClaudeModelOption> options, String? model) {
  final value = model ?? 'default';
  for (final option in options) {
    if (option.value == value) return option.label;
  }
  return value == 'default' ? 'Default' : value;
}

String claudeModelDescription(List<ClaudeModelOption> options, String model) {
  for (final option in options) {
    if (option.value == model) return option.description ?? '';
  }
  return '';
}

bool claudeModelSupportsFast(List<ClaudeModelOption> options, String? model) {
  final value = model ?? 'default';
  for (final option in options) {
    if (option.value == value) return option.supportsFastMode;
  }
  return false;
}

String claudeEffortDescription(ClaudeEffort effort, AppLocalizations l) =>
    switch (effort) {
      ClaudeEffort.low => l.claudeEffortLowDesc,
      ClaudeEffort.medium => l.claudeEffortMediumDesc,
      ClaudeEffort.high => l.claudeEffortHighDesc,
      ClaudeEffort.xhigh => l.claudeEffortXHighDesc,
      ClaudeEffort.max => l.claudeEffortMaxDesc,
    };

/// Claude model / effort / fast mode / ultracode controls with the same
/// quick (slider) and advanced (rows) layout as the Codex settings.
class ClaudeSettingsPanel extends StatefulWidget {
  final List<ClaudeModelOption> models;
  final Map<String, List<ClaudeEffort>> modelEfforts;
  final String? model;
  final ClaudeEffort? effort;
  final bool fastMode;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<ClaudeEffort> onEffortChanged;
  final ValueChanged<bool> onFastModeChanged;

  /// Claude Code ultracode. It is independent of the effort level, and no
  /// model metadata tells which models support it: Claude Code rejects it
  /// where unavailable.
  final bool ultracode;
  final ValueChanged<bool> onUltracodeChanged;

  /// Prefix for widget keys (e.g. `claude_settings` / `dialog_claude`).
  final String keyPrefix;

  const ClaudeSettingsPanel({
    super.key,
    required this.models,
    required this.modelEfforts,
    required this.model,
    required this.effort,
    required this.fastMode,
    required this.onModelChanged,
    required this.onEffortChanged,
    required this.onFastModeChanged,
    required this.ultracode,
    required this.onUltracodeChanged,
    this.keyPrefix = 'claude_settings',
  });

  @override
  State<ClaudeSettingsPanel> createState() => _ClaudeSettingsPanelState();
}

class _ClaudeSettingsPanelState extends State<ClaudeSettingsPanel> {
  bool _showAdvanced = false;

  String get _model => widget.model ?? 'default';

  List<ClaudeEffort> get _efforts =>
      claudeEffortsForModel(_model, widget.modelEfforts);

  ClaudeEffort? get _effort =>
      preferredClaudeEffort(_efforts, current: widget.effort);

  bool get _supportsFast =>
      widget.fastMode || claudeModelSupportsFast(widget.models, _model);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefix = widget.keyPrefix;
    final effort = _effort;
    final efforts = _efforts;
    return CodexSettingsPanel(
      modelLabel: claudeModelLabel(widget.models, _model),
      effortLabel: efforts.isEmpty ? '' : (effort?.label ?? ''),
      speed: widget.fastMode ? CodexSpeed.fast : CodexSpeed.standard,
      supportsFast: _supportsFast,
      onSpeedChanged: (speed) =>
          widget.onFastModeChanged(speed == CodexSpeed.fast),
      speedButtonKey: '${prefix}_speed_button',
      showAdvanced: _showAdvanced,
      advancedLabel: l.advanced,
      toggleButtonKey: '${prefix}_advanced',
      onToggleMode: () => setState(() => _showAdvanced = !_showAdvanced),
      quickPanelKey: '${prefix}_quick_panel',
      advancedPanelKey: '${prefix}_advanced_panel',
      modelLabelKey: '${prefix}_model_label',
      effortLabelKey: '${prefix}_effort_label',
      onModelTap: () => _showModelPicker(prefix),
      quickChild: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuickEffort(context, prefix, efforts, effort),
          _UltracodeSwitch(
            key: ValueKey('${prefix}_ultracode_switch'),
            value: widget.ultracode,
            onChanged: widget.onUltracodeChanged,
          ),
        ],
      ),
      advancedChild: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._buildAdvancedRows(context, prefix, efforts, effort),
          _SettingsRow(
            key: ValueKey('${prefix}_ultracode_row'),
            label: 'Ultracode',
            value: widget.ultracode
                ? l.claudeUltracodeOn
                : l.claudeUltracodeOff,
            onTap: () => _showPicker<bool>(
              title: 'Ultracode',
              values: const [false, true],
              selected: widget.ultracode,
              label: (on) => on ? l.claudeUltracodeOn : l.claudeUltracodeOff,
              subtitle: (on) => on ? l.claudeUltracodeDesc : null,
              optionKey: (on) =>
                  '${prefix}_ultracode_${on ? 'on' : 'off'}_option',
              onSelected: widget.onUltracodeChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEffort(
    BuildContext context,
    String prefix,
    List<ClaudeEffort> efforts,
    ClaudeEffort? effort,
  ) {
    return efforts.isEmpty || effort == null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                claudeModelDescription(widget.models, _model),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        : SettingsLevelSlider<ClaudeEffort>(
            levels: efforts,
            value: effort,
            labelOf: (e) => e.label,
            onChanged: widget.onEffortChanged,
            sliderKey: '${prefix}_effort_slider',
          );
  }

  List<Widget> _buildAdvancedRows(
    BuildContext context,
    String prefix,
    List<ClaudeEffort> efforts,
    ClaudeEffort? effort,
  ) {
    final l = AppLocalizations.of(context);
    return [
      _SettingsRow(
        key: ValueKey('${prefix}_model_row'),
        label: l.model,
        value: claudeModelLabel(widget.models, _model),
        onTap: () => _showModelPicker(prefix),
      ),
      if (efforts.isNotEmpty && effort != null)
        _SettingsRow(
          key: ValueKey('${prefix}_effort_row'),
          label: l.effort,
          value: effort.label,
          onTap: () => _showPicker<ClaudeEffort>(
            title: l.effort,
            values: efforts,
            selected: effort,
            label: (e) => e.label,
            subtitle: (e) => claudeEffortDescription(e, l),
            optionKey: (e) => '${prefix}_effort_${e.value}_option',
            onSelected: widget.onEffortChanged,
          ),
        ),
      if (_supportsFast)
        _SettingsRow(
          key: ValueKey('${prefix}_speed_row'),
          label: 'Speed',
          value: widget.fastMode ? 'Fast' : 'Standard',
          onTap: () => _showPicker<bool>(
            title: 'Speed',
            values: const [false, true],
            selected: widget.fastMode,
            label: (fast) => fast ? 'Fast' : 'Standard',
            subtitle: (fast) =>
                fast ? 'Faster output, more usage' : 'Default speed',
            optionKey: (fast) =>
                '${prefix}_speed_${fast ? 'fast' : 'standard'}_option',
            onSelected: widget.onFastModeChanged,
          ),
        ),
    ];
  }

  void _showModelPicker(String prefix) {
    _showPicker<String>(
      title: AppLocalizations.of(context).model,
      values: [for (final option in widget.models) option.value],
      selected: _model,
      label: (m) => claudeModelLabel(widget.models, m),
      subtitle: (m) {
        final description = claudeModelDescription(widget.models, m);
        return description.isEmpty ? null : description;
      },
      optionKey: (m) => '${prefix}_model_${m}_option',
      onSelected: widget.onModelChanged,
    );
  }

  void _showPicker<T>({
    required String title,
    required List<T> values,
    required T selected,
    required String Function(T) label,
    String? Function(T)? subtitle,
    required String Function(T) optionKey,
    required ValueChanged<T> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
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
                        key: ValueKey(optionKey(value)),
                        title: Text(label(value)),
                        subtitle: subtitle?.call(value) == null
                            ? null
                            : Text(subtitle!(value)!),
                        trailing: value == selected
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(sheetContext);
                          if (value != selected) onSelected(value);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UltracodeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _UltracodeSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: const Text('Ultracode'),
      subtitle: Text(
        l.claudeUltracodeDesc,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: (next) {
        HapticFeedback.selectionClick();
        onChanged(next);
      },
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// In-session Claude settings sheet. Changes apply immediately to the
/// following turns.
class ClaudeSettingsSheet extends StatefulWidget {
  final List<ClaudeModelOption> models;
  final Map<String, List<ClaudeEffort>> modelEfforts;
  final String? initialModel;
  final ClaudeEffort? initialEffort;
  final bool initialFastMode;
  final bool initialUltracode;
  final void Function({
    String? model,
    ClaudeEffort? effort,
    bool? fastMode,
    bool? ultracode,
  })
  onChanged;

  const ClaudeSettingsSheet({
    super.key,
    required this.models,
    required this.modelEfforts,
    required this.initialModel,
    required this.initialEffort,
    required this.initialFastMode,
    this.initialUltracode = false,
    required this.onChanged,
  });

  @override
  State<ClaudeSettingsSheet> createState() => _ClaudeSettingsSheetState();
}

class _ClaudeSettingsSheetState extends State<ClaudeSettingsSheet> {
  late String? _model = widget.initialModel;
  late ClaudeEffort? _effort = widget.initialEffort;
  late bool _fastMode = widget.initialFastMode;
  late bool _ultracode = widget.initialUltracode;

  @override
  void didUpdateWidget(ClaudeSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the Bridge's confirmed settings, e.g. when it rejects a change.
    if (widget.initialModel != oldWidget.initialModel) {
      _model = widget.initialModel;
    }
    if (widget.initialEffort != oldWidget.initialEffort) {
      _effort = widget.initialEffort;
    }
    if (widget.initialFastMode != oldWidget.initialFastMode) {
      _fastMode = widget.initialFastMode;
    }
    if (widget.initialUltracode != oldWidget.initialUltracode) {
      _ultracode = widget.initialUltracode;
    }
  }

  void _selectModel(String model) {
    final efforts = claudeEffortsForModel(model, widget.modelEfforts);
    final nextEffort = preferredClaudeEffort(efforts, current: _effort);
    final keepFast = _fastMode && claudeModelSupportsFast(widget.models, model);
    setState(() {
      _model = model;
      _effort = nextEffort;
      _fastMode = keepFast;
    });
    widget.onChanged(
      model: model,
      effort: efforts.isEmpty ? null : nextEffort,
      fastMode: keepFast,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ClaudeSettingsPanel(
          models: widget.models,
          modelEfforts: widget.modelEfforts,
          model: _model,
          effort: _effort,
          fastMode: _fastMode,
          onModelChanged: _selectModel,
          onEffortChanged: (effort) {
            setState(() => _effort = effort);
            widget.onChanged(effort: effort);
          },
          onFastModeChanged: (fast) {
            setState(() => _fastMode = fast);
            widget.onChanged(fastMode: fast);
          },
          ultracode: _ultracode,
          onUltracodeChanged: (on) {
            setState(() => _ultracode = on);
            widget.onChanged(ultracode: on);
          },
        ),
      ),
    );
  }
}
