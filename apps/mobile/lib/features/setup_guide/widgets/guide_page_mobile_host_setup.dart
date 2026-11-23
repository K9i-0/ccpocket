import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import 'guide_components.dart';
import 'guide_page.dart';

enum _HostSetupMode { macApp, cli }

/// Mobile Step 2: Prepare the host Mac / PC.
/// Recommends the macOS desktop app by default with copy/share install links,
/// and provides a dedicated tab for Linux / Windows / CLI users.
class GuidePageMobileHostSetup extends HookWidget {
  const GuidePageMobileHostSetup({super.key, required this.totalSteps});

  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mode = useState(_HostSetupMode.macApp);

    return GuidePage(
      icon: mode.value == _HostSetupMode.macApp
          ? Icons.laptop_mac_rounded
          : Icons.terminal_rounded,
      title: l.guideHostSetupTitle,
      subtitle: l.guideHostSetupDescription,
      stepIndex: 2,
      totalSteps: totalSteps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HostModeSwitcher(
            selected: mode.value,
            onChanged: (next) => mode.value = next,
          ),
          const SizedBox(height: 16),
          if (mode.value == _HostSetupMode.macApp)
            const _MacRecommendedContent()
          else
            const _CliHostContent(),
        ],
      ),
    );
  }
}

class _HostModeSwitcher extends StatelessWidget {
  const _HostModeSwitcher({required this.selected, required this.onChanged});

  final _HostSetupMode selected;
  final ValueChanged<_HostSetupMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = GuidePalette.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.mutedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              key: const ValueKey('guide_host_tab_mac'),
              icon: Icons.laptop_mac_rounded,
              label: l.guideHostTabMac,
              selected: selected == _HostSetupMode.macApp,
              onTap: () => onChanged(_HostSetupMode.macApp),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeTabButton(
              key: const ValueKey('guide_host_tab_cli'),
              icon: Icons.terminal_rounded,
              label: l.guideHostTabCli,
              selected: selected == _HostSetupMode.cli,
              onTap: () => onChanged(_HostSetupMode.cli),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: selected ? cs.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? cs.onPrimary : cs.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacRecommendedContent extends StatelessWidget {
  const _MacRecommendedContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final palette = GuidePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuideCard(
          key: const ValueKey('guide_mac_recommended_card'),
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l.guideMacRecommendTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GuideBadge(
                    label: l.guideConnectionRecommended,
                    icon: Icons.auto_awesome_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.guideMacRecommendSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              GuideBulletItem(text: l.guideMacBenefit1),
              const SizedBox(height: 8),
              GuideBulletItem(text: l.guideMacBenefit2),
              const SizedBox(height: 8),
              GuideBulletItem(text: l.guideMacBenefit3),
              const SizedBox(height: 16),
              Divider(height: 1, color: palette.accentBorder),
              const SizedBox(height: 14),
              GuideCopyableBox(
                label: l.guideMacInstallMethodDownload,
                value: AppConstants.macOSReleasesUrl,
                displayValue: 'github.com/K9i-0/ccpocket/releases?q=macos',
                copyLabel: l.guideCopyLink,
                copyButtonKey: const ValueKey('guide_mac_copy_link_button'),
                shareText: l.guideShareMacDownloadMessage(
                  AppConstants.macOSReleasesUrl,
                ),
                shareLabel: l.guideSendToMac,
                shareButtonKey: const ValueKey('guide_mac_share_link_button'),
              ),
              const SizedBox(height: 14),
              GuideCopyableBox(
                label: l.guideMacInstallMethodHomebrew,
                value: AppConstants.macOSHomebrewCommand,
                copyButtonKey: const ValueKey('guide_mac_copy_brew_button'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GuideCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.guideMacAfterInstallTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              GuideNumberedStep(number: 1, title: l.guideMacAfterInstallStep1),
              const SizedBox(height: 12),
              GuideNumberedStep(number: 2, title: l.guideMacAfterInstallStep2),
              const SizedBox(height: 12),
              GuideNumberedStep(number: 3, title: l.guideMacAfterInstallStep3),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GuideCallout(
          icon: Icons.info_outline_rounded,
          text: l.guideMacAppleSiliconNote,
          tone: GuideCalloutTone.hint,
        ),
      ],
    );
  }
}

class _CliHostContent extends StatelessWidget {
  const _CliHostContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('guide_cli_setup_content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuideCallout(
          icon: Icons.checklist_rounded,
          title: l.guideBridgePrerequisites,
          text: l.guideCliPrerequisitesNote,
          tone: GuideCalloutTone.info,
        ),
        const SizedBox(height: 14),
        GuideCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.guideCliRunTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              GuideCopyableBox(
                value: l.guideBridgeStep1Command,
                copyLabel: l.copy,
                copyButtonKey: const ValueKey('guide_cli_copy_npx_button'),
                shareText: l.guideShareBridgeCommandMessage(
                  l.guideBridgeStep1Command,
                ),
                shareLabel: l.guideSendToPc,
                shareButtonKey: const ValueKey('guide_cli_share_npx_button'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.guideBridgeQrNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GuideExpandableSection(
          toggleKey: const ValueKey('guide_cli_autostart_toggle'),
          icon: Icons.schedule_rounded,
          title: l.guideCliAutostartToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.guideLaunchdDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              GuideCopyableBox(
                value: l.guideLaunchdCommandValue,
                copyButtonKey: const ValueKey('guide_cli_copy_setup_button'),
              ),
              const SizedBox(height: 12),
              GuideBulletItem(
                icon: Icons.laptop_mac_rounded,
                iconColor: cs.onSurfaceVariant,
                text: 'macOS: ${l.guideAutostartMacDescription}',
              ),
              const SizedBox(height: 6),
              GuideBulletItem(
                icon: Icons.terminal_rounded,
                iconColor: cs.onSurfaceVariant,
                text: 'Linux: ${l.guideAutostartLinuxDescription}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GuideExpandableSection(
          toggleKey: const ValueKey('guide_cli_auth_toggle'),
          icon: Icons.key_rounded,
          title: l.guideCliAuthToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuideBulletItem(text: l.guideCliAuthCodex),
              const SizedBox(height: 8),
              GuideBulletItem(text: l.guideCliAuthClaude),
              const SizedBox(height: 8),
              GuideBulletItem(text: l.guideCliAuthAntigravity),
            ],
          ),
        ),
      ],
    );
  }
}
