import 'package:material_ui/material_ui.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';

/// Compact inline card displaying Claude Code's session recap (`away_summary`
/// or `/recap` command output) with a `recap:` badge.
class SessionRecapCard extends StatelessWidget {
  const SessionRecapCard({super.key, required this.message});

  final SessionRecapMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final accent = theme.colorScheme.primary;
    return Padding(
      key: const ValueKey('session_recap_card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.summarize_outlined, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: appColors.subtleText,
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(
                        text: 'recap: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      TextSpan(text: message.content),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
