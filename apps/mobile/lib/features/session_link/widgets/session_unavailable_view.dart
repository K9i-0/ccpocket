import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

class SessionUnavailableView extends StatelessWidget {
  const SessionUnavailableView({super.key, required this.onOpenRecentSessions});

  final VoidCallback onOpenRecentSessions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 20),
            Text(
              l.sessionUnavailableTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l.sessionUnavailableDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('open_recent_sessions_button'),
              onPressed: onOpenRecentSessions,
              icon: const Icon(Icons.history),
              label: Text(l.openRecentSessions),
            ),
          ],
        ),
      ),
    );
  }
}
