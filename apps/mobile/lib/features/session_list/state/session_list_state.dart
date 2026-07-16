import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'session_list_state.freezed.dart';

/// Provider filter for recent sessions (toggles: All → Codex → Claude → All).
enum ProviderFilter { all, claude, codex }

/// Core state for the session list screen.
@freezed
abstract class SessionListState with _$SessionListState {
  const factory SessionListState({
    /// All sessions loaded from the server (including paginated results).
    @Default([]) List<RecentSession> sessions,

    /// Whether there are more sessions available on the server.
    @Default(false) bool hasMore,

    /// Loading more sessions (pagination).
    @Default(false) bool isLoadingMore,

    /// Initial loading (true until the first recent sessions response arrives).
    @Default(true) bool isInitialLoading,

    /// Client-side text search query (bound to the TextField, sent to server
    /// after debounce).
    @Default('') String searchQuery,

    /// Accumulated project paths from all loaded sessions + project history.
    /// Used for the "New Session" project picker.
    @Default({}) Set<String> accumulatedProjectPaths,

    /// Project paths collapsed by the user. Defaults to empty because project
    /// groups are expanded by default.
    @Default({}) Set<String> collapsedProjectPaths,

    /// Project paths currently loading an additional page.
    @Default({}) Set<String> loadingProjectPaths,

    /// Project paths known to have no more recent sessions to load.
    @Default({}) Set<String> exhaustedProjectPaths,

    /// Per-project number of recent sessions currently visible in the list.
    @Default({}) Map<String, int> projectSessionDisplayLimits,

    /// Stable keys for sessions pinned on this device.
    @Default({}) Set<String> pinnedSessionKeys,

    /// Project paths pinned on this device.
    @Default({}) Set<String> pinnedProjectPaths,

    /// Provider filter (All / Claude / Codex). Applied server-side.
    @Default(ProviderFilter.all) ProviderFilter providerFilter,

    /// Named-only filter toggle. Applied server-side.
    @Default(false) bool namedOnly,
  }) = _SessionListState;
}
