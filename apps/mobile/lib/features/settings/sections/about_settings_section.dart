import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../services/app_update_service.dart';
import '../models/settings_catalog.dart';
import '../widgets/about_tiles.dart';
import '../widgets/settings_tiles.dart';

class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key, required this.visibility});

  final SettingsVisibility visibility;

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
            if (visibility.isIOSAppOnMac)
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
