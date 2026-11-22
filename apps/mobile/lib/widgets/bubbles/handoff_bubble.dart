import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

/// A user message the Bridge wrote for a session handoff, read from its
/// marker. Either the request for a handoff note in the source session, or
/// the first prompt of the session that continues it.
///
/// The marker is part of the text because history reloaded from the agent's
/// own transcript carries nothing else. See docs/session-handoff.md.
class HandoffMessage {
  /// Agent that worked on the task before, for the first prompt of the
  /// continuing session. Null for a note request.
  final String? source;

  /// Agent that continues the task.
  final String? target;

  const HandoffMessage({this.source, this.target});

  static final _prompt = RegExp(r'^\[ccpocket handoff: (.+?) → (.+?)\]');
  static final _noteRequest = RegExp(
    r'^\[ccpocket handoff\] This session is being handed over to (.+?),',
  );

  static HandoffMessage? parse(String text) {
    if (!text.startsWith('[ccpocket handoff')) return null;
    final prompt = _prompt.firstMatch(text);
    if (prompt != null) {
      return HandoffMessage(source: prompt.group(1), target: prompt.group(2));
    }
    final request = _noteRequest.firstMatch(text);
    if (request != null) return HandoffMessage(target: request.group(1));
    return null;
  }
}

/// Compact card for a [HandoffMessage]; tapping it shows the full text.
class HandoffBubble extends StatefulWidget {
  final HandoffMessage handoff;
  final String text;

  const HandoffBubble({super.key, required this.handoff, required this.text});

  @override
  State<HandoffBubble> createState() => _HandoffBubbleState();
}

class _HandoffBubbleState extends State<HandoffBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final source = widget.handoff.source;
    final title = source != null
        ? l.handoffCardFrom(source)
        : l.handoffCardNoteRequest(widget.handoff.target ?? '');
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: const ValueKey('handoff_bubble'),
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.bubbleMarginV,
          horizontal: AppSpacing.bubbleMarginH,
        ),
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.of(context).size.width *
              AppSpacing.maxBubbleWidthFraction,
        ),
        decoration: BoxDecoration(
          color: appColors.userBubble,
          borderRadius: AppSpacing.userBubbleBorderRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.bubblePaddingV,
                  horizontal: AppSpacing.bubblePaddingH,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 18,
                      color: appColors.userBubbleText,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: appColors.userBubbleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: appColors.userBubbleText,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.bubblePaddingH,
                  right: AppSpacing.bubblePaddingH,
                  bottom: AppSpacing.bubblePaddingV,
                ),
                child: SelectableText(
                  widget.text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: appColors.userBubbleText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
