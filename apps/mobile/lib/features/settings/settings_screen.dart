import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';
import '../../services/bridge_service.dart';
import '../../services/database_service.dart';
import 'state/settings_cubit.dart';
import 'state/settings_state.dart';
import 'widgets/app_locale_bottom_sheet.dart';
import 'widgets/speech_locale_bottom_sheet.dart';
import 'widgets/theme_bottom_sheet.dart';
import 'widgets/backup_section.dart';
import 'widgets/usage_section.dart';

@RoutePage()
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              // ── General ──
              _SectionHeader(title: l.sectionGeneral),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Theme
                    ListTile(
                      leading: Icon(Icons.palette, color: cs.primary),
                      title: Text(l.theme),
                      subtitle: Text(_getThemeLabel(context, state.themeMode)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showThemeBottomSheet(
                        context: context,
                        current: state.themeMode,
                        onChanged: (mode) =>
                            context.read<SettingsCubit>().setThemeMode(mode),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Language
                    ListTile(
                      leading: Icon(Icons.language, color: cs.primary),
                      title: Text(l.language),
                      subtitle: Text(
                        getAppLocaleLabel(context, state.appLocaleId),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showAppLocaleBottomSheet(
                        context: context,
                        current: state.appLocaleId,
                        onChanged: (id) =>
                            context.read<SettingsCubit>().setAppLocaleId(id),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Voice Input
                    ListTile(
                      leading: Icon(Icons.record_voice_over, color: cs.primary),
                      title: Text(l.voiceInput),
                      subtitle: Text(
                        getSpeechLocaleLabel(state.speechLocaleId),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showSpeechLocaleBottomSheet(
                        context: context,
                        current: state.speechLocaleId,
                        onChanged: (id) =>
                            context.read<SettingsCubit>().setSpeechLocaleId(id),
                      ),
                    ),
                    // Push Notifications (only when connected to a server)
                    if (state.activeMachineId != null) ...[
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: cs.outlineVariant,
                      ),
                      _PushNotificationTile(
                        state: state,
                        onChanged: (enabled) =>
                            context.read<SettingsCubit>().toggleFcm(enabled),
                      ),
                      if (state.fcmEnabled) ...[
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: cs.outlineVariant,
                        ),
                        _UpdateNotificationLanguageTile(
                          syncInProgress: state.fcmSyncInProgress,
                          onTap: () async {
                            final cubit = context.read<SettingsCubit>();
                            await cubit.syncPushLocale();
                            if (context.mounted) {
                              final status = cubit.state.fcmStatusKey;
                              final isSuccess =
                                  status == FcmStatusKey.enabled ||
                                  status == FcmStatusKey.enabledPending;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isSuccess
                                        ? l.notificationLanguageUpdated
                                        : l.fcmTokenFailed,
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Usage ──
              UsageSection(bridgeService: context.read<BridgeService>()),
              const SizedBox(height: 8),

              // ── Backup ──
              BackupSection(
                bridgeService: context.read<BridgeService>(),
                databaseService: context.read<DatabaseService>(),
              ),
              const SizedBox(height: 8),

              // ── About ──
              _SectionHeader(title: l.sectionAbout),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Version
                    const _VersionTile(),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // GitHub Repository
                    ListTile(
                      leading: Icon(Icons.code, color: cs.onSurfaceVariant),
                      title: Text(l.githubRepository),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => launchUrl(
                        Uri.parse('https://github.com/K9i-0/ccpocket'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Changelog
                    ListTile(
                      leading: Icon(Icons.history, color: cs.onSurfaceVariant),
                      title: Text(l.changelog),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.router.push(const ChangelogRoute()),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Setup Guide
                    ListTile(
                      leading: Icon(
                        Icons.lightbulb_outline,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(l.setupGuide),
                      subtitle: Text(l.setupGuideSubtitle),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.router.push(const SetupGuideRoute()),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Licenses
                    ListTile(
                      leading: Icon(
                        Icons.article_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(l.openSourceLicenses),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.router.push(const LicensesRoute()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Footer ──
              Center(
                child: Column(
                  children: [
                    Text(
                      'ccpocket',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u00a9 2026 K9i',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  static String _getThemeLabel(BuildContext context, ThemeMode mode) {
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PushNotificationTile extends StatelessWidget {
  final SettingsState state;
  final ValueChanged<bool> onChanged;

  const _PushNotificationTile({required this.state, required this.onChanged});

  static String? _resolveFcmStatus(AppLocalizations l, FcmStatusKey? key) {
    if (key == null) return null;
    return switch (key) {
      FcmStatusKey.unavailable => l.pushNotificationsUnavailable,
      FcmStatusKey.bridgeNotInitialized => l.fcmBridgeNotInitialized,
      FcmStatusKey.tokenFailed => l.fcmTokenFailed,
      FcmStatusKey.enabled => l.fcmEnabled,
      FcmStatusKey.enabledPending => l.fcmEnabledPending,
      FcmStatusKey.disabled => l.fcmDisabled,
      FcmStatusKey.disabledPending => l.fcmDisabledPending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final baseSubtitle = state.fcmAvailable
        ? l.pushNotificationsSubtitle
        : l.pushNotificationsUnavailable;
    final subtitle = _resolveFcmStatus(l, state.fcmStatusKey) ?? baseSubtitle;

    return SwitchListTile(
      value: state.fcmEnabled,
      onChanged: state.fcmSyncInProgress ? null : onChanged,
      title: Text(l.pushNotifications),
      subtitle: Text(subtitle),
      secondary: state.fcmSyncInProgress
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined),
    );
  }
}

class _UpdateNotificationLanguageTile extends StatelessWidget {
  final bool syncInProgress;
  final VoidCallback onTap;

  const _UpdateNotificationLanguageTile({
    required this.syncInProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.translate_outlined),
      title: Text(l.updateNotificationLanguage),
      trailing: syncInProgress
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right, size: 20),
      onTap: syncInProgress ? null : onTap,
    );
  }
}

class _VersionTile extends StatefulWidget {
  const _VersionTile();

  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  String? _versionText;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';

    String result = version;
    try {
      final updater = ShorebirdUpdater();
      final patch = await updater.readCurrentPatch();
      if (patch != null) {
        result = '$version (patch ${patch.number})';
      }
    } catch (_) {
      // Shorebird not available (e.g. debug builds)
    }

    if (mounted) {
      setState(() => _versionText = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final l = AppLocalizations.of(context);

    return ListTile(
      leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
      title: Text(l.version),
      subtitle: Text(_versionText ?? l.loading),
    );
  }
}
