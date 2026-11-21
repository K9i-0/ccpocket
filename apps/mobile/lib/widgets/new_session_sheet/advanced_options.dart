import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../codex_effort_slider.dart';
import 'options_section.dart';

String newSessionClaudeModelLabel(
  Map<String, ClaudeModelOption> options,
  String model,
) => options[model]?.label ?? model;

class NewSessionAdvancedOptions extends StatelessWidget {
  final Provider provider;
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;

  // Claude
  final List<String> claudeModels;
  final Map<String, ClaudeModelOption> claudeModelOptions;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final String? selectedClaudeFallbackModel;
  final ValueChanged<String?> onClaudeFallbackModelChanged;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const NewSessionAdvancedOptions({
    super.key,
    required this.provider,
    required this.buildInputDecoration,
    required this.claudeModels,
    required this.claudeModelOptions,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.selectedClaudeFallbackModel,
    required this.onClaudeFallbackModelChanged,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
    required this.webSearchMode,
    required this.onWebSearchModeChanged,
    required this.networkAccessEnabled,
    required this.onNetworkAccessChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: ValueKey('dialog_advanced_${provider.value}'),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Text(
          l.advanced,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: provider == Provider.claude
            ? _ClaudeAdvancedOptions(
                buildInputDecoration: buildInputDecoration,
                claudeModels: claudeModels,
                claudeModelOptions: claudeModelOptions,
                claudeMaxTurnsController: claudeMaxTurnsController,
                maxTurnsError: maxTurnsError,
                onMaxTurnsChanged: onMaxTurnsChanged,
                claudeMaxBudgetController: claudeMaxBudgetController,
                maxBudgetError: maxBudgetError,
                onMaxBudgetChanged: onMaxBudgetChanged,
                selectedClaudeFallbackModel: selectedClaudeFallbackModel,
                onClaudeFallbackModelChanged: onClaudeFallbackModelChanged,
                claudeForkSession: claudeForkSession,
                onClaudeForkSessionChanged: onClaudeForkSessionChanged,
                claudePersistSession: claudePersistSession,
                onClaudePersistSessionChanged: onClaudePersistSessionChanged,
              ).buildChildren(context)
            : _CodexAdvancedOptions(
                buildInputDecoration: buildInputDecoration,
                webSearchMode: webSearchMode,
                onWebSearchModeChanged: onWebSearchModeChanged,
                networkAccessEnabled: networkAccessEnabled,
                onNetworkAccessChanged: onNetworkAccessChanged,
              ).buildChildren(context),
      ),
    );
  }
}

class _ClaudeAdvancedOptions extends StatelessWidget {
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;
  final List<String> claudeModels;
  final Map<String, ClaudeModelOption> claudeModelOptions;
  final TextEditingController claudeMaxTurnsController;
  final String? maxTurnsError;
  final VoidCallback onMaxTurnsChanged;
  final TextEditingController claudeMaxBudgetController;
  final String? maxBudgetError;
  final VoidCallback onMaxBudgetChanged;
  final String? selectedClaudeFallbackModel;
  final ValueChanged<String?> onClaudeFallbackModelChanged;
  final bool claudeForkSession;
  final ValueChanged<bool> onClaudeForkSessionChanged;
  final bool claudePersistSession;
  final ValueChanged<bool> onClaudePersistSessionChanged;

  const _ClaudeAdvancedOptions({
    required this.buildInputDecoration,
    required this.claudeModels,
    required this.claudeModelOptions,
    required this.claudeMaxTurnsController,
    required this.maxTurnsError,
    required this.onMaxTurnsChanged,
    required this.claudeMaxBudgetController,
    required this.maxBudgetError,
    required this.onMaxBudgetChanged,
    required this.selectedClaudeFallbackModel,
    required this.onClaudeFallbackModelChanged,
    required this.claudeForkSession,
    required this.onClaudeForkSessionChanged,
    required this.claudePersistSession,
    required this.onClaudePersistSessionChanged,
  });

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      TextField(
        key: const ValueKey('dialog_claude_max_turns'),
        controller: claudeMaxTurnsController,
        keyboardType: TextInputType.number,
        decoration: buildInputDecoration(
          l.maxTurns,
          hintText: l.maxTurnsHint,
          errorText: maxTurnsError,
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (_) {
          onMaxTurnsChanged();
        },
      ),
      const SizedBox(height: 8),
      NewSessionResponsiveOptionRow(
        leading: TextField(
          key: const ValueKey('dialog_claude_max_budget'),
          controller: claudeMaxBudgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: buildInputDecoration(
            l.maxBudgetUsd,
            hintText: l.maxBudgetHint,
            errorText: maxBudgetError,
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (_) {
            onMaxBudgetChanged();
          },
        ),
        trailing: DropdownButtonFormField<String?>(
          key: const ValueKey('dialog_claude_fallback_model'),
          initialValue: selectedClaudeFallbackModel,
          isExpanded: true,
          decoration: buildInputDecoration(l.fallbackModel),
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l.defaultLabel, style: const TextStyle(fontSize: 13)),
            ),
            for (final model in claudeModels)
              DropdownMenuItem<String?>(
                value: model,
                child: Text(
                  newSessionClaudeModelLabel(claudeModelOptions, model),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
          onChanged: (value) => onClaudeFallbackModelChanged(value),
        ),
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        key: const ValueKey('dialog_claude_fork_session'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.forkSessionOnResume,
          style: const TextStyle(fontSize: 13),
        ),
        value: claudeForkSession,
        onChanged: (value) {
          onClaudeForkSessionChanged(value);
        },
      ),
      SwitchListTile(
        key: const ValueKey('dialog_claude_persist_session'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          l.persistSessionHistory,
          style: const TextStyle(fontSize: 13),
        ),
        value: claudePersistSession,
        onChanged: (value) {
          onClaudePersistSessionChanged(value);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: buildChildren(context));
  }
}

class NewSessionCodexModelOptions extends StatelessWidget {
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;
  final List<String> models;
  final String? selectedModel;
  final ValueChanged<String?> onModelChanged;
  final List<ReasoningEffort> reasoningEfforts;
  final ReasoningEffort reasoningEffort;
  final ValueChanged<ReasoningEffort> onReasoningEffortChanged;
  final CodexSpeed speed;
  final List<CodexSpeed> availableSpeeds;
  final ValueChanged<CodexSpeed> onSpeedChanged;

  const NewSessionCodexModelOptions({
    super.key,
    required this.buildInputDecoration,
    required this.models,
    required this.selectedModel,
    required this.onModelChanged,
    required this.reasoningEfforts,
    required this.reasoningEffort,
    required this.onReasoningEffortChanged,
    required this.speed,
    required this.availableSpeeds,
    required this.onSpeedChanged,
  });

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    final effectiveEffort = reasoningEfforts.contains(reasoningEffort)
        ? reasoningEffort
        : reasoningEfforts.firstOrNull;
    return [
      DropdownButtonFormField<String>(
        key: const ValueKey('dialog_codex_model'),
        initialValue: models.contains(selectedModel)
            ? selectedModel
            : models.firstOrNull,
        isExpanded: true,
        decoration: buildInputDecoration(l.model),
        items: [
          for (final model in models)
            DropdownMenuItem(
              value: model,
              child: Text(codexModelDisplayName(model)),
            ),
        ],
        onChanged: onModelChanged,
      ),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: ValueKey('codex_effort_field_${selectedModel ?? 'default'}'),
        child: DropdownButtonFormField<ReasoningEffort>(
          key: const ValueKey('dialog_codex_effort_advanced'),
          initialValue: effectiveEffort,
          isExpanded: true,
          decoration: buildInputDecoration(l.effort),
          items: [
            for (final effort in reasoningEfforts)
              DropdownMenuItem(value: effort, child: Text(effort.label)),
          ],
          onChanged: (value) {
            if (value != null) onReasoningEffortChanged(value);
          },
        ),
      ),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: ValueKey(
          'codex_speed_field_${selectedModel ?? 'default'}_${speed.value}_${availableSpeeds.map((value) => value.value).join(',')}',
        ),
        child: DropdownButtonFormField<CodexSpeed>(
          key: const ValueKey('dialog_codex_speed_advanced'),
          initialValue: speed,
          isExpanded: true,
          itemHeight: null,
          selectedItemBuilder: (_) => [
            if (!availableSpeeds.contains(speed))
              Text('${speed.label} (unavailable)'),
            for (final option in availableSpeeds) Text(option.label),
          ],
          decoration: buildInputDecoration(
            'Speed',
            errorText: availableSpeeds.contains(speed)
                ? null
                : codexSpeedUnavailableMessage(speed),
          ),
          items: [
            if (!availableSpeeds.contains(speed))
              DropdownMenuItem(
                value: speed,
                enabled: false,
                child: Text('${speed.label} (unavailable)'),
              ),
            for (final option in availableSpeeds)
              DropdownMenuItem(
                value: option,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label),
                      if (option.description != null)
                        Text(
                          option.description!,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSpeedChanged(value);
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: buildChildren(context));
  }
}

class _CodexAdvancedOptions extends StatelessWidget {
  final InputDecoration Function(
    String, {
    String? hintText,
    Widget? prefixIcon,
    String? errorText,
  })
  buildInputDecoration;
  final WebSearchMode? webSearchMode;
  final ValueChanged<WebSearchMode?> onWebSearchModeChanged;
  final bool networkAccessEnabled;
  final ValueChanged<bool> onNetworkAccessChanged;

  const _CodexAdvancedOptions({
    required this.buildInputDecoration,
    required this.webSearchMode,
    required this.onWebSearchModeChanged,
    required this.networkAccessEnabled,
    required this.onNetworkAccessChanged,
  });

  List<Widget> buildChildren(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      DropdownButtonFormField<WebSearchMode?>(
        key: const ValueKey('dialog_codex_web_search_mode'),
        initialValue: webSearchMode,
        isExpanded: true,
        decoration: buildInputDecoration(l.webSearch),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: [
          DropdownMenuItem<WebSearchMode?>(
            value: null,
            child: Text(l.defaultLabel, style: const TextStyle(fontSize: 13)),
          ),
          for (final mode in WebSearchMode.values)
            DropdownMenuItem<WebSearchMode?>(
              value: mode,
              child: Text(mode.label, style: const TextStyle(fontSize: 13)),
            ),
        ],
        onChanged: onWebSearchModeChanged,
      ),
      const SizedBox(height: 4),
      SwitchListTile(
        key: const ValueKey('dialog_codex_network_access'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.networkAccess, style: const TextStyle(fontSize: 13)),
        value: networkAccessEnabled,
        onChanged: (value) {
          onNetworkAccessChanged(value);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: buildChildren(context));
  }
}
