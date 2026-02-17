import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'guide_page.dart';

/// Page 6: 準備完了
class GuidePageReady extends StatelessWidget {
  final VoidCallback onGetStarted;

  const GuidePageReady({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return GuidePage(
      icon: Icons.rocket_launch,
      title: l.guideReadyTitle,
      body: Column(
        children: [
          Text(
            l.guideReadyDescription,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.arrow_forward),
              label: Text(l.guideReadyStart),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.guideReadyHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
