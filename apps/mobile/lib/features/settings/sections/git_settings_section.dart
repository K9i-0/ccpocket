import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/git_diff_interaction_mode.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import '../widgets/settings_tiles.dart';

class GitSettingsSection extends StatelessWidget {
  const GitSettingsSection({super.key, required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    return SettingsGroup(
      title: l.settingsGroupDiffView,
      children: [
        SettingsItem(
          id: SettingsEntryIds.gitDiffMode,
          child: SettingsControlTile(
            icon: Icons.touch_app_rounded,
            title: l.gitDiffInteractionMode,
            description: switch (state.gitDiffInteractionMode) {
              GitDiffInteractionMode.quickActions =>
                l.gitDiffQuickActionsDescription,
              GitDiffInteractionMode.scrollFirst =>
                l.gitDiffScrollFirstDescription,
            },
            control: SegmentedButton<GitDiffInteractionMode>(
              key: const ValueKey('git_diff_interaction_mode_segment'),
              segments: [
                ButtonSegment(
                  value: GitDiffInteractionMode.quickActions,
                  label: Text(l.gitDiffQuickActions),
                ),
                ButtonSegment(
                  value: GitDiffInteractionMode.scrollFirst,
                  label: Text(l.gitDiffScrollFirst),
                ),
              ],
              selected: {state.gitDiffInteractionMode},
              onSelectionChanged: (selected) =>
                  cubit.setGitDiffInteractionMode(selected.first),
              showSelectedIcon: false,
            ),
          ),
        ),
        SettingsItem(
          id: SettingsEntryIds.gitDiffAutoLandscape,
          child: SettingsSwitchTile(
            key: const ValueKey('git_diff_focus_auto_landscape_toggle'),
            icon: Icons.screen_rotation_rounded,
            title: l.gitDiffFocusAutoLandscape,
            subtitle: l.gitDiffFocusAutoLandscapeDescription,
            value: state.gitDiffFocusAutoLandscape,
            onChanged: cubit.setGitDiffFocusAutoLandscape,
          ),
        ),
        SettingsItem(
          id: SettingsEntryIds.remoteGitStatusBadge,
          child: SettingsSwitchTile(
            key: const ValueKey('remote_git_status_badge_toggle'),
            icon: Icons.cloud_sync_rounded,
            title: l.remoteGitStatusBadge,
            subtitle: l.remoteGitStatusBadgeDescription,
            value: state.showRemoteGitStatusBadge,
            onChanged: cubit.setShowRemoteGitStatusBadge,
          ),
        ),
      ],
    );
  }
}
