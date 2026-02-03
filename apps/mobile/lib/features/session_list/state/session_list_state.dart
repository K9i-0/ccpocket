import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'session_list_state.freezed.dart';

/// Date filter period for session list.
enum DateFilter { all, today, thisWeek, thisMonth }

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

    /// Client-side project name filter (null = show all).
    String? selectedProject,

    /// Client-side date filter.
    @Default(DateFilter.all) DateFilter dateFilter,

    /// Client-side text search query.
    @Default('') String searchQuery,

    /// Accumulated project paths from all loaded sessions + project history.
    /// Used for the "New Session" project picker.
    @Default({}) Set<String> accumulatedProjectPaths,
  }) = _SessionListState;
}
