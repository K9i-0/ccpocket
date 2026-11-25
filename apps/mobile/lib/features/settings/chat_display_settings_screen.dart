import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/chat_display_filter.dart';
import 'state/settings_cubit.dart';
import 'state/settings_state.dart';

String chatDisplayPresetLabel(AppLocalizations l, ChatDisplayPreset preset) =>
    switch (preset) {
      ChatDisplayPreset.all => l.displayPresetAll,
      ChatDisplayPreset.recommended => l.displayPresetRecommended,
      ChatDisplayPreset.custom => l.displayPresetCustom,
    };

String chatDisplayFilterSummary(AppLocalizations l, ChatDisplayFilter filter) =>
    switch (filter.preset) {
      ChatDisplayPreset.all => l.displayPresetAll,
      ChatDisplayPreset.recommended => l.displayPresetRecommended,
      ChatDisplayPreset.custom => l.displayPresetCustomSummary(
        filter.enabledCount,
        ChatDisplayFilter.totalCategoryCount,
      ),
    };

class ChatDisplaySettingsScreen extends StatelessWidget {
  const ChatDisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.chatDisplayMode)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();
          final filter = state.chatDisplayFilter;
          final preset = filter.preset;
          final cs = Theme.of(context).colorScheme;
          final theme = Theme.of(context);

          final description = switch (preset) {
            ChatDisplayPreset.all => l.displayPresetAllDescription,
            ChatDisplayPreset.recommended =>
              l.displayPresetRecommendedDescription,
            ChatDisplayPreset.custom => l.displayPresetCustomDescription,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<ChatDisplayPreset>(
                        key: const ValueKey('display_preset_selector'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ChatDisplayPreset.all,
                            label: Text(l.displayPresetAll),
                          ),
                          ButtonSegment(
                            value: ChatDisplayPreset.recommended,
                            label: Text(l.displayPresetRecommended),
                          ),
                          ButtonSegment(
                            value: ChatDisplayPreset.custom,
                            label: Text(l.displayPresetCustom),
                          ),
                        ],
                        selected: {preset},
                        onSelectionChanged: (selection) =>
                            cubit.setChatDisplayPreset(selection.first),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  l.displayItemsSectionTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _DisplayItemToggle(
                      key: const ValueKey('display_item_tasks'),
                      icon: Icons.checklist_rounded,
                      title: l.displayItemTasks,
                      subtitle: l.displayItemTasksSubtitle,
                      value: filter.tasks,
                      onChanged: (v) =>
                          cubit.setChatDisplayFilter(filter.copyWith(tasks: v)),
                    ),
                    const Divider(height: 1),
                    _DisplayItemToggle(
                      key: const ValueKey('display_item_thinking'),
                      icon: Icons.psychology_outlined,
                      title: l.displayItemThinking,
                      subtitle: l.displayItemThinkingSubtitle,
                      value: filter.thinking,
                      onChanged: (v) => cubit.setChatDisplayFilter(
                        filter.copyWith(thinking: v),
                      ),
                    ),
                    const Divider(height: 1),
                    _DisplayItemToggle(
                      key: const ValueKey('display_item_subagents'),
                      icon: Icons.smart_toy_outlined,
                      title: l.displayItemSubagents,
                      subtitle: l.displayItemSubagentsSubtitle,
                      value: filter.subagents,
                      onChanged: (v) => cubit.setChatDisplayFilter(
                        filter.copyWith(subagents: v),
                      ),
                    ),
                    const Divider(height: 1),
                    _DisplayItemToggle(
                      key: const ValueKey('display_item_code_edits'),
                      icon: Icons.edit_note_rounded,
                      title: l.displayItemCodeEdits,
                      subtitle: l.displayItemCodeEditsSubtitle,
                      value: filter.codeEdits,
                      onChanged: (v) => cubit.setChatDisplayFilter(
                        filter.copyWith(codeEdits: v),
                      ),
                    ),
                    const Divider(height: 1),
                    _DisplayItemToggle(
                      key: const ValueKey('display_item_other_tools'),
                      icon: Icons.terminal_rounded,
                      title: l.displayItemOtherTools,
                      subtitle: l.displayItemOtherToolsSubtitle,
                      value: filter.otherTools,
                      onChanged: (v) => cubit.setChatDisplayFilter(
                        filter.copyWith(otherTools: v),
                      ),
                    ),
                    const Divider(height: 1),
                    _DisplayItemToggle(
                      key: const ValueKey('display_item_tool_results'),
                      icon: Icons.output_rounded,
                      title: l.displayItemToolResults,
                      subtitle: l.displayItemToolResultsSubtitle,
                      value: filter.toolResults,
                      onChanged: (v) => cubit.setChatDisplayFilter(
                        filter.copyWith(toolResults: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l.displayItemsAlwaysVisibleNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DisplayItemToggle extends StatelessWidget {
  const _DisplayItemToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
