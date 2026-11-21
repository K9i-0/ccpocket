import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/markdown_style.dart';

/// Tool name the Bridge uses for a post on an Antigravity swarm's board.
const swarmPostToolName = 'SwarmPost';

/// One post on a swarm's shared board: who said it, and what.
///
/// The swarm's members talk to each other there, not to the user, so it reads
/// as a side conversation rather than as the agent's reply.
class SwarmPostCard extends StatelessWidget {
  final Map<String, dynamic> input;

  const SwarmPostCard({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final agent = input['agent']?.toString() ?? '';
    final text = input['text']?.toString() ?? '';
    final seq = input['seq'];
    final isCoordinator = agent == 'coordinator';
    final accent = isCoordinator ? cs.primary : cs.tertiary;

    return Padding(
      key: ValueKey('swarm_post_$seq'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.bubbleMarginH,
        vertical: 2,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).copied),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border(left: BorderSide(color: accent, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCoordinator
                        ? Icons.hub_outlined
                        : Icons.smart_toy_outlined,
                    size: 13,
                    color: accent,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      agent,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (seq != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '#$seq',
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              MarkdownBody(
                data: text,
                selectable: false,
                styleSheet: buildMarkdownStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
