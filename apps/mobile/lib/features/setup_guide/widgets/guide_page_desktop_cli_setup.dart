import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'guide_components.dart';
import 'guide_page.dart';

/// Linux / Windows Desktop Step 2: Start the Bridge via terminal CLI.
class GuidePageDesktopCliSetup extends StatelessWidget {
  const GuidePageDesktopCliSetup({super.key, required this.totalSteps});

  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);

    return GuidePage(
      icon: Icons.terminal_rounded,
      title: l.guideBridgeTitle,
      subtitle: l.guideBridgeDescription,
      stepIndex: 2,
      totalSteps: totalSteps,
      body: Column(
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
                  copyButtonKey: const ValueKey(
                    'guide_desktop_copy_npx_button',
                  ),
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
            toggleKey: const ValueKey('guide_desktop_autostart_toggle'),
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
                  copyButtonKey: const ValueKey(
                    'guide_desktop_copy_setup_button',
                  ),
                ),
                const SizedBox(height: 10),
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
            toggleKey: const ValueKey('guide_desktop_auth_toggle'),
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
      ),
    );
  }
}
