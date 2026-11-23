import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../local_bridge/local_bridge_screen.dart';
import 'guide_page.dart';

/// macOS: start and manage the Bridge on this Mac from the app. Replaces the
/// terminal setup and auto-start pages of the guide.
class GuidePageLocalBridge extends StatelessWidget {
  const GuidePageLocalBridge({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = [
      (l.guideLocalBridgeStep1, l.guideLocalBridgeStep1Detail),
      (l.guideLocalBridgeStep2, l.guideLocalBridgeStep2Detail),
      (l.guideLocalBridgeStep3, l.guideLocalBridgeStep3Detail),
    ];

    return GuidePage(
      icon: Icons.dns,
      title: l.guideLocalBridgeTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.guideLocalBridgeDescription, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          for (final (index, (title, detail)) in steps.indexed)
            GuideNumberedStep(number: index + 1, title: title, detail: detail),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('guide_open_local_bridge_button'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LocalBridgeScreen(),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l.guideLocalBridgeOpen),
          ),
        ],
      ),
    );
  }
}

class GuideNumberedStep extends StatelessWidget {
  const GuideNumberedStep({
    super.key,
    required this.number,
    required this.title,
    required this.detail,
  });

  final int number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: cs.primaryContainer,
            child: Text(
              '$number',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
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
