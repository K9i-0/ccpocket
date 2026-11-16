import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../services/draft_service.dart';
import '../../chat_session/state/chat_session_cubit.dart';
import '../../chat_session/state/chat_session_state.dart';
import '../../chat_session/widgets/floating_composer_layout.dart';
import '../../session_list/workspace_shell_screen.dart';
import '../github_screen.dart';
import 'github_mark_icon.dart';

/// Whether a chat still offers the "Open Issues / PRs" entry.
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

/// Opens the Issues / PRs screen for the chat of [sessionId]. What is picked
/// there becomes that session's selection; nothing is sent.
Future<void> openGitHubScreenForSession(
  BuildContext context, {
  required String projectPath,
  required String sessionId,
  bool toggle = true,
}) async {
  final shell = WorkspaceShellScreen.maybeOf(context);
  if (shell?.canOpenToolPane ?? false) {
    shell!.openGitHubPane(
      projectPath: projectPath,
      sessionId: sessionId,
      toggle: toggle,
    );
    return;
  }
  // Keep the screen on the Bridge this chat talks to rather than whatever a
  // new route would inherit.
  final bridge = context.read<BridgeService>();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RepositoryProvider<BridgeService>.value(
        value: bridge,
        child: GitHubScreen(projectPath: projectPath, sessionId: sessionId),
      ),
    ),
  );
}

/// "Open Issues / PRs" entry centered in an empty chat.
///
/// It never calls the Bridge itself; a non-GitHub project or an older Bridge
/// is explained inside the screen it opens. A session that was started from a
/// project's Issues / PRs entry opens the screen by itself once the chat is
/// ready and is the current route (`GitHubSelectionCubit.requestOpen`).
class EmptyChatGitHubButton extends StatefulWidget {
  final String sessionId;
  final String? projectPath;

  const EmptyChatGitHubButton({
    super.key,
    required this.sessionId,
    required this.projectPath,
  });

  @override
  State<EmptyChatGitHubButton> createState() => _EmptyChatGitHubButtonState();
}

class _EmptyChatGitHubButtonState extends State<EmptyChatGitHubButton> {
  bool _autoOpenScheduled = false;

  void _open({bool toggle = true}) {
    final projectPath = widget.projectPath;
    if (projectPath == null || projectPath.isEmpty) return;
    unawaited(
      openGitHubScreenForSession(
        context,
        projectPath: projectPath,
        sessionId: widget.sessionId,
        toggle: toggle,
      ),
    );
  }

  /// Runs after the frame, because opening the screen navigates.
  void _scheduleAutoOpen() {
    if (_autoOpenScheduled) return;
    _autoOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoOpenScheduled = false;
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      final selection = context.read<DraftService?>()?.githubSelection;
      if (selection == null || !selection.takeOpenRequest(widget.sessionId)) {
        return;
      }
      _open(toggle: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectPath = widget.projectPath;
    final visible = context.select<ChatSessionCubit, bool>(
      (cubit) => showsEmptyChatGitHubEntry(cubit.state),
    );
    if (!visible || projectPath == null || projectPath.isEmpty) {
      return const SizedBox.shrink();
    }
    // Only while this chat is what the user is looking at. A route on top
    // (or a chat that is still covered) keeps the request; this widget
    // rebuilds when its route becomes current again.
    if (ModalRoute.of(context)?.isCurrent ?? true) _scheduleAutoOpen();
    return Padding(
      // The chat content extends behind the bars and the composer.
      padding: EdgeInsets.only(
        bottom: FloatingComposerStatus.obscuredBottomOf(context),
      ),
      // Near the composer, where the thumb already is.
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: FilledButton.tonalIcon(
            key: const ValueKey('empty_chat_github_button'),
            onPressed: _open,
            icon: const GitHubMarkIcon(size: 20),
            label: Text(AppLocalizations.of(context).githubOpenIssuesAndPrs),
          ),
        ),
      ),
    );
  }
}
