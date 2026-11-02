import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../state/settings_state.dart';

class PushNotificationTile extends StatelessWidget {
  final SettingsState state;
  final ValueChanged<bool> onChanged;

  const PushNotificationTile({
    super.key,
    required this.state,
    required this.onChanged,
  });

  static String? _resolveFcmStatus(AppLocalizations l, FcmStatusKey? key) {
    if (key == null) return null;
    return switch (key) {
      FcmStatusKey.unavailable => l.pushNotificationsUnavailable,
      FcmStatusKey.bridgeNotInitialized => l.fcmBridgeNotInitialized,
      FcmStatusKey.tokenFailed => l.fcmTokenFailed,
      FcmStatusKey.registrationFailed => l.fcmRegistrationFailed,
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

class PushPrivacyTile extends StatelessWidget {
  final bool value;
  final bool syncInProgress;
  final ValueChanged<bool> onChanged;

  const PushPrivacyTile({
    super.key,
    required this.value,
    required this.syncInProgress,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      value: value,
      onChanged: syncInProgress ? null : onChanged,
      title: Text(l.pushPrivacyMode),
      subtitle: Text(l.pushPrivacyModeSubtitle),
      secondary: const Icon(Icons.visibility_off_outlined),
    );
  }
}

class UpdateNotificationLanguageTile extends StatelessWidget {
  final bool syncInProgress;
  final VoidCallback onTap;

  const UpdateNotificationLanguageTile({
    super.key,
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
