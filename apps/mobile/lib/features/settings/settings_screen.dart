import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'state/settings_cubit.dart';
import 'state/settings_state.dart';

/// Available speech recognition locales.
const _speechLocales = <(String id, String label, String? subtitle)>[
  ('ja-JP', 'Japanese', '日本語'),
  ('en-US', 'English (US)', null),
  ('en-GB', 'English (UK)', null),
  ('zh-Hans-CN', 'Chinese (Mandarin)', '中文'),
  ('ko-KR', 'Korean', '한국어'),
  ('es-ES', 'Spanish', 'Español'),
  ('fr-FR', 'French', 'Français'),
  ('de-DE', 'German', 'Deutsch'),
];

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
              // ── Theme ──
              _SectionHeader(title: 'APPEARANCE'),
              _ThemeSelector(
                current: state.themeMode,
                onChanged: (mode) =>
                    context.read<SettingsCubit>().setThemeMode(mode),
              ),
              Divider(height: 1, color: cs.outlineVariant),

              // ── Push ──
              _SectionHeader(title: 'PUSH NOTIFICATIONS'),
              _PushNotificationTile(
                state: state,
                onChanged: (enabled) =>
                    context.read<SettingsCubit>().toggleFcm(enabled),
              ),
              Divider(height: 1, color: cs.outlineVariant),

              // ── Speech ──
              _SectionHeader(title: 'VOICE INPUT'),
              _SpeechLocaleSelector(
                current: state.speechLocaleId,
                onChanged: (id) =>
                    context.read<SettingsCubit>().setSpeechLocaleId(id),
              ),
            ],
          );
        },
      ),
    );
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

class _ThemeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.settings_brightness, size: 18),
            label: Text('System'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode, size: 18),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode, size: 18),
            label: Text('Dark'),
          ),
        ],
        selected: {current},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return cs.primaryContainer;
            }
            return cs.surfaceContainerLow;
          }),
        ),
      ),
    );
  }
}

class _SpeechLocaleSelector extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _SpeechLocaleSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (id, label, subtitle) in _speechLocales)
          ListTile(
            leading: Icon(Icons.language, color: cs.onSurfaceVariant),
            title: Text(label),
            subtitle: subtitle != null ? Text(subtitle) : null,
            trailing: current == id
                ? Icon(Icons.check, color: cs.primary)
                : null,
            onTap: () => onChanged(id),
          ),
      ],
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
      title: const Text('Enable Push Notifications'),
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
