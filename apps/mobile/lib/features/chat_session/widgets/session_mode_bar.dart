import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../state/chat_session_cubit.dart';

class SessionModeBar extends StatelessWidget {
  const SessionModeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chatCubit = context.watch<ChatSessionCubit>();
    final permissionMode = chatCubit.state.permissionMode;
    // sandboxMode is only available for Codex
    final sandboxMode = chatCubit.isCodex ? chatCubit.state.sandboxMode : null;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surface.withValues(alpha: 0.6)
                  : cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
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
    );
  }
}

void showPermissionModeMenu(BuildContext context, ChatSessionCubit chatCubit) {
  final currentMode = chatCubit.state.permissionMode;

  const modeDetails = <PermissionMode, ({IconData icon, String description})>{
    PermissionMode.defaultMode: (
      icon: Icons.tune,
      description: 'Standard permission prompts',
    ),
    PermissionMode.plan: (
      icon: Icons.assignment,
      description: 'Analyze & plan without executing',
    ),
    PermissionMode.acceptEdits: (
      icon: Icons.edit_note,
      description: 'Auto-approve file edits',
    ),
    PermissionMode.bypassPermissions: (
      icon: Icons.flash_on,
      description: 'Skip all permission prompts',
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
                      ? sheetCs.primary
                      : sheetCs.onSurfaceVariant,
                ),
                title: Text(mode.label),
                subtitle: Text(
                  modeDetails[mode]!.description,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: mode == currentMode
                    ? Icon(Icons.check, color: sheetCs.primary, size: 20)
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

    final (IconData icon, String label, Color fg) = switch (currentMode) {
      PermissionMode.defaultMode => (
        Icons.tune,
        'Default',
        cs.onSurfaceVariant,
      ),
      PermissionMode.plan => (Icons.assignment, 'Plan', cs.tertiary),
      PermissionMode.acceptEdits => (Icons.edit_note, 'Edits', cs.primary),
      PermissionMode.bypassPermissions => (Icons.flash_on, 'Bypass', cs.error),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(width: 2),
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
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(width: 2),
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
