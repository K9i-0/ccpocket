import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../chat_session/state/chat_session_cubit.dart';
import '../../chat_session/state/chat_session_state.dart';
import '../../session_list/workspace_shell_screen.dart';
import '../github_screen.dart';
import '../triage_prompt.dart';

/// Whether a chat still offers the "Issues / PRs" entry.
///
/// It is offered only until the user sends something: a sent, failed, or
/// offline-pending message and a queued input all count. Assistant and system
/// entries do not, so a greeting or an init notice keeps it visible.
///
/// A resumed session shows no entries until the Bridge delivers its context
/// and history, so the entry waits for an idle session whose context has
/// arrived. Earlier turns that were trimmed from the live window
/// ([ChatSessionState.olderHistoryAvailable]) also mean the chat is not new.
bool showsEmptyChatGitHubEntry(ChatSessionState state) {
  if (state.status != ProcessStatus.idle || !state.sessionContextLoaded) {
    return false;
  }
  if (state.olderHistoryAvailable || state.queuedInput != null) return false;
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
  Future<bool> send(String prompt) => sendTriageAsFirstMessage(cubit, prompt);

  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openGitHubPane(
      projectPath: projectPath,
      sessionId: sessionId,
      onSubmitTriage: send,
    );
    return;
  }
  // Without a workspace shell (previews), keep the screen on the Bridge this
  // chat talks to rather than whatever a new route would inherit.
  final bridge = context.read<BridgeService>();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RepositoryProvider<BridgeService>.value(
        value: bridge,
        child: GitHubScreen(
          projectPath: projectPath,
          triageTarget: GitHubTriageTarget.currentSession,
          onSubmitTriage: send,
        ),
      ),
    ),
  );
}

/// Sends [prompt] only while the chat is still empty. The screen can stay
/// open while the session moves on (another client, a queued input), and a
/// triage request must not land in the middle of a conversation.
///
/// The trigger is converted here as well as in the send path, because a new
/// Codex session may not have reported its skill list yet.
Future<bool> sendTriageAsFirstMessage(
  ChatSessionCubit cubit,
  String prompt,
) async {
  if (cubit.isClosed || !showsEmptyChatGitHubEntry(cubit.state)) return false;
  return cubit.sendMessage(
    triagePromptForProvider(
      prompt,
      cubit.isCodex ? Provider.codex : Provider.claude,
    ),
  );
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
