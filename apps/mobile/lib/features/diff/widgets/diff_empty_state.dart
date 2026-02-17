import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class DiffEmptyState extends StatelessWidget {
  const DiffEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: appColors.toolIcon),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).noChanges,
            style: TextStyle(fontSize: 16, color: appColors.subtleText),
          ),
        ],
      ),
    );
  }
}
