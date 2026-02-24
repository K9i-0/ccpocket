import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/logger.dart';
import '../../features/settings/state/settings_cubit.dart';
import '../../features/settings/state/settings_state.dart';
import '../../features/settings/widgets/app_locale_bottom_sheet.dart';
import '../../features/settings/widgets/theme_bottom_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';

@RoutePage()
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.debug)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return ListView(
            children: [
              ListTile(
                key: const ValueKey('debug_theme_button'),
                leading: Icon(Icons.palette, color: cs.primary),
                title: Text(l.theme),
                subtitle: Text(_getThemeLabel(context, settings.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showThemeBottomSheet(
                  context: context,
                  current: settings.themeMode,
                  onChanged: (mode) =>
                      context.read<SettingsCubit>().setThemeMode(mode),
                ),
              ),
              ListTile(
                key: const ValueKey('debug_language_button'),
                leading: Icon(Icons.language, color: cs.primary),
                title: Text(l.language),
                subtitle: Text(
                  getAppLocaleLabel(context, settings.appLocaleId),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAppLocaleBottomSheet(
                  context: context,
                  current: settings.appLocaleId,
                  onChanged: (id) =>
                      context.read<SettingsCubit>().setAppLocaleId(id),
                ),
              ),
              ListTile(
                key: const ValueKey('debug_update_track_button'),
                leading: Icon(Icons.update, color: cs.primary),
                title: Text(l.updateTrack),
                subtitle: Text(
                  settings.shorebirdTrack == 'staging'
                      ? l.updateTrackStaging
                      : l.updateTrackStable,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showUpdateTrackSheet(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l.logs),
                subtitle: Text(l.viewApplicationLogs),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TalkerScreen(talker: logger),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.science),
                title: Text(l.mockPreview),
                subtitle: Text(l.viewMockChatScenarios),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.router.push(MockPreviewRoute()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateTrackSheet(BuildContext context, SettingsState settings) {
    final l = AppLocalizations.of(context);
    final tracks = [
      ('stable', l.updateTrackStable),
      ('staging', l.updateTrackStaging),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.updateTrackDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            RadioGroup<String>(
              groupValue: settings.shorebirdTrack,
              onChanged: (v) {
                if (v != null) {
                  context.read<SettingsCubit>().setShorebirdTrack(v);
                  Navigator.pop(context);
                  _checkForUpdate(context, v);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (value, label) in tracks)
                    RadioListTile<String>(title: Text(label), value: value),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdate(BuildContext context, String trackName) async {
    try {
      final updater = ShorebirdUpdater();
      final track = UpdateTrack(trackName);
      final status = await updater.checkForUpdate(track: track);
      if (status == UpdateStatus.outdated) {
        await updater.update(track: track);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).updateDownloaded),
            ),
          );
        }
      }
    } catch (e) {
      logger.warning('[shorebird] checkForUpdate failed: $e');
    }
  }

  String _getThemeLabel(BuildContext context, ThemeMode mode) {
    final l = AppLocalizations.of(context);
    switch (mode) {
      case ThemeMode.system:
        return l.themeSystem;
      case ThemeMode.light:
        return l.themeLight;
      case ThemeMode.dark:
        return l.themeDark;
    }
  }
}
