import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import '../utils/command_parser.dart';
import 'plan_detail_sheet.dart';
import 'session_visual_status.dart';

/// Shared layout constant for AskUserArea buttons.
const _buttonHeight = 44.0;

/// Card for a currently running session
class RunningSessionCard extends StatefulWidget {
  final SessionInfo session;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final VoidCallback? onLongPress;
  final void Function(
    String toolUseId, {
    Map<String, dynamic>? updatedInput,
    bool clearContext,
  })?
  onApprove;
  final ValueChanged<String>? onApproveAlways;
  final void Function(String toolUseId, {String? message})? onReject;
  final void Function(String toolUseId, String result)? onAnswer;

  const RunningSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onStop,
    this.onLongPress,
    this.onApprove,
    this.onApproveAlways,
    this.onReject,
    this.onAnswer,
  });

  @override
  State<RunningSessionCard> createState() => _RunningSessionCardState();
}

class _RunningSessionCardState extends State<RunningSessionCard> {
  late final TextEditingController _planFeedbackController;
  String? _editedPlanText;
  String? _activePlanToolUseId;

  @override
  void initState() {
    super.initState();
    _planFeedbackController = TextEditingController();
  }

  @override
  void dispose() {
    _planFeedbackController.dispose();
    super.dispose();
  }

  void _syncPlanApprovalState(PermissionRequestMessage? permission) {
    final toolUseId = permission?.toolUseId;
    if (_activePlanToolUseId == toolUseId) return;
    _activePlanToolUseId = toolUseId;
    _editedPlanText = null;
    _planFeedbackController.clear();
  }

  String? _extractPlanText(PermissionRequestMessage permission) {
    final raw = permission.input['plan'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw;
    }
    return null;
  }

  Future<void> _openPlanSheet(PermissionRequestMessage permission) async {
    final originalText = _extractPlanText(permission);
    if (originalText == null || !mounted) return;
    final current = _editedPlanText ?? originalText;
    final edited = await showPlanDetailSheet(context, current, editable: true);
    if (!mounted) return;
    if (edited != null) {
      setState(() => _editedPlanText = edited);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final visualStatus = sessionVisualStatusFor(
      rawStatus: session.status,
      permissionMode: session.permissionMode,
      pendingPermission: session.pendingPermission,
    );
    final statusColor = switch (visualStatus.primary) {
      SessionPrimaryStatus.working => appColors.statusRunning,
      SessionPrimaryStatus.needsYou => appColors.statusApproval,
      SessionPrimaryStatus.ready => appColors.statusIdle,
    };

    final permission = session.pendingPermission;
    final hasPermission = permission != null;
    final isCodexSession = session.provider == Provider.codex.value;
    final isPlanApproval =
        hasPermission && permission.toolName == 'ExitPlanMode';
    if (isPlanApproval) {
      _syncPlanApprovalState(permission);
    } else {
      _syncPlanApprovalState(null);
    }
    final projectName = session.projectPath.split('/').last;
    final provider = providerFromRaw(session.provider);
    final providerStyle = providerStyleFor(context, provider);
    final elapsed = _formatElapsed(session.lastActivityAt);
    final displayMessage = formatCommandText(
      session.lastMessage.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    final codexSummary = session.provider == 'codex'
        ? _buildCodexSettingsSummary(
            model: session.codexModel,
            sandboxMode: session.codexSandboxMode,
            approvalPolicy: session.codexApprovalPolicy,
          )
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    statusColor.withValues(alpha: 0.15),
                    statusColor.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _StatusDot(
                          color: statusColor,
                          animate: visualStatus.animate,
                          inPlanMode: visualStatus.showPlanBadge,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          visualStatus.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        if (visualStatus.detail != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              visualStatus.detail!,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor.withValues(alpha: 0.82),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (visualStatus.showPlanBadge) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Plan',
                            key: const ValueKey('running_session_plan_badge'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: appColors.statusPlan,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.stop_circle_outlined),
                      onPressed: widget.onStop,
                      tooltip: 'Stop session',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            // Approval area (shown when waiting for permission)
            if (hasPermission)
              isCodexSession
                  ? (isPlanApproval
                        ? _CodexPlanApprovalArea(
                            statusColor: statusColor,
                            canOpenPlan: _extractPlanText(permission) != null,
                            onOpenPlan: () => _openPlanSheet(permission),
                            onApprove: () => widget.onApprove?.call(
                              permission.toolUseId,
                              updatedInput: _editedPlanText != null
                                  ? {'plan': _editedPlanText!}
                                  : null,
                              clearContext: false,
                            ),
                            onReject: () =>
                                widget.onReject?.call(permission.toolUseId),
                          )
                        : _ToolApprovalArea(
                            permission: permission,
                            statusColor: statusColor,
                            onApprove: () => widget.onApprove?.call(
                              permission.toolUseId,
                              clearContext: false,
                            ),
                            onApproveAlways: () => widget.onApproveAlways?.call(
                              permission.toolUseId,
                            ),
                            onReject: () =>
                                widget.onReject?.call(permission.toolUseId),
                          ))
                  : switch (permission.toolName) {
                      'AskUserQuestion' => _AskUserArea(
                        permission: permission,
                        statusColor: statusColor,
                        onAnswer: (result) =>
                            widget.onAnswer?.call(permission.toolUseId, result),
                        onTap: widget.onTap,
                      ),
                      'ExitPlanMode' => _PlanApprovalArea(
                        statusColor: statusColor,
                        planFeedbackController: _planFeedbackController,
                        canOpenPlan: _extractPlanText(permission) != null,
                        onOpenPlan: () => _openPlanSheet(permission),
                        onApprove: () => widget.onApprove?.call(
                          permission.toolUseId,
                          updatedInput: _editedPlanText != null
                              ? {'plan': _editedPlanText!}
                              : null,
                          clearContext: false,
                        ),
                        onApproveClearContext: () => widget.onApprove?.call(
                          permission.toolUseId,
                          updatedInput: _editedPlanText != null
                              ? {'plan': _editedPlanText!}
                              : null,
                          clearContext: true,
                        ),
                        onKeepPlanning: () {
                          final feedback = _planFeedbackController.text.trim();
                          widget.onReject?.call(
                            permission.toolUseId,
                            message: feedback.isNotEmpty ? feedback : null,
                          );
                          _planFeedbackController.clear();
                        },
                      ),
                      _ => _ToolApprovalArea(
                        permission: permission,
                        statusColor: statusColor,
                        onApprove: () => widget.onApprove?.call(
                          permission.toolUseId,
                          clearContext: false,
                        ),
                        onApproveAlways: () =>
                            widget.onApproveAlways?.call(permission.toolUseId),
                        onReject: () =>
                            widget.onReject?.call(permission.toolUseId),
                      ),
                    },
            // Content (same structure as RecentSessionCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: session name + project badge + elapsed
                  Row(
                    children: [
                      // Left-aligned group: badge/name
                      Expanded(
                        child: Row(
                          children: [
                            if (session.name != null &&
                                session.name!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.label_outline,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        session.name!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Hero(
                              tag: 'project_name_${session.id}',
                              child: Material(
                                color: Colors.transparent,
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
                                    projectName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: providerStyle.foreground,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right-aligned time
                      Text(
                        elapsed,
                        style: TextStyle(
                          fontSize: 11,
                          color: appColors.subtleText,
                        ),
                      ),
                    ],
                  ),
                  // Last message
                  if (displayMessage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayMessage,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (codexSummary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      codexSummary,
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Git branch + worktree
                  if (session.gitBranch.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (session.gitBranch.isNotEmpty) ...[
                          Icon(
                            Icons.fork_right,
                            size: 13,
                            color: appColors.subtleText,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              session.gitBranch,
                              style: TextStyle(
                                fontSize: 11,
                                color: appColors.subtleText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        // messageCount removed for performance
                        if (session.worktreePath != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.account_tree_outlined,
                            size: 12,
                            color: appColors.subtleText,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'worktree',
                            style: TextStyle(
                              fontSize: 11,
                              color: appColors.subtleText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

/// Approval area for normal tool execution (Bash, Edit, etc.)
class _ToolApprovalArea extends StatelessWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final VoidCallback onApprove;
  final VoidCallback? onApproveAlways;
  final VoidCallback onReject;

  const _ToolApprovalArea({
    required this.permission,
    required this.statusColor,
    required this.onApprove,
    this.onApproveAlways,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            permission.summary,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: onApproveAlways,
                  icon: const Icon(Icons.done_all, size: 14),
                  label: const Text('Always'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                    foregroundColor: statusColor,
                    side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton.tonalIcon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    foregroundColor: statusColor,
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

/// Approval area for ExitPlanMode (plan review).
class _PlanApprovalArea extends StatelessWidget {
  final Color statusColor;
  final TextEditingController planFeedbackController;
  final bool canOpenPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onApprove;
  final VoidCallback onApproveClearContext;
  final VoidCallback onKeepPlanning;

  const _PlanApprovalArea({
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
                  maxLines: 2,
                  onSubmitted: (_) => onKeepPlanning(),
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
class _CodexPlanApprovalArea extends StatelessWidget {
  final Color statusColor;
  final bool canOpenPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _CodexPlanApprovalArea({
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
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.reject,
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

/// Approval area for AskUserQuestion.
/// Supports three modes:
/// - Single question, single select → full-width buttons + Other
/// - Single question, multi select → toggle buttons + Confirm + Other
/// - Multiple questions → PageView with one question per page + Other
class _AskUserArea extends StatefulWidget {
  final PermissionRequestMessage permission;
  final Color statusColor;
  final ValueChanged<String> onAnswer;
  final VoidCallback onTap;

  const _AskUserArea({
    required this.permission,
    required this.statusColor,
    required this.onAnswer,
    required this.onTap,
  });

  @override
  State<_AskUserArea> createState() => _AskUserAreaState();
}

class _AskUserAreaState extends State<_AskUserArea> {
  late final PageController _pageController;

  /// 0 to questions.length (where questions.length == summary page).
  int _currentPage = 0;

  /// questionIndex -> chosen label
  final Map<int, String> _singleAnswers = {};

  /// questionIndex -> set of chosen labels
  final Map<int, Set<String>> _multiAnswers = {};

  final Map<int, TextEditingController> _customControllers = {};

  /// Keep track of which questions have their "Other" input shown
  final Set<int> _customInputs = {};

  List<dynamic> get _questions =>
      widget.permission.input['questions'] as List<dynamic>? ?? [];

  bool get _isMultiQuestion => _questions.length > 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    for (var c in _customControllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _answerSingle(int questionIndex, String label) {
    setState(() {
      _singleAnswers[questionIndex] = label;

      // Only clear custom input for single-select questions
      final q = _questions[questionIndex] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;
      if (!isMulti) {
        _customControllers[questionIndex]?.clear();
      }
    });
    if (!_isMultiQuestion) {
      // Single question → send immediately
      widget.onAnswer(label);
    }
  }

  void _confirmMultiSelect(int questionIndex) {
    final selected = _multiAnswers[questionIndex];
    if (selected == null || selected.isEmpty) return;
    final answer = selected.join(', ');
    if (!_isMultiQuestion) {
      widget.onAnswer(answer);
    } else {
      setState(() {
        _singleAnswers[questionIndex] = answer;
      });
      _goToPage(_currentPage + 1);
    }
  }

  void _submitCustomText(int questionIndex) {
    // Determine the combined text for submission
    String finalAnswer = '';

    final q = _questions[questionIndex] as Map<String, dynamic>;
    final isMulti = q['multiSelect'] as bool? ?? false;

    final customText = _customControllers[questionIndex]?.text.trim() ?? '';

    if (isMulti) {
      final selected = _multiAnswers[questionIndex] ?? {};
      final parts = [...selected];
      if (customText.isNotEmpty) parts.add(customText);
      finalAnswer = parts.join(', ');
    } else {
      finalAnswer = _singleAnswers[questionIndex]?.trim() ?? '';
    }

    if (finalAnswer.isEmpty) return;

    if (!_isMultiQuestion) {
      widget.onAnswer(finalAnswer);
      return;
    }

    final next = questionIndex + 1;
    if (next <= _questions.length) {
      _goToPage(next);
    }
  }

  void _submitAll() {
    final parts = <String>[];
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;
      final header = q['header'] as String? ?? 'Q${i + 1}';

      String answer = '';
      if (isMulti) {
        final selected = _multiAnswers[i] ?? {};
        final subParts = [...selected];
        final customText = _customControllers[i]?.text.trim() ?? '';
        if (customText.isNotEmpty) subParts.add(customText);
        answer = subParts.isNotEmpty ? subParts.join(', ') : '(skipped)';
      } else {
        answer = _singleAnswers[i] ?? '(skipped)';
      }

      parts.add('$header: $answer');
    }
    widget.onAnswer(parts.join('\n'));
  }

  void _resetAll() {
    setState(() {
      _singleAnswers.clear();
      for (var s in _multiAnswers.values) {
        s.clear();
      }
      _multiAnswers.clear();
      _customInputs.clear();
      for (var c in _customControllers.values) {
        c.clear();
      }
      _currentPage = 0;
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _toggleMultiSelectLabel(int questionIndex, String label) {
    setState(() {
      final selected = _multiAnswers.putIfAbsent(questionIndex, () => {});
      if (selected.contains(label)) {
        selected.remove(label);
      } else {
        selected.add(label);
      }

      final parts = [...selected];
      final customText = _customControllers[questionIndex]?.text.trim() ?? '';
      if (customText.isNotEmpty) parts.add(customText);

      _singleAnswers[questionIndex] = parts.join(', ');
    });
  }

  void _onCustomTextChanged(int questionIndex, String text) {
    setState(() {
      final q = _questions[questionIndex] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;

      if (isMulti) {
        final selected = _multiAnswers[questionIndex] ?? {};
        final parts = [...selected];
        if (text.trim().isNotEmpty) parts.add(text.trim());
        _singleAnswers[questionIndex] = parts.join(', ');
      } else {
        _singleAnswers[questionIndex] = text.trim();
        // Clear single-select chips when typing
        if (text.trim().isNotEmpty) {
          _multiAnswers[questionIndex]?.clear();
        }
      }
    });
  }

  void _showCustomInput(int questionIndex) {
    setState(() {
      _customInputs.add(questionIndex);
    });
  }

  TextEditingController _getOrCreateController(int questionIndex) {
    return _customControllers.putIfAbsent(
      questionIndex,
      () => TextEditingController(),
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    if (questions.isEmpty) return const SizedBox.shrink();

    final firstQ = questions[0] as Map<String, dynamic>;
    final options = firstQ['options'] as List<dynamic>? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: widget.statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMultiQuestion) ...[
            _QuestionPageView(
              questions: questions,
              currentPage: _currentPage,
              pageController: _pageController,
              statusColor: widget.statusColor,
              isMultiQuestion: _isMultiQuestion,
              singleAnswers: _singleAnswers,
              multiAnswers: _multiAnswers,
              customInputs: _customInputs,
              getOrCreateController: _getOrCreateController,
              onAnswerSingle: _answerSingle,
              onToggleMultiSelectLabel: _toggleMultiSelectLabel,
              onConfirmMultiSelect: _confirmMultiSelect,
              onSubmitCustomText: _submitCustomText,
              onCustomTextChanged: _onCustomTextChanged,
              onShowCustomInput: _showCustomInput,
              onPageChanged: _onPageChanged,
              onGoToPage: _goToPage,
              onResetAll: _resetAll,
              onSubmitAll: _submitAll,
            ),
          ] else if (options.isNotEmpty) ...[
            _QuestionLayout(
              question: firstQ,
              questionIndex: 0,
              statusColor: widget.statusColor,
              isMultiQuestion: _isMultiQuestion,
              singleAnswers: _singleAnswers,
              multiAnswers: _multiAnswers,
              customInputs: _customInputs,
              getOrCreateController: _getOrCreateController,
              onAnswerSingle: _answerSingle,
              onToggleMultiSelectLabel: _toggleMultiSelectLabel,
              onConfirmMultiSelect: _confirmMultiSelect,
              onSubmitCustomText: _submitCustomText,
              onCustomTextChanged: _onCustomTextChanged,
              onShowCustomInput: _showCustomInput,
            ),
          ] else ...[
            _QuestionText(question: firstQ),
            const SizedBox(height: 6),
            _OpenButton(onTap: widget.onTap),
          ],
        ],
      ),
    );
  }
}

/// Displays the question text from a question map.
class _QuestionText extends StatelessWidget {
  final Map<String, dynamic> question;

  const _QuestionText({required this.question});

  @override
  Widget build(BuildContext context) {
    final text = question['question'] as String? ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// "Open" button for questions without options.
class _OpenButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: _buttonHeight,
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

/// Single-select option chips for a question.
class _SingleSelectChips extends StatelessWidget {
  final int questionIndex;
  final List<dynamic> options;
  final String? selectedLabel;
  final Color statusColor;
  final void Function(int questionIndex, String label) onAnswerSingle;

  const _SingleSelectChips({
    required this.questionIndex,
    required this.options,
    required this.selectedLabel,
    required this.statusColor,
    required this.onAnswerSingle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opt in options)
          if (opt is Map<String, dynamic>)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Builder(
                builder: (context) {
                  final label = opt['label'] as String? ?? '';
                  final isChosen = selectedLabel == label;
                  return OutlinedButton.icon(
                    onPressed: () => onAnswerSingle(questionIndex, label),
                    icon: isChosen
                        ? Icon(Icons.check_circle, size: 16, color: statusColor)
                        : const SizedBox.shrink(),
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, _buttonHeight),
                      foregroundColor: statusColor,
                      backgroundColor: isChosen
                          ? statusColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      side: BorderSide(
                        color: statusColor.withValues(
                          alpha: isChosen ? 0.6 : 0.3,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

/// Multi-select option chips for a question.
class _MultiSelectChips extends StatelessWidget {
  final int questionIndex;
  final List<dynamic> options;
  final Set<String> selected;
  final Color statusColor;
  final void Function(int questionIndex, String label) onToggleLabel;

  const _MultiSelectChips({
    required this.questionIndex,
    required this.options,
    required this.selected,
    required this.statusColor,
    required this.onToggleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opt in options)
          if (opt is Map<String, dynamic>)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Builder(
                builder: (context) {
                  final label = opt['label'] as String? ?? '';
                  final isSelected = selected.contains(label);
                  return OutlinedButton.icon(
                    onPressed: () => onToggleLabel(questionIndex, label),
                    icon: Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: isSelected
                          ? statusColor
                          : statusColor.withValues(alpha: 0.5),
                    ),
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, _buttonHeight),
                      alignment: Alignment.centerLeft,
                      foregroundColor: statusColor,
                      backgroundColor: isSelected
                          ? statusColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      side: BorderSide(
                        color: statusColor.withValues(
                          alpha: isSelected ? 0.6 : 0.3,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

/// Confirm button for multi-select (used in single-question mode).
class _ConfirmButton extends StatelessWidget {
  final int questionIndex;
  final Set<String> selected;
  final Color statusColor;
  final void Function(int questionIndex) onConfirmMultiSelect;

  const _ConfirmButton({
    required this.questionIndex,
    required this.selected,
    required this.statusColor,
    required this.onConfirmMultiSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: double.infinity,
        height: _buttonHeight,
        child: FilledButton.icon(
          onPressed: selected.isNotEmpty
              ? () => onConfirmMultiSelect(questionIndex)
              : null,
          icon: const Icon(Icons.check, size: 16),
          label: Text('Confirm (${selected.length})'),
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 13),
            backgroundColor: statusColor.withValues(alpha: 0.15),
            foregroundColor: statusColor,
            disabledBackgroundColor: statusColor.withValues(alpha: 0.05),
            disabledForegroundColor: statusColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Other answer..." toggle button + inline text field.
class _OtherAnswerSection extends StatelessWidget {
  final int questionIndex;
  final bool isCustomInputShown;
  final bool isMultiQuestion;
  final Color statusColor;
  final TextEditingController controller;
  final void Function(int questionIndex, String text) onCustomTextChanged;
  final void Function(int questionIndex) onSubmitCustomText;
  final void Function(int questionIndex) onShowCustomInput;

  const _OtherAnswerSection({
    required this.questionIndex,
    required this.isCustomInputShown,
    required this.isMultiQuestion,
    required this.statusColor,
    required this.controller,
    required this.onCustomTextChanged,
    required this.onSubmitCustomText,
    required this.onShowCustomInput,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canSubmit = controller.text.trim().isNotEmpty;

    if (isCustomInputShown) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: _buttonHeight,
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type your answer...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: statusColor),
                    ),
                    isDense: true,
                  ),
                  onChanged: (text) => onCustomTextChanged(questionIndex, text),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: _buttonHeight,
              child: FilledButton(
                onPressed: canSubmit
                    ? () {
                        FocusScope.of(context).unfocus();
                        onSubmitCustomText(questionIndex);
                      }
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  foregroundColor: statusColor,
                  disabledBackgroundColor: statusColor.withValues(alpha: 0.08),
                  disabledForegroundColor: statusColor.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isMultiQuestion ? l.next : l.send,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: TextButton(
          onPressed: () => onShowCustomInput(questionIndex),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 36),
            textStyle: const TextStyle(fontSize: 12),
            foregroundColor: statusColor.withValues(alpha: 0.7),
          ),
          child: const Text('Other answer...'),
        ),
      ),
    );
  }
}

/// Common layout for a single question page.
/// Used by both inline (single-question) and PageView (multi-question) modes
/// to ensure consistent ordering: question -> options -> other answer -> confirm.
class _QuestionLayout extends StatelessWidget {
  final Map<String, dynamic> question;
  final int questionIndex;
  final Color statusColor;
  final bool isMultiQuestion;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final Set<int> customInputs;
  final TextEditingController Function(int) getOrCreateController;
  final void Function(int questionIndex, String label) onAnswerSingle;
  final void Function(int questionIndex, String label) onToggleMultiSelectLabel;
  final void Function(int questionIndex) onConfirmMultiSelect;
  final void Function(int questionIndex) onSubmitCustomText;
  final void Function(int questionIndex, String text) onCustomTextChanged;
  final void Function(int questionIndex) onShowCustomInput;

  const _QuestionLayout({
    required this.question,
    required this.questionIndex,
    required this.statusColor,
    required this.isMultiQuestion,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customInputs,
    required this.getOrCreateController,
    required this.onAnswerSingle,
    required this.onToggleMultiSelectLabel,
    required this.onConfirmMultiSelect,
    required this.onSubmitCustomText,
    required this.onCustomTextChanged,
    required this.onShowCustomInput,
  });

  @override
  Widget build(BuildContext context) {
    final opts = question['options'] as List<dynamic>? ?? [];
    final isMulti = question['multiSelect'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuestionText(question: question),
        const SizedBox(height: 6),
        if (isMulti && opts.isNotEmpty)
          _MultiSelectChips(
            questionIndex: questionIndex,
            options: opts,
            selected: multiAnswers.putIfAbsent(questionIndex, () => {}),
            statusColor: statusColor,
            onToggleLabel: onToggleMultiSelectLabel,
          )
        else if (opts.isNotEmpty)
          _SingleSelectChips(
            questionIndex: questionIndex,
            options: opts,
            selectedLabel: singleAnswers[questionIndex],
            statusColor: statusColor,
            onAnswerSingle: onAnswerSingle,
          ),
        _OtherAnswerSection(
          questionIndex: questionIndex,
          isCustomInputShown: customInputs.contains(questionIndex),
          isMultiQuestion: isMultiQuestion,
          statusColor: statusColor,
          controller: getOrCreateController(questionIndex),
          onCustomTextChanged: onCustomTextChanged,
          onSubmitCustomText: onSubmitCustomText,
          onShowCustomInput: onShowCustomInput,
        ),
        if (isMulti && !isMultiQuestion)
          _ConfirmButton(
            questionIndex: questionIndex,
            selected: multiAnswers[questionIndex] ?? {},
            statusColor: statusColor,
            onConfirmMultiSelect: onConfirmMultiSelect,
          ),
      ],
    );
  }
}

/// PageView for multi-question flows with step indicators and summary page.
class _QuestionPageView extends StatelessWidget {
  final List<dynamic> questions;
  final int currentPage;
  final PageController pageController;
  final Color statusColor;
  final bool isMultiQuestion;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final Set<int> customInputs;
  final TextEditingController Function(int) getOrCreateController;
  final void Function(int questionIndex, String label) onAnswerSingle;
  final void Function(int questionIndex, String label) onToggleMultiSelectLabel;
  final void Function(int questionIndex) onConfirmMultiSelect;
  final void Function(int questionIndex) onSubmitCustomText;
  final void Function(int questionIndex, String text) onCustomTextChanged;
  final void Function(int questionIndex) onShowCustomInput;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onResetAll;
  final VoidCallback onSubmitAll;

  const _QuestionPageView({
    required this.questions,
    required this.currentPage,
    required this.pageController,
    required this.statusColor,
    required this.isMultiQuestion,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customInputs,
    required this.getOrCreateController,
    required this.onAnswerSingle,
    required this.onToggleMultiSelectLabel,
    required this.onConfirmMultiSelect,
    required this.onSubmitCustomText,
    required this.onCustomTextChanged,
    required this.onShowCustomInput,
    required this.onPageChanged,
    required this.onGoToPage,
    required this.onResetAll,
    required this.onSubmitAll,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = isMultiQuestion
        ? questions.length + 1
        : questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimal step indicators: 1 of 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                currentPage < questions.length
                    ? ((questions[currentPage]
                                  as Map<String, dynamic>)['header']
                              as String? ??
                          'Q${currentPage + 1}')
                    : 'Review Summary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${currentPage + 1} of $totalPages',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar instead of bulky chips
        LinearProgressIndicator(
          value: (currentPage + 1) / totalPages,
          backgroundColor: statusColor.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          minHeight: 2,
        ),
        const SizedBox(height: 10),
        // Dynamic height container based on content, avoiding rigid PageView size
        ExpandablePageView.builder(
          controller: pageController,
          itemCount: totalPages,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            if (index == questions.length) {
              return _SummaryPage(
                questions: questions,
                statusColor: statusColor,
                singleAnswers: singleAnswers,
                multiAnswers: multiAnswers,
                customControllers: getOrCreateController,
                onGoToPage: onGoToPage,
                onResetAll: onResetAll,
                onSubmitAll: onSubmitAll,
              );
            }
            return _QuestionLayout(
              question: questions[index] as Map<String, dynamic>,
              questionIndex: index,
              statusColor: statusColor,
              isMultiQuestion: isMultiQuestion,
              singleAnswers: singleAnswers,
              multiAnswers: multiAnswers,
              customInputs: customInputs,
              getOrCreateController: getOrCreateController,
              onAnswerSingle: onAnswerSingle,
              onToggleMultiSelectLabel: onToggleMultiSelectLabel,
              onConfirmMultiSelect: onConfirmMultiSelect,
              onSubmitCustomText: onSubmitCustomText,
              onCustomTextChanged: onCustomTextChanged,
              onShowCustomInput: onShowCustomInput,
            );
          },
        ),
      ],
    );
  }
}

/// Summary page showing all answers with Submit/Cancel buttons.
class _SummaryPage extends StatelessWidget {
  final List<dynamic> questions;
  final Color statusColor;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final TextEditingController Function(int) customControllers;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onResetAll;
  final VoidCallback onSubmitAll;

  const _SummaryPage({
    required this.questions,
    required this.statusColor,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customControllers,
    required this.onGoToPage,
    required this.onResetAll,
    required this.onSubmitAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Review your answers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < questions.length; i++) ...[
            _SummaryRow(
              index: i,
              question: questions[i] as Map<String, dynamic>,
              statusColor: statusColor,
              singleAnswers: singleAnswers,
              multiAnswers: multiAnswers,
              customControllers: customControllers,
              onGoToPage: onGoToPage,
            ),
            if (i < questions.length - 1) const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: onResetAll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      side: BorderSide(color: cs.outlineVariant),
                      foregroundColor: cs.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: onSubmitAll,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: statusColor,
                      foregroundColor: statusColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.send, size: 14),
                      ],
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

/// A single row in the summary page showing the answer for one question.
class _SummaryRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> question;
  final Color statusColor;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final TextEditingController Function(int) customControllers;
  final ValueChanged<int> onGoToPage;

  const _SummaryRow({
    required this.index,
    required this.question,
    required this.statusColor,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customControllers,
    required this.onGoToPage,
  });

  @override
  Widget build(BuildContext context) {
    final header = question['header'] as String? ?? 'Q${index + 1}';
    final isMulti = question['multiSelect'] as bool? ?? false;

    // Compute combined answer for summary
    String? answer;
    if (isMulti) {
      final selected = multiAnswers[index] ?? {};
      final parts = [...selected];
      final customText = customControllers(index).text.trim();
      if (customText.isNotEmpty) parts.add(customText);
      answer = parts.isNotEmpty ? parts.join(', ') : null;
    } else {
      answer = singleAnswers[index];
    }

    final hasAnswer = answer != null && answer.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onGoToPage(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: cs.surfaceContainerLowest,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasAnswer ? Icons.check_circle : Icons.error_outline,
              size: 14,
              color: hasAnswer ? statusColor : cs.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasAnswer ? answer : '(No answer selected)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: hasAnswer ? cs.onSurface : cs.error,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              size: 14,
              color: statusColor.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool animate;
  final bool inPlanMode;
  const _StatusDot({
    required this.color,
    required this.animate,
    this.inPlanMode = false,
  });

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.animate) _pulseController.repeat(reverse: true);
    if (widget.inPlanMode) _orbitController.repeat();
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.animate && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
    if (widget.inPlanMode && !_orbitController.isAnimating) {
      _orbitController.repeat();
    } else if (!widget.inPlanMode && _orbitController.isAnimating) {
      _orbitController.stop();
      _orbitController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _orbitController]),
      builder: (context, child) {
        return CustomPaint(
          size: const Size(14, 14),
          painter: _StatusDotPainter(
            color: widget.color,
            pulseValue: _pulseAnimation.value,
            animate: widget.animate,
            inPlanMode: widget.inPlanMode,
            orbitProgress: _orbitController.value,
            planColor: appColors.statusPlan,
            planGlowColor: appColors.statusPlanGlow,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _StatusDotPainter extends CustomPainter {
  final Color color;
  final double pulseValue;
  final bool animate;
  final bool inPlanMode;
  final double orbitProgress;
  final Color planColor;
  final Color planGlowColor;
  final bool isDark;

  _StatusDotPainter({
    required this.color,
    required this.pulseValue,
    required this.animate,
    required this.inPlanMode,
    required this.orbitProgress,
    required this.planColor,
    required this.planGlowColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const dotRadius = 5.0;

    // Glow behind the dot
    if (animate) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: pulseValue * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, dotRadius + 1.5, glowPaint);
    }

    // Main dot
    final dotPaint = Paint()..color = color.withValues(alpha: pulseValue);
    canvas.drawCircle(center, dotRadius, dotPaint);

    // Plan mode: orbiting light around the dot
    if (inPlanMode) {
      final orbitRadius = dotRadius + 2.5;
      final path = Path()
        ..addOval(Rect.fromCircle(center: center, radius: orbitRadius));
      final metric = path.computeMetrics().first;
      final lightPos =
          metric.getTangentForOffset(metric.length * orbitProgress)!.position;

      // Clip to a thin ring around the dot
      const ringHalf = 2.0;
      final clipPath = Path()
        ..addOval(
          Rect.fromCircle(center: center, radius: orbitRadius + ringHalf),
        )
        ..addOval(
          Rect.fromCircle(center: center, radius: dotRadius - 0.5),
        )
        ..fillType = PathFillType.evenOdd;

      canvas.save();
      canvas.clipPath(clipPath);

      // Glow
      final glowRect = Rect.fromCircle(center: lightPos, radius: 8);
      final radial = RadialGradient(
        colors: [
          planGlowColor.withValues(alpha: isDark ? 0.9 : 0.7),
          planColor.withValues(alpha: isDark ? 0.3 : 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      );
      final glowPaint = Paint()
        ..shader = radial.createShader(glowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawRect(glowRect, glowPaint);

      // Bright core
      final coreRect = Rect.fromCircle(center: lightPos, radius: 4);
      final coreGradient = RadialGradient(
        colors: [
          planGlowColor.withValues(alpha: isDark ? 1.0 : 0.85),
          planColor.withValues(alpha: isDark ? 0.4 : 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      canvas.drawRect(
        coreRect,
        Paint()..shader = coreGradient.createShader(coreRect),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StatusDotPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.orbitProgress != orbitProgress ||
      oldDelegate.color != color ||
      oldDelegate.inPlanMode != inPlanMode;
}

class RecentSessionCard extends StatelessWidget {
  final RecentSession session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool hideProjectBadge;
  final SessionDisplayMode displayMode;
  final String? draftText;
  final bool isProcessing;

  const RecentSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onLongPress,
    this.hideProjectBadge = false,
    this.displayMode = SessionDisplayMode.first,
    this.draftText,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final provider = providerFromRaw(session.provider);
    final providerStyle = providerStyleFor(context, provider);
    final codexSummary = session.provider == 'codex'
        ? _buildCodexSettingsSummary(
            model: session.codexModel,
            sandboxMode: session.codexSandboxMode,
            approvalPolicy: session.codexApprovalPolicy,
          )
        : null;
    final dateStr = _formatDateRange(session.created, session.modified);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isProcessing ? null : onTap,
        onLongPress: isProcessing ? null : onLongPress,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.label_outline,
                                      size: 14,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
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
                                  ],
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
                                    session.projectName,
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
                    Text(
                      _displayTextForMode(session, displayMode),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  if (codexSummary != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      codexSummary,
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Meta Row
                  Row(
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
                        const SizedBox(width: 16),
                      ],
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

String _buildCodexSettingsSummary({
  String? model,
  String? sandboxMode,
  String? approvalPolicy,
}) {
  final modelText = (model == null || model.isEmpty) ? 'model:auto' : model;
  final sandboxText = (sandboxMode == null || sandboxMode.isEmpty)
      ? 'sandbox:default'
      : 'sandbox:$sandboxMode';
  final approvalText = (approvalPolicy == null || approvalPolicy.isEmpty)
      ? 'approval:default'
      : 'approval:$approvalPolicy';
  return '$modelText  $sandboxText  $approvalText';
}
