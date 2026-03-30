import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../state/git_view_state.dart';

class DiffEmptyState extends StatelessWidget {
  final GitViewMode? viewMode;

  const DiffEmptyState({super.key, this.viewMode});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    final (icon, message) = switch (viewMode) {
      GitViewMode.staged => (Icons.inbox_outlined, 'No staged files'),
      GitViewMode.unstaged => (
        Icons.check_circle_outline,
        AppLocalizations.of(context).noChanges,
      ),
      null => (
        Icons.check_circle_outline,
        AppLocalizations.of(context).noChanges,
      ),
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: appColors.toolIcon),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: appColors.subtleText),
          ),
        ],
      ),
    );
  }
}
