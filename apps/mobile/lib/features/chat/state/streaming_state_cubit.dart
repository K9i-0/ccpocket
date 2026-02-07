import 'package:flutter_bloc/flutter_bloc.dart';

import 'streaming_state.dart';

/// Manages the high-frequency streaming state for a chat session.
///
/// Kept separate from [ChatSessionCubit] to avoid rebuilding the
/// entire message list on every streaming delta.
class StreamingStateCubit extends Cubit<StreamingState> {
  StreamingStateCubit() : super(const StreamingState());

  void appendText(String text) {
    emit(state.copyWith(text: state.text + text, isStreaming: true));
  }

  void appendThinking(String text) {
    emit(state.copyWith(thinking: state.thinking + text));
  }

  void reset() {
    emit(const StreamingState());
  }
}
