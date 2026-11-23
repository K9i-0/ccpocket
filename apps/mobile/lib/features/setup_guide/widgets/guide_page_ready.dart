import 'package:material_ui/material_ui.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../setup_guide_platform.dart';
import 'guide_components.dart';
import 'guide_page.dart';
import 'guide_page_mobile_connect.dart';

/// Final step for both mobile and desktop flows.
class GuidePageReady extends StatelessWidget {
  const GuidePageReady({
    super.key,
    required this.platform,
    required this.totalSteps,
    required this.onGetStarted,
    this.onScanQrCode,
  });

  final SetupGuidePlatform platform;
  final int totalSteps;
  final VoidCallback onGetStarted;
  final VoidCallback? onScanQrCode;

  @override
  Widget build(BuildContext context) {
    return switch (platform) {
      SetupGuidePlatform.mobile => _MobileReadyPage(
        totalSteps: totalSteps,
        onGetStarted: onGetStarted,
        onScanQrCode: onScanQrCode,
      ),
      SetupGuidePlatform.macOS ||
      SetupGuidePlatform.desktopOther => _DesktopReadyPage(
        platform: platform,
        totalSteps: totalSteps,
        onGetStarted: onGetStarted,
      ),
    };
  }
}

class _MobileReadyPage extends StatelessWidget {
  const _MobileReadyPage({
    required this.totalSteps,
    required this.onGetStarted,
    this.onScanQrCode,
  });

  final int totalSteps;
  final VoidCallback onGetStarted;
  final VoidCallback? onScanQrCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return GuidePage(
      icon: Icons.rocket_launch_rounded,
      title: l.guideReadyTitle,
      subtitle: l.guideReadyDescription,
      stepIndex: totalSteps,
      totalSteps: totalSteps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onScanQrCode != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('guide_scan_qr_button'),
                onPressed: onScanQrCode,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l.guideReadyScanQr),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('guide_ready_later_button'),
                onPressed: onGetStarted,
                child: Text(l.guideReadyLater),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('guide_ready_start_button'),
                onPressed: onGetStarted,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(l.guideReadyStart),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l.guideReadyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DesktopReadyPage extends StatelessWidget {
  const _DesktopReadyPage({
    required this.platform,
    required this.totalSteps,
    required this.onGetStarted,
  });

  final SetupGuidePlatform platform;
  final int totalSteps;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return GuidePage(
      icon: Icons.devices_rounded,
      title: l.guideReadyDesktopTitle,
      subtitle: l.guideReadyDesktopDescription,
      stepIndex: totalSteps,
      totalSteps: totalSteps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (platform == SetupGuidePlatform.desktopOther) ...[
            GuideCallout(
              icon: Icons.lan_outlined,
              text: l.guideDesktopLocalConnectTip,
              tone: GuideCalloutTone.info,
            ),
            const SizedBox(height: 12),
          ],
          GuideCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.smartphone_rounded, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.guideMobileAppCardTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l.guideMobileAppCardBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                GuideCopyableBox(
                  value: AppConstants.installUrl,
                  displayValue: 'k9i-0.github.io/ccpocket/install',
                  copyLabel: l.guideCopyLink,
                  copyButtonKey: const ValueKey(
                    'guide_mobile_install_copy_button',
                  ),
                  openUrl: AppConstants.installUrl,
                  openLabel: l.guideOpenWebsite,
                  openButtonKey: const ValueKey(
                    'guide_mobile_install_open_button',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GuideExpandableSection(
            toggleKey: const ValueKey('guide_desktop_tailscale_toggle'),
            icon: Icons.vpn_lock_rounded,
            title: l.guideTailscaleSectionTitle,
            child: const GuideTailscaleSteps(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('guide_ready_start_button'),
              onPressed: onGetStarted,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(l.guideReadyStart),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.guideReadyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
