import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'licenses_screen.dart';
import 'state/settings_cubit.dart';
import 'state/settings_state.dart';
import 'widgets/speech_locale_bottom_sheet.dart';
import 'widgets/theme_bottom_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              // ── General ──
              _SectionHeader(title: 'GENERAL'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Theme
                    ListTile(
                      leading: Icon(Icons.palette, color: cs.primary),
                      title: const Text('Theme'),
                      subtitle: Text(_getThemeLabel(state.themeMode)),
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
                    // Voice Input
                    ListTile(
                      leading:
                          Icon(Icons.record_voice_over, color: cs.primary),
                      title: const Text('Voice Input'),
                      subtitle:
                          Text(getSpeechLocaleLabel(state.speechLocaleId)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => showSpeechLocaleBottomSheet(
                        context: context,
                        current: state.speechLocaleId,
                        onChanged: (id) => context
                            .read<SettingsCubit>()
                            .setSpeechLocaleId(id),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant,
                    ),
                    // Push Notifications
                    _PushNotificationTile(
                      state: state,
                      onChanged: (enabled) =>
                          context.read<SettingsCubit>().toggleFcm(enabled),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── About ──
              _SectionHeader(title: 'ABOUT'),
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
                    // Licenses
                    ListTile(
                      leading: Icon(
                        Icons.article_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                      title: const Text('Open Source Licenses'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LicensesScreen(),
                        ),
                      ),
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

  static String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
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

  @override
  Widget build(BuildContext context) {
    final baseSubtitle = state.fcmAvailable
        ? 'Bridge 経由でセッション通知を受け取ります'
        : 'Firebase 設定後に利用できます';
    final subtitle = state.fcmStatusMessage ?? baseSubtitle;

    return SwitchListTile(
      value: state.fcmEnabled,
      onChanged: state.fcmSyncInProgress ? null : onChanged,
      title: const Text('Push Notifications'),
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

    return ListTile(
      leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
      title: const Text('Version'),
      subtitle: Text(_versionText ?? 'Loading...'),
    );
  }
}
