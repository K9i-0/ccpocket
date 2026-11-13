import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/new_session_tab.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import '../widgets/new_session_tabs_bottom_sheet.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/terminal_app_bottom_sheet.dart';

String enabledAgentsLabel(AppLocalizations l, EnabledAgentsMode mode) =>
    switch (mode) {
      EnabledAgentsMode.both => l.settingsAgentsBoth,
      EnabledAgentsMode.codex => 'Codex',
      EnabledAgentsMode.claude => 'Claude',
    };

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
    final mode = enabledAgentsModeFromTabs(state.newSessionTabs);
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
                control: SegmentedButton<EnabledAgentsMode>(
                  key: const ValueKey('enabled_agents_selector'),
                  segments: [
                    for (final value in EnabledAgentsMode.values)
                      ButtonSegment(
                        value: value,
                        label: Text(enabledAgentsLabel(l, value)),
                      ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      cubit.setEnabledAgentsMode(selection.single),
                ),
              ),
            ),
            if (visibility.bothAgents)
              SettingsItem(
                id: SettingsEntryIds.newSessionTabs,
                child: SettingsNavTile(
                  icon: Icons.tab_rounded,
                  title: Text(l.settingsNewSessionTabs),
                  subtitle: state.newSessionTabs
                      .map((t) => t.localizedLabel(l))
                      .join(', '),
                  onTap: () => showNewSessionTabsBottomSheet(
                    context: context,
                    current: state.newSessionTabs,
                    onChanged: cubit.setNewSessionTabs,
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
                      _ExperimentalBadge(label: l.terminalAppExperimental),
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

class _ExperimentalBadge extends StatelessWidget {
  const _ExperimentalBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: cs.onTertiaryContainer),
      ),
    );
  }
}
