import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class SessionListEmptyState extends StatelessWidget {
  final VoidCallback onNewSession;

  const SessionListEmptyState({super.key, required this.onNewSession});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.rocket_launch_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.readyToStart,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.readyToStartDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: appColors.subtleText),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onNewSession,
                  icon: const Icon(Icons.add),
                  label: Text(l.newSession),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
