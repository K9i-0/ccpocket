import 'package:flutter/material.dart';

import '../../features/chat_session/permission_transcript.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

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
    final appColors = Theme.of(context).extension<AppColors>()!;
    final presentation = widget.message.presentation;
    final detailLines = presentation.secondaryDetails;
    final inputStr = presentation.rawDetails;
    final primaryTarget = presentation.primaryTarget;
    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      decoration: BoxDecoration(
        color: appColors.permissionBubble,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: appColors.permissionBubbleBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    size: 16,
                    color: appColors.permissionIcon,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      presentation.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _PermissionStatusBadge(status: widget.status),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: appColors.subtleText,
                  ),
                ],
              ),
              if (!_expanded && primaryTarget != null) ...[
                const SizedBox(height: 5),
                Text(
                  primaryTarget,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: appColors.subtleText,
                  ),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 6),
                Text(
                  presentation.summary,
                  style: TextStyle(fontSize: 12, color: appColors.subtleText),
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
                      color: appColors.permissionBubble.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: appColors.permissionBubbleBorder.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    child: Text(
                      primaryTarget,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: appColors.subtleText,
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
                            padding: const EdgeInsets.only(top: 5, right: 6),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: appColors.subtleText,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 11,
                                color: appColors.subtleText,
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
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: appColors.subtleText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStatusBadge extends StatelessWidget {
  final PermissionTranscriptStatus status;

  const _PermissionStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final (label, foreground, background) = switch (status) {
      PermissionTranscriptStatus.pending => (
        l.approvalStatusPending,
        appColors.permissionIcon,
        appColors.permissionIcon.withValues(alpha: 0.14),
      ),
      PermissionTranscriptStatus.approved => (
        l.approvalStatusApproved,
        colorScheme.primary,
        appColors.successChip,
      ),
      PermissionTranscriptStatus.approvedForSession => (
        l.approvalStatusApprovedForSession,
        colorScheme.primary,
        appColors.successChip,
      ),
      PermissionTranscriptStatus.rejected => (
        l.approvalStatusRejected,
        colorScheme.error,
        appColors.errorChip,
      ),
      PermissionTranscriptStatus.answered ||
      PermissionTranscriptStatus.resolved => (
        l.approvalStatusResolved,
        appColors.subtleText,
        appColors.subtleText.withValues(alpha: 0.12),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
