import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../theme/app_theme.dart';
import '../theme/provider_style.dart';
import '../utils/command_parser.dart';

/// Card for a currently running session
class RunningSessionCard extends StatelessWidget {
  final SessionInfo session;
  final VoidCallback onTap;
  final VoidCallback onStop;
  final ValueChanged<String>? onApprove;
  final ValueChanged<String>? onApproveAlways;
  final ValueChanged<String>? onReject;
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
  Widget build(BuildContext context) {
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
    final providerLabel = provider.label;
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
        onTap: onTap,
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
                  SizedBox(
                    width: 28,
                    height: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.stop_circle_outlined, size: 16),
                      onPressed: onStop,
                      tooltip: 'Stop session',
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                      onAnswer?.call(permission.toolUseId, result),
                  onTap: onTap,
                ),
                'ExitPlanMode' => _PlanApprovalArea(
                  statusColor: statusColor,
                  onApprove: () => onApprove?.call(permission.toolUseId),
                  onTap: onTap,
                ),
                _ => _ToolApprovalArea(
                  permission: permission,
                  statusColor: statusColor,
                  onApprove: () => onApprove?.call(permission.toolUseId),
                  onApproveAlways: () =>
                      onApproveAlways?.call(permission.toolUseId),
                  onReject: () => onReject?.call(permission.toolUseId),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              projectName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ProviderBadge(
                        label: providerLabel,
                        style: providerStyle,
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
  final VoidCallback onApprove;
  final VoidCallback onTap;

  const _PlanApprovalArea({
    required this.statusColor,
    required this.onApprove,
    required this.onTap,
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
            'Plan is ready for review',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Open'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton.tonalIcon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Accept Plan'),
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
/// - Single question, single select → ActionChip buttons
/// - Single question, multi select → FilterChip toggles + Confirm
/// - Multiple questions → PageView with one question per page
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
  final Map<int, String> _singleAnswers = {};
  final Map<int, Set<String>> _multiAnswers = {};
  int _currentPage = 0;

  List<dynamic> get _questions =>
      widget.permission.input['questions'] as List<dynamic>? ?? [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _answerSingle(int questionIndex, String label) {
    _singleAnswers[questionIndex] = label;
    if (_questions.length == 1) {
      // Single question → send immediately
      widget.onAnswer(label);
    } else {
      // Multi-question → advance to next page or submit
      _advanceOrSubmit();
    }
  }

  void _confirmMultiSelect(int questionIndex) {
    final selected = _multiAnswers[questionIndex];
    if (selected == null || selected.isEmpty) return;
    if (_questions.length == 1) {
      widget.onAnswer(selected.join(', '));
    } else {
      _singleAnswers[questionIndex] = selected.join(', ');
      _advanceOrSubmit();
    }
  }

  void _advanceOrSubmit() {
    if (_currentPage < _questions.length - 1) {
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // All answered → submit combined result
      final parts = <String>[];
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i] as Map<String, dynamic>;
        final header = q['header'] as String? ?? 'Q${i + 1}';
        final answer = _singleAnswers[i] ?? '(skipped)';
        parts.add('$header: $answer');
      }
      widget.onAnswer(parts.join('\n'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    if (questions.isEmpty) return const SizedBox.shrink();

    final firstQ = questions[0] as Map<String, dynamic>;
    final options = firstQ['options'] as List<dynamic>? ?? [];
    final multiSelect = firstQ['multiSelect'] as bool? ?? false;
    final isSingleSimple =
        questions.length == 1 && !multiSelect && options.isNotEmpty;
    final isSingleMultiSelect =
        questions.length == 1 && multiSelect && options.isNotEmpty;
    final isMultiQuestion = questions.length > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: widget.statusColor.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSingleSimple) ...[
            _buildQuestionText(firstQ),
            const SizedBox(height: 6),
            _buildSingleSelectChips(0, options),
          ] else if (isSingleMultiSelect) ...[
            _buildQuestionText(firstQ),
            const SizedBox(height: 6),
            _buildMultiSelectChips(0, options),
          ] else if (isMultiQuestion) ...[
            _buildPageView(questions),
          ] else ...[
            _buildQuestionText(firstQ),
            const SizedBox(height: 6),
            _buildOpenButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionText(Map<String, dynamic> question) {
    final text = question['question'] as String? ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSingleSelectChips(int questionIndex, List<dynamic> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opt in options)
          if (opt is Map<String, dynamic>)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Builder(
                builder: (context) {
                  final label = opt['label'] as String? ?? '';
                  return OutlinedButton(
                    onPressed: () => _answerSingle(questionIndex, label),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                      backgroundColor: widget.statusColor.withValues(
                        alpha: 0.08,
                      ),
                      side: BorderSide(
                        color: widget.statusColor.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(label, style: const TextStyle(fontSize: 12)),
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
              padding: const EdgeInsets.only(bottom: 4),
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
                      });
                    },
                    icon: Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: isSelected
                          ? widget.statusColor
                          : widget.statusColor.withValues(alpha: 0.5),
                    ),
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
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
        const SizedBox(height: 2),
        SizedBox(
          width: double.infinity,
          height: 32,
          child: FilledButton.icon(
            onPressed: selected.isNotEmpty
                ? () => _confirmMultiSelect(questionIndex)
                : null,
            icon: const Icon(Icons.check, size: 14),
            label: Text('Confirm (${selected.length})'),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
              backgroundColor: widget.statusColor.withValues(alpha: 0.15),
              foregroundColor: widget.statusColor,
              disabledBackgroundColor: widget.statusColor.withValues(
                alpha: 0.05,
              ),
              disabledForegroundColor: widget.statusColor.withValues(
                alpha: 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageView(List<dynamic> questions) {
    // Calculate height based on max option count across questions
    var maxRows = 0;
    for (final q in questions) {
      final qMap = q as Map<String, dynamic>;
      final opts = qMap['options'] as List<dynamic>? ?? [];
      final isMulti = qMap['multiSelect'] as bool? ?? false;
      // multiSelect adds a Confirm button row
      final rows = opts.length + (isMulti ? 1 : 0);
      if (rows > maxRows) maxRows = rows;
    }
    // Each button ~48px (incl. padding/margin) + question text ~20px + gap 6px
    final pageHeight = (20.0 + 6 + (maxRows * 48)).clamp(100.0, 360.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: pageHeight,
          child: PageView.builder(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index] as Map<String, dynamic>;
              final opts = q['options'] as List<dynamic>? ?? [];
              final multi = q['multiSelect'] as bool? ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionText(q),
                    const SizedBox(height: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        child: multi
                            ? _buildMultiSelectChips(index, opts)
                            : _buildSingleSelectChips(index, opts),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < questions.length; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentPage
                      ? widget.statusColor
                      : widget.statusColor.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpenButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 28,
        child: OutlinedButton.icon(
          onPressed: widget.onTap,
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('Open'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(fontSize: 12),
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

/// Card for a recent (past) session from sessions-index.json
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
    final appColors = Theme.of(context).extension<AppColors>()!;
    final provider = providerFromRaw(session.provider);
    final providerLabel = provider.label;
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
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(
          children: [
            if (!hideProjectBadge) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  session.projectName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
            ] else
              const Spacer(),
            _ProviderBadge(label: providerLabel, style: providerStyle),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: TextStyle(fontSize: 11, color: appColors.subtleText),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (draftText != null && draftText!.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Icon(
                      Icons.edit_note,
                      size: 14,
                      color: appColors.subtleText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      draftText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: appColors.subtleText,
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
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (codexSummary != null) ...[
              const SizedBox(height: 4),
              Text(
                codexSummary,
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (session.gitBranch.isNotEmpty) ...[
                  Icon(Icons.fork_right, size: 13, color: appColors.subtleText),
                  const SizedBox(width: 2),
                  Text(
                    session.gitBranch,
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(
                  Icons.chat_bubble_outline,
                  size: 12,
                  color: appColors.subtleText,
                ),
                const SizedBox(width: 3),
                Text(
                  '${session.messageCount}',
                  style: TextStyle(fontSize: 11, color: appColors.subtleText),
                ),
              ],
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

class _ProviderBadge extends StatelessWidget {
  final String label;
  final ProviderStyle style;

  const _ProviderBadge({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
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
