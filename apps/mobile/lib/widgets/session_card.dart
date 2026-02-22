import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import '../utils/command_parser.dart';
import 'plan_detail_sheet.dart';

/// Card for a currently running session
class RunningSessionCard extends StatefulWidget {
  final SessionInfo session;
  final VoidCallback onTap;
  final VoidCallback onStop;
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
    final statusColor = switch (session.status) {
      'starting' => appColors.statusStarting,
      'running' => appColors.statusRunning,
      'waiting_approval' => appColors.statusApproval,
      _ => appColors.statusIdle,
    };

    final permission = session.pendingPermission;
    final hasPermission =
        session.status == 'waiting_approval' && permission != null;
    final isPlanApproval =
        hasPermission && permission.toolName == 'ExitPlanMode';
    if (isPlanApproval) {
      _syncPlanApprovalState(permission);
    } else {
      _syncPlanApprovalState(null);
    }
    final statusLabel = switch (session.status) {
      'starting' => 'Starting',
      'running' => 'Running',
      'waiting_approval' when hasPermission => switch (permission.toolName) {
        'ExitPlanMode' => 'Plan Ready',
        'AskUserQuestion' => 'Question',
        _ => 'Approval · ${permission.toolName}',
      },
      'waiting_approval' => 'Approval',
      _ => 'Idle',
    };

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: statusColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  _StatusDot(
                    color: statusColor,
                    animate: session.status != 'idle',
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: widget.onStop,
                    tooltip: 'Stop session',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
            // Approval area (shown when waiting for permission)
            if (hasPermission)
              switch (permission.toolName) {
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
                  onReject: () => widget.onReject?.call(permission.toolUseId),
                ),
              },
            // Content (same structure as RecentSessionCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: project badge + elapsed
                  Row(
                    children: [
                      Hero(
                        tag: 'project_name_${session.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: providerStyle.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: providerStyle.border),
                            ),
                            child: Text(
                              projectName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: providerStyle.foreground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
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
                  // Git branch + message count
                  if (session.gitBranch.isNotEmpty ||
                      session.messageCount > 0) ...[
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
                        if (session.messageCount > 0) ...[
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: appColors.subtleText,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${session.messageCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: appColors.subtleText,
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: canOpenPlan ? onOpenPlan : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.planApprovalSummary,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canOpenPlan)
                      Icon(Icons.open_in_full, size: 16, color: cs.primary),
                  ],
                ),
              ),
            ),
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
                child: FilledButton.tonal(
                  key: const ValueKey('approve_clear_context_button'),
                  onPressed: onApproveClearContext,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    l.acceptAndClear,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: FilledButton.tonalIcon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 14),
                  label: Text(l.acceptPlan),
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
  // Layout constants
  static const _buttonHeight = 44.0;

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
        _currentPage++;
      });
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
            _buildPageView(questions),
          ] else if (options.isNotEmpty) ...[
            _buildQuestionLayout(firstQ, 0),
          ] else ...[
            _buildQuestionText(firstQ),
            const SizedBox(height: 6),
            _buildOpenButton(),
          ],
        ],
      ),
    );
  }

  /// Common layout for a single question page.
  /// Used by both inline (single-question) and PageView (multi-question) modes
  /// to ensure consistent ordering: question → options → other answer → confirm.
  Widget _buildQuestionLayout(Map<String, dynamic> q, int questionIndex) {
    final opts = q['options'] as List<dynamic>? ?? [];
    final isMulti = q['multiSelect'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildQuestionText(q),
        const SizedBox(height: 6),
        if (isMulti && opts.isNotEmpty)
          _buildMultiSelectChips(questionIndex, opts)
        else if (opts.isNotEmpty)
          _buildSingleSelectChips(questionIndex, opts),
        _buildOtherAnswerSection(questionIndex),
        if (isMulti && !_isMultiQuestion) _buildConfirmButton(questionIndex),
      ],
    );
  }

  Widget _buildQuestionText(Map<String, dynamic> question) {
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

  Widget _buildSingleSelectChips(int questionIndex, List<dynamic> options) {
    final selectedLabel = _singleAnswers[questionIndex];
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
                    onPressed: () => _answerSingle(questionIndex, label),
                    icon: isChosen
                        ? Icon(
                            Icons.check_circle,
                            size: 16,
                            color: widget.statusColor,
                          )
                        : const SizedBox.shrink(),
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, _buttonHeight),
                      backgroundColor: widget.statusColor.withValues(
                        alpha: isChosen ? 0.20 : 0.08,
                      ),
                      side: BorderSide(
                        color: widget.statusColor.withValues(
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

  Widget _buildMultiSelectChips(int questionIndex, List<dynamic> options) {
    final selected = _multiAnswers.putIfAbsent(questionIndex, () => {});
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
                    onPressed: () {
                      setState(() {
                        if (isSelected) {
                          selected.remove(label);
                        } else {
                          selected.add(label);
                        }

                        final parts = [...selected];
                        final customText =
                            _customControllers[questionIndex]?.text.trim() ??
                            '';
                        if (customText.isNotEmpty) parts.add(customText);

                        _singleAnswers[questionIndex] = parts.join(', ');

                        // We do NOT clear the custom controller for multi-select
                      });
                    },
                    icon: Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: isSelected
                          ? widget.statusColor
                          : widget.statusColor.withValues(alpha: 0.5),
                    ),
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, _buttonHeight),
                      alignment: Alignment.centerLeft,
                      backgroundColor: isSelected
                          ? widget.statusColor.withValues(alpha: 0.15)
                          : widget.statusColor.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: widget.statusColor.withValues(
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

  /// Confirm button for multi-select (used in single-question mode).
  Widget _buildConfirmButton(int questionIndex) {
    final selected = _multiAnswers[questionIndex] ?? {};
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: double.infinity,
        height: _buttonHeight,
        child: FilledButton.icon(
          onPressed: selected.isNotEmpty
              ? () => _confirmMultiSelect(questionIndex)
              : null,
          icon: const Icon(Icons.check, size: 16),
          label: Text('Confirm (${selected.length})'),
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 13),
            backgroundColor: widget.statusColor.withValues(alpha: 0.15),
            foregroundColor: widget.statusColor,
            disabledBackgroundColor: widget.statusColor.withValues(alpha: 0.05),
            disabledForegroundColor: widget.statusColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  /// "Other answer..." toggle button + inline text field.
  Widget _buildOtherAnswerSection(int questionIndex) {
    if (_customInputs.contains(questionIndex)) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: _buttonHeight,
                child: TextField(
                  controller: _customControllers.putIfAbsent(
                    questionIndex,
                    () => TextEditingController(),
                  ),
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Type your answer...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: widget.statusColor.withValues(alpha: 0.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: widget.statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: widget.statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.statusColor),
                    ),
                    isDense: true,
                  ),
                  onChanged: (text) {
                    setState(() {
                      final q =
                          _questions[questionIndex] as Map<String, dynamic>;
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
                  },
                  onSubmitted: (_) => _submitCustomText(questionIndex),
                ),
              ),
            ),
            if (!_isMultiQuestion) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: _buttonHeight,
                child: FilledButton(
                  onPressed: () => _submitCustomText(questionIndex),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: widget.statusColor.withValues(alpha: 0.15),
                    foregroundColor: widget.statusColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Send', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: TextButton(
          onPressed: () => setState(() {
            _customInputs.add(questionIndex);
          }),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 36),
            textStyle: const TextStyle(fontSize: 12),
            foregroundColor: widget.statusColor.withValues(alpha: 0.7),
          ),
          child: const Text('Other answer...'),
        ),
      ),
    );
  }

  Widget _buildPageView(List<dynamic> questions) {
    final totalPages = _isMultiQuestion
        ? questions.length + 1
        : questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Ensure it shrinks to content
      children: [
        // Minimal step indicators: 1 of 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _currentPage < questions.length
                    ? ((questions[_currentPage]
                                  as Map<String, dynamic>)['header']
                              as String? ??
                          'Q${_currentPage + 1}')
                    : 'Review Summary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.statusColor.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${_currentPage + 1} of $totalPages',
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
          value: (_currentPage + 1) / totalPages,
          backgroundColor: widget.statusColor.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(widget.statusColor),
          minHeight: 2,
        ),
        const SizedBox(height: 10),
        // Dynamic height container based on content, avoiding rigid PageView size
        ExpandablePageView.builder(
          controller: _pageController,
          itemCount: totalPages,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            if (index == questions.length) {
              return _buildSummaryPage(questions);
            }
            return _buildQuestionPage(
              questions[index] as Map<String, dynamic>,
              index,
              questions.length,
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuestionPage(
    Map<String, dynamic> q,
    int index,
    int totalQuestions,
  ) {
    return _buildQuestionLayout(q, index);
  }

  /// Summary page showing all answers with Submit/Cancel buttons.
  Widget _buildSummaryPage(List<dynamic> questions) {
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
            _buildSummaryRow(i, questions[i] as Map<String, dynamic>),
            if (i < questions.length - 1) const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: _resetAll,
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
                    onPressed: _submitAll,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: widget.statusColor,
                      foregroundColor:
                          widget.statusColor.computeLuminance() > 0.5
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

  Widget _buildSummaryRow(int index, Map<String, dynamic> question) {
    final header = question['header'] as String? ?? 'Q${index + 1}';
    final isMulti = question['multiSelect'] as bool? ?? false;

    // Compute combined answer for summary
    String? answer;
    if (isMulti) {
      final selected = _multiAnswers[index] ?? {};
      final parts = [...selected];
      final customText = _customControllers[index]?.text.trim() ?? '';
      if (customText.isNotEmpty) parts.add(customText);
      answer = parts.isNotEmpty ? parts.join(', ') : null;
    } else {
      answer = _singleAnswers[index];
    }

    final hasAnswer = answer != null && answer.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _currentPage = index),
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
              color: hasAnswer ? widget.statusColor : cs.error,
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
              color: widget.statusColor.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: _buttonHeight,
        child: OutlinedButton.icon(
          onPressed: widget.onTap,
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

class _StatusDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _StatusDot({required this.color, required this.animate});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class RecentSessionCard extends StatelessWidget {
  final RecentSession session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool hideProjectBadge;
  final SessionDisplayMode displayMode;
  final String? draftText;

  const RecentSessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onLongPress,
    this.hideProjectBadge = false,
    this.displayMode = SessionDisplayMode.first,
    this.draftText,
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
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!hideProjectBadge) ...[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: providerStyle.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: providerStyle.border),
                          ),
                          child: Text(
                            session.projectName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: providerStyle.foreground,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
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
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
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
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 13,
                    color: appColors.subtleText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.messageCount}',
                    style: TextStyle(fontSize: 12, color: appColors.subtleText),
                  ),
                ],
              ),
            ],
          ),
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
