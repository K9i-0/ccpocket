import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logger.dart';
import '../../../services/bridge_service.dart';
import '../../../services/prompt_history_service.dart';
import 'prompt_history_state.dart';

/// Page size for prompt history pagination.
const _pageSize = 30;

/// Manages the prompt history bottom sheet state.
class PromptHistoryCubit extends Cubit<PromptHistoryState> {
  final PromptHistoryService _service;
  final BridgeService? _bridgeService;
  final String? _currentProjectPath;
  final String? _currentBridgeId;

  PromptHistoryCubit(
    this._service, {
    BridgeService? bridgeService,
    String? currentProjectPath,
    String? currentBridgeId,
    PromptHistoryFilters initialFilters = const PromptHistoryFilters(),
  }) : _bridgeService = bridgeService,
       _currentProjectPath = currentProjectPath,
       _currentBridgeId = currentBridgeId,
       super(PromptHistoryState(filters: initialFilters));

  Future<void> load({bool syncFirst = false}) async {
    emit(state.copyWith(isLoading: true));

    try {
      final bridge = _bridgeService;
      if (syncFirst && bridge != null && bridge.lastUrl != null) {
        final bridgeUrl = bridge.lastUrl!;
        final bridgeId =
            bridge.promptHistoryBridgeId ?? _service.bridgeIdForUrl(bridgeUrl);
        if (bridgeId != null) {
          await _service.syncBridge(
            PromptHistorySyncTarget(
              bridgeId: bridgeId,
              bridgeUrl: bridgeUrl,
              bridgeName: bridgeId,
            ),
          );
        }
      }

      final prompts = await _service.getPrompts(
        sort: state.sortOrder,
        filters: state.filters,
        currentProjectPath: _currentProjectPath,
        currentBridgeId: _currentBridgeId,
        limit: _pageSize,
        offset: 0,
      );

      emit(
        state.copyWith(
          prompts: prompts,
          isLoading: false,
          hasMore: prompts.length >= _pageSize,
        ),
      );
    } catch (e) {
      logger.error('[PromptHistoryCubit] load failed', e);
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;

    emit(state.copyWith(isLoading: true));

    try {
      final prompts = await _service.getPrompts(
        sort: state.sortOrder,
        filters: state.filters,
        currentProjectPath: _currentProjectPath,
        currentBridgeId: _currentBridgeId,
        limit: _pageSize,
        offset: state.prompts.length,
      );

      emit(
        state.copyWith(
          prompts: [...state.prompts, ...prompts],
          isLoading: false,
          hasMore: prompts.length >= _pageSize,
        ),
      );
    } catch (e) {
      logger.error('[PromptHistoryCubit] loadMore failed', e);
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> cycleSortOrder() async {
    final next = switch (state.sortOrder) {
      PromptSortOrder.frequency => PromptSortOrder.recency,
      PromptSortOrder.recency => PromptSortOrder.favoritesFirst,
      PromptSortOrder.favoritesFirst => PromptSortOrder.frequency,
    };
    emit(state.copyWith(sortOrder: next));
    await load();
  }

  Future<void> restorePreferences({
    required PromptHistoryFilters filters,
    required bool filtersExpanded,
    bool syncFirst = false,
  }) async {
    emit(state.copyWith(filters: filters, filtersExpanded: filtersExpanded));
    await load(syncFirst: syncFirst);
  }

  Future<void> toggleFiltersExpanded() async {
    final next = !state.filtersExpanded;
    await _service.setFiltersExpanded(next);
    emit(state.copyWith(filtersExpanded: next));
  }

  Future<void> setFilters(
    PromptHistoryFilters filters, {
    bool persist = true,
    bool syncFirst = false,
  }) async {
    if (persist) {
      await _service.setDefaultFilters(filters);
    }
    emit(state.copyWith(filters: filters));
    await load(syncFirst: syncFirst);
  }

  Future<void> toggleFavorite(PromptHistoryEntry entry) async {
    await _service.toggleFavorite(
      entry.id,
      sources: entry.sources,
      bridgeService: _bridgeService,
    );
    await load();
  }

  Future<void> delete(PromptHistoryEntry entry) async {
    await _service.delete(
      entry.id,
      sources: entry.sources,
      bridgeService: _bridgeService,
    );
    await load();
  }
}
