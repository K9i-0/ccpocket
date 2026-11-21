import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_theme.dart';
import '../../theme/provider_style.dart';
import '../../utils/command_parser.dart';
import '../adaptive_context_menu.dart';
import '../codex_environment_summary.dart';
import '../pin_toggle_button.dart';
import 'header_widgets.dart';

class RecentSessionCard extends StatelessWidget {
  final RecentSession session;
  final String? projectNameOverride;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset?>? onShowActions;
  final bool hideProjectBadge;
  final SessionDisplayMode displayMode;
  final String? draftText;
  final bool isProcessing;
  final bool isSelected;
  final bool isPinned;
  final VoidCallback? onTogglePinned;

  /// Search text to highlight; also enables the "matched in" row for
  /// [RecentSession.searchMatch] fields the card does not otherwise show.
  final String? highlightQuery;

  const RecentSessionCard({
    super.key,
    required this.session,
    this.projectNameOverride,
    required this.onTap,
    this.onLongPress,
    this.onShowActions,
    this.hideProjectBadge = false,
    this.displayMode = SessionDisplayMode.first,
    this.draftText,
    this.isProcessing = false,
    this.isSelected = false,
    this.isPinned = false,
    this.onTogglePinned,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final provider = providerFromRaw(session.provider);
    final providerStyle = providerStyleFor(context, provider);
    final isCodex = session.provider == 'codex';
    final agentLabel = formatSessionAgentLabel(
      session.agentNickname,
      session.agentRole,
    );
    final dateStr = _formatDateRange(session.created, session.modified);
    final query = highlightQuery?.trim() ?? '';
    final highlightStyle = TextStyle(
      backgroundColor: colorScheme.tertiaryContainer,
      color: colorScheme.onTertiaryContainer,
    );
    final matchRow = query.isEmpty
        ? null
        : _searchMatchRow(context, query, highlightStyle);

    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.9)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isProcessing ? null : onTap,
        onLongPress: isProcessing || onShowActions != null ? null : onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (session.name != null &&
                                session.name!.isNotEmpty) ...[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    session.name!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (!hideProjectBadge) ...[
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: providerStyle.background,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: providerStyle.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    projectNameOverride ?? session.projectName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: providerStyle.foreground,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Sessions that cannot be pinned (Antigravity) show no
                      // pin at all rather than a dead button.
                      if (onTogglePinned != null || isPinned) ...[
                        const SizedBox(width: 8),
                        PinToggleButton(
                          key: ValueKey(
                            'recent_session_pin_${session.sessionId}_button',
                          ),
                          isPinned: isPinned,
                          onPressed: onTogglePinned,
                          pinTooltip: AppLocalizations.of(context).pin,
                          unpinTooltip: AppLocalizations.of(context).unpin,
                        ),
                      ],
                    ],
                  ),
                  if (agentLabel != null) ...[
                    const SizedBox(height: 8),
                    SessionAgentLabel(label: agentLabel),
                  ],
                  const SizedBox(height: 8),

                  // Body Content
                  if (draftText != null && draftText!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 6),
                          child: Icon(
                            Icons.edit_note,
                            size: 16,
                            color: appColors.subtleText,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            draftText!,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: appColors.subtleText,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Text.rich(
                      TextSpan(
                        children: highlightSearchSpans(
                          _displayTextForMode(session, displayMode),
                          query,
                          highlightStyle,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (matchRow != null) ...[
                    const SizedBox(height: 6),
                    matchRow,
                  ],

                  if (isCodex) ...[
                    const SizedBox(height: 6),
                    CodexEnvironmentSummary(
                      model: session.codexModel,
                      reasoningEffort: session.codexModelReasoningEffort,
                      serviceTier: session.codexServiceTier,
                      approvalPolicy: session.codexApprovalPolicy,
                      approvalsReviewer: session.codexApprovalsReviewer,
                      sandboxMode: session.codexSandboxMode,
                      showDefaultReasoning: true,
                      showApprovalMode: false,
                      compact: true,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Meta Row: branch (left) + date (right)
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (session.gitBranch.isNotEmpty) ...[
                              Icon(
                                Icons.fork_right,
                                size: 14,
                                color: appColors.subtleText,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  session.gitBranch,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: appColors.subtleText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: appColors.subtleText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isProcessing)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.55),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (isProcessing || onShowActions == null) return card;
    return AdaptiveContextMenuRegion(onOpen: onShowActions!, child: card);
  }

  /// "Matched: `field`" row for a search hit the card does not show.
  Widget? _searchMatchRow(
    BuildContext context,
    String query,
    TextStyle highlightStyle,
  ) {
    final match = session.searchMatch;
    if (match == null) return null;
    final l = AppLocalizations.of(context);
    final (label, text) = switch (match.field) {
      RecentSessionSearchField.content => (l.recentMatchContent, match.snippet),
      RecentSessionSearchField.firstPrompt
          when displayMode != SessionDisplayMode.first =>
        (l.recentMatchFirstPrompt, session.firstPrompt),
      RecentSessionSearchField.lastPrompt
          when displayMode != SessionDisplayMode.last =>
        (l.recentMatchLastPrompt, session.lastPrompt),
      RecentSessionSearchField.summary
          when displayMode != SessionDisplayMode.summary =>
        (l.recentMatchSummary, session.summary),
      RecentSessionSearchField.project when hideProjectBadge => (
        l.recentMatchProject,
        session.projectPath,
      ),
      _ => (null, null),
    };
    if (label == null) return null;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final snippet = text == null ? '' : _snippetAround(text, query);
    return Row(
      key: ValueKey('recent_session_match_${session.sessionId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 4),
          child: Icon(Icons.search, size: 13, color: appColors.subtleText),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: snippet.isEmpty
                      ? l.recentMatchedIn(label)
                      : '${l.recentMatchedIn(label)}  ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                ...highlightSearchSpans(snippet, query, highlightStyle),
              ],
            ),
            style: TextStyle(fontSize: 12, color: appColors.subtleText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _snippetAround(String text, String query) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final index = flat.toLowerCase().indexOf(query.toLowerCase());
    if (index <= 30) return flat;
    return '…${flat.substring(index - 30)}';
  }

  static String _displayTextForMode(
    RecentSession session,
    SessionDisplayMode mode,
  ) {
    final String raw;
    switch (mode) {
      case SessionDisplayMode.first:
        raw = session.firstPrompt.isNotEmpty
            ? session.firstPrompt
            : session.displayText;
      case SessionDisplayMode.last:
        final text = session.lastPrompt ?? session.firstPrompt;
        raw = text.isNotEmpty ? text : '(no description)';
      case SessionDisplayMode.summary:
        final text = session.summary ?? session.firstPrompt;
        raw = text.isNotEmpty ? text : '(no description)';
    }
    return formatCommandText(raw);
  }

  String _formatDateRange(String createdIso, String modifiedIso) {
    if (modifiedIso.isEmpty) return _formatDate(createdIso);
    final modified = _formatDate(modifiedIso);
    if (createdIso.isEmpty || createdIso == modifiedIso) return modified;
    try {
      final first = DateTime.parse(createdIso).toLocal();
      final last = DateTime.parse(modifiedIso).toLocal();
      // Same minute → single timestamp
      if (first.year == last.year &&
          first.month == last.month &&
          first.day == last.day &&
          first.hour == last.hour &&
          first.minute == last.minute) {
        return modified;
      }
      final firstTime =
          '${first.hour.toString().padLeft(2, '0')}:${first.minute.toString().padLeft(2, '0')}';
      final lastTime =
          '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
      // Same day → "Today 10:00–12:30"
      if (first.year == last.year &&
          first.month == last.month &&
          first.day == last.day) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final dtDate = DateTime(first.year, first.month, first.day);
        if (dtDate == today) return 'Today $firstTime–$lastTime';
        if (dtDate == yesterday) return 'Yesterday $firstTime–$lastTime';
        return '${first.month}/${first.day} $firstTime–$lastTime';
      }
      // Different days → "1/10 10:00–1/11 12:30"
      return '${first.month}/${first.day} $firstTime–${last.month}/${last.day} $lastTime';
    } catch (_) {
      return modified;
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dtDate = DateTime(dt.year, dt.month, dt.day);

      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (dtDate == today) return 'Today $time';
      if (dtDate == yesterday) return 'Yesterday $time';
      return '${dt.month}/${dt.day} $time';
    } catch (_) {
      return '';
    }
  }
}

/// Split [text] into spans, applying [highlightStyle] to case-insensitive
/// occurrences of [query].
List<TextSpan> highlightSearchSpans(
  String text,
  String query,
  TextStyle highlightStyle,
) {
  if (query.isEmpty || text.isEmpty) return [TextSpan(text: text)];
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  // Lower-casing can change length for some scripts; fall back to no
  // highlight rather than misaligned ranges.
  if (lowerText.length != text.length) return [TextSpan(text: text)];
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = lowerText.indexOf(lowerQuery, start);
    if (index < 0) break;
    if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
    spans.add(
      TextSpan(
        text: text.substring(index, index + query.length),
        style: highlightStyle,
      ),
    );
    start = index + query.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}
