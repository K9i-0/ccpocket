import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../models/new_session_tab.dart';
import '../../../services/bridge_service.dart';
import '../../../utils/session_ordering.dart';
import 'session_list_state.dart';

export '../../../utils/session_ordering.dart';

const _collapsedProjectPathsKey = 'session_list_collapsed_project_paths';
const _projectInitialSessionDisplayLimit = 5;
const _projectSessionDisplayPageSize = 20;

/// Manages session list state: sessions, filters, pagination, and
/// accumulated project paths.
///
/// All filters (project, provider, namedOnly, searchQuery) are applied
/// server-side. Filter changes trigger a re-fetch from offset 0 with
/// a skeleton loading state.
class SessionListCubit extends Cubit<SessionListState> {
  final BridgeService _bridge;
  StreamSubscription<List<RecentSession>>? _recentSub;
  StreamSubscription<List<String>>? _projectHistorySub;
  Timer? _searchDebounce;
  late final Future<void> _preferencesLoaded;

  SessionListCubit({required BridgeService bridge})
    : _bridge = bridge,
      super(const SessionListState()) {
    _recentSub = _bridge.recentSessionsStream.listen(_onSessionsUpdate);
    _projectHistorySub = _bridge.projectHistoryStream.listen(
      _onProjectHistoryUpdate,
    );
    _preferencesLoaded = _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final providerStr = prefs.getString('session_list_provider');
    final namedOnly = prefs.getBool('session_list_named_only');
    final collapsedProjectPaths =
        prefs.getStringList(_collapsedProjectPathsKey)?.toSet() ??
        const <String>{};
    final pinnedSessionKeys =
        prefs.getStringList(pinnedSessionKeysPreferenceKey)?.toSet() ??
        const <String>{};
    final pinnedProjectPaths =
        prefs.getStringList(pinnedProjectPathsPreferenceKey)?.toSet() ??
        const <String>{};

    var provider = ProviderFilter.all;
    if (providerStr == ProviderFilter.claude.name) {
      provider = ProviderFilter.claude;
    } else if (providerStr == ProviderFilter.codex.name) {
      provider = ProviderFilter.codex;
    }

    if (isClosed) return;
    emit(
      state.copyWith(
        providerFilter: provider,
        namedOnly: namedOnly ?? false,
        collapsedProjectPaths: collapsedProjectPaths,
        pinnedSessionKeys: pinnedSessionKeys,
        pinnedProjectPaths: pinnedProjectPaths,
      ),
    );
  }

  void _onSessionsUpdate(List<RecentSession> sessions) {
    final response = _bridge.lastRecentSessionsMessage;
    final projectPath = response?.projectPath;
    final isProjectPage =
        response?.requestScope == 'project' &&
        projectPath != null &&
        projectPath.isNotEmpty;
    final newPaths = sessions
        .map((s) => s.projectPath)
        .where((p) => p.isNotEmpty)
        .toSet();
    final current = state.accumulatedProjectPaths;
    final merged = newPaths.difference(current).isNotEmpty
        ? {...current, ...newPaths}
        : current;

    if (isProjectPage) {
      emit(
        state.copyWith(
          sessions: sessions,
          isInitialLoading: false,
          accumulatedProjectPaths: merged,
          loadingProjectPaths: {...state.loadingProjectPaths}
            ..remove(projectPath),
          exhaustedProjectPaths: response!.hasMore
              ? ({...state.exhaustedProjectPaths}..remove(projectPath))
              : {...state.exhaustedProjectPaths, projectPath},
        ),
      );
      return;
    }

    final hasMore = _bridge.recentSessionsHasMore;
    final isFirstPage = (response?.offset ?? 0) == 0;
    emit(
      state.copyWith(
        sessions: sessions,
        hasMore: hasMore,
        isLoadingMore: false,
        isInitialLoading: false,
        accumulatedProjectPaths: merged,
        loadingProjectPaths: const {},
        exhaustedProjectPaths: hasMore ? const {} : merged,
        projectSessionDisplayLimits: isFirstPage
            ? const {}
            : state.projectSessionDisplayLimits,
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

  // ---- Filter commands (all trigger server re-fetch) ----

  /// Switch project filter. Resets sessions on the server side and fetches
  /// from offset 0 for the selected project.
  void selectProject(String? projectPath) {
    emit(state.copyWith(isInitialLoading: true));
    _bridge.switchFilter(
      projectPath: projectPath,
      provider: _providerToString(state.providerFilter),
      namedOnly: state.namedOnly ? true : null,
      searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
    );
  }

  /// Set search query with debounce (server-side).
  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (isClosed) return;
      emit(state.copyWith(isInitialLoading: true));
      _requestWithCurrentFilters();
    });
  }

  /// Toggle provider filter: All → Codex → Claude → All.
  void toggleProviderFilter({List<ProviderFilter>? allowedFilters}) {
    final options = allowedFilters == null || allowedFilters.isEmpty
        ? const [
            ProviderFilter.all,
            ProviderFilter.codex,
            ProviderFilter.claude,
          ]
        : allowedFilters;
    final currentIndex = options.indexOf(state.providerFilter);
    final next = options[(currentIndex + 1) % options.length];
    setProviderFilter(next);
  }

  void setProviderFilter(ProviderFilter next) {
    if (state.providerFilter == next) return;
    emit(state.copyWith(providerFilter: next, isInitialLoading: true));
    _requestWithCurrentFilters();
    // Persist preference in background (fire-and-forget).
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('session_list_provider', next.name),
    );
  }

  void applyEnabledAgents(List<NewSessionTab> enabledTabs) {
    final allowed = providerFiltersForEnabledTabs(enabledTabs);
    final next = coerceProviderFilter(state.providerFilter, allowed);
    setProviderFilter(next);
  }

  /// Toggle named-only filter on/off.
  void toggleNamedOnly() async {
    final next = !state.namedOnly;
    emit(state.copyWith(namedOnly: next, isInitialLoading: true));
    _requestWithCurrentFilters();
    // Persist preference in background (fire-and-forget).
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('session_list_named_only', next),
    );
  }

  /// Load more sessions (pagination).
  void loadMore() {
    emit(state.copyWith(isLoadingMore: true));
    _bridge.loadMoreRecentSessions();
  }

  /// Load the next project-scoped page without replacing other projects.
  void loadMoreProject(String projectPath) {
    if (projectPath.isEmpty ||
        state.loadingProjectPaths.contains(projectPath)) {
      return;
    }
    final loadedCount = state.sessions
        .where((session) => session.projectPath == projectPath)
        .length;
    final currentLimit =
        state.projectSessionDisplayLimits[projectPath] ??
        _projectInitialSessionDisplayLimit;
    final nextLimit = currentLimit + _projectSessionDisplayPageSize;
    final shouldFetch =
        nextLimit > loadedCount &&
        !state.exhaustedProjectPaths.contains(projectPath);
    emit(
      state.copyWith(
        projectSessionDisplayLimits: {
          ...state.projectSessionDisplayLimits,
          projectPath: nextLimit,
        },
        loadingProjectPaths: shouldFetch
            ? {...state.loadingProjectPaths, projectPath}
            : state.loadingProjectPaths,
      ),
    );
    if (!shouldFetch) return;
    _bridge.loadMoreRecentSessions(
      projectPath: projectPath,
      offset: loadedCount,
      pageSize: _projectSessionDisplayPageSize,
      requestScope: 'project',
    );
  }

  void toggleProjectCollapsed(String projectPath) {
    if (projectPath.isEmpty) return;
    final next = {...state.collapsedProjectPaths};
    if (!next.remove(projectPath)) {
      next.add(projectPath);
    }
    emit(state.copyWith(collapsedProjectPaths: next));
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setStringList(_collapsedProjectPathsKey, next.toList()),
    );
  }

  bool isRecentSessionPinned(RecentSession session) =>
      state.pinnedSessionKeys.contains(recentSessionPinKey(session));

  bool isRunningSessionPinned(SessionInfo session) {
    final key = runningSessionPinKey(session);
    return key != null && state.pinnedSessionKeys.contains(key);
  }

  bool isProjectPinned(String projectPath) =>
      state.pinnedProjectPaths.contains(projectPath);

  Future<void> toggleRecentSessionPinned(RecentSession session) async {
    await _preferencesLoaded;
    if (isClosed) return;
    await _toggleSessionPin(recentSessionPinKey(session));
  }

  Future<void> toggleRunningSessionPinned(SessionInfo session) async {
    final key = runningSessionPinKey(session);
    if (key == null) return;
    await _preferencesLoaded;
    if (isClosed) return;
    await _toggleSessionPin(key);
  }

  Future<void> _toggleSessionPin(String key) async {
    final next = {...state.pinnedSessionKeys};
    if (!next.remove(key)) next.add(key);
    emit(state.copyWith(pinnedSessionKeys: next));
    await _persistStringSet(pinnedSessionKeysPreferenceKey, next);
  }

  Future<void> toggleProjectPinned(String projectPath) async {
    if (projectPath.isEmpty) return;
    await _preferencesLoaded;
    if (isClosed) return;
    final next = {...state.pinnedProjectPaths};
    if (!next.remove(projectPath)) next.add(projectPath);
    emit(state.copyWith(pinnedProjectPaths: next));
    await _persistStringSet(pinnedProjectPathsPreferenceKey, next);
  }

  Future<void> _persistStringSet(String key, Set<String> values) async {
    final sorted = values.toList()..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, sorted);
    notifySessionOrderingChanged();
  }

  /// Request fresh data from the server.
  void refresh() {
    _bridge.requestSessionList();
    _requestWithCurrentFilters();
    _bridge.requestProjectHistory();
  }

  /// Reset all filter state (used on disconnect).
  void resetFilters() {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        sessions: const [],
        searchQuery: '',
        accumulatedProjectPaths: const {},
        loadingProjectPaths: const {},
        exhaustedProjectPaths: const {},
        projectSessionDisplayLimits: const {},
        isLoadingMore: false,
        isInitialLoading: true,
        providerFilter: ProviderFilter.all,
        namedOnly: false,
      ),
    );
  }

  /// Optimistically update a session's name in the local state.
  void updateSessionName(String sessionId, String? name) {
    final updated = state.sessions.map((s) {
      if (s.sessionId == sessionId) {
        return name == null
            ? s.copyWithName(clearName: true)
            : s.copyWithName(name: name);
      }
      return s;
    }).toList();
    emit(state.copyWith(sessions: updated));
  }

  // ---- Private helpers ----

  /// Send a re-fetch request with all current filters applied.
  void _requestWithCurrentFilters() {
    _bridge.switchFilter(
      projectPath: _bridge.currentProjectFilter,
      provider: _providerToString(state.providerFilter),
      namedOnly: state.namedOnly ? true : null,
      searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
    );
  }

  /// Convert [ProviderFilter] enum to the wire-format string (or null for all).
  static String? _providerToString(ProviderFilter f) => switch (f) {
    ProviderFilter.all => null,
    ProviderFilter.claude => 'claude',
    ProviderFilter.codex => 'codex',
  };

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    _recentSub?.cancel();
    _projectHistorySub?.cancel();
    return super.close();
  }
}

List<ProviderFilter> providerFiltersForEnabledTabs(
  List<NewSessionTab> enabledTabs,
) {
  return switch (enabledAgentsModeFromTabs(enabledTabs)) {
    EnabledAgentsMode.both => const [
      ProviderFilter.all,
      ProviderFilter.codex,
      ProviderFilter.claude,
    ],
    EnabledAgentsMode.codex => const [ProviderFilter.codex],
    EnabledAgentsMode.claude => const [ProviderFilter.claude],
  };
}

ProviderFilter coerceProviderFilter(
  ProviderFilter current,
  List<ProviderFilter> allowedFilters,
) {
  if (allowedFilters.contains(current)) return current;
  return allowedFilters.firstOrNull ?? ProviderFilter.all;
}
