import 'package:material_ui/material_ui.dart';

import '../../features/chat_session/permission_transcript.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/code_text_style.dart';
import '../google_search_text_selection.dart';

class PermissionRequestBubble extends StatefulWidget {
  final PermissionRequestMessage message;
  final bool isCodex;
  final PermissionTranscriptStatus status;
  const PermissionRequestBubble({
    super.key,
    required this.message,
    this.isCodex = false,
    this.status = PermissionTranscriptStatus.resolved,
  });

  @override
  State<PermissionRequestBubble> createState() =>
      _PermissionRequestBubbleState();
}

class _PermissionRequestBubbleState extends State<PermissionRequestBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppColors>()!;
    final codeSettings = codeTextSettingsOf(context);
    final presentation = widget.message.presentation;
    final detailLines = presentation.secondaryDetails;
    final inputStr = presentation.rawDetails;
    final primaryTarget = presentation.primaryTarget;
    final isPending = widget.status == PermissionTranscriptStatus.pending;

    final cardBackground = isPending
        ? Color.alphaBlend(
            appColors.permissionIcon.withValues(alpha: isDark ? 0.06 : 0.04),
            cs.surfaceContainerHigh,
          )
        : cs.surfaceContainerLow;
    final cardBorder = isPending
        ? appColors.permissionIcon.withValues(alpha: isDark ? 0.45 : 0.38)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.65 : 0.8);

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: cardBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppSpacing.cardRadius),
              bottom: _expanded
                  ? Radius.zero
                  : const Radius.circular(AppSpacing.cardRadius),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 10, _expanded ? 8 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPending)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: appColors.permissionIcon.withValues(
                              alpha: isDark ? 0.16 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.security,
                            size: 14,
                            color: appColors.permissionIcon,
                          ),
                        )
                      else
                        Icon(
                          Icons.security,
                          size: 15,
                          color: cs.onSurfaceVariant,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          presentation.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isPending
                                ? cs.onSurface
                                : cs.onSurface.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PermissionStatusBadge(status: widget.status),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if (!_expanded && primaryTarget != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      primaryTarget,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: codeSettings.style(
                        fontSize: 11.5,
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GoogleSearchSelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (primaryTarget != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: appColors.codeBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(
                              alpha: isDark ? 0.65 : 0.8,
                            ),
                          ),
                        ),
                        child: Text(
                          primaryTarget,
                          style: codeSettings.style(
                            fontSize: 11.5,
                            color: cs.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    if (detailLines.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final line in detailLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 5,
                                  right: 6,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 4,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: cs.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      inputStr,
                      style: codeSettings.style(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PermissionStatusBadge extends StatelessWidget {
  final PermissionTranscriptStatus status;

  const _PermissionStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appColors = theme.extension<AppColors>()!;
    final colorScheme = theme.colorScheme;
    final l = AppLocalizations.of(context);

    final (label, foreground, background) = switch (status) {
      PermissionTranscriptStatus.pending => (
        l.approvalStatusPending,
        isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412),
        (isDark ? const Color(0xFFF97316) : const Color(0xFFEA580C)).withValues(
          alpha: isDark ? 0.16 : 0.10,
        ),
      ),
      PermissionTranscriptStatus.approved => (
        l.approvalStatusApproved,
        appColors.diffAdditionText,
        (isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A)).withValues(
          alpha: isDark ? 0.15 : 0.10,
        ),
      ),
      PermissionTranscriptStatus.approvedForSession => (
        l.approvalStatusApprovedForSession,
        appColors.diffAdditionText,
        (isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A)).withValues(
          alpha: isDark ? 0.15 : 0.10,
        ),
      ),
      PermissionTranscriptStatus.rejected => (
        l.approvalStatusRejected,
        appColors.diffDeletionText,
        (isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626)).withValues(
          alpha: isDark ? 0.16 : 0.10,
        ),
      ),
      PermissionTranscriptStatus.answered ||
      PermissionTranscriptStatus.resolved => (
        l.approvalStatusResolved,
        colorScheme.onSurfaceVariant,
        colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: isDark ? 0.22 : 0.18),
          width: 0.75,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
