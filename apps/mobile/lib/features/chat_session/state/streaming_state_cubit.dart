import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
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
    emit(state.copyWith(thinking: state.thinking + text, isStreaming: true));
  }

  void setActivity(AgentActivityInfo? activity) {
    if (state.activity == activity) return;
    emit(state.copyWith(activity: activity));
  }

  /// Clears committed text/thinking buffers mid-turn while preserving any
  /// ongoing turn summary (`activity.summary`).
  void clearStream() {
    final currentActivity = state.activity;
    final retainedActivity =
        currentActivity != null && currentActivity.summary != null
        ? AgentActivityInfo(summary: currentActivity.summary)
        : null;
    emit(StreamingState(activity: retainedActivity));
  }

  void reset() {
    emit(const StreamingState());
  }
}
