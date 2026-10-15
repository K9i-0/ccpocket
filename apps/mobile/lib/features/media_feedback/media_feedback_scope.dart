import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/draft_service.dart';
import '../chat_session/state/chat_session_cubit.dart';
import '../session_list/workspace_shell_screen.dart';
import 'state/media_feedback_cubit.dart';

/// Captured before opening a route so an open preview cannot change sessions.
class MediaFeedbackBinding {
  final MediaFeedbackCubit cubit;
  final String sessionId;
  const MediaFeedbackBinding(this.cubit, this.sessionId);

  static MediaFeedbackBinding? maybeOf(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<MediaFeedbackScope>();
    if (inherited != null) return inherited.binding;
    final drafts = context.read<DraftService?>();
    final id =
        context.read<ChatSessionCubit?>()?.sessionId ??
        WorkspaceShellScreen.maybeOf(context)?.liveSessionId;
    return drafts == null || id == null
        ? null
        : MediaFeedbackBinding(drafts.mediaFeedback, id);
  }
}

class MediaFeedbackScope extends InheritedWidget {
  final MediaFeedbackBinding? binding;
  const MediaFeedbackScope({
    super.key,
    required this.binding,
    required super.child,
  });
  @override
  bool updateShouldNotify(MediaFeedbackScope oldWidget) =>
      binding != oldWidget.binding;
}
