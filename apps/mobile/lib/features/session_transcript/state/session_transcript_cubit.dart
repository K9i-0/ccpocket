import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/chat_message_handler.dart';
import 'session_transcript_state.dart';

/// Pages the full session transcript (`get_session_transcript`) for the
/// read-only transcript screen. The first page ends at the latest context
/// compaction boundary; older pages are loaded on demand.
class SessionTranscriptCubit extends Cubit<SessionTranscriptState> {
  SessionTranscriptCubit({
    required Stream<ServerMessage> messages,
    required this.send,
    required this.sessionId,
    this.pageSize = 200,
    this.timeout = const Duration(seconds: 30),
  }) : super(const SessionTranscriptState()) {
    _subscription = messages.listen(_onMessage);
  }

  final String sessionId;
  final int pageSize;
  final Duration timeout;
  final void Function(ClientMessage) send;
  late final StreamSubscription<ServerMessage> _subscription;

  String? _pendingRequestId;
  bool _pendingIsOlder = false;
  Timer? _timeoutTimer;
  int _requestCounter = 0;

  void load() {
    emit(const SessionTranscriptState());
    _request(older: false);
  }

  void loadOlder() {
    if (!state.hasOlder || state.loadingOlder || _pendingRequestId != null) {
      return;
    }
    emit(state.copyWith(loadingOlder: true, olderFailed: false));
    _request(older: true);
  }

  void _request({required bool older}) {
    final requestId =
        '$sessionTranscriptRequestIdPrefix$sessionId-${++_requestCounter}';
    _pendingRequestId = requestId;
    _pendingIsOlder = older;
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(timeout, _fail);
    send(
      ClientMessage.getSessionTranscript(
        sessionId: sessionId,
        requestId: requestId,
        beforeIndex: older ? state.startIndex : null,
        untilLatestCompaction: !older,
        limit: pageSize,
      ),
    );
  }

  void _onMessage(ServerMessage message) {
    final requestId = _pendingRequestId;
    if (requestId == null) return;
    switch (message) {
      case SessionTranscriptMessage() when message.requestId == requestId:
        _finish();
        _applyPage(message);
      case ErrorMessage(
        errorCode: 'unsupported_message',
        message: 'get_session_transcript',
      ):
        _finish();
        emit(
          state.copyWith(
            status: SessionTranscriptStatus.bridgeUpdateRequired,
            loadingOlder: false,
          ),
        );
      case ErrorMessage() when message.requestId == requestId:
        _fail();
      default:
        break;
    }
  }

  void _applyPage(SessionTranscriptMessage page) {
    final pageEntries = ChatMessageHandler()
        .handle(
          PastHistoryMessage(claudeSessionId: '', messages: page.messages),
          isBackground: true,
        )
        .entriesToPrepend;
    emit(
      state.copyWith(
        status: SessionTranscriptStatus.loaded,
        entries: _pendingIsOlder
            ? [...pageEntries, ...state.entries]
            : pageEntries,
        startIndex: page.startIndex,
        loadingOlder: false,
        olderFailed: false,
      ),
    );
  }

  void _fail() {
    final wasOlder = _pendingIsOlder;
    _finish();
    if (isClosed) return;
    if (wasOlder && state.status == SessionTranscriptStatus.loaded) {
      emit(state.copyWith(loadingOlder: false, olderFailed: true));
    } else {
      emit(state.copyWith(status: SessionTranscriptStatus.failed));
    }
  }

  void _finish() {
    _pendingRequestId = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  Future<void> close() {
    _timeoutTimer?.cancel();
    _subscription.cancel();
    return super.close();
  }
}
