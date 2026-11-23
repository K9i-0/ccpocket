import 'package:material_ui/material_ui.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import 'guide_components.dart';
import 'guide_page.dart';

/// Mobile Step 3: Connect via QR code (LAN) or remotely via Tailscale.
class GuidePageMobileConnect extends StatelessWidget {
  const GuidePageMobileConnect({super.key, required this.totalSteps});

  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return GuidePage(
      icon: Icons.qr_code_scanner_rounded,
      title: l.guideConnectionTitle,
      subtitle: l.guideConnectionDescription,
      stepIndex: 3,
      totalSteps: totalSteps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConnectionMethodCard(
            icon: Icons.qr_code_scanner_rounded,
            title: l.guideConnectionQr,
            description: l.guideConnectionQrDescription,
            recommendedLabel: l.guideConnectionRecommended,
          ),
          const SizedBox(height: 12),
          _ConnectionMethodCard(
            icon: Icons.tune_rounded,
            title: l.guideConnectionManual,
            description: l.guideConnectionManualDescription,
          ),
          const SizedBox(height: 14),
          GuideExpandableSection(
            toggleKey: const ValueKey('guide_tailscale_toggle'),
            icon: Icons.vpn_lock_rounded,
            title: l.guideTailscaleSectionTitle,
            child: const GuideTailscaleSteps(),
          ),
        ],
      ),
    );
  }
}

class _ConnectionMethodCard extends StatelessWidget {
  const _ConnectionMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    this.recommendedLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? recommendedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = GuidePalette.of(context);
    final recommended = recommendedLabel != null;

    return GuideCard(
      highlighted: recommended,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: recommended ? palette.accentSurface : palette.mutedSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: recommended ? palette.accentBorder : palette.cardBorder,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: recommended ? cs.primary : cs.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (recommendedLabel != null)
                      GuideBadge(label: recommendedLabel!),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable Tailscale remote-access steps used on both mobile and desktop.
class GuideTailscaleSteps extends StatelessWidget {
  const GuideTailscaleSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.guideTailscaleDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        GuideNumberedStep(number: 1, title: l.guideTailscaleStep1),
        const SizedBox(height: 10),
        GuideNumberedStep(number: 2, title: l.guideTailscaleStep2),
        const SizedBox(height: 10),
        GuideNumberedStep(number: 3, title: l.guideTailscaleStep3),
        const SizedBox(height: 14),
        GuideCopyableBox(
          value: AppConstants.tailscaleUrl,
          displayValue: 'tailscale.com',
          copyLabel: l.guideCopyLink,
          copyButtonKey: const ValueKey('guide_tailscale_copy_link_button'),
          openUrl: AppConstants.tailscaleUrl,
          openLabel: l.guideTailscaleWebsite,
          openButtonKey: const ValueKey('guide_tailscale_open_button'),
        ),
      ],
    );
  }
}
