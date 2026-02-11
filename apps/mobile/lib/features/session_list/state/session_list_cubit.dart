import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'session_list_state.dart';

/// Manages session list state: sessions, filters, pagination, and
/// accumulated project paths.
///
/// Subscribes to [BridgeService.recentSessionsStream] and
/// [BridgeService.projectHistoryStream] to accumulate project paths
/// and track session data.
class SessionListCubit extends Cubit<SessionListState> {
  final BridgeService _bridge;
  StreamSubscription<List<RecentSession>>? _recentSub;
  StreamSubscription<List<String>>? _projectHistorySub;

  SessionListCubit({required BridgeService bridge})
    : _bridge = bridge,
      super(const SessionListState()) {
    _recentSub = _bridge.recentSessionsStream.listen(_onSessionsUpdate);
    _projectHistorySub = _bridge.projectHistoryStream.listen(
      _onProjectHistoryUpdate,
    );
  }

  void _onSessionsUpdate(List<RecentSession> sessions) {
    final newPaths = sessions
        .map((s) => s.projectPath)
        .where((p) => p.isNotEmpty)
        .toSet();
    final current = state.accumulatedProjectPaths;
    final merged = newPaths.difference(current).isNotEmpty
        ? {...current, ...newPaths}
        : current;

    emit(
      state.copyWith(
        sessions: sessions,
        hasMore: _bridge.recentSessionsHasMore,
        isLoadingMore: false,
        accumulatedProjectPaths: merged,
      ),
    );
  }

  void _onProjectHistoryUpdate(List<String> projects) {
    if (projects.isEmpty) return;
    final current = state.accumulatedProjectPaths;
    final newPaths = projects.toSet();
    if (newPaths.difference(current).isNotEmpty) {
      emit(state.copyWith(accumulatedProjectPaths: {...current, ...newPaths}));
    }
  }

  // ---- Filter commands ----

  /// Switch project filter. Resets sessions on the server side and fetches
  /// from offset 0 for the selected project.
  void selectProject(String? projectPath) {
    final projectName = projectPath?.split('/').last;
    emit(state.copyWith(selectedProject: projectName));
    _bridge.switchProjectFilter(projectPath);
  }

  /// Set search query (client-side only).
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Load more sessions (pagination).
  void loadMore() {
    emit(state.copyWith(isLoadingMore: true));
    _bridge.loadMoreRecentSessions();
  }

  /// Request fresh data from the server.
  void refresh() {
    _bridge.requestSessionList();
    _bridge.requestRecentSessions(
      offset: 0,
      projectPath: _bridge.currentProjectFilter,
    );
    _bridge.requestProjectHistory();
  }

  /// Reset all filter state (used on disconnect).
  void resetFilters() {
    emit(
      state.copyWith(
        selectedProject: null,
        searchQuery: '',
        accumulatedProjectPaths: const {},
        isLoadingMore: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _recentSub?.cancel();
    _projectHistorySub?.cancel();
    return super.close();
  }
}
