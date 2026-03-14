import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'guide_page.dart';

/// Page 5: Auto-start setup (launchd on macOS / systemd on Linux)
class GuidePageAutostart extends StatelessWidget {
  const GuidePageAutostart({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;

    return GuidePage(
      icon: Icons.schedule,
      title: l.guideLaunchdTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.guideLaunchdDescription, style: bodyStyle),
          const SizedBox(height: 20),
          // Command
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.guideLaunchdCommand,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.guideLaunchdCommandValue,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Platform details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlatformRow(
                  icon: Icons.laptop_mac,
                  label: 'macOS',
                  description: l.guideAutostartMacDescription,
                  cs: cs,
                ),
                const SizedBox(height: 8),
                _PlatformRow(
                  icon: Icons.terminal,
                  label: 'Linux',
                  description: l.guideAutostartLinuxDescription,
                  cs: cs,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Recommendation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: cs.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.guideLaunchdRecommendation,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onTertiaryContainer,
                    ),
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

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final String description;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
