import '../../../models/messages.dart';
import '../../chat_session/state/chat_session_cubit.dart';

/// Codex-specific session cubit.
///
/// Extends [ChatSessionCubit] so that shared widgets
/// (`ChatMessageList`, `ChatInputWithOverlays`, etc.) that read
/// `context.read<ChatSessionCubit>()` continue to work.
///
/// Codex sessions do not support rewind.
class CodexSessionCubit extends ChatSessionCubit {
  CodexSessionCubit({
    required super.sessionId,
    required super.bridge,
    required super.streamingCubit,
    super.initialSandboxMode,
    super.initialPermissionMode,
  }) : super(provider: Provider.codex);

  /// Rewind is not supported for Codex sessions.
  @override
  List<UserChatEntry> get rewindableUserMessages => const [];
}
