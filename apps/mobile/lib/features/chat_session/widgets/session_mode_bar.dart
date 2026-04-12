import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../state/chat_session_state.dart';
import '../state/chat_session_cubit.dart';

class SessionModeBar extends StatelessWidget {
  final Future<void> Function()? onBeforeRestart;

  const SessionModeBar({super.key, this.onBeforeRestart});

  @override
  Widget build(BuildContext context) {
    final chatCubit = context.watch<ChatSessionCubit>();
    final executionMode = chatCubit.state.executionMode;
    final planMode = chatCubit.state.planMode;
    final inPlanMode = chatCubit.state.inPlanMode;
    final status = chatCubit.state.status;
    final isActive =
        status == ProcessStatus.running ||
        status == ProcessStatus.waitingApproval ||
        status == ProcessStatus.compacting;
    final sandboxMode = chatCubit.state.sandboxMode;
    final permissionMode = chatCubit.state.permissionMode;
    final isCodex = chatCubit.provider == Provider.codex;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surface.withValues(alpha: 0.6)
                : cs.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCodex) ...[
                  PlanModeChip(
                    enabled: planMode,
                    activeGlow: false,
                    onTap: () => togglePlanMode(
                      context,
                      chatCubit,
                      onBeforeRestart: onBeforeRestart,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  ExecutionModeChip(
                    currentMode: executionMode,
                    codexApprovalPolicy: chatCubit.state.codexApprovalPolicy,
                    provider: chatCubit.provider,
                    onTap: () => showExecutionModeMenu(
                      context,
                      chatCubit,
                      onBeforeRestart: onBeforeRestart,
                    ),
                  ),
                ] else ...[
                  PermissionModeChip(
                    currentMode: permissionMode,
                    onTap: () => showPermissionModeMenu(
                      context,
                      chatCubit,
                      onBeforeRestart: onBeforeRestart,
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                SandboxModeChip(
                  currentMode: sandboxMode,
                  provider: chatCubit.provider,
                  onTap: () => showSandboxModeMenu(
                    context,
                    chatCubit,
                    onBeforeRestart: onBeforeRestart,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: _PulsingModeBarSurface(
        inPlanMode: inPlanMode && isActive,
        child: bar,
      ),
    );
  }
}

class _PulsingModeBarSurface extends StatefulWidget {
  final bool inPlanMode;
  final Widget child;

  const _PulsingModeBarSurface({
    super.key,
    required this.inPlanMode,
    required this.child,
  });

  @override
  State<_PulsingModeBarSurface> createState() => _PulsingModeBarSurfaceState();
}

class _PulsingModeBarSurfaceState extends State<_PulsingModeBarSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    if (widget.inPlanMode) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_PulsingModeBarSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inPlanMode && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.inPlanMode && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!widget.inPlanMode) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return CustomPaint(
          painter: _RotatingBorderPainter(
            progress: _controller.value,
            color: appColors.statusPlan,
            glowColor: appColors.statusPlanGlow,
            borderRadius: 12,
            strokeWidth: 1.5,
            isDark: isDark,
          ),
          child: child,
        );
      },
    );
  }
}

class _RotatingBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color glowColor;
  final double borderRadius;
  final double strokeWidth;
  final bool isDark;

  _RotatingBorderPainter({
    required this.progress,
    required this.color,
    required this.glowColor,
    required this.borderRadius,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Subtle base border
    final basePaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, basePaint);

    // Build path from the rounded rect and find the dot position
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final totalLen = metric.length;
    final dotOffset = metric.getTangentForOffset(totalLen * progress)!.position;

    // Radial gradient centered on the dot for a clean glow
    final glowRadius = 18.0;
    final dotRect = Rect.fromCircle(center: dotOffset, radius: glowRadius);
    final radial = RadialGradient(
      colors: [
        glowColor.withValues(alpha: isDark ? 0.85 : 0.7),
        color.withValues(alpha: isDark ? 0.4 : 0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 1.0],
    );

    // Clip to border stroke region (outer rrect minus inner rrect)
    final halfW = (strokeWidth + 4) / 2;
    final outerRRect = RRect.fromRectAndRadius(
      rect.inflate(halfW),
      Radius.circular(borderRadius + halfW),
    );
    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(halfW),
      Radius.circular((borderRadius - halfW).clamp(0, double.infinity)),
    );
    final clipPath = Path()
      ..addRRect(outerRRect)
      ..addRRect(innerRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.save();
    canvas.clipPath(clipPath);

    // Outer glow
    final glowPaint = Paint()
      ..shader = radial.createShader(dotRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRect(dotRect, glowPaint);

    // Bright core
    final coreRect = Rect.fromCircle(center: dotOffset, radius: 8);
    final coreGradient = RadialGradient(
      colors: [
        glowColor.withValues(alpha: isDark ? 1.0 : 0.9),
        color.withValues(alpha: isDark ? 0.5 : 0.35),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    final corePaint = Paint()..shader = coreGradient.createShader(coreRect);
    canvas.drawRect(coreRect, corePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RotatingBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

void showExecutionModeMenu(
  BuildContext context,
  ChatSessionCubit chatCubit, {
  Future<void> Function()? onBeforeRestart,
}) {
  if (chatCubit.provider != Provider.codex) {
    showPermissionModeMenu(
      context,
      chatCubit,
      onBeforeRestart: onBeforeRestart,
    );
    return;
  }
  final currentPolicy = chatCubit.state.codexApprovalPolicy;
  final l = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final sheetCs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.approval,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sheetCs.onSurface,
                    ),
                  ),
                ),
              ),
              for (final policy in CodexApprovalPolicy.values)
                ListTile(
                  leading: Icon(
                    switch (policy) {
                      CodexApprovalPolicy.untrusted =>
                        Icons.verified_user_outlined,
                      CodexApprovalPolicy.onRequest => Icons.tune,
                      CodexApprovalPolicy.onFailure => Icons.auto_mode_outlined,
                      CodexApprovalPolicy.never => Icons.flash_on,
                    },
                    color: policy == currentPolicy
                        ? (policy == CodexApprovalPolicy.never
                              ? sheetCs.error
                              : sheetCs.primary)
                        : sheetCs.onSurfaceVariant,
                  ),
                  title: Text(switch (policy) {
                    CodexApprovalPolicy.untrusted => 'Untrusted',
                    CodexApprovalPolicy.onRequest => 'On Request',
                    CodexApprovalPolicy.onFailure => 'On Failure',
                    CodexApprovalPolicy.never => 'Never Ask',
                  }),
                  subtitle: Text(switch (policy) {
                    CodexApprovalPolicy.untrusted =>
                      l.codexApprovalUntrustedDescription,
                    CodexApprovalPolicy.onRequest =>
                      l.codexApprovalOnRequestDescription,
                    CodexApprovalPolicy.onFailure =>
                      l.codexApprovalOnFailureDescription,
                    CodexApprovalPolicy.never =>
                      l.codexApprovalNeverDescription,
                  }, style: const TextStyle(fontSize: 12)),
                  trailing: policy == currentPolicy
                      ? Icon(
                          Icons.check,
                          color: policy == CodexApprovalPolicy.never
                              ? sheetCs.error
                              : sheetCs.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (policy == currentPolicy) return;
                    HapticFeedback.lightImpact();
                    _confirmExecutionModeChange(
                      context,
                      chatCubit,
                      policy,
                      onBeforeRestart: onBeforeRestart,
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// Show confirmation dialog before changing permission mode for Codex sessions,
/// because the change requires a session restart (like sandbox mode).
Future<void> _confirmExecutionModeChange(
  BuildContext context,
  ChatSessionCubit chatCubit,
  CodexApprovalPolicy policy, {
  Future<void> Function()? onBeforeRestart,
}) async {
  final l = AppLocalizations.of(context);
  final policyLabel = switch (policy) {
    CodexApprovalPolicy.untrusted => 'Untrusted',
    CodexApprovalPolicy.onRequest => 'On Request',
    CodexApprovalPolicy.onFailure => 'On Failure',
    CodexApprovalPolicy.never => 'Never Ask',
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l.changeApprovalPolicyTitle),
        content: Text(l.changeApprovalPolicyBody(policyLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: policy == CodexApprovalPolicy.never
                ? FilledButton.styleFrom(backgroundColor: cs.error)
                : null,
            child: Text(l.restart),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await onBeforeRestart?.call();
    chatCubit.setCodexApprovalPolicy(policy);
  }
}

Future<void> togglePlanMode(
  BuildContext context,
  ChatSessionCubit chatCubit, {
  Future<void> Function()? onBeforeRestart,
}) async {
  final nextPlanMode = !chatCubit.state.planMode;
  final hasPendingApproval = chatCubit.state.approval is! ApprovalNone;
  final l = AppLocalizations.of(context);
  final canToggleInPlace =
      chatCubit.isCodex &&
      chatCubit.state.status == ProcessStatus.idle &&
      !hasPendingApproval;

  if (canToggleInPlace) {
    HapticFeedback.lightImpact();
    chatCubit.setSessionModes(planMode: nextPlanMode);
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          nextPlanMode ? l.enablePlanModeTitle : l.disablePlanModeTitle,
        ),
        content: Text(
          nextPlanMode ? l.enablePlanModeBody : l.disablePlanModeBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.restart),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await onBeforeRestart?.call();
    chatCubit.setSessionModes(planMode: nextPlanMode);
  }
}

void showSandboxModeMenu(
  BuildContext context,
  ChatSessionCubit chatCubit, {
  Future<void> Function()? onBeforeRestart,
}) {
  final currentMode = chatCubit.state.sandboxMode;
  final isClaude = chatCubit.provider != Provider.codex;
  final l = AppLocalizations.of(context);

  showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final sheetCs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sandbox',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sheetCs.onSurface,
                  ),
                ),
              ),
            ),
            for (final mode
                in isClaude ? SandboxMode.values.reversed : SandboxMode.values)
              ListTile(
                leading: Icon(
                  _sandboxMenuIcon(mode, isClaude),
                  color: mode == currentMode
                      ? sheetCs.primary
                      : _sandboxMenuIconColor(mode, isClaude, sheetCs),
                ),
                title: Text(
                  _sandboxMenuTitle(mode, isClaude),
                  style: TextStyle(
                    color:
                        !isClaude &&
                            mode == SandboxMode.off &&
                            currentMode != mode
                        ? sheetCs.error
                        : null,
                  ),
                ),
                subtitle: Text(
                  _sandboxMenuSubtitle(mode, isClaude, l),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: mode == currentMode
                    ? Icon(Icons.check, color: sheetCs.primary, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (mode == currentMode) return;
                  HapticFeedback.lightImpact();
                  _confirmSandboxModeChange(
                    context,
                    chatCubit,
                    mode,
                    isClaude: isClaude,
                    onBeforeRestart: onBeforeRestart,
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

IconData _sandboxMenuIcon(SandboxMode mode, bool isClaude) {
  if (mode == SandboxMode.on) return Icons.shield_outlined;
  return isClaude ? Icons.code : Icons.warning_amber;
}

Color _sandboxMenuIconColor(SandboxMode mode, bool isClaude, ColorScheme cs) {
  if (mode == SandboxMode.off && !isClaude) return cs.error;
  return cs.onSurfaceVariant;
}

String _sandboxMenuTitle(SandboxMode mode, bool isClaude) {
  if (isClaude) {
    return mode == SandboxMode.on ? 'Sandbox (Safe Mode)' : 'Standard';
  }
  return mode == SandboxMode.on ? 'Sandbox On' : 'Sandbox Off';
}

String _sandboxMenuSubtitle(
  SandboxMode mode,
  bool isClaude,
  AppLocalizations l,
) {
  if (isClaude) {
    return mode == SandboxMode.on
        ? l.sandboxRestrictedDescription
        : l.sandboxNativeDescription;
  }
  return mode == SandboxMode.on
      ? l.sandboxRestrictedDescription
      : l.sandboxNativeCautionDescription;
}

/// Show confirmation dialog before changing sandbox mode, because
/// the change requires a session restart (thread/resume with new sandbox).
Future<void> _confirmSandboxModeChange(
  BuildContext context,
  ChatSessionCubit chatCubit,
  SandboxMode mode, {
  bool isClaude = false,
  Future<void> Function()? onBeforeRestart,
}) async {
  final l = AppLocalizations.of(context);
  final modeLabel = isClaude
      ? (mode == SandboxMode.on ? 'Sandbox (Safe Mode)' : 'Standard')
      : mode.label;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      // For Codex, turning off sandbox is dangerous (red button).
      // For Claude, turning off is standard — no red.
      final useErrorStyle = mode == SandboxMode.off && !isClaude;
      return AlertDialog(
        title: Text(l.changeSandboxModeTitle),
        content: Text(l.changeSandboxModeBody(modeLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: useErrorStyle
                ? FilledButton.styleFrom(backgroundColor: cs.error)
                : null,
            child: Text(l.restart),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await onBeforeRestart?.call();
    chatCubit.setSandboxMode(mode);
  }
}

void showPermissionModeMenu(
  BuildContext context,
  ChatSessionCubit chatCubit, {
  Future<void> Function()? onBeforeRestart,
}) {
  final currentMode = chatCubit.state.permissionMode;
  final l = AppLocalizations.of(context);
  const purple = Color(0xFFBB86FC);

  final modeDetails =
      <PermissionMode, ({IconData icon, String description, Color color})>{
        PermissionMode.defaultMode: (
          icon: Icons.tune,
          description: l.permissionDefaultDescription,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        PermissionMode.acceptEdits: (
          icon: Icons.edit_note,
          description: l.permissionAcceptEditsDescription,
          color: purple,
        ),
        PermissionMode.plan: (
          icon: Icons.assignment_outlined,
          description: l.permissionPlanDescription,
          color: Theme.of(context).extension<AppColors>()!.statusPlan,
        ),
        PermissionMode.bypassPermissions: (
          icon: Icons.flash_on,
          description: l.permissionBypassDescription,
          color: Theme.of(context).colorScheme.error,
        ),
      };

  showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      final sheetCs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Permission',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sheetCs.onSurface,
                  ),
                ),
              ),
            ),
            for (final mode in PermissionMode.values)
              ListTile(
                leading: Icon(
                  modeDetails[mode]!.icon,
                  color: mode == currentMode
                      ? modeDetails[mode]!.color
                      : sheetCs.onSurfaceVariant,
                ),
                title: Text(mode.label),
                subtitle: Text(
                  modeDetails[mode]!.description,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: mode == currentMode
                    ? Icon(
                        Icons.check,
                        color: modeDetails[mode]!.color,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (mode == currentMode) return;
                  HapticFeedback.lightImpact();
                  _confirmPermissionModeChange(
                    context,
                    chatCubit,
                    mode,
                    onBeforeRestart: onBeforeRestart,
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmPermissionModeChange(
  BuildContext context,
  ChatSessionCubit chatCubit,
  PermissionMode mode, {
  Future<void> Function()? onBeforeRestart,
}) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l.changePermissionModeTitle),
        content: Text(l.changePermissionModeBody(mode.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: mode == PermissionMode.bypassPermissions
                ? FilledButton.styleFrom(backgroundColor: cs.error)
                : null,
            child: Text(l.restart),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    await onBeforeRestart?.call();
    chatCubit.setPermissionMode(mode);
  }
}

class PermissionModeChip extends StatelessWidget {
  final PermissionMode currentMode;
  final VoidCallback onTap;

  const PermissionModeChip({
    super.key,
    required this.currentMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const purple = Color(0xFFBB86FC);
    final plan = Theme.of(context).extension<AppColors>()!.statusPlan;

    final (IconData icon, String label, Color fg) = switch (currentMode) {
      PermissionMode.defaultMode => (
        Icons.tune,
        'Default',
        cs.onSurfaceVariant,
      ),
      PermissionMode.acceptEdits => (Icons.edit_note, 'Edits', purple),
      PermissionMode.plan => (Icons.assignment_outlined, 'Plan', plan),
      PermissionMode.bypassPermissions => (Icons.flash_on, 'Bypass', cs.error),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: fg.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExecutionModeChip extends StatelessWidget {
  final ExecutionMode currentMode;
  final CodexApprovalPolicy? codexApprovalPolicy;
  final Provider? provider;
  final VoidCallback onTap;

  const ExecutionModeChip({
    super.key,
    required this.currentMode,
    this.codexApprovalPolicy,
    this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Colors aligned with Claude Code CLI
    const purple = Color(0xFFBB86FC);

    final (
      IconData icon,
      String label,
      Color fg,
    ) = provider == Provider.codex && codexApprovalPolicy != null
        ? switch (codexApprovalPolicy!) {
            CodexApprovalPolicy.untrusted => (
              Icons.verified_user_outlined,
              'Untrusted',
              cs.primary,
            ),
            CodexApprovalPolicy.onRequest => (
              Icons.tune,
              'On Request',
              cs.onSurfaceVariant,
            ),
            CodexApprovalPolicy.onFailure => (
              Icons.auto_mode_outlined,
              'On Failure',
              purple,
            ),
            CodexApprovalPolicy.never => (Icons.flash_on, 'Never', cs.error),
          }
        : switch (currentMode) {
            ExecutionMode.defaultMode => (
              Icons.tune,
              'Default',
              cs.onSurfaceVariant,
            ),
            ExecutionMode.acceptEdits => (Icons.edit_note, 'Edits', purple),
            ExecutionMode.fullAccess => (Icons.flash_on, 'Full', cs.error),
          };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: fg.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanModeChip extends StatelessWidget {
  final bool enabled;
  final bool activeGlow;
  final VoidCallback onTap;

  const PlanModeChip({
    super.key,
    required this.enabled,
    this.activeGlow = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final fg = enabled ? appColors.statusPlan : cs.onSurfaceVariant;

    final chip = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 13, color: fg),
              const SizedBox(width: 3),
              Text(
                enabled ? 'Plan On' : 'Plan Off',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!activeGlow) return chip;

    return _PulsingModeBarSurface(
      key: const ValueKey('plan_mode_chip_glow'),
      inPlanMode: true,
      child: chip,
    );
  }
}

class SandboxModeChip extends StatelessWidget {
  final SandboxMode currentMode;
  final Provider? provider;
  final VoidCallback onTap;

  const SandboxModeChip({
    super.key,
    required this.currentMode,
    this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isClaude = provider != Provider.codex;

    final (IconData icon, String label, Color fg) = switch (currentMode) {
      SandboxMode.on => (Icons.shield_outlined, 'Sandbox', cs.tertiary),
      SandboxMode.off =>
        isClaude
            ? (Icons.code, 'Standard', cs.onSurfaceVariant)
            : (Icons.warning_amber, 'No SB', cs.error),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 14,
                color: fg.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
