import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final providerStr = prefs.getString('session_list_provider');
    final namedOnly = prefs.getBool('session_list_named_only');

    var provider = ProviderFilter.all;
    if (providerStr == ProviderFilter.claude.name) {
      provider = ProviderFilter.claude;
    } else if (providerStr == ProviderFilter.codex.name) {
      provider = ProviderFilter.codex;
    }

    emit(
      state.copyWith(providerFilter: provider, namedOnly: namedOnly ?? false),
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
        isInitialLoading: false,
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

  /// Toggle provider filter: All → Claude → Codex → All.
  void toggleProviderFilter() async {
    final next = switch (state.providerFilter) {
      ProviderFilter.all => ProviderFilter.claude,
      ProviderFilter.claude => ProviderFilter.codex,
      ProviderFilter.codex => ProviderFilter.all,
    };
    emit(state.copyWith(providerFilter: next));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_list_provider', next.name);
  }

  /// Toggle named-only filter on/off.
  void toggleNamedOnly() async {
    final next = !state.namedOnly;
    emit(state.copyWith(namedOnly: next));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_list_named_only', next);
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
        sessions: const [],
        selectedProject: null,
        searchQuery: '',
        accumulatedProjectPaths: const {},
        isLoadingMore: false,
        isInitialLoading: true,
        providerFilter: ProviderFilter.all,
        namedOnly: false,
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
