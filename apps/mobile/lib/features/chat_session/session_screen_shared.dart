import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../constants/feature_flags.dart';
import '../../hooks/use_scroll_tracking.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../router/app_router.dart';
import '../../services/bridge_service.dart';
import '../../services/chat_message_handler.dart';
import '../../services/draft_service.dart';
import '../../services/notification_service.dart';
import '../../utils/diff_parser.dart';
import '../../utils/network_endpoint.dart';
import '../../utils/terminal_launcher.dart';
import '../session_list/workspace_shell_screen.dart';
import '../settings/state/settings_cubit.dart';
import '../../widgets/rename_session_dialog.dart';
import '../../widgets/workspace_pane_chrome.dart';
import 'state/chat_session_state.dart';
import '../git/state/git_status_cubit.dart';

class SessionNoopListenable implements Listenable {
  const SessionNoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

Widget? sessionAppBarLeading(
  BuildContext context, {
  VoidCallback? onBackToSessions,
  bool hideSessionBackButton = false,
}) {
  if (!hideSessionBackButton && onBackToSessions != null) {
    return BackButton(
      key: const ValueKey('session_back_button'),
      onPressed: onBackToSessions,
    );
  }
  if (hideSessionBackButton) {
    return null;
  }
  return BackButton(
    key: const ValueKey('session_back_button'),
    onPressed: () => Navigator.of(context).maybePop(),
  );
}

WorkspacePaneChrome resolveSessionPaneChrome(
  BuildContext context,
  WorkspaceShellScreenState? shell,
) {
  return resolveWorkspacePaneChrome(
    platform: Theme.of(context).platform,
    isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
    isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
    slot: WorkspacePaneSlot.center,
  );
}

enum SessionGitBadgeTone { dirty, remote }

String? firstNonEmptyProjectPath(String? primary, String? fallback) {
  if (primary?.trim().isNotEmpty == true) return primary;
  if (fallback?.trim().isNotEmpty == true) return fallback;
  return null;
}

SessionGitBadgeTone? sessionGitBadgeToneOf(
  BuildContext context,
  String sessionId,
  String? projectPath, {
  required bool showRemoteGitStatusBadge,
}) {
  if (projectPath == null || projectPath.isEmpty) return null;
  try {
    return context.select((GitStatusCubit cubit) {
      final entry = cubit.state.entryFor(sessionId);
      if (entry?.projectPath != projectPath) return null;
      if (entry?.showDirtyBadge == true) return SessionGitBadgeTone.dirty;
      if (entry?.showRemoteBadge(enabled: showRemoteGitStatusBadge) == true) {
        return SessionGitBadgeTone.remote;
      }
      return null;
    });
  } catch (_) {
    return null;
  }
}

Color? sessionGitBadgeColor(BuildContext context, SessionGitBadgeTone? tone) {
  final error = Theme.of(context).colorScheme.error;
  return switch (tone) {
    SessionGitBadgeTone.dirty => error,
    SessionGitBadgeTone.remote => error.withValues(alpha: 0.45),
    null => null,
  };
}

Future<void> openSessionGitScreen(
  BuildContext context,
  String projectPath,
  ValueNotifier<DiffSelection?> diffSelectionNotifier, {
  String? sessionId,
  String? worktreePath,
  ValueChanged<String>? onFilePeekOpened,
}) async {
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openGitPane(
      projectPath: projectPath,
      sessionId: sessionId,
      worktreePath: worktreePath,
      diffSelectionNotifier: diffSelectionNotifier,
      onFilePeekOpened: onFilePeekOpened,
    );
    return;
  }
  final selection = await context.router.push<DiffSelection>(
    GitRoute(
      projectPath: projectPath,
      sessionId: sessionId,
      worktreePath: worktreePath,
      onFilePeekOpened: onFilePeekOpened,
    ),
  );
  if (selection != null) {
    diffSelectionNotifier.value = selection.isEmpty ? null : selection;
  }
}

void openSessionGalleryScreen(
  BuildContext context, {
  required String sessionId,
}) {
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openSessionGalleryPane(sessionId: sessionId);
    return;
  }
  context.router.push(GalleryRoute(sessionId: sessionId));
}

void executeSessionSideEffects(
  Set<ChatSideEffect> effects, {
  required String sessionId,
  required bool isBackground,
  required bool remoteNotificationsReady,
  required ApprovalState approval,
  required AppLocalizations l,

  /// Body of the local notification shown when the session finishes.
  required String completionNotificationBody,
  required ValueNotifier<int> collapseToolResults,
  required TextEditingController planFeedbackController,
  required bool Function() isReadingHistory,
}) {
  final useLocalNotification = shouldUseLocalNotificationFallback(
    isBackground: isBackground,
    remoteNotificationsReady: remoteNotificationsReady,
  );
  for (final effect in effects) {
    switch (effect) {
      case ChatSideEffect.heavyHaptic:
        HapticFeedback.heavyImpact();
      case ChatSideEffect.mediumHaptic:
        HapticFeedback.mediumImpact();
      case ChatSideEffect.lightHaptic:
        HapticFeedback.lightImpact();
      case ChatSideEffect.collapseToolResults:
        if (shouldAutoCollapseToolResults(isReadingHistory())) {
          collapseToolResults.value++;
        }
      case ChatSideEffect.clearPlanFeedback:
        planFeedbackController.clear();
      case ChatSideEffect.notifyApprovalRequired:
        if (useLocalNotification) {
          final permission = notificationPermissionFor(approval);
          if (permission != null) {
            NotificationService.instance.showApprovalNotification(
              permission,
              l: l,
              id: 1,
              payload: sessionId,
            );
          }
        }
      case ChatSideEffect.notifyAskQuestion:
        if (useLocalNotification) {
          final permission = notificationPermissionFor(approval);
          if (permission != null) {
            NotificationService.instance.showApprovalNotification(
              permission,
              l: l,
              id: 2,
              payload: sessionId,
            );
          }
        }
      case ChatSideEffect.notifyGoalProgress:
      case ChatSideEffect.notifyGoalComplete:
      case ChatSideEffect.notifyGoalBlocked:
      case ChatSideEffect.notifyGoalBudgetLimited:
      case ChatSideEffect.notifyGoalUsageLimited:
        if (useLocalNotification) {
          final title = switch (effect) {
            ChatSideEffect.notifyGoalProgress => l.notifyGoalProgress,
            ChatSideEffect.notifyGoalComplete => l.notifyGoalComplete,
            ChatSideEffect.notifyGoalBlocked => l.notifyGoalBlocked,
            ChatSideEffect.notifyGoalBudgetLimited => l.notifyGoalBudgetLimited,
            ChatSideEffect.notifyGoalUsageLimited => l.notifyGoalUsageLimited,
            _ => '',
          };
          NotificationService.instance.show(
            title: title,
            body: title,
            id: 3,
            payload: sessionId,
          );
        }
      case ChatSideEffect.notifySessionComplete:
        if (useLocalNotification) {
          NotificationService.instance.showSessionCompleteNotification(
            body: completionNotificationBody,
            id: 3,
            payload: sessionId,
          );
        }
    }
  }
}

PermissionRequestMessage? notificationPermissionFor(ApprovalState approval) {
  return switch (approval) {
    ApprovalPermission(:final request) => request,
    ApprovalAskUser(:final toolUseId, :final input) => PermissionRequestMessage(
      toolUseId: toolUseId,
      toolName: 'AskUserQuestion',
      input: input,
    ),
    ApprovalNone() => null,
    _ => null,
  };
}

Future<void> openSessionInTerminal(
  BuildContext context,
  String? projectPath,
) async {
  if (!FeatureFlags.current.isEnabled(AppFeature.terminalAppIntegration)) {
    return;
  }
  if (projectPath == null) return;
  final config = context.read<SettingsCubit>().state.terminalApp;
  if (!config.isConfigured) return;

  final bridge = context.read<BridgeService>();
  final url = bridge.lastUrl;
  final uri = url != null
      ? Uri.tryParse(
          url
              .replaceFirst('ws://', 'http://')
              .replaceFirst('wss://', 'https://'),
        )
      : null;
  final host = normalizeHostInput(uri?.host ?? '');

  // Resolve SSH user from machine config
  String? sshUser;
  try {
    final machines = context.read<MachineManagerCubit>().state.machines;
    for (final item in machines) {
      if (canonicalHostIdentity(item.machine.host) ==
          canonicalHostIdentity(host)) {
        sshUser = item.machine.sshUsername;
        break;
      }
    }
  } catch (_) {
    // MachineManagerCubit may not be available
  }

  final launched = await launchTerminalApp(
    config: config,
    host: host,
    sshUser: sshUser,
    projectPath: projectPath,
  );

  if (!launched && context.mounted) {
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.terminalAppNotInstalled)));
  }
}

Future<void> renameSessionFromScreen(
  BuildContext context,
  String sessionId,
) async {
  final bridge = context.read<BridgeService>();
  final sessions = bridge.sessions;
  final session = sessions.where((s) => s.id == sessionId).firstOrNull;
  final newName = await showRenameSessionDialog(
    context,
    currentName: session?.name,
  );
  if (newName == null || !context.mounted) return;
  bridge.renameSession(
    sessionId: sessionId,
    name: newName.isEmpty ? null : newName,
  );
}

void restoreRewindMessageToComposer({
  required TextEditingController inputController,
  required DraftService draftService,
  required String sessionId,
  required String text,
}) {
  inputController.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  draftService.saveDraft(sessionId, text);
}
