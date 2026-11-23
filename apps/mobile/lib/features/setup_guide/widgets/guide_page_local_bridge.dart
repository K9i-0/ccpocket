import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../local_bridge/local_bridge_screen.dart';
import 'guide_components.dart';
import 'guide_page.dart';

/// macOS Step 2: Start and manage the Bridge on this Mac directly from the app.
class GuidePageLocalBridge extends StatelessWidget {
  const GuidePageLocalBridge({super.key, required this.totalSteps});

  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = [
      (l.guideLocalBridgeStep1, l.guideLocalBridgeStep1Detail),
      (l.guideLocalBridgeStep2, l.guideLocalBridgeStep2Detail),
      (l.guideLocalBridgeStep3, l.guideLocalBridgeStep3Detail),
    ];

    return GuidePage(
      icon: Icons.dns_rounded,
      title: l.guideLocalBridgeTitle,
      subtitle: l.guideLocalBridgeDescription,
      stepIndex: 2,
      totalSteps: totalSteps,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuideCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, (title, detail)) in steps.indexed) ...[
                  if (index > 0) const SizedBox(height: 16),
                  GuideNumberedStep(
                    number: index + 1,
                    title: title,
                    detail: detail,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('guide_open_local_bridge_button'),
              onPressed: () => openLocalBridgeScreen(context),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l.guideLocalBridgeOpen),
            ),
          ),
        ],
      ),
    );
  }
}
