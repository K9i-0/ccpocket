import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import '../utils/command_parser.dart';
import 'adaptive_context_menu.dart';
import 'codex_environment_summary.dart';
import 'plan_detail_sheet.dart';
import 'pin_toggle_button.dart';
import 'session_visual_status.dart';
import 'session_card/status_dot.dart';
import 'session_card/header_widgets.dart';
import 'session_card/approval_areas.dart';
import 'session_card/ask_user_area.dart';
import 'session_card/settings_summary.dart';
export 'session_card/recent_session_card.dart';

/// Card for a currently running session
class RunningSessionCard extends StatefulWidget {
  final SessionInfo session;
  final String? projectNameOverride;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset?>? onShowActions;
  final void Function(String toolUseId, {bool clearContext})? onApprove;
  final ValueChanged<String>? onApproveAlways;
  final void Function(String toolUseId, {String? message})? onReject;
  final void Function(String toolUseId, String result)? onAnswer;
  final VoidCallback? onStop;
  final bool isUnseen;
  final bool isSelected;
  final bool isPinned;
  final VoidCallback? onTogglePinned;

  const RunningSessionCard({
    super.key,
    required this.session,
    this.projectNameOverride,
    required this.onTap,
    this.onLongPress,
    this.onShowActions,
    this.onApprove,
    this.onApproveAlways,
    this.onReject,
    this.onAnswer,
    this.onStop,
    this.isUnseen = false,
    this.isSelected = false,
    this.isPinned = false,
    this.onTogglePinned,
  });

  @override
  State<RunningSessionCard> createState() => _RunningSessionCardState();
}

class _RunningSessionCardState extends State<RunningSessionCard> {
  late final TextEditingController _planFeedbackController;
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
    await showPlanDetailSheet(context, originalText);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isCodexSession = session.provider == Provider.codex.value;
    final visualStatus = sessionVisualStatusFor(
      rawStatus: session.status,
      permissionMode: session.effectivePermissionMode,
      planMode: session.resolvedPlanMode,
      pendingPermission: session.pendingPermission,
    );
    final statusDetail = visualStatus.detail;
    // The status follows the main turn only; work left running after it
    // (agents, shells, monitors, Codex terminals) gets its own counts, drawn
    // in the running color so a Ready session still shows live work.
    final subagentBadgeCount = isCodexSession
        ? 0
        : session.backgroundAgentCount;
    final backgroundBadgeCount = isCodexSession
        ? session.backgroundTaskCount
        : session.backgroundTaskCount - session.backgroundAgentCount;
    final backgroundWorkColor = appColors.statusRunning;
    final isReadyUnseen =
        visualStatus.primary == SessionPrimaryStatus.ready && widget.isUnseen;
    final statusColor = switch (visualStatus.primary) {
      SessionPrimaryStatus.working => appColors.statusRunning,
      SessionPrimaryStatus.needsYou => appColors.statusApproval,
      SessionPrimaryStatus.ready =>
        isReadyUnseen
            ? Theme.of(context).colorScheme.onSurface
            : appColors.statusIdle,
    };

    final permission = session.pendingPermission;
    final hasPermission = permission != null;
    final queuedInput = session.queuedInput;
    final isPlanApproval =
        hasPermission && permission.toolName == 'ExitPlanMode';
    final isToolSuggestion = hasPermission && permission.isToolSuggestion;
    final hasQuestionPrompt = hasPermission && permission.usesAskUserUi;
    if (isPlanApproval) {
      _syncPlanApprovalState(permission);
    } else {
      _syncPlanApprovalState(null);
    }
    final projectName = widget.projectNameOverride ?? session.projectName;
    final provider = providerFromRaw(session.provider);
    final providerStyle = providerStyleFor(context, provider);
    final elapsed = _formatElapsed(session.lastActivityAt);
    final agentLabel = formatSessionAgentLabel(
      session.agentNickname,
      session.agentRole,
    );
    final displayMessage = formatCommandText(
      session.lastMessage.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final card = Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isSelected
              ? statusColor.withValues(alpha: 0.95)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: widget.isSelected ? 2.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onShowActions == null ? widget.onLongPress : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clean flat status header separated by a subtle hairline divider
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    width: 0.5,
                  ),
                ),
              ),
              // The header actions own tap regions that reach the header's
              // edges, so the padding lives on the status side and inside the
              // regions instead of on the container.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 0, 6),
                        child: Row(
                          children: [
                            SessionStatusDot(
                              color: statusColor,
                              animate: visualStatus.animate,
                              glow: isReadyUnseen,
                              inPlanMode:
                                  visualStatus.showPlanBadge &&
                                  visualStatus.animate,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              visualStatus.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isReadyUnseen
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                            if (statusDetail != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  statusDetail,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor.withValues(alpha: 0.82),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (subagentBadgeCount > 0) ...[
                              const SizedBox(width: 6),
                              SessionCountBadge(
                                key: const ValueKey(
                                  'session_card_subagent_badge',
                                ),
                                icon: Icons.hub_outlined,
                                count: subagentBadgeCount,
                                label: AppLocalizations.of(context)
                                    .sessionCardBackgroundAgents(
                                      subagentBadgeCount,
                                    ),
                                color: backgroundWorkColor,
                              ),
                            ],
                            if (backgroundBadgeCount > 0) ...[
                              const SizedBox(width: 4),
                              SessionCountBadge(
                                key: const ValueKey(
                                  'session_card_background_badge',
                                ),
                                icon: Icons.layers_outlined,
                                count: backgroundBadgeCount,
                                label: AppLocalizations.of(context)
                                    .sessionCardBackgroundTasks(
                                      backgroundBadgeCount,
                                    ),
                                color: backgroundWorkColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (queuedInput != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Center(
                          child: SessionQueuedInputBadge(item: queuedInput),
                        ),
                      ),
                    SessionCardHeaderTapRegion(
                      key: ValueKey('running_session_pin_${session.id}_hit'),
                      onTap: widget.onTogglePinned,
                      // Keep the queue badge's 4px gap; otherwise reach
                      // into the empty space left of the pin.
                      padding: EdgeInsets.fromLTRB(
                        queuedInput != null ? 4 : 10,
                        6,
                        widget.onStop != null ? 3 : 12,
                        6,
                      ),
                      child: PinToggleButton(
                        key: ValueKey(
                          'running_session_pin_${session.id}_button',
                        ),
                        isPinned: widget.isPinned,
                        onPressed: widget.onTogglePinned,
                        pinTooltip: AppLocalizations.of(context).pin,
                        unpinTooltip: AppLocalizations.of(context).unpin,
                      ),
                    ),
                    if (widget.onStop != null)
                      SessionCardHeaderTapRegion(
                        key: const ValueKey('running_session_stop_hit'),
                        onTap: widget.onStop,
                        padding: const EdgeInsets.fromLTRB(3, 6, 12, 6),
                        child: RunningSessionStopButton(
                          onPressed: widget.onStop!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Approval area (shown when waiting for permission)
            if (hasPermission)
              isCodexSession
                  ? (isPlanApproval
                        ? SessionCardCodexPlanApprovalArea(
                            statusColor: statusColor,
                            canOpenPlan: _extractPlanText(permission) != null,
                            onOpenPlan: () => _openPlanSheet(permission),
                            onApprove: () => widget.onApprove?.call(
                              permission.toolUseId,
                              clearContext: false,
                            ),
                            onReject: () =>
                                widget.onReject?.call(permission.toolUseId),
                          )
                        : isToolSuggestion
                        ? SessionCardToolSuggestionArea(
                            permission: permission,
                            statusColor: statusColor,
                            onTap: widget.onTap,
                          )
                        : hasQuestionPrompt
                        ? SessionCardAskUserArea(
                            permission: permission,
                            statusColor: statusColor,
                            preferQuestionIds: isCodexSession,
                            onAnswer: (result) => widget.onAnswer?.call(
                              permission.toolUseId,
                              result,
                            ),
                            onTap: widget.onTap,
                          )
                        : SessionCardToolApprovalArea(
                            permission: permission,
                            statusColor: statusColor,
                            isCodex: isCodexSession,
                            onApprove: () => widget.onApprove?.call(
                              permission.toolUseId,
                              clearContext: false,
                            ),
                            onApproveAlways: widget.onApproveAlways == null
                                ? null
                                : () => widget.onApproveAlways!(
                                    permission.toolUseId,
                                  ),
                            onReject: () =>
                                widget.onReject?.call(permission.toolUseId),
                          ))
                  : switch (permission.toolName) {
                      'AskUserQuestion' || 'McpElicitation'
                          when hasQuestionPrompt =>
                        SessionCardAskUserArea(
                          permission: permission,
                          statusColor: statusColor,
                          preferQuestionIds: isCodexSession,
                          onAnswer: (result) => widget.onAnswer?.call(
                            permission.toolUseId,
                            result,
                          ),
                          onTap: widget.onTap,
                        ),
                      'ExitPlanMode' => SessionCardPlanApprovalArea(
                        statusColor: statusColor,
                        planFeedbackController: _planFeedbackController,
                        canOpenPlan: _extractPlanText(permission) != null,
                        onOpenPlan: () => _openPlanSheet(permission),
                        onApprove: () => widget.onApprove?.call(
                          permission.toolUseId,
                          clearContext: false,
                        ),
                        onApproveClearContext: () => widget.onApprove?.call(
                          permission.toolUseId,
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
                      _ => SessionCardToolApprovalArea(
                        permission: permission,
                        statusColor: statusColor,
                        isCodex: isCodexSession,
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
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
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.45),
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
                    ],
                  ),
                  if (agentLabel != null) ...[
                    const SizedBox(height: 6),
                    SessionAgentLabel(label: agentLabel),
                  ],
                  // Last message
                  if (displayMessage.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      displayMessage,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.38,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (isCodexSession)
                    CodexEnvironmentSummary(
                      leadingLabel:
                          (session.status == 'running' ||
                                  session.status == 'starting') &&
                              session.resolvedPlanMode
                          ? 'Planning'
                          : null,
                      model: session.codexModel,
                      reasoningEffort: session.codexModelReasoningEffort,
                      serviceTier: session.codexServiceTier,
                      approvalPolicy: session.codexApprovalPolicy,
                      approvalsReviewer: session.codexApprovalsReviewer,
                      sandboxMode: session.codexSandboxMode,
                      showDefaultReasoning: true,
                      compact: true,
                    )
                  else
                    Text(
                      buildSessionSettingsSummary(
                        isCodex: false,
                        // Antigravity reports a display name for its model.
                        model:
                            session.antigravitySettings?.modelSummary ??
                            session.model,
                        contextPercent:
                            session.antigravitySettings?.contextUsage?.percent,
                        effort: session.claudeEffort,
                        fastMode: session.claudeFastMode,
                        ultracode: session.claudeUltracode,
                        permissionMode: session.effectivePermissionMode,
                        executionMode: session.resolvedExecutionMode.value,
                        planMode: session.resolvedPlanMode,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: appColors.subtleText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // Meta Row: branch + worktree (left) + elapsed (right)
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
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
                            ],
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
                      ),
                      const SizedBox(width: 8),
                      Text(
                        elapsed,
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
          ],
        ),
      ),
    );

    final onShowActions = widget.onShowActions;
    if (onShowActions == null) return card;
    return AdaptiveContextMenuRegion(onOpen: onShowActions, child: card);
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
