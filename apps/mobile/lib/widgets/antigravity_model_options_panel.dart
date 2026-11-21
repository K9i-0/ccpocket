import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../models/model_picker_style.dart';
import 'codex_effort_slider.dart';
import 'model_picker.dart';

const _antigravityThoughtLevelOrder = <String>[
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
  'max',
];

/// Orders Antigravity thinking levels from lowest to highest for slider UI.
/// Unknown level IDs are preserved at the end in their original order.
List<String> sortAntigravityThoughtLevels(List<String> levels) {
  if (levels.length <= 1) return levels;
  final known = [
    for (final ordered in _antigravityThoughtLevelOrder)
      if (levels.contains(ordered)) ordered,
  ];
  final unknown = [
    for (final level in levels)
      if (!known.contains(level)) level,
  ];
  return [...known, ...unknown];
}

/// Keeps [current] when supported by [levels], otherwise prefers `high` or the
/// first available level.
String? preferredAntigravityThoughtLevel(
  List<String> levels, {
  String? current,
}) {
  final sorted = sortAntigravityThoughtLevels(levels);
  if (sorted.isEmpty) return null;
  if (current != null && sorted.contains(current)) return current;
  if (sorted.contains('high')) return 'high';
  return sorted.first;
}

/// Antigravity model and thinking level controls using the same quick (slider)
/// and advanced (rows) card layout as Claude and Codex settings.
/// Shared by the chat screen's model sheet and the new-session sheet.
class AntigravityModelOptionsPanel extends StatefulWidget {
  final List<AntigravityModelOption> modelOptions;
  final String? model;
  final String? thoughtLevel;

  /// Levels of the selected family; empty when it has none.
  final List<String> thoughtLevels;
  final ValueChanged<AntigravityModelOption> onModelSelected;
  final ValueChanged<String> onThoughtLevelSelected;

  /// Optional account plan label (e.g. `Google AI Ultra`).
  final String? tierName;

  /// How tapping the model name opens the model selector.
  final ModelPickerStyle modelPickerStyle;

  /// Prefix for widget keys (e.g. `antigravity_settings` / `dialog_antigravity`).
  final String keyPrefix;

  const AntigravityModelOptionsPanel({
    super.key,
    required this.modelOptions,
    required this.model,
    required this.thoughtLevel,
    required this.thoughtLevels,
    required this.onModelSelected,
    required this.onThoughtLevelSelected,
    this.tierName,
    this.modelPickerStyle = ModelPickerStyle.bottomSheet,
    this.keyPrefix = 'antigravity_settings',
  });

  @override
  State<AntigravityModelOptionsPanel> createState() =>
      _AntigravityModelOptionsPanelState();
}

class _AntigravityModelOptionsPanelState
    extends State<AntigravityModelOptionsPanel> {
  bool _showAdvanced = false;

  AntigravityModelOption? get _selectedOption {
    final current = widget.model;
    if (current != null) {
      for (final option in widget.modelOptions) {
        if (option.id == current) return option;
      }
    }
    return widget.modelOptions.firstOrNull;
  }

  List<String> get _sortedLevels =>
      sortAntigravityThoughtLevels(widget.thoughtLevels);

  String? get _effectiveLevel => preferredAntigravityThoughtLevel(
    _sortedLevels,
    current: widget.thoughtLevel,
  );

  void _openModelPicker(BuildContext anchorContext) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModelPicker<AntigravityModelOption>(
      context: context,
      anchorContext: anchorContext,
      style: widget.modelPickerStyle,
      title: l.model,
      values: widget.modelOptions,
      selected: _selectedOption,
      label: (option) => option.name,
      optionKey: (option) => 'antigravity_model_option_${option.id}',
      checkColor: cs.tertiary,
      onSelected: widget.onModelSelected,
    );
  }

  void _openThoughtLevelPicker(
    BuildContext anchorContext,
    List<String> levels,
    String current,
  ) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModelPicker<String>(
      context: context,
      anchorContext: anchorContext,
      style: ModelPickerStyle.bottomSheet,
      title: l.effort,
      values: levels,
      selected: current,
      label: antigravityThoughtLevelLabel,
      optionKey: (level) => 'antigravity_thought_level_$level',
      checkColor: cs.tertiary,
      onSelected: widget.onThoughtLevelSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final prefix = widget.keyPrefix;
    final selectedOption = _selectedOption;
    final levels = _sortedLevels;
    final effectiveLevel = _effectiveLevel;
    final modelLabel = selectedOption?.name ?? widget.model ?? l.model;
    final effortLabel = levels.isEmpty || effectiveLevel == null
        ? ''
        : antigravityThoughtLevelLabel(effectiveLevel);

    return CodexSettingsPanel(
      modelLabel: modelLabel,
      effortLabel: effortLabel,
      showSpeedButton: false,
      showAdvanced: _showAdvanced,
      advancedLabel: l.advanced,
      toggleButtonKey: '${prefix}_advanced',
      onToggleMode: () => setState(() => _showAdvanced = !_showAdvanced),
      quickPanelKey: '${prefix}_quick_panel',
      advancedPanelKey: '${prefix}_advanced_panel',
      modelLabelKey: '${prefix}_model_label',
      effortLabelKey: '${prefix}_effort_label',
      onModelTapWithContext: widget.modelOptions.isEmpty
          ? null
          : _openModelPicker,
      quickChild: _AntigravityQuickBody(
        prefix: prefix,
        levels: levels,
        effectiveLevel: effectiveLevel,
        tierName: widget.tierName,
        onThoughtLevelSelected: widget.onThoughtLevelSelected,
      ),
      advancedChild: _AntigravityAdvancedBody(
        prefix: prefix,
        modelLabel: modelLabel,
        levels: levels,
        effectiveLevel: effectiveLevel,
        tierName: widget.tierName,
        onModelTap: widget.modelOptions.isEmpty ? null : _openModelPicker,
        onThoughtLevelTap: levels.isEmpty || effectiveLevel == null
            ? null
            : (anchor) =>
                  _openThoughtLevelPicker(anchor, levels, effectiveLevel),
      ),
    );
  }
}

class _AntigravityQuickBody extends StatelessWidget {
  final String prefix;
  final List<String> levels;
  final String? effectiveLevel;
  final String? tierName;
  final ValueChanged<String> onThoughtLevelSelected;

  const _AntigravityQuickBody({
    required this.prefix,
    required this.levels,
    required this.effectiveLevel,
    required this.tierName,
    required this.onThoughtLevelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasTier = tierName != null && tierName!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (levels.isNotEmpty && effectiveLevel != null)
          SettingsLevelSlider<String>(
            levels: levels,
            value: effectiveLevel!,
            labelOf: antigravityThoughtLevelLabel,
            onChanged: onThoughtLevelSelected,
            sliderKey: '${prefix}_effort_slider',
          )
        else if (!hasTier)
          const SizedBox(height: 6),
        if (hasTier)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tierName!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AntigravityAdvancedBody extends StatelessWidget {
  final String prefix;
  final String modelLabel;
  final List<String> levels;
  final String? effectiveLevel;
  final String? tierName;
  final ValueChanged<BuildContext>? onModelTap;
  final ValueChanged<BuildContext>? onThoughtLevelTap;

  const _AntigravityAdvancedBody({
    required this.prefix,
    required this.modelLabel,
    required this.levels,
    required this.effectiveLevel,
    required this.tierName,
    required this.onModelTap,
    required this.onThoughtLevelTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasTier = tierName != null && tierName!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (rowContext) => _AntigravitySettingsRow(
            key: ValueKey('${prefix}_model_row'),
            label: l.model,
            value: modelLabel,
            onTap: onModelTap == null ? null : () => onModelTap!(rowContext),
          ),
        ),
        if (levels.isNotEmpty && effectiveLevel != null)
          Builder(
            builder: (rowContext) => _AntigravitySettingsRow(
              key: ValueKey('${prefix}_effort_row'),
              label: l.effort,
              value: antigravityThoughtLevelLabel(effectiveLevel!),
              onTap: onThoughtLevelTap == null
                  ? null
                  : () => onThoughtLevelTap!(rowContext),
            ),
          ),
        if (hasTier)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tierName!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AntigravitySettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _AntigravitySettingsRow({
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
