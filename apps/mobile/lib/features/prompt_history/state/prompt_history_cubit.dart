import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/prompt_history_service.dart';
import 'prompt_history_state.dart';

/// Manages the prompt history bottom sheet state.
///
/// Created when the sheet is displayed and disposed when it closes.
class PromptHistoryCubit extends Cubit<PromptHistoryState> {
  final PromptHistoryService _service;

  PromptHistoryCubit(this._service) : super(const PromptHistoryState());

  /// Load prompt history with current filters.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true));

    try {
      final results = await Future.wait([
        _service.getPrompts(
          sort: state.sortOrder,
          projectPath: state.projectFilter,
          searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
        ),
        _service.getProjectPaths(),
      ]);

      final prompts = results[0] as List<PromptHistoryEntry>;
      final projects = results[1] as List<String>;

      emit(
        state.copyWith(
          prompts: prompts,
          availableProjects: projects,
          isLoading: false,
        ),
      );
    } catch (e) {
      debugPrint('[PromptHistoryCubit] load failed: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Change sort order and reload.
  Future<void> setSortOrder(PromptSortOrder order) async {
    emit(state.copyWith(sortOrder: order));
    await load();
  }

  /// Set project filter and reload.
  /// Pass `null` for "all projects".
  Future<void> setProjectFilter(String? projectPath) async {
    emit(state.copyWith(projectFilter: projectPath));
    await load();
  }

  /// Set search query and reload.
  Future<void> setSearchQuery(String query) async {
    emit(state.copyWith(searchQuery: query));
    await load();
  }

  /// Toggle favorite status and reload.
  Future<void> toggleFavorite(int id) async {
    await _service.toggleFavorite(id);
    await load();
  }

  /// Delete a prompt entry and reload.
  Future<void> delete(int id) async {
    await _service.delete(id);
    await load();
  }
}
