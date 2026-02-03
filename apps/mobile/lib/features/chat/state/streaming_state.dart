import 'package:freezed_annotation/freezed_annotation.dart';

part 'streaming_state.freezed.dart';

/// High-frequency streaming state, kept in a separate provider to avoid
/// rebuilding the entire message list on every delta.
@freezed
class StreamingState with _$StreamingState {
  const factory StreamingState({
    /// Accumulated assistant text from stream_delta messages.
    @Default('') String text,

    /// Accumulated thinking text from thinking_delta messages.
    @Default('') String thinking,

    /// Whether we are actively receiving deltas.
    @Default(false) bool isStreaming,
  }) = _StreamingState;
}
