import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../setup_guide_platform.dart';
import 'guide_components.dart';
import 'guide_page.dart';

/// Step 1: Overview of CC Pocket, supported agents, and how the Bridge works.
class GuidePageAbout extends StatelessWidget {
  const GuidePageAbout({
    super.key,
    required this.platform,
    required this.totalSteps,
  });

  final SetupGuidePlatform platform;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMobile = platform == SetupGuidePlatform.mobile;
    final isMacOS = platform == SetupGuidePlatform.macOS;

    final title = isMobile ? l.guideAboutTitle : l.guideAboutDesktopTitle;
    final subtitle = switch (platform) {
      SetupGuidePlatform.mobile => l.guideAboutDescription,
      SetupGuidePlatform.macOS => l.guideAboutMacDescription,
      SetupGuidePlatform.desktopOther => l.guideAboutDesktopDescription,
    };
    final icon = switch (platform) {
      SetupGuidePlatform.mobile => Icons.smartphone_rounded,
      SetupGuidePlatform.macOS => Icons.laptop_mac_rounded,
      SetupGuidePlatform.desktopOther => Icons.desktop_windows_rounded,
    };

    return GuidePage(
      icon: icon,
      title: title,
      subtitle: subtitle,
      stepIndex: 1,
      totalSteps: totalSteps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GuideProviderBadges(),
          const SizedBox(height: 18),
          _ArchitectureCard(isMobile: isMobile),
          const SizedBox(height: 14),
          GuideCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GuideBulletItem(
                  icon: Icons.shield_outlined,
                  text: l.guideAboutHighlightLocal,
                ),
                const SizedBox(height: 10),
                GuideBulletItem(
                  icon: isMacOS ? Icons.bolt_rounded : Icons.laptop_mac_rounded,
                  text: isMacOS
                      ? l.guideAboutHighlightMacLocal
                      : l.guideAboutHighlightMac,
                ),
                const SizedBox(height: 10),
                GuideBulletItem(
                  icon: Icons.devices_rounded,
                  text: l.guideAboutHighlightHandoff,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchitectureCard extends StatelessWidget {
  const _ArchitectureCard({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return GuideCard(
      child: Column(
        children: [
          Text(
            l.guideAboutDiagramTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DiagramNode(
                    icon: isMobile
                        ? Icons.phone_iphone_rounded
                        : Icons.devices_rounded,
                    label: isMobile
                        ? l.guideAboutDiagramPhone
                        : l.guideAboutDiagramDesktop,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.sync_alt_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                ),
                Expanded(
                  child: _DiagramNode(
                    icon: Icons.dns_rounded,
                    label: l.guideAboutDiagramBridge,
                    accent: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.sync_alt_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                ),
                Expanded(
                  child: _DiagramNode(
                    icon: Icons.smart_toy_outlined,
                    label: l.guideAboutDiagramClaude,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.guideAboutDiagramCaption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DiagramNode extends StatelessWidget {
  const _DiagramNode({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = GuidePalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: accent ? palette.accentSurface : palette.mutedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent ? palette.accentBorder : palette.cardBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: accent ? cs.primary : cs.onSurface),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
