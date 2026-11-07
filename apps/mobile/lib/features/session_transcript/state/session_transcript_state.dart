import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'session_transcript_state.freezed.dart';

enum SessionTranscriptStatus { loading, loaded, failed, bridgeUpdateRequired }

/// Read-only transcript pages loaded from the Bridge, oldest first.
@freezed
abstract class SessionTranscriptState with _$SessionTranscriptState {
  const factory SessionTranscriptState({
    @Default(SessionTranscriptStatus.loading) SessionTranscriptStatus status,
    @Default([]) List<ChatEntry> entries,

    /// Transcript index of the first loaded message; older pages end here.
    @Default(0) int startIndex,
    @Default(false) bool loadingOlder,

    /// An older page failed; the loaded entries stay visible.
    @Default(false) bool olderFailed,
  }) = _SessionTranscriptState;
}

extension SessionTranscriptStateX on SessionTranscriptState {
  bool get hasOlder => startIndex > 0;
}
