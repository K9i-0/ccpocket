import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_update_service.dart';
import '../models/settings_catalog.dart';
import '../widgets/about_tiles.dart';
import '../widgets/settings_tiles.dart';

class AboutSettingsSection extends StatefulWidget {
  const AboutSettingsSection({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  State<AboutSettingsSection> createState() => _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends State<AboutSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasAppUpdate = AppUpdateService.instance.cachedUpdate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasAppUpdate)
          const SettingsItem(
            id: SettingsEntryIds.appUpdate,
            framed: true,
            child: SettingsGroup(children: [AppUpdateTile()]),
          ),
        SettingsGroup(
          children: [
            const SettingsItem(
              id: SettingsEntryIds.version,
              child: VersionTile(),
            ),
            if (widget.visibility.isMacOS)
              SettingsItem(
                id: SettingsEntryIds.checkForUpdates,
                child: _CheckForUpdatesTile(
                  onUpdateFound: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            if (widget.visibility.isIOSAppOnMac)
              const SettingsItem(
                id: SettingsEntryIds.macosNativeApp,
                child: MacOSNativeAppTile(),
              ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsItem(
              id: SettingsEntryIds.changelog,
              child: SettingsNavTile(
                icon: Icons.history_rounded,
                title: Text(l.changelog),
                onTap: () => context.router.push(const ChangelogRoute()),
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.setupGuide,
              child: SettingsNavTile(
                icon: Icons.lightbulb_rounded,
                title: Text(l.setupGuide),
                subtitle: l.setupGuideSubtitle,
                onTap: () => context.router.push(SetupGuideRoute()),
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.githubRepository,
              child: SettingsNavTile(
                icon: Icons.code_rounded,
                title: Text(l.githubRepository),
                external: true,
                onTap: () => launchUrl(
                  Uri.parse(AppConstants.githubUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.licenses,
              child: SettingsNavTile(
                icon: Icons.article_rounded,
                title: Text(l.openSourceLicenses),
                onTap: () => context.router.push(const LicensesRoute()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'ccpocket',
          textAlign: TextAlign.center,
          style: textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2026 K9i',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _CheckForUpdatesTile extends StatefulWidget {
  const _CheckForUpdatesTile({required this.onUpdateFound});

  final VoidCallback onUpdateFound;

  @override
  State<_CheckForUpdatesTile> createState() => _CheckForUpdatesTileState();
}

class _CheckForUpdatesTileState extends State<_CheckForUpdatesTile> {
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final update = await AppUpdateService.instance.checkForUpdate(
        force: true,
      );
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final messenger = ScaffoldMessenger.of(context);
      if (update != null) {
        widget.onUpdateFound();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l.appUpdateAvailable(update.latestVersion)),
              action: SnackBarAction(
                label: update.canInstallInApp ? l.update : l.download,
                onPressed: () {
                  AppUpdateService.instance.performUpdate(update);
                },
              ),
            ),
          );
      } else {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.settingsUpToDate)));
      }
    } catch (_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.settingsUpdateCheckFailed)));
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: const ValueKey('settings_check_for_updates_tile'),
      leading: const SettingsLeadingIcon(Icons.system_update_alt_rounded),
      title: Text(l.settingsCheckForUpdates),
      subtitle: _checking ? Text(l.settingsCheckingForUpdates) : null,
      trailing: _checking
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      onTap: _checking ? null : _check,
    );
  }
}
