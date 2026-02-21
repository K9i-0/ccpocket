import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
