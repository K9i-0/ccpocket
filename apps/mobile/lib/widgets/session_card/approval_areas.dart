import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../expandable_summary_text.dart';
import 'ask_user_widgets.dart';

class SessionCardToolSuggestionArea extends StatelessWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final VoidCallback onTap;

  const SessionCardToolSuggestionArea({
    super.key,
    required this.permission,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('session_tool_suggestion_area'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.extension_outlined, size: 17, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  permission.suggestedToolName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            permission.toolSuggestionReason,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          SessionCardOpenButton(onTap: onTap),
        ],
      ),
    );
  }
}

/// Approval area for normal tool execution (Bash, Edit, etc.)
class SessionCardToolApprovalArea extends StatelessWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final VoidCallback onApprove;
  final VoidCallback? onApproveAlways;
  final VoidCallback onReject;
  final bool isCodex;

  const SessionCardToolApprovalArea({
    super.key,
    required this.permission,
    required this.statusColor,
    required this.onApprove,
    this.onApproveAlways,
    required this.onReject,
    this.isCodex = false,
  });

  @override
  Widget build(BuildContext context) {
    final presentation = permission.presentation;
    final detailLines = presentation.secondaryDetails;
    final canReject = permission.canDecline;
    final canApproveAlways =
        permission.canApproveForSession && onApproveAlways != null;
    final canApprove = permission.canApprove;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            presentation.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          ExpandableSummaryText(
            text: presentation.summary,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.8),
            ),
            maxLines: 2,
          ),
          if (presentation.primaryTarget != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                presentation.primaryTarget!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...detailLines
                .take(5)
                .map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 400;
              final l = AppLocalizations.of(context);
              final cs = Theme.of(context).colorScheme;
              final rejectLabel = permission.showsCancelAction
                  ? l.cancel
                  : l.reject;
              final alwaysMain = isCodex
                  ? l.approveSessionMain
                  : l.approveAlways;
              final alwaysSub = isCodex
                  ? l.approveSessionSub
                  : l.approveAlwaysSub;
              Widget buildApproveLabel() {
                final approveLabel = isCodex ? l.approve : l.approveOnce;
                if (isWide || !approveLabel.contains(' ')) {
                  return Text(
                    approveLabel,
                    style: const TextStyle(fontSize: 12),
                  );
                }
                final splitIndex = approveLabel.lastIndexOf(' ');
                final sub = approveLabel.substring(0, splitIndex);
                final main = approveLabel.substring(splitIndex + 1);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                        color: statusColor.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(main, style: const TextStyle(fontSize: 11)),
                  ],
                );
              }

              final buttons = <Widget>[
                if (canReject)
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      key: const ValueKey('reject_button'),
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 14),
                      label: Text(rejectLabel),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (canApproveAlways) ...[
                  if (canReject) const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      key: const ValueKey('approve_always_button'),
                      onPressed: onApproveAlways,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: cs.error,
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: isWide || alwaysSub.isEmpty
                          ? Text(
                              alwaysSub.isEmpty
                                  ? alwaysMain
                                  : '$alwaysMain $alwaysSub',
                              style: const TextStyle(fontSize: 12),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  alwaysSub,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w400,
                                    color: cs.error.withValues(alpha: 0.7),
                                  ),
                                ),
                                Text(
                                  alwaysMain,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                if (canApprove) ...[
                  if (canReject || canApproveAlways) const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('approve_button'),
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 14),
                      label: buildApproveLabel(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        foregroundColor: statusColor,
                      ),
                    ),
                  ),
                ],
              ];
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: buttons,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Approval area for ExitPlanMode (plan review).
class SessionCardPlanApprovalArea extends StatelessWidget {
  final Color statusColor;
  final TextEditingController planFeedbackController;
  final bool canOpenPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onApprove;
  final VoidCallback onApproveClearContext;
  final VoidCallback onKeepPlanning;

  const SessionCardPlanApprovalArea({
    super.key,
    required this.statusColor,
    required this.planFeedbackController,
    required this.canOpenPlan,
    required this.onOpenPlan,
    required this.onApprove,
    required this.onApproveClearContext,
    required this.onKeepPlanning,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    l.planApprovalSummaryCard,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (canOpenPlan)
                IconButton(
                  onPressed: onOpenPlan,
                  icon: const Icon(Icons.open_in_full, size: 22),
                  color: cs.primary,
                  tooltip: l.viewEditPlan,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.keepPlanning,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('plan_feedback_input'),
                  controller: planFeedbackController,
                  style: const TextStyle(fontSize: 13),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  decoration: InputDecoration(
                    hintText: l.keepPlanningHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const ValueKey('reject_button'),
                onPressed: onKeepPlanning,
                icon: Icon(Icons.send, size: 18, color: cs.primary),
                tooltip: l.sendFeedbackKeepPlanning,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    key: const ValueKey('approve_clear_context_button'),
                    onPressed: onApproveClearContext,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      foregroundColor: statusColor,
                      side: BorderSide(
                        color: statusColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.acceptAndClear,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    key: const ValueKey('approve_button'),
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      foregroundColor: statusColor,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.acceptPlan,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plan approval area for Codex sessions in session list.
class SessionCardCodexPlanApprovalArea extends StatelessWidget {
  final Color statusColor;
  final bool canOpenPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const SessionCardCodexPlanApprovalArea({
    super.key,
    required this.statusColor,
    required this.canOpenPlan,
    required this.onOpenPlan,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('codex_plan_approval_area'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    l.planApprovalSummaryCard,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (canOpenPlan)
                IconButton(
                  onPressed: onOpenPlan,
                  icon: const Icon(Icons.open_in_full, size: 22),
                  color: cs.primary,
                  tooltip: l.viewEditPlan,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    key: const ValueKey('reject_button'),
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.continuePlanning,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    key: const ValueKey('approve_button'),
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      foregroundColor: statusColor,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.acceptPlan,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Open" button for questions without options.
class SessionCardOpenButton extends StatelessWidget {
  final VoidCallback onTap;

  const SessionCardOpenButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: sessionCardButtonHeight,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('Open'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }
}
