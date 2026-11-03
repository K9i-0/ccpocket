import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/messages.dart';
import '../../../models/new_session_tab.dart';
import '../../../services/bridge_service.dart';
import 'recent_session_filters.dart';
import 'session_list_state.dart';

const _collapsedProjectPathsKey = 'session_list_collapsed_project_paths';
const _pinnedSessionKeysKey = 'session_list_pinned_session_keys_v1';
const _pinnedProjectPathsKey = 'session_list_pinned_project_paths_v1';
const _projectInitialSessionDisplayLimit = 5;
const _projectSessionDisplayPageSize = 20;

String sessionPinKey({
  required String? provider,
  required String projectPath,
  required String sessionId,
}) => '${provider ?? Provider.claude.value}\n$projectPath\n$sessionId';

String recentSessionPinKey(RecentSession session) => sessionPinKey(
  provider: session.provider,
  projectPath: session.projectPath,
  sessionId: session.sessionId,
);

String? runningSessionPinKey(SessionInfo session) {
  final providerSessionId = session.claudeSessionId;
  if (providerSessionId == null || providerSessionId.isEmpty) return null;
  return sessionPinKey(
    provider: session.provider,
    projectPath: session.projectPath,
    sessionId: providerSessionId,
  );
}

/// Parse the provider-qualified identity from a [sessionPinKey].
RecentSessionRef? recentSessionRefFromPinKey(String key) {
  final parts = key.split('\n');
  if (parts.length < 3) return null;
  final provider = parts.first;
  final sessionId = parts.last;
  if (sessionId.isEmpty ||
      (provider != Provider.claude.value && provider != Provider.codex.value)) {
    return null;
  }
  return (provider: provider, sessionId: sessionId);
}

/// Provider-qualified identity (`provider:sessionId`) of a stored pin key.
///
/// Pins are matched by this identity rather than the full key, because the
/// key also contains a `projectPath` that differs between a running worktree
/// session, the repository-grouped listing and the Codex `thread/list` shape.
String? pinIdentityFromKey(String key) {
  final ref = recentSessionRefFromPinKey(key);
  return ref == null ? null : '${ref.provider}:${ref.sessionId}';
}

String recentSessionPinIdentity(RecentSession session) =>
    '${session.provider ?? Provider.claude.value}:${session.sessionId}';

String? runningSessionPinIdentity(SessionInfo session) {
  final providerSessionId = session.claudeSessionId;
  if (providerSessionId == null || providerSessionId.isEmpty) return null;
  return '${session.provider ?? Provider.claude.value}:$providerSessionId';
}

/// Identities of every stored pin key.
Set<String> pinIdentitiesOf(Iterable<String> pinKeys) =>
    pinKeys.map(pinIdentityFromKey).nonNulls.toSet();

/// Toggle the pin for [key]: removes every stored key sharing its identity,
/// or adds [key] when none was stored.
Set<String> togglePinKey(Set<String> pinKeys, String key) {
  final identity = pinIdentityFromKey(key);
  final next = {...pinKeys};
  final removed = identity == null
      ? next.remove(key)
      : (next..removeWhere((k) => pinIdentityFromKey(k) == identity)).length !=
            pinKeys.length;
  if (!removed) next.add(key);
  return next;
}

List<T> prioritizePinned<T>(
  Iterable<T> items, {
  required bool Function(T item) isPinned,
  bool Function(T item)? isProjectPinned,
}) {
  final pinned = <T>[];
  final pinnedProjects = <T>[];
  final others = <T>[];
  for (final item in items) {
    if (isPinned(item)) {
      pinned.add(item);
    } else if (isProjectPinned?.call(item) ?? false) {
      pinnedProjects.add(item);
    } else {
      others.add(item);
    }
  }
  return [...pinned, ...pinnedProjects, ...others];
}

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
  StreamSubscription<ServerMessage>? _messageSub;
  StreamSubscription<void>? _filtersAvailableSub;
  Timer? _searchDebounce;
  late final Future<void> _preferencesLoaded;

  /// Whether a first-page list request went out (possibly before the pinned
  /// sessions were loaded from preferences).
  bool _hasRequestedList = false;

  SessionListCubit({required BridgeService bridge})
    : _bridge = bridge,
      super(const SessionListState()) {
    _recentSub = _bridge.recentSessionsStream.listen(_onSessionsUpdate);
    _projectHistorySub = _bridge.projectHistoryStream.listen(
      _onProjectHistoryUpdate,
    );
    _messageSub = _bridge.messages.listen(_onBridgeMessage);
    // A filtered request built while reconnecting goes out without the
    // filters; ask again once the Bridge announces them.
    _filtersAvailableSub = _bridge.recentSessionFiltersAvailable.listen((_) {
      if (!isClosed && state.filters.isActive) _requestWithCurrentFilters();
    });
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
        prefs.getStringList(_pinnedSessionKeysKey)?.toSet() ?? const <String>{};
    final pinnedProjectPaths =
        prefs.getStringList(_pinnedProjectPathsKey)?.toSet() ??
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
    _pushPinnedSessionsToBridge();
    // The first page may have been requested before preferences loaded; ask
    // again so the Bridge can return the pinned sessions with it.
    if (_hasRequestedList && pinnedSessionKeys.isNotEmpty) {
      _requestWithCurrentFilters();
    }
  }

  void _pushPinnedSessionsToBridge() {
    _bridge.setPinnedRecentSessions(
      state.pinnedSessionKeys.map(recentSessionRefFromPinKey).nonNulls,
    );
  }

  void _onSessionsUpdate(List<RecentSession> sessions) {
    final response = _bridge.lastRecentSessionsMessage;
    final projectPath = response?.projectFilterKey;
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

  void _onBridgeMessage(ServerMessage message) {
    if (message is! ErrorMessage ||
        message.errorCode != 'recent_sessions_failed' ||
        isClosed) {
      return;
    }
    final projectPath = message.projectId?.isNotEmpty == true
        ? 'project:${message.projectId}'
        : message.path;
    if (message.requestScope == 'project' &&
        projectPath != null &&
        projectPath.isNotEmpty) {
      emit(
        state.copyWith(
          loadingProjectPaths: {...state.loadingProjectPaths}
            ..remove(projectPath),
        ),
      );
      return;
    }
    emit(state.copyWith(isInitialLoading: false, isLoadingMore: false));
  }

  // ---- Filter commands (all trigger server re-fetch) ----

  /// Switch to a single project filter (or none). Resets sessions on the
  /// server side and fetches from offset 0 for the selected project.
  void selectProject(String? projectPath) {
    setProjectFilters({?projectPath});
  }

  /// Select any number of projects. Two or more require
  /// [BridgeService.supportsRecentSessionFilters].
  void setProjectFilters(Set<String> projectKeys) {
    _updateFilters(
      state.filters.copyWith(
        projectKeys: projectKeys.where((key) => key.isNotEmpty).toSet(),
      ),
    );
  }

  void setDateFilter(RecentDateFilter? dateFilter) {
    _updateFilters(
      dateFilter == null
          ? state.filters.copyWith(clearDateFilter: true)
          : state.filters.copyWith(dateFilter: dateFilter),
    );
  }

  void togglePinnedOnly() {
    _updateFilters(
      state.filters.copyWith(pinnedOnly: !state.filters.pinnedOnly),
    );
  }

  /// Apply everything the advanced search screen edits in one request.
  void applyAdvancedSearch({
    required String searchQuery,
    required RecentSessionFilters filters,
    required ProviderFilter providerFilter,
    required bool namedOnly,
  }) {
    _searchDebounce?.cancel();
    final providerChanged = providerFilter != state.providerFilter;
    final namedChanged = namedOnly != state.namedOnly;
    emit(
      state.copyWith(
        searchQuery: searchQuery,
        filters: filters,
        providerFilter: providerFilter,
        namedOnly: namedOnly,
        isInitialLoading: true,
      ),
    );
    _requestWithCurrentFilters();
    if (providerChanged || namedChanged) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('session_list_provider', providerFilter.name);
        prefs.setBool('session_list_named_only', namedOnly);
      });
    }
  }

  /// Clear search text and every filter except the AI tool preference.
  void clearFilters() {
    _searchDebounce?.cancel();
    emit(
      state.copyWith(
        searchQuery: '',
        filters: const RecentSessionFilters(),
        namedOnly: false,
        isInitialLoading: true,
      ),
    );
    _requestWithCurrentFilters();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('session_list_named_only', false),
    );
  }

  void _updateFilters(RecentSessionFilters next) {
    if (next == state.filters) return;
    emit(state.copyWith(filters: next, isInitialLoading: true));
    _requestWithCurrentFilters();
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
    // Pinned extras are not part of the loaded pages, so they must not shift
    // the project-scoped offset.
    final loadedCount = state.sessions
        .where(
          (session) =>
              session.workspaceGroupKey == projectPath &&
              !_bridge.isPinnedRecentExtra(session),
        )
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
      pinIdentitiesOf(state.pinnedSessionKeys)
          .contains(recentSessionPinIdentity(session));

  bool isRunningSessionPinned(SessionInfo session) {
    final identity = runningSessionPinIdentity(session);
    return identity != null &&
        pinIdentitiesOf(state.pinnedSessionKeys).contains(identity);
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
    final next = togglePinKey(state.pinnedSessionKeys, key);
    emit(state.copyWith(pinnedSessionKeys: next));
    _pushPinnedSessionsToBridge();
    // Pins define the pinned-only result set.
    if (state.filters.pinnedOnly) _requestWithCurrentFilters();
    await _persistStringSet(_pinnedSessionKeysKey, next);
  }

  Future<void> toggleProjectPinned(String projectPath) async {
    if (projectPath.isEmpty) return;
    await _preferencesLoaded;
    if (isClosed) return;
    final next = {...state.pinnedProjectPaths};
    if (!next.remove(projectPath)) next.add(projectPath);
    emit(state.copyWith(pinnedProjectPaths: next));
    if (state.filters.pinnedOnly) _requestWithCurrentFilters();
    await _persistStringSet(_pinnedProjectPathsKey, next);
  }

  Future<void> _persistStringSet(String key, Set<String> values) async {
    final sorted = values.toList()..sort();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, sorted);
  }

  /// Request fresh data from the server.
  void refresh() {
    _bridge.requestSessionList();
    _requestWithCurrentFilters();
    _bridge.requestProjectHistory();
    _bridge.requestProjects();
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
        filters: const RecentSessionFilters(),
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
    _hasRequestedList = true;
    final filters = state.filters;
    final supportsExtra = _bridge.supportsRecentSessionFilters;
    final projectKeys = filters.projectKeys.toList()..sort();
    // Without the capability only one project can be sent.
    final singleProject = projectKeys.length == 1 || !supportsExtra
        ? projectKeys.firstOrNull
        : null;
    final dateFilter = filters.dateFilter;
    _bridge.switchFilter(
      projectPath: singleProject,
      provider: _providerToString(state.providerFilter),
      namedOnly: state.namedOnly ? true : null,
      searchQuery: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      extraFilters: RecentSessionsExtraFilters(
        // Kept even when only the first project can be sent, so the request
        // counts as filtered and is repeated once the capability arrives.
        projectKeys: projectKeys.length > 1 ? projectKeys : const [],
        // Resolved at send time so "today" stays current on later pages.
        resolveDateRange: dateFilter == null
            ? null
            : () {
                final range = dateFilter.resolve(DateTime.now());
                return (
                  after: range.start.toUtc().toIso8601String(),
                  before: range.end?.toUtc().toIso8601String(),
                );
              },
        dateField:
            dateFilter != null && filters.dateField == RecentDateField.created
            ? 'created'
            : null,
        pinnedOnly: filters.pinnedOnly,
        pinnedProjectKeys: filters.pinnedOnly
            ? (state.pinnedProjectPaths.toList()..sort())
            : const [],
        searchContent: filters.searchContent && state.searchQuery.isNotEmpty,
      ),
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
    _messageSub?.cancel();
    _filtersAvailableSub?.cancel();
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
