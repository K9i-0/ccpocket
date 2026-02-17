import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'guide_page.dart';

/// Page 3: 接続方法（自宅 / 同一 LAN）
class GuidePageConnection extends StatelessWidget {
  const GuidePageConnection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;

    return GuidePage(
      icon: Icons.wifi,
      title: l.guideConnectionTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.guideConnectionDescription, style: bodyStyle),
          const SizedBox(height: 20),
          _ConnectionMethod(
            colorScheme: cs,
            icon: Icons.qr_code_scanner,
            title: l.guideConnectionQr,
            description: l.guideConnectionQrDescription,
            recommended: true,
            recommendedLabel: l.guideConnectionRecommended,
          ),
          const SizedBox(height: 12),
          _ConnectionMethod(
            colorScheme: cs,
            icon: Icons.search,
            title: l.guideConnectionMdns,
            description: l.guideConnectionMdnsDescription,
          ),
          const SizedBox(height: 12),
          _ConnectionMethod(
            colorScheme: cs,
            icon: Icons.edit,
            title: l.guideConnectionManual,
            description: l.guideConnectionManualDescription,
          ),
        ],
      ),
    );
  }
}

class _ConnectionMethod extends StatelessWidget {
  final ColorScheme colorScheme;
  final IconData icon;
  final String title;
  final String description;
  final bool recommended;
  final String? recommendedLabel;

  const _ConnectionMethod({
    required this.colorScheme,
    required this.icon,
    required this.title,
    required this.description,
    this.recommended = false,
    this.recommendedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: recommended
            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: recommended
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (recommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          recommendedLabel ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
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
