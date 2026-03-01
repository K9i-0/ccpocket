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
    final appColors = Theme.of(context).extension<AppColors>()!;
    // sandboxMode is only available for Codex
    final sandboxMode = chatCubit.isCodex ? chatCubit.state.sandboxMode : null;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: _PulsingModeBarSurface(
        inPlanMode: inPlanMode,
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
                  color: inPlanMode
                      ? appColors.statusPlan.withValues(
                          alpha: isDark ? 0.9 : 0.8,
                        )
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.6)),
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
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.inPlanMode) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingModeBarSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inPlanMode && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
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

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final intensity = widget.inPlanMode ? _animation.value : 0.0;
        return DecoratedBox(
          key: const ValueKey('session_mode_bar_pulse'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: intensity > 0
                ? [
                    BoxShadow(
                      color: appColors.statusPlanGlow.withValues(
                        alpha: (isDark ? 0.24 : 0.18) * intensity,
                      ),
                      blurRadius: 8 + (12 * intensity),
                      spreadRadius: 0.4 + (0.8 * intensity),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
    );
  }
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
                  HapticFeedback.lightImpact();
                  chatCubit.setSandboxMode(mode);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
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
