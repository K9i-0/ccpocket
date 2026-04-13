import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SupporterBadge extends StatelessWidget {
  const SupporterBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final iconSize = compact ? 12.0 : 14.0;
    final fontSize = compact ? 10.0 : 11.0;
    final horizontalPadding = compact ? 6.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: iconSize, color: cs.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            l.supporterTitle,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: cs.onTertiaryContainer,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
