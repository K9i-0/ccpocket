import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../router/app_router.dart';
import '../../chat_session/state/chat_session_cubit.dart';
import '../../chat_session/state/chat_session_state.dart';
import '../../session_list/workspace_shell_screen.dart';
import 'github_triage_sheet.dart';

/// Whether a chat still offers the "Issues / PRs" entry.
///
/// It is offered only until the user sends something: a sent, failed, or
/// offline-pending message and a queued input all count. Assistant and system
/// entries do not, so a greeting or an init notice keeps it visible. It waits
/// for an idle session so it does not flash while a session starts, restores
/// its history, or already runs the prompt it was started with.
bool showsEmptyChatGitHubEntry(ChatSessionState state) {
  if (state.status != ProcessStatus.idle || state.bulkLoading) return false;
  if (state.queuedInput != null) return false;
  return !state.entries.any(
    (entry) => entry is UserChatEntry || entry is QuestionAnswerChatEntry,
  );
}

/// Opens the Issues / PRs screen for a chat. The composed `/triage ...`
/// request is sent through the session's normal send path, which converts
/// the skill trigger for the session's agent.
Future<void> openGitHubScreenForSession(
  BuildContext context, {
  required String projectPath,
  required String sessionId,
}) async {
  final cubit = context.read<ChatSessionCubit>();
  void send(String prompt) {
    if (!cubit.isClosed) unawaited(cubit.sendMessage(prompt));
  }

  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openGitHubPane(
      projectPath: projectPath,
      sessionId: sessionId,
      onSubmitTriage: send,
    );
    return;
  }
  final prompt = await context.router.push<String>(
    GitHubRoute(
      projectPath: projectPath,
      triageTarget: GitHubTriageTarget.currentSession,
    ),
  );
  if (prompt != null && prompt.isNotEmpty) send(prompt);
}

/// "Issues / PRs" shortcut shown above the composer of an empty chat.
///
/// It never calls the Bridge itself; a non-GitHub project or an older Bridge
/// is explained inside the screen it opens.
class EmptyChatGitHubButton extends StatelessWidget {
  final String sessionId;
  final String? projectPath;

  const EmptyChatGitHubButton({
    super.key,
    required this.sessionId,
    required this.projectPath,
  });

  @override
  Widget build(BuildContext context) {
    final projectPath = this.projectPath;
    final visible = context.select<ChatSessionCubit, bool>(
      (cubit) => showsEmptyChatGitHubEntry(cubit.state),
    );
    if (!visible || projectPath == null || projectPath.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          key: const ValueKey('empty_chat_github_button'),
          avatar: const Icon(Icons.fact_check_outlined, size: 18),
          label: Text(AppLocalizations.of(context).githubIssuesAndPrs),
          onPressed: () => unawaited(
            openGitHubScreenForSession(
              context,
              projectPath: projectPath,
              sessionId: sessionId,
            ),
          ),
        ),
      ),
    );
  }
}
