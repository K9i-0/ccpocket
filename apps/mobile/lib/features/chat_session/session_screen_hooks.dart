import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/messages.dart';
import '../../services/bridge_service.dart';
import '../../services/draft_service.dart';
import '../git/state/git_status_cubit.dart';
import '../git/state/git_view_cache_service.dart';

/// Restores the saved draft into [chatInputController] and saves it again as the user
/// types (debounced) and when the screen goes away.
void useComposerDraft(
  String sessionId,
  DraftService draftService,
  TextEditingController chatInputController,
) {
  useEffect(() {
    final draft = draftService.getDraft(sessionId);
    if (draft != null && draft.isNotEmpty) {
      chatInputController.text = draft;
      chatInputController.selection = TextSelection.collapsed(
        offset: draft.length,
      );
    }

    Timer? debounce;
    void onChanged() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 500), () {
        draftService.saveDraft(sessionId, chatInputController.text);
      });
    }

    chatInputController.addListener(onChanged);
    return () {
      debounce?.cancel();
      // Flush current text on dispose (navigating away)
      draftService.saveDraft(sessionId, chatInputController.text);
      chatInputController.removeListener(onChanged);
    };
  }, [sessionId]);
}

/// Asks the Bridge for the file list, git status, session list and branch
/// when a foreground session screen appears or its project changes.
void useInitialSessionRequests(
  BuildContext context, {
  required String sessionId,
  required bool isBackground,
  required String? effectiveProjectPath,
  required String? gitProjectPath,
  required bool showRemoteGitStatusBadge,
}) {
  useEffect(
    () {
      final bridge = context.read<BridgeService>();
      final path = gitProjectPath;
      if (!isBackground && effectiveProjectPath != null) {
        bridge.requestFileList(effectiveProjectPath);
      }
      if (!isBackground && path != null && path.isNotEmpty) {
        try {
          context.read<GitStatusCubit>().refresh(
            sessionId: sessionId,
            projectPath: path,
            includeRemote: showRemoteGitStatusBadge,
          );
        } catch (_) {}
      }
      if (!isBackground) {
        bridge.requestSessionList();
        bridge.refreshBranch(sessionId);
      }
      return null;
    },
    [sessionId, effectiveProjectPath, gitProjectPath, showRemoteGitStatusBadge],
  );
}

/// Refreshes the file list and git status when a tool in [refreshToolNames]
/// finishes or a turn ends with file edits.
void useSessionFileRefresh(
  BuildContext context, {
  required String sessionId,
  required ObjectRef<bool> isBackgroundRef,
  required String? effectiveProjectPath,
  required String? gitProjectPath,
  required bool showRemoteGitStatusBadge,
  required Set<String> refreshToolNames,
}) {
  useEffect(
    () {
      if (effectiveProjectPath == null) return null;

      final bridge = context.read<BridgeService>();
      GitStatusCubit? gitStatusCubit;
      GitViewCacheService? gitViewCache;
      try {
        gitStatusCubit = context.read<GitStatusCubit>();
        gitViewCache = context.read<GitViewCacheService>();
      } catch (_) {}
      final sub = bridge.messagesForSession(sessionId).listen((msg) {
        if (isBackgroundRef.value) return;
        if (msg case ToolResultMessage(:final toolName)
            when refreshToolNames.contains(toolName)) {
          bridge.requestFileList(effectiveProjectPath);
        } else if (msg case ResultMessage(:final fileEdits)) {
          if ((fileEdits ?? 0) > 0) {
            bridge.requestFileList(effectiveProjectPath);
          }
          gitStatusCubit?.refresh(
            sessionId: sessionId,
            projectPath: gitProjectPath!,
            includeRemote: showRemoteGitStatusBadge,
          );
          gitViewCache?.refreshIfPresent(sessionId);
        }
      });
      return sub.cancel;
    },
    [sessionId, effectiveProjectPath, gitProjectPath, showRemoteGitStatusBadge],
  );
}
