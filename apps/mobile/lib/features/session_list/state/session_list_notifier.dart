import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/messages.dart';
import '../../../providers/bridge_providers.dart';
import '../../../services/bridge_service.dart';
import 'session_list_state.dart';

part 'session_list_notifier.g.dart';

/// Manages session list state: sessions, filters, pagination, and
/// accumulated project paths.
///
/// Subscribes to [BridgeService.recentSessionsStream] and
/// [BridgeService.projectHistoryStream] to accumulate project paths
/// and track session data.
@riverpod
class SessionListNotifier extends _$SessionListNotifier {
  late final BridgeService _bridge;
  StreamSubscription<List<RecentSession>>? _recentSub;
  StreamSubscription<List<String>>? _projectHistorySub;

  @override
  SessionListState build() {
    _bridge = ref.read(bridgeServiceProvider);

    _recentSub = _bridge.recentSessionsStream.listen(_onSessionsUpdate);
    _projectHistorySub =
        _bridge.projectHistoryStream.listen(_onProjectHistoryUpdate);

    ref.onDispose(() {
      _recentSub?.cancel();
      _projectHistorySub?.cancel();
    });

    return const SessionListState();
  }

  void _onSessionsUpdate(List<RecentSession> sessions) {
    final newPaths = sessions
        .map((s) => s.projectPath)
        .where((p) => p.isNotEmpty)
        .toSet();
    final current = state.accumulatedProjectPaths;
    final merged =
        newPaths.difference(current).isNotEmpty
            ? {...current, ...newPaths}
            : current;

    state = state.copyWith(
      sessions: sessions,
      hasMore: _bridge.recentSessionsHasMore,
      isLoadingMore: false,
      accumulatedProjectPaths: merged,
    );
  }

  void _onProjectHistoryUpdate(List<String> projects) {
    if (projects.isEmpty) return;
    final current = state.accumulatedProjectPaths;
    final newPaths = projects.toSet();
    if (newPaths.difference(current).isNotEmpty) {
      state = state.copyWith(
        accumulatedProjectPaths: {...current, ...newPaths},
      );
    }
  }

  // ---- Filter commands (Path B) ----

  /// Switch project filter. Resets sessions on the server side and fetches
  /// from offset 0 for the selected project.
  void selectProject(String? projectPath) {
    final projectName =
        projectPath != null ? projectPath.split('/').last : null;
    state = state.copyWith(selectedProject: projectName);
    _bridge.switchProjectFilter(projectPath);
  }

  /// Set date filter (client-side only).
  void setDateFilter(DateFilter filter) {
    state = state.copyWith(dateFilter: filter);
  }

  /// Set search query (client-side only).
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Load more sessions (pagination).
  void loadMore() {
    state = state.copyWith(isLoadingMore: true);
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
    state = state.copyWith(
      selectedProject: null,
      dateFilter: DateFilter.all,
      searchQuery: '',
      accumulatedProjectPaths: const {},
      isLoadingMore: false,
    );
  }
}
