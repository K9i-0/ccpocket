import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_tiles.dart';
import '../data/local_bridge_client.dart';
import '../data/local_bridge_models.dart';
import '../state/local_bridge_state.dart';
import 'local_bridge_setting_editors.dart';

/// Label, icon and help text of one Bridge setting.
class LocalBridgeSettingInfo {
  const LocalBridgeSettingInfo(
    this.key,
    this.icon,
    this.label, [
    this.description,
  ]);

  final String key;
  final IconData icon;
  final String Function(AppLocalizations l) label;
  final String Function(AppLocalizations l)? description;
}

class _SettingGroupInfo {
  const _SettingGroupInfo(this.title, this.settings);

  final String Function(AppLocalizations l) title;
  final List<LocalBridgeSettingInfo> settings;
}

final _groups = <_SettingGroupInfo>[
  _SettingGroupInfo((l) => l.localBridgeGroupNetwork, [
    LocalBridgeSettingInfo(
      'port',
      Icons.tag_rounded,
      (l) => l.localBridgeSettingPort,
      (l) => l.localBridgeSettingPortDesc,
    ),
    LocalBridgeSettingInfo(
      'host',
      Icons.lan_outlined,
      (l) => l.localBridgeSettingHost,
      (l) => l.localBridgeSettingHostDesc,
    ),
    LocalBridgeSettingInfo(
      'publicWsUrl',
      Icons.public_rounded,
      (l) => l.localBridgeSettingPublicWsUrl,
      (l) => l.localBridgeSettingPublicWsUrlDesc,
    ),
  ]),
  _SettingGroupInfo((l) => l.localBridgeGroupAccess, [
    LocalBridgeSettingInfo(
      'allowedDirs',
      Icons.folder_open_rounded,
      (l) => l.localBridgeSettingAllowedDirs,
      (l) => l.localBridgeSettingAllowedDirsDesc,
    ),
    LocalBridgeSettingInfo(
      'readOnlyDirs',
      Icons.folder_special_outlined,
      (l) => l.localBridgeSettingReadOnlyDirs,
      (l) => l.localBridgeSettingReadOnlyDirsDesc,
    ),
    LocalBridgeSettingInfo(
      'fileDownloadAllowAllPaths',
      Icons.download_rounded,
      (l) => l.localBridgeSettingFileDownloadAllowAllPaths,
      (l) => l.localBridgeSettingFileDownloadAllowAllPathsDesc,
    ),
  ]),
  _SettingGroupInfo((l) => l.localBridgeGroupAgents, [
    LocalBridgeSettingInfo(
      'allowClaudeOAuth',
      Icons.verified_user_outlined,
      (l) => l.localBridgeSettingAllowClaudeOAuth,
      (l) => l.localBridgeSettingAllowClaudeOAuthDesc,
    ),
    LocalBridgeSettingInfo(
      'antigravityApiKey',
      Icons.key_rounded,
      (l) => l.localBridgeSettingAntigravityApiKey,
      (l) => l.localBridgeSettingAntigravityApiKeyDesc,
    ),
    LocalBridgeSettingInfo(
      'codexAppServerMode',
      Icons.hub_outlined,
      (l) => l.localBridgeSettingCodexAppServerMode,
      (l) => l.localBridgeSettingCodexAppServerModeDesc,
    ),
    LocalBridgeSettingInfo(
      'codexSharedAppServerUrl',
      Icons.link_rounded,
      (l) => l.localBridgeSettingCodexSharedAppServerUrl,
      (l) => l.localBridgeSettingCodexSharedAppServerUrlDesc,
    ),
    LocalBridgeSettingInfo(
      'codexAssistModel',
      Icons.auto_awesome_outlined,
      (l) => l.localBridgeSettingCodexAssistModel,
      (l) => l.localBridgeSettingCodexAssistModelDesc,
    ),
    LocalBridgeSettingInfo(
      'codexAssistReasoningEffort',
      Icons.psychology_outlined,
      (l) => l.localBridgeSettingCodexAssistReasoningEffort,
      (l) => l.localBridgeSettingCodexAssistReasoningEffortDesc,
    ),
    LocalBridgeSettingInfo(
      'notifyGoalTurnCompleted',
      Icons.notifications_active_outlined,
      (l) => l.localBridgeSettingNotifyGoalTurnCompleted,
      (l) => l.localBridgeSettingNotifyGoalTurnCompletedDesc,
    ),
  ]),
  _SettingGroupInfo((l) => l.localBridgeGroupSecurity, [
    LocalBridgeSettingInfo(
      'insecureNoAuth',
      Icons.no_encryption_outlined,
      (l) => l.localBridgeSettingInsecureNoAuth,
      (l) => l.localBridgeSettingInsecureNoAuthDesc,
    ),
  ]),
];

/// Folders outside projects that agents commonly write files to, offered as
/// one-tap additions to the view-only folders.
List<FolderSuggestion> readOnlyFolderSuggestions(
  AppLocalizations l, {
  String? home,
  TargetPlatform? platform,
}) {
  final isMac = (platform ?? defaultTargetPlatform) == TargetPlatform.macOS;
  final userHome = home ?? realHomeDirectory();
  return [
    FolderSuggestion(
      id: 'tmp',
      title: l.localBridgeFolderSuggestionTmpTitle,
      description: l.localBridgeFolderSuggestionTmpDesc,
      // On macOS /tmp is a link to /private/tmp and agents report either
      // spelling; the Bridge checks the path as written first.
      paths: ['/tmp', if (isMac) '/private/tmp'],
    ),
    FolderSuggestion(
      id: 'antigravity',
      title: l.localBridgeFolderSuggestionAntigravityTitle,
      description: l.localBridgeFolderSuggestionAntigravityDesc,
      // The default profile, and the one the Bridge uses with an API key.
      paths: [
        '$userHome/.gemini/antigravity-cli/brain',
        '$userHome/.gemini/antigravity-cli-ccpocket-apikey/brain',
      ],
    ),
  ];
}

/// Every Bridge setting the config file can hold, grouped.
class LocalBridgeSettingsSection extends StatelessWidget {
  const LocalBridgeSettingsSection({
    super.key,
    required this.state,
    required this.onEdit,
  });

  final LocalBridgeState state;
  final void Function(String key, Object? value) onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final config = state.config;
    if (config == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in _groups)
          SettingsGroup(
            title: group.title(l),
            children: [
              for (final info in group.settings)
                if (config.setting(info.key) case final setting?)
                  LocalBridgeSettingTile(
                    info: info,
                    setting: setting,
                    value: state.displayValue(setting),
                    edited: state.edits.containsKey(setting.key),
                    error: state.settingErrors[setting.key],
                    enabled: state.busy == LocalBridgeBusy.none,
                    onEdit: (value) => onEdit(setting.key, value),
                  ),
            ],
          ),
      ],
    );
  }
}

class LocalBridgeSettingTile extends StatelessWidget {
  const LocalBridgeSettingTile({
    super.key,
    required this.info,
    required this.setting,
    required this.value,
    required this.edited,
    required this.enabled,
    required this.onEdit,
    this.error,
  });

  final LocalBridgeSettingInfo info;
  final LocalBridgeSetting setting;

  /// Saved value or the unsaved edit.
  final Object? value;
  final bool edited;
  final bool enabled;
  final String? error;
  final ValueChanged<Object?> onEdit;

  bool get _isSecret => setting.type == LocalBridgeSettingType.secret;

  String _choiceLabel(AppLocalizations l, String value) => switch (value) {
    'private' => l.localBridgeCodexModePrivate,
    'managed' => l.localBridgeCodexModeManaged,
    'external' => l.localBridgeCodexModeExternal,
    _ => value,
  };

  String _summary(AppLocalizations l) {
    if (_isSecret) {
      final isSet = edited
          ? value != null
          : (setting.lockedByEnv ? setting.configured : setting.fileIsSet);
      return isSet
          ? l.localBridgeSettingConfigured
          : l.localBridgeSettingNotSet;
    }
    return switch (value) {
      null => l.localBridgeSettingNotSet,
      final List<Object?> dirs when dirs.contains('*') =>
        l.localBridgeAllowedDirsAll,
      final List<Object?> dirs => dirs.join('\n'),
      final String choice
          when setting.type == LocalBridgeSettingType.enumeration =>
        _choiceLabel(l, choice),
      final other => '$other',
    };
  }

  Future<void> _openEditor(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final title = info.label(l);
    final Widget dialog = switch (setting.type) {
      LocalBridgeSettingType.dirs => FoldersSettingDialog(
        title: title,
        description: info.description?.call(l),
        initialValue: [
          if (value case final List<Object?> dirs) ...dirs.whereType<String>(),
        ],
        allowAll: setting.key == 'allowedDirs',
        // Only the project folders need at least one entry.
        allowEmpty: setting.key != 'allowedDirs',
        suggestions: setting.key == 'readOnlyDirs'
            ? readOnlyFolderSuggestions(l)
            : const [],
      ),
      LocalBridgeSettingType.enumeration => ChoiceSettingDialog(
        title: title,
        description: info.description?.call(l),
        values: setting.values,
        current: value is String ? value as String : null,
        labelOf: (choice) => _choiceLabel(l, choice),
      ),
      _ => TextSettingDialog(
        title: title,
        description: info.description?.call(l),
        initialValue: _isSecret || value == null ? '' : '$value',
        numeric: setting.type == LocalBridgeSettingType.port,
        obscure: _isSecret,
      ),
    };
    final result = await showDialog<SettingEdit>(
      context: context,
      builder: (_) => dialog,
    );
    if (result != null) onEdit(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locked = setting.lockedByEnv;
    final description = info.description?.call(l);
    final status =
        error ?? (locked ? l.localBridgeSettingLockedByEnv(setting.env) : null);
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
    );
    final statusStyle = theme.textTheme.bodySmall?.copyWith(
      color: error != null ? cs.error : cs.onSurfaceVariant,
    );
    final title = Row(
      children: [
        Flexible(child: Text(info.label(l))),
        if (edited) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.circle,
            key: ValueKey('local_bridge_setting_edited:${setting.key}'),
            size: 8,
            color: cs.tertiary,
          ),
        ],
      ],
    );

    if (setting.type == LocalBridgeSettingType.boolean) {
      return SwitchListTile(
        key: ValueKey('local_bridge_setting_toggle:${setting.key}'),
        secondary: SettingsLeadingIcon(info.icon),
        title: title,
        subtitle: description == null && status == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null)
                    Text(description, style: descriptionStyle),
                  if (status != null) Text(status, style: statusStyle),
                ],
              ),
        value: value == true,
        onChanged: locked || !enabled ? null : onEdit,
      );
    }
    return ListTile(
      key: ValueKey('local_bridge_setting_tile:${setting.key}'),
      leading: SettingsLeadingIcon(info.icon),
      title: title,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Text(
              description,
              key: ValueKey('local_bridge_setting_description:${setting.key}'),
              style: descriptionStyle,
            ),
            const SizedBox(height: 4),
          ],
          Text(_summary(l)),
          if (status != null) Text(status, style: statusStyle),
        ],
      ),
      trailing: locked
          ? Icon(Icons.lock_outline_rounded, size: 18, color: cs.outline)
          : const Icon(Icons.chevron_right_rounded),
      enabled: enabled,
      onTap: locked ? null : () => _openEditor(context),
    );
  }
}
