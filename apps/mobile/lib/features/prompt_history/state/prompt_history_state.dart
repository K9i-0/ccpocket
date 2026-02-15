import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../services/prompt_history_service.dart';

part 'prompt_history_state.freezed.dart';

@freezed
abstract class PromptHistoryState with _$PromptHistoryState {
  const factory PromptHistoryState({
    @Default([]) List<PromptHistoryEntry> prompts,
    @Default(PromptSortOrder.frequency) PromptSortOrder sortOrder,
    String? projectFilter,
    @Default('') String searchQuery,
    @Default(false) bool isLoading,
    @Default([]) List<String> availableProjects,
  }) = _PromptHistoryState;
}
