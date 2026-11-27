import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../models/new_session_tab.dart';
import '../../services/bridge_service.dart';
import '../session_list/services/session_start_defaults_store.dart';
import '../session_list/session_list_screen.dart';
import '../session_list/workspace_shell_screen.dart';
import '../settings/state/settings_cubit.dart';
import '../../widgets/app_toast.dart';

/// Session handoff: stop a session and continue its task in another agent.
/// The Bridge does the work (`handoff_session`); see docs/session-handoff.md.

const _handoffMenuValuePrefix = 'handoff:';

/// Agents [current] can hand a session over to, in menu order.
///
/// They are the agents of the new session sheet ([visibleTabs]) other than
/// [current]. Empty when the Bridge predates handoff ([supportsHandoff]).
List<Provider> handoffTargets({
  required Provider current,
  required bool supportsHandoff,
  required List<NewSessionTab> visibleTabs,
}) {
  if (!supportsHandoff) return const [];
  return [
    for (final tab in visibleTabs)
      if (tab.toProvider() != current) tab.toProvider(),
  ];
}

/// "Hand off to …" entries of a chat's overflow menu, one per other agent.
List<PopupMenuItem<String>> handoffSessionMenuItems(
  BuildContext context, {
  required Provider current,
}) {
  final l = AppLocalizations.of(context);
  final bridge = context.read<BridgeService>();
  final settings = context.read<SettingsCubit>().state;
  final targets = handoffTargets(
    current: current,
    supportsHandoff: bridge.supportsSessionHandoff,
    visibleTabs: visibleNewSessionTabs(
      settings.newSessionTabs,
      supportsAntigravity:
          bridge.supportsAntigravity && settings.showAntigravityTab,
    ),
  );
  return [
    for (final target in targets)
      PopupMenuItem(
        key: ValueKey('menu_handoff_${target.value}'),
        value: '$_handoffMenuValuePrefix${target.value}',
        child: ListTile(
          leading: const Icon(Icons.swap_horiz, size: 20),
          title: Text(l.handoffTo(target.label)),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
  ];
}

/// The agent a menu value of [handoffSessionMenuItems] stands for.
Provider? handoffTargetFromMenuValue(String value) {
  if (!value.startsWith(_handoffMenuValuePrefix)) return null;
  return Provider.fromValue(value.substring(_handoffMenuValuePrefix.length));
}

/// Confirm and request the handoff of [sessionId] from [source] to [target].
///
/// The Bridge answers with `session_created` carrying `handoff`; the chat
/// screen then opens the new session with [openHandoffSession].
Future<void> handoffSessionFromScreen(
  BuildContext context, {
  required String sessionId,
  required Provider source,
  required Provider target,
}) async {
  final instruction = await showHandoffDialog(
    context,
    source: source,
    target: target,
  );
  if (instruction == null || !context.mounted) return;
  final bridge = context.read<BridgeService>();
  final start = await rememberedStartOptions(
    target,
    antigravityPermissionModes: antigravityStartPermissionModes(bridge),
  );
  if (!context.mounted) return;
  bridge.send(
    ClientMessage.handoffSession(
      sessionId,
      target: target,
      instruction: instruction.trim(),
      start: start,
    ),
  );
  final l = AppLocalizations.of(context);
  AppToast.of(context).show(l.handoffStarted(target.label));
}

/// The `start` message a new [target] session would be started with, from
/// the settings remembered for that agent (model, effort, permission mode).
/// Null when nothing is remembered; the Bridge then uses its own defaults.
///
/// The Bridge ignores the project, worktree and prompt in it.
Future<Map<String, dynamic>?> rememberedStartOptions(
  Provider target, {
  List<PermissionMode>? antigravityPermissionModes,
  SessionStartDefaultsStore store = const SessionStartDefaultsStore(),
}) async {
  final defaults = await store.loadFor(target);
  if (defaults == null || defaults.provider != target) return null;
  final message = sessionStartMessage(
    defaults,
    autoRename: false,
    antigravityPermissionModes: antigravityPermissionModes,
    requestId: '',
  );
  return jsonDecode(message.toJson()) as Map<String, dynamic>;
}

/// Returns the instruction for the target (empty to continue the task), or
/// null when the dialog was cancelled.
Future<String?> showHandoffDialog(
  BuildContext context, {
  required Provider source,
  required Provider target,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _HandoffDialog(source: source, target: target),
  );
}

class _HandoffDialog extends StatefulWidget {
  final Provider source;
  final Provider target;

  const _HandoffDialog({required this.source, required this.target});

  @override
  State<_HandoffDialog> createState() => _HandoffDialogState();
}

class _HandoffDialogState extends State<_HandoffDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final target = widget.target.label;
    return AlertDialog(
      key: const ValueKey('handoff_dialog'),
      title: Text(l.handoffTo(target)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.handoffConfirmBody(widget.source.label, target)),
            const SizedBox(height: 16),
            Text(
              l.handoffInstructionLabel(target),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('handoff_instruction_field'),
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: l.handoffInstructionHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('handoff_confirm_button'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l.handoffConfirmAction),
        ),
      ],
    );
  }
}

/// Replace the chat of the stopped source session with the session that
/// continues it. The provider differs, so the screen itself is replaced
/// rather than switched in place.
///
/// [hostedByShell] is true when the chat is a pane of the workspace shell
/// and false when it is a route of its own.
void openHandoffSession(
  BuildContext context,
  SystemMessage msg, {
  required bool hostedByShell,
}) {
  final sessionId = msg.sessionId;
  if (sessionId == null) return;
  final provider = Provider.fromValue(msg.provider);
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (hostedByShell && shell != null) {
    shell.selectSession(
      WorkspaceSessionSelection(
        sessionId: sessionId,
        projectPath: msg.projectPath,
        workspace: msg.workspace,
        gitBranch: msg.worktreeBranch,
        worktreePath: msg.worktreePath,
        provider: provider,
        permissionMode: msg.permissionMode,
        sandboxMode: msg.sandboxMode,
        approvalPolicy: msg.approvalPolicy,
        approvalsReviewer: msg.approvalsReviewer,
      ),
    );
    return;
  }
  context.router.replace(
    chatRouteForProvider(
      provider,
      sessionId: sessionId,
      projectPath: msg.projectPath,
      workspace: msg.workspace,
      gitBranch: msg.worktreeBranch,
      worktreePath: msg.worktreePath,
      permissionMode: msg.permissionMode,
      sandboxMode: msg.sandboxMode,
      approvalPolicy: msg.approvalPolicy,
      approvalsReviewer: msg.approvalsReviewer,
    ),
  );
}
