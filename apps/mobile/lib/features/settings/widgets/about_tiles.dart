import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/app_update_service.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';

class VersionTile extends StatefulWidget {
  const VersionTile({super.key});

  @override
  State<VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<VersionTile> {
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

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final trackSuffix = settings.shorebirdTrack != 'stable'
            ? ' [${settings.shorebirdTrack}]'
            : '';
        return ListTile(
          leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          title: Text(l.version),
          subtitle: Text(
            _versionText != null ? '$_versionText$trackSuffix' : l.loading,
          ),
        );
      },
    );
  }
}

/// Shows a download link when a newer macOS version is available.
///
/// Only visible on macOS desktop. Reads from [AppUpdateService.cachedUpdate].
class AppUpdateTile extends StatelessWidget {
  const AppUpdateTile({super.key});

  @override
  Widget build(BuildContext context) {
    final update = AppUpdateService.instance.cachedUpdate;
    if (update == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(Icons.upgrade, color: cs.primary),
      title: Text(
        l.appUpdateAvailable(update.latestVersion),
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      ),
      trailing: TextButton(
        onPressed: () async {
          await AppUpdateService.instance.performUpdate(update);
        },
        child: Text(update.canInstallInApp ? l.update : l.download),
      ),
    );
  }
}

class MacOSNativeAppTile extends StatelessWidget {
  const MacOSNativeAppTile({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('macos_native_app_settings_tile'),
      leading: Icon(Icons.desktop_mac_outlined, color: cs.onSurfaceVariant),
      title: Text(l.macosNativeAppSettingsTitle),
      subtitle: Text(l.macosNativeAppSettingsSubtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => launchUrl(
        Uri.parse(AppConstants.macOSReleasesUrl),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}
