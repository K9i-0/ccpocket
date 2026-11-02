import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import '../widgets/notification_tiles.dart';
import '../widgets/settings_tiles.dart';

class NotificationSettingsSection extends StatelessWidget {
  const NotificationSettingsSection({
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
    return SettingsGroup(
      children: [
        SettingsItem(
          id: SettingsEntryIds.pushNotifications,
          child: PushNotificationTile(state: state, onChanged: cubit.toggleFcm),
        ),
        if (visibility.fcmEnabled) ...[
          SettingsItem(
            id: SettingsEntryIds.pushPrivacy,
            child: PushPrivacyTile(
              value: state.fcmPrivacy,
              syncInProgress: state.fcmSyncInProgress,
              onChanged: cubit.toggleFcmPrivacy,
            ),
          ),
          SettingsItem(
            id: SettingsEntryIds.notificationLanguage,
            child: UpdateNotificationLanguageTile(
              syncInProgress: state.fcmSyncInProgress,
              onTap: () async {
                await cubit.syncPushLocale();
                if (!context.mounted) return;
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
              },
            ),
          ),
        ],
      ],
    );
  }
}
