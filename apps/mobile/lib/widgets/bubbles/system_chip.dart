import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_theme.dart';

class SystemChip extends StatelessWidget {
  final SystemMessage message;
  const SystemChip({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final label = message.model != null
        ? l.sessionStarted(message.model!)
        : l.systemSubtypeLabel(message.subtype);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: appColors.systemChip,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
