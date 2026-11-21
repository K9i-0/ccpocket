import '../../../widgets/preview_badge.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../models/model_picker_style.dart';
import '../../../models/new_session_tab.dart';
import '../../../services/bridge_service.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import '../widgets/enabled_models_bottom_sheet.dart';
import '../widgets/new_session_tabs_bottom_sheet.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/terminal_app_bottom_sheet.dart';

/// Agents offered by the selector, in its fixed order.
const _selectableAgents = [
  NewSessionTab.codex,
  NewSessionTab.claude,
  NewSessionTab.antigravity,
];

class AgentsSettingsSection extends StatelessWidget {
  const AgentsSettingsSection({
    super.key,
    required this.state,
    required this.visibility,
  });

  final SettingsState state;
  final SettingsVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    final agents = enabledAgents(
      state.newSessionTabs,
      antigravity: state.showAntigravityTab,
    );
    final hasSessionOptions =
        visibility.codexEnabled || visibility.claudeEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            SettingsItem(
              id: SettingsEntryIds.enabledAgents,
              child: SettingsControlTile(
                icon: Icons.smart_toy_rounded,
                title: l.settingsEnabledAgents,
                // Antigravity is offered only by a Bridge that has its CLI.
                description: l.showAntigravityTabSubtitle,
                control: SegmentedButton<NewSessionTab>(
                  key: const ValueKey('enabled_agents_selector'),
                  multiSelectionEnabled: true,
                  segments: [
                    for (final agent in _selectableAgents)
                      ButtonSegment(
                        value: agent,
                        label: Text(
                          agent.label,
                          key: ValueKey('enabled_agent_${agent.value}'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                  ],
                  selected: agents.toSet(),
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    for (final agent in _selectableAgents) {
                      cubit.setAgentEnabled(agent, selection.contains(agent));
                    }
                  },
                ),
              ),
            ),
            if (visibility.multipleAgents)
              SettingsItem(
                id: SettingsEntryIds.newSessionTabs,
                child: SettingsNavTile(
                  icon: Icons.tab_rounded,
                  title: Text(l.settingsNewSessionTabs),
                  subtitle: agents.map((t) => t.localizedLabel(l)).join(', '),
                  onTap: () => showNewSessionTabsBottomSheet(
                    context: context,
                    current: agents,
                    onChanged: cubit.setNewSessionTabs,
                  ),
                ),
              ),
            SettingsItem(
              id: SettingsEntryIds.enabledModels,
              child: SettingsNavTile(
                key: const ValueKey('enabled_models_tile'),
                icon: Icons.checklist_rounded,
                title: Text(l.settingsEnabledModels),
                subtitle: _enabledModelsSummary(l, agents, state),
                onTap: () => showEnabledModelsBottomSheet(
                  context: context,
                  agents: agents,
                  initialEnabledByProvider: {
                    Provider.claude: state.enabledClaudeModels,
                    Provider.codex: state.enabledCodexModels,
                    Provider.antigravity: state.enabledAntigravityModels,
                  },
                  bridge: _maybeBridge(context),
                  onSaved: (updated) {
                    for (final entry in updated.entries) {
                      cubit.setEnabledModelsForProvider(entry.key, entry.value);
                    }
                  },
                ),
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.modelPickerStyle,
              child: SettingsControlTile(
                key: const ValueKey('model_picker_style_tile'),
                icon: Icons.arrow_drop_down_circle_outlined,
                title: l.settingsModelPickerStyle,
                description: l.settingsModelPickerStyleSubtitle,
                control: SegmentedButton<ModelPickerStyle>(
                  key: const ValueKey('model_picker_style_selector'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ModelPickerStyle.bottomSheet,
                      icon: const Icon(Icons.view_agenda_outlined, size: 18),
                      label: Text(l.modelPickerStyleBottomSheet),
                    ),
                    ButtonSegment(
                      value: ModelPickerStyle.popupMenu,
                      icon: const Icon(Icons.menu_open_rounded, size: 18),
                      label: Text(l.modelPickerStylePopupMenu),
                    ),
                  ],
                  selected: {state.modelPickerStyle},
                  onSelectionChanged: (selection) =>
                      cubit.setModelPickerStyle(selection.first),
                ),
              ),
            ),
          ],
        ),
        if (hasSessionOptions)
          SettingsGroup(
            title: l.settingsGroupSessions,
            children: [
              if (visibility.codexEnabled) ...[
                SettingsItem(
                  id: SettingsEntryIds.autoRenameCodex,
                  child: SettingsSwitchTile(
                    icon: Icons.drive_file_rename_outline_rounded,
                    title: l.autoRenameCodexSessions,
                    subtitle: l.autoRenameCodexSessionsSubtitle,
                    value: state.autoRenameCodexSessions,
                    onChanged: cubit.setAutoRenameCodexSessions,
                  ),
                ),
                SettingsItem(
                  id: SettingsEntryIds.extendedCodexEfforts,
                  child: SettingsSwitchTile(
                    key: const ValueKey('show_extended_codex_efforts_toggle'),
                    icon: Icons.linear_scale_rounded,
                    title: l.showExtendedCodexEfforts,
                    subtitle: l.showExtendedCodexEffortsSubtitle,
                    value: state.showExtendedCodexEfforts,
                    onChanged: cubit.setShowExtendedCodexEfforts,
                  ),
                ),
              ],
              if (visibility.claudeEnabled)
                SettingsItem(
                  id: SettingsEntryIds.autoRenameClaude,
                  child: SettingsSwitchTile(
                    icon: Icons.drive_file_rename_outline_rounded,
                    title: l.autoRenameClaudeSessions,
                    subtitle: l.autoRenameClaudeSessionsSubtitle,
                    value: state.autoRenameClaudeSessions,
                    onChanged: cubit.setAutoRenameClaudeSessions,
                  ),
                ),
            ],
          ),
        SettingsGroup(
          title: l.settingsGroupFilesAndApps,
          children: [
            SettingsItem(
              id: SettingsEntryIds.showHiddenDirectories,
              child: SettingsSwitchTile(
                key: const ValueKey('show_hidden_directories_toggle'),
                icon: Icons.folder_open_rounded,
                title: l.showHiddenDirectories,
                subtitle: l.showHiddenDirectoriesSubtitle,
                value: state.showHiddenDirectories,
                onChanged: cubit.setShowHiddenDirectories,
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.showBridgeName,
              child: SettingsSwitchTile(
                icon: Icons.dns_rounded,
                title: l.showBridgeNameInSessionList,
                subtitle: l.showBridgeNameInSessionListSubtitle,
                value: state.showBridgeNameInSessionList,
                onChanged: cubit.setShowBridgeNameInSessionList,
              ),
            ),
            if (visibility.terminalAppEnabled)
              SettingsItem(
                id: SettingsEntryIds.terminalApp,
                child: SettingsNavTile(
                  icon: Icons.terminal_rounded,
                  title: Row(
                    children: [
                      Flexible(child: Text(l.terminalApp)),
                      const SizedBox(width: 8),
                      PreviewBadge(label: l.terminalAppExperimental),
                    ],
                  ),
                  subtitle: state.terminalApp.isConfigured
                      ? state.terminalApp.displayName
                      : l.terminalAppNone,
                  onTap: () => showTerminalAppBottomSheet(
                    context: context,
                    current: state.terminalApp,
                    onChanged: cubit.setTerminalApp,
                    onClear: cubit.clearTerminalApp,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

BridgeService? _maybeBridge(BuildContext context) {
  try {
    return context.read<BridgeService>();
  } on ProviderNotFoundException {
    return null;
  }
}

String _enabledModelsSummary(
  AppLocalizations l,
  List<NewSessionTab> agents,
  SettingsState state,
) {
  final parts = <String>[];
  for (final agent in agents) {
    final enabled = state.enabledModelsForProvider(agent.toProvider());
    if (enabled.isNotEmpty) {
      parts.add('${agent.label}: ${enabled.length}');
    }
  }
  return parts.isEmpty ? l.settingsEnabledModelsAll : parts.join(', ');
}
