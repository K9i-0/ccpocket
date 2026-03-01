import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../state/chat_session_cubit.dart';

class SessionModeBar extends StatelessWidget {
  const SessionModeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chatCubit = context.watch<ChatSessionCubit>();
    final permissionMode = chatCubit.state.permissionMode;
    final inPlanMode = chatCubit.state.inPlanMode;
    final status = chatCubit.state.status;
    final isActive =
        status == ProcessStatus.running ||
        status == ProcessStatus.waitingApproval ||
        status == ProcessStatus.compacting;
    // sandboxMode is only available for Codex
    final sandboxMode = chatCubit.isCodex ? chatCubit.state.sandboxMode : null;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: _PulsingModeBarSurface(
        inPlanMode: inPlanMode && isActive,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              key: const ValueKey('session_mode_bar_glow'),
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
                    PermissionModeChip(
                      currentMode: permissionMode,
                      onTap: () => showPermissionModeMenu(context, chatCubit),
                    ),
                    if (sandboxMode != null) ...[
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
                        onTap: () => showSandboxModeMenu(context, chatCubit),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingModeBarSurface extends StatefulWidget {
  final bool inPlanMode;
  final Widget child;

  const _PulsingModeBarSurface({required this.inPlanMode, required this.child});

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

void showPermissionModeMenu(BuildContext context, ChatSessionCubit chatCubit) {
  final currentMode = chatCubit.state.permissionMode;
  final appColors = Theme.of(context).extension<AppColors>()!;

  const purple = Color(0xFFBB86FC);

  final modeDetails =
      <PermissionMode, ({IconData icon, String description, Color color})>{
        PermissionMode.defaultMode: (
          icon: Icons.tune,
          description: 'Standard permission prompts',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        PermissionMode.acceptEdits: (
          icon: Icons.edit_note,
          description: 'Auto-approve file edits',
          color: purple,
        ),
        PermissionMode.plan: (
          icon: Icons.assignment,
          description: 'Analyze & plan without executing',
          color: appColors.statusPlan,
        ),
        PermissionMode.bypassPermissions: (
          icon: Icons.flash_on,
          description: 'Skip all permission prompts',
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
                  'Permission Mode',
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
                  HapticFeedback.lightImpact();
                  chatCubit.setPermissionMode(mode);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void showSandboxModeMenu(BuildContext context, ChatSessionCubit chatCubit) {
  if (!chatCubit.isCodex) return;
  final currentMode = chatCubit.state.sandboxMode;

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
                  'Sandbox Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sheetCs.onSurface,
                  ),
                ),
              ),
            ),
            for (final mode in SandboxMode.values)
              ListTile(
                leading: Icon(
                  mode == SandboxMode.on
                      ? Icons.shield_outlined
                      : Icons.warning_amber,
                  color: mode == currentMode
                      ? sheetCs.primary
                      : (mode == SandboxMode.off
                            ? sheetCs.error
                            : sheetCs.onSurfaceVariant),
                ),
                title: Text(
                  mode == SandboxMode.on ? 'Sandbox On' : 'Sandbox Off',
                  style: TextStyle(
                    color: mode == SandboxMode.off && currentMode != mode
                        ? sheetCs.error
                        : null,
                  ),
                ),
                subtitle: Text(
                  mode == SandboxMode.on
                      ? 'Run commands in restricted environment'
                      : 'Run commands natively (CAUTION)',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: mode == currentMode
                    ? Icon(Icons.check, color: sheetCs.primary, size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (mode == currentMode) return;
                  HapticFeedback.lightImpact();
                  _confirmSandboxModeChange(context, chatCubit, mode);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Show confirmation dialog before changing sandbox mode, because
/// the change requires a session restart (thread/resume with new sandbox).
Future<void> _confirmSandboxModeChange(
  BuildContext context,
  ChatSessionCubit chatCubit,
  SandboxMode mode,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final cs = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: const Text('Change Sandbox Mode'),
        content: Text(
          'Switching to ${mode.label} will restart the session. '
          'Your conversation will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: mode == SandboxMode.off
                ? FilledButton.styleFrom(backgroundColor: cs.error)
                : null,
            child: const Text('Restart'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    chatCubit.setSandboxMode(mode);
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
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Colors aligned with Claude Code CLI
    const purple = Color(0xFFBB86FC);

    final (IconData icon, String label, Color fg) = switch (currentMode) {
      PermissionMode.defaultMode => (
        Icons.tune,
        'Default',
        cs.onSurfaceVariant,
      ),
      PermissionMode.acceptEdits => (Icons.edit_note, 'Edits', purple),
      PermissionMode.plan => (Icons.assignment, 'Plan', appColors.statusPlan),
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

class SandboxModeChip extends StatelessWidget {
  final SandboxMode currentMode;
  final VoidCallback onTap;

  const SandboxModeChip({
    super.key,
    required this.currentMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (IconData icon, String label, Color fg) = switch (currentMode) {
      SandboxMode.on => (Icons.shield_outlined, 'Sandbox', cs.tertiary),
      SandboxMode.off => (Icons.warning_amber, 'No SB', cs.error),
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
