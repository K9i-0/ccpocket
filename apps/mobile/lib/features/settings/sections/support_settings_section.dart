import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/platform_helper.dart';
import '../models/settings_catalog.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/spread_appeal_message.dart';
import '../widgets/support_section.dart';

class SupportSettingsSection extends StatelessWidget {
  const SupportSettingsSection({
    super.key,
    required this.visibility,
    this.highlightSupporter = false,
  });

  final SettingsVisibility visibility;

  /// Emphasizes the supporter card (used when deep-linked to support).
  final bool highlightSupporter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visibility.supportAvailable) ...[
          const SizedBox(height: 16),
          SettingsItem(
            id: SettingsEntryIds.supporter,
            framed: true,
            child: SupportSectionCard(highlighted: highlightSupporter),
          ),
        ],
        if (visibility.hasActiveMachine) ...[
          SettingsSectionHeader(title: l.sectionSpread),
          const SpreadAppealMessage(),
          SettingsGroup(
            children: [
              if (visibility.isMobile)
                SettingsItem(
                  id: SettingsEntryIds.rateApp,
                  child: SettingsNavTile(
                    icon: Icons.rate_review_rounded,
                    title: Text(
                      isIOSPlatform ? l.rateOnStore : l.rateOnStoreAndroid,
                    ),
                    external: true,
                    onTap: () => launchUrl(
                      Uri.parse(
                        isIOSPlatform
                            ? AppConstants.appStoreUrl
                            : AppConstants.playStoreUrl,
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              SettingsItem(
                id: SettingsEntryIds.shareApp,
                child: SettingsNavTile(
                  icon: Icons.ios_share_rounded,
                  title: Text(l.shareApp),
                  subtitle: l.shareAppSubtitle,
                  trailing: const SizedBox.shrink(),
                  onTap: () => SharePlus.instance.share(
                    ShareParams(text: l.shareText(AppConstants.shareUrl)),
                  ),
                ),
              ),
              SettingsItem(
                id: SettingsEntryIds.starOnGithub,
                child: SettingsNavTile(
                  icon: Icons.star_rounded,
                  title: Text(l.starOnGithub),
                  external: true,
                  onTap: () => launchUrl(
                    Uri.parse(AppConstants.githubUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
