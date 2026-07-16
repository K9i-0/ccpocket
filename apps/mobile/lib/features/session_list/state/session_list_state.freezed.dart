// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionListState {

/// All sessions loaded from the server (including paginated results).
 List<RecentSession> get sessions;/// Whether there are more sessions available on the server.
 bool get hasMore;/// Loading more sessions (pagination).
 bool get isLoadingMore;/// Initial loading (true until the first recent sessions response arrives).
 bool get isInitialLoading;/// Client-side text search query (bound to the TextField, sent to server
/// after debounce).
 String get searchQuery;/// Accumulated project paths from all loaded sessions + project history.
/// Used for the "New Session" project picker.
 Set<String> get accumulatedProjectPaths;/// Project paths collapsed by the user. Defaults to empty because project
/// groups are expanded by default.
 Set<String> get collapsedProjectPaths;/// Project paths currently loading an additional page.
 Set<String> get loadingProjectPaths;/// Project paths known to have no more recent sessions to load.
 Set<String> get exhaustedProjectPaths;/// Per-project number of recent sessions currently visible in the list.
 Map<String, int> get projectSessionDisplayLimits;/// Stable keys for sessions pinned on this device.
 Set<String> get pinnedSessionKeys;/// Project paths pinned on this device.
 Set<String> get pinnedProjectPaths;/// Provider filter (All / Claude / Codex). Applied server-side.
 ProviderFilter get providerFilter;/// Named-only filter toggle. Applied server-side.
 bool get namedOnly;
/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListStateCopyWith<SessionListState> get copyWith => _$SessionListStateCopyWithImpl<SessionListState>(this as SessionListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListState&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.isInitialLoading, isInitialLoading) || other.isInitialLoading == isInitialLoading)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other.accumulatedProjectPaths, accumulatedProjectPaths)&&const DeepCollectionEquality().equals(other.collapsedProjectPaths, collapsedProjectPaths)&&const DeepCollectionEquality().equals(other.loadingProjectPaths, loadingProjectPaths)&&const DeepCollectionEquality().equals(other.exhaustedProjectPaths, exhaustedProjectPaths)&&const DeepCollectionEquality().equals(other.projectSessionDisplayLimits, projectSessionDisplayLimits)&&const DeepCollectionEquality().equals(other.pinnedSessionKeys, pinnedSessionKeys)&&const DeepCollectionEquality().equals(other.pinnedProjectPaths, pinnedProjectPaths)&&(identical(other.providerFilter, providerFilter) || other.providerFilter == providerFilter)&&(identical(other.namedOnly, namedOnly) || other.namedOnly == namedOnly));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions),hasMore,isLoadingMore,isInitialLoading,searchQuery,const DeepCollectionEquality().hash(accumulatedProjectPaths),const DeepCollectionEquality().hash(collapsedProjectPaths),const DeepCollectionEquality().hash(loadingProjectPaths),const DeepCollectionEquality().hash(exhaustedProjectPaths),const DeepCollectionEquality().hash(projectSessionDisplayLimits),const DeepCollectionEquality().hash(pinnedSessionKeys),const DeepCollectionEquality().hash(pinnedProjectPaths),providerFilter,namedOnly);

@override
String toString() {
  return 'SessionListState(sessions: $sessions, hasMore: $hasMore, isLoadingMore: $isLoadingMore, isInitialLoading: $isInitialLoading, searchQuery: $searchQuery, accumulatedProjectPaths: $accumulatedProjectPaths, collapsedProjectPaths: $collapsedProjectPaths, loadingProjectPaths: $loadingProjectPaths, exhaustedProjectPaths: $exhaustedProjectPaths, projectSessionDisplayLimits: $projectSessionDisplayLimits, pinnedSessionKeys: $pinnedSessionKeys, pinnedProjectPaths: $pinnedProjectPaths, providerFilter: $providerFilter, namedOnly: $namedOnly)';
}


}

/// @nodoc
abstract mixin class $SessionListStateCopyWith<$Res>  {
  factory $SessionListStateCopyWith(SessionListState value, $Res Function(SessionListState) _then) = _$SessionListStateCopyWithImpl;
@useResult
$Res call({
 List<RecentSession> sessions, bool hasMore, bool isLoadingMore, bool isInitialLoading, String searchQuery, Set<String> accumulatedProjectPaths, Set<String> collapsedProjectPaths, Set<String> loadingProjectPaths, Set<String> exhaustedProjectPaths, Map<String, int> projectSessionDisplayLimits, Set<String> pinnedSessionKeys, Set<String> pinnedProjectPaths, ProviderFilter providerFilter, bool namedOnly
});




}
/// @nodoc
class _$SessionListStateCopyWithImpl<$Res>
    implements $SessionListStateCopyWith<$Res> {
  _$SessionListStateCopyWithImpl(this._self, this._then);

  final SessionListState _self;
  final $Res Function(SessionListState) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,Object? hasMore = null,Object? isLoadingMore = null,Object? isInitialLoading = null,Object? searchQuery = null,Object? accumulatedProjectPaths = null,Object? collapsedProjectPaths = null,Object? loadingProjectPaths = null,Object? exhaustedProjectPaths = null,Object? projectSessionDisplayLimits = null,Object? pinnedSessionKeys = null,Object? pinnedProjectPaths = null,Object? providerFilter = null,Object? namedOnly = null,}) {
  return _then(_self.copyWith(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<RecentSession>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,isInitialLoading: null == isInitialLoading ? _self.isInitialLoading : isInitialLoading // ignore: cast_nullable_to_non_nullable
as bool,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,accumulatedProjectPaths: null == accumulatedProjectPaths ? _self.accumulatedProjectPaths : accumulatedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,collapsedProjectPaths: null == collapsedProjectPaths ? _self.collapsedProjectPaths : collapsedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,loadingProjectPaths: null == loadingProjectPaths ? _self.loadingProjectPaths : loadingProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,exhaustedProjectPaths: null == exhaustedProjectPaths ? _self.exhaustedProjectPaths : exhaustedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,projectSessionDisplayLimits: null == projectSessionDisplayLimits ? _self.projectSessionDisplayLimits : projectSessionDisplayLimits // ignore: cast_nullable_to_non_nullable
as Map<String, int>,pinnedSessionKeys: null == pinnedSessionKeys ? _self.pinnedSessionKeys : pinnedSessionKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,pinnedProjectPaths: null == pinnedProjectPaths ? _self.pinnedProjectPaths : pinnedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,providerFilter: null == providerFilter ? _self.providerFilter : providerFilter // ignore: cast_nullable_to_non_nullable
as ProviderFilter,namedOnly: null == namedOnly ? _self.namedOnly : namedOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionListState].
extension SessionListStatePatterns on SessionListState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionListState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionListState value)  $default,){
final _that = this;
switch (_that) {
case _SessionListState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionListState value)?  $default,){
final _that = this;
switch (_that) {
case _SessionListState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RecentSession> sessions,  bool hasMore,  bool isLoadingMore,  bool isInitialLoading,  String searchQuery,  Set<String> accumulatedProjectPaths,  Set<String> collapsedProjectPaths,  Set<String> loadingProjectPaths,  Set<String> exhaustedProjectPaths,  Map<String, int> projectSessionDisplayLimits,  Set<String> pinnedSessionKeys,  Set<String> pinnedProjectPaths,  ProviderFilter providerFilter,  bool namedOnly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionListState() when $default != null:
return $default(_that.sessions,_that.hasMore,_that.isLoadingMore,_that.isInitialLoading,_that.searchQuery,_that.accumulatedProjectPaths,_that.collapsedProjectPaths,_that.loadingProjectPaths,_that.exhaustedProjectPaths,_that.projectSessionDisplayLimits,_that.pinnedSessionKeys,_that.pinnedProjectPaths,_that.providerFilter,_that.namedOnly);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RecentSession> sessions,  bool hasMore,  bool isLoadingMore,  bool isInitialLoading,  String searchQuery,  Set<String> accumulatedProjectPaths,  Set<String> collapsedProjectPaths,  Set<String> loadingProjectPaths,  Set<String> exhaustedProjectPaths,  Map<String, int> projectSessionDisplayLimits,  Set<String> pinnedSessionKeys,  Set<String> pinnedProjectPaths,  ProviderFilter providerFilter,  bool namedOnly)  $default,) {final _that = this;
switch (_that) {
case _SessionListState():
return $default(_that.sessions,_that.hasMore,_that.isLoadingMore,_that.isInitialLoading,_that.searchQuery,_that.accumulatedProjectPaths,_that.collapsedProjectPaths,_that.loadingProjectPaths,_that.exhaustedProjectPaths,_that.projectSessionDisplayLimits,_that.pinnedSessionKeys,_that.pinnedProjectPaths,_that.providerFilter,_that.namedOnly);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RecentSession> sessions,  bool hasMore,  bool isLoadingMore,  bool isInitialLoading,  String searchQuery,  Set<String> accumulatedProjectPaths,  Set<String> collapsedProjectPaths,  Set<String> loadingProjectPaths,  Set<String> exhaustedProjectPaths,  Map<String, int> projectSessionDisplayLimits,  Set<String> pinnedSessionKeys,  Set<String> pinnedProjectPaths,  ProviderFilter providerFilter,  bool namedOnly)?  $default,) {final _that = this;
switch (_that) {
case _SessionListState() when $default != null:
return $default(_that.sessions,_that.hasMore,_that.isLoadingMore,_that.isInitialLoading,_that.searchQuery,_that.accumulatedProjectPaths,_that.collapsedProjectPaths,_that.loadingProjectPaths,_that.exhaustedProjectPaths,_that.projectSessionDisplayLimits,_that.pinnedSessionKeys,_that.pinnedProjectPaths,_that.providerFilter,_that.namedOnly);case _:
  return null;

}
}

}

/// @nodoc


class _SessionListState implements SessionListState {
  const _SessionListState({final  List<RecentSession> sessions = const [], this.hasMore = false, this.isLoadingMore = false, this.isInitialLoading = true, this.searchQuery = '', final  Set<String> accumulatedProjectPaths = const {}, final  Set<String> collapsedProjectPaths = const {}, final  Set<String> loadingProjectPaths = const {}, final  Set<String> exhaustedProjectPaths = const {}, final  Map<String, int> projectSessionDisplayLimits = const {}, final  Set<String> pinnedSessionKeys = const {}, final  Set<String> pinnedProjectPaths = const {}, this.providerFilter = ProviderFilter.all, this.namedOnly = false}): _sessions = sessions,_accumulatedProjectPaths = accumulatedProjectPaths,_collapsedProjectPaths = collapsedProjectPaths,_loadingProjectPaths = loadingProjectPaths,_exhaustedProjectPaths = exhaustedProjectPaths,_projectSessionDisplayLimits = projectSessionDisplayLimits,_pinnedSessionKeys = pinnedSessionKeys,_pinnedProjectPaths = pinnedProjectPaths;
  

/// All sessions loaded from the server (including paginated results).
 final  List<RecentSession> _sessions;
/// All sessions loaded from the server (including paginated results).
@override@JsonKey() List<RecentSession> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

/// Whether there are more sessions available on the server.
@override@JsonKey() final  bool hasMore;
/// Loading more sessions (pagination).
@override@JsonKey() final  bool isLoadingMore;
/// Initial loading (true until the first recent sessions response arrives).
@override@JsonKey() final  bool isInitialLoading;
/// Client-side text search query (bound to the TextField, sent to server
/// after debounce).
@override@JsonKey() final  String searchQuery;
/// Accumulated project paths from all loaded sessions + project history.
/// Used for the "New Session" project picker.
 final  Set<String> _accumulatedProjectPaths;
/// Accumulated project paths from all loaded sessions + project history.
/// Used for the "New Session" project picker.
@override@JsonKey() Set<String> get accumulatedProjectPaths {
  if (_accumulatedProjectPaths is EqualUnmodifiableSetView) return _accumulatedProjectPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_accumulatedProjectPaths);
}

/// Project paths collapsed by the user. Defaults to empty because project
/// groups are expanded by default.
 final  Set<String> _collapsedProjectPaths;
/// Project paths collapsed by the user. Defaults to empty because project
/// groups are expanded by default.
@override@JsonKey() Set<String> get collapsedProjectPaths {
  if (_collapsedProjectPaths is EqualUnmodifiableSetView) return _collapsedProjectPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_collapsedProjectPaths);
}

/// Project paths currently loading an additional page.
 final  Set<String> _loadingProjectPaths;
/// Project paths currently loading an additional page.
@override@JsonKey() Set<String> get loadingProjectPaths {
  if (_loadingProjectPaths is EqualUnmodifiableSetView) return _loadingProjectPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_loadingProjectPaths);
}

/// Project paths known to have no more recent sessions to load.
 final  Set<String> _exhaustedProjectPaths;
/// Project paths known to have no more recent sessions to load.
@override@JsonKey() Set<String> get exhaustedProjectPaths {
  if (_exhaustedProjectPaths is EqualUnmodifiableSetView) return _exhaustedProjectPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_exhaustedProjectPaths);
}

/// Per-project number of recent sessions currently visible in the list.
 final  Map<String, int> _projectSessionDisplayLimits;
/// Per-project number of recent sessions currently visible in the list.
@override@JsonKey() Map<String, int> get projectSessionDisplayLimits {
  if (_projectSessionDisplayLimits is EqualUnmodifiableMapView) return _projectSessionDisplayLimits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_projectSessionDisplayLimits);
}

/// Stable keys for sessions pinned on this device.
 final  Set<String> _pinnedSessionKeys;
/// Stable keys for sessions pinned on this device.
@override@JsonKey() Set<String> get pinnedSessionKeys {
  if (_pinnedSessionKeys is EqualUnmodifiableSetView) return _pinnedSessionKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pinnedSessionKeys);
}

/// Project paths pinned on this device.
 final  Set<String> _pinnedProjectPaths;
/// Project paths pinned on this device.
@override@JsonKey() Set<String> get pinnedProjectPaths {
  if (_pinnedProjectPaths is EqualUnmodifiableSetView) return _pinnedProjectPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pinnedProjectPaths);
}

/// Provider filter (All / Claude / Codex). Applied server-side.
@override@JsonKey() final  ProviderFilter providerFilter;
/// Named-only filter toggle. Applied server-side.
@override@JsonKey() final  bool namedOnly;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListStateCopyWith<_SessionListState> get copyWith => __$SessionListStateCopyWithImpl<_SessionListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListState&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.isInitialLoading, isInitialLoading) || other.isInitialLoading == isInitialLoading)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other._accumulatedProjectPaths, _accumulatedProjectPaths)&&const DeepCollectionEquality().equals(other._collapsedProjectPaths, _collapsedProjectPaths)&&const DeepCollectionEquality().equals(other._loadingProjectPaths, _loadingProjectPaths)&&const DeepCollectionEquality().equals(other._exhaustedProjectPaths, _exhaustedProjectPaths)&&const DeepCollectionEquality().equals(other._projectSessionDisplayLimits, _projectSessionDisplayLimits)&&const DeepCollectionEquality().equals(other._pinnedSessionKeys, _pinnedSessionKeys)&&const DeepCollectionEquality().equals(other._pinnedProjectPaths, _pinnedProjectPaths)&&(identical(other.providerFilter, providerFilter) || other.providerFilter == providerFilter)&&(identical(other.namedOnly, namedOnly) || other.namedOnly == namedOnly));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),hasMore,isLoadingMore,isInitialLoading,searchQuery,const DeepCollectionEquality().hash(_accumulatedProjectPaths),const DeepCollectionEquality().hash(_collapsedProjectPaths),const DeepCollectionEquality().hash(_loadingProjectPaths),const DeepCollectionEquality().hash(_exhaustedProjectPaths),const DeepCollectionEquality().hash(_projectSessionDisplayLimits),const DeepCollectionEquality().hash(_pinnedSessionKeys),const DeepCollectionEquality().hash(_pinnedProjectPaths),providerFilter,namedOnly);

@override
String toString() {
  return 'SessionListState(sessions: $sessions, hasMore: $hasMore, isLoadingMore: $isLoadingMore, isInitialLoading: $isInitialLoading, searchQuery: $searchQuery, accumulatedProjectPaths: $accumulatedProjectPaths, collapsedProjectPaths: $collapsedProjectPaths, loadingProjectPaths: $loadingProjectPaths, exhaustedProjectPaths: $exhaustedProjectPaths, projectSessionDisplayLimits: $projectSessionDisplayLimits, pinnedSessionKeys: $pinnedSessionKeys, pinnedProjectPaths: $pinnedProjectPaths, providerFilter: $providerFilter, namedOnly: $namedOnly)';
}


}

/// @nodoc
abstract mixin class _$SessionListStateCopyWith<$Res> implements $SessionListStateCopyWith<$Res> {
  factory _$SessionListStateCopyWith(_SessionListState value, $Res Function(_SessionListState) _then) = __$SessionListStateCopyWithImpl;
@override @useResult
$Res call({
 List<RecentSession> sessions, bool hasMore, bool isLoadingMore, bool isInitialLoading, String searchQuery, Set<String> accumulatedProjectPaths, Set<String> collapsedProjectPaths, Set<String> loadingProjectPaths, Set<String> exhaustedProjectPaths, Map<String, int> projectSessionDisplayLimits, Set<String> pinnedSessionKeys, Set<String> pinnedProjectPaths, ProviderFilter providerFilter, bool namedOnly
});




}
/// @nodoc
class __$SessionListStateCopyWithImpl<$Res>
    implements _$SessionListStateCopyWith<$Res> {
  __$SessionListStateCopyWithImpl(this._self, this._then);

  final _SessionListState _self;
  final $Res Function(_SessionListState) _then;

/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? hasMore = null,Object? isLoadingMore = null,Object? isInitialLoading = null,Object? searchQuery = null,Object? accumulatedProjectPaths = null,Object? collapsedProjectPaths = null,Object? loadingProjectPaths = null,Object? exhaustedProjectPaths = null,Object? projectSessionDisplayLimits = null,Object? pinnedSessionKeys = null,Object? pinnedProjectPaths = null,Object? providerFilter = null,Object? namedOnly = null,}) {
  return _then(_SessionListState(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<RecentSession>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,isInitialLoading: null == isInitialLoading ? _self.isInitialLoading : isInitialLoading // ignore: cast_nullable_to_non_nullable
as bool,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,accumulatedProjectPaths: null == accumulatedProjectPaths ? _self._accumulatedProjectPaths : accumulatedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,collapsedProjectPaths: null == collapsedProjectPaths ? _self._collapsedProjectPaths : collapsedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,loadingProjectPaths: null == loadingProjectPaths ? _self._loadingProjectPaths : loadingProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,exhaustedProjectPaths: null == exhaustedProjectPaths ? _self._exhaustedProjectPaths : exhaustedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,projectSessionDisplayLimits: null == projectSessionDisplayLimits ? _self._projectSessionDisplayLimits : projectSessionDisplayLimits // ignore: cast_nullable_to_non_nullable
as Map<String, int>,pinnedSessionKeys: null == pinnedSessionKeys ? _self._pinnedSessionKeys : pinnedSessionKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,pinnedProjectPaths: null == pinnedProjectPaths ? _self._pinnedProjectPaths : pinnedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,providerFilter: null == providerFilter ? _self.providerFilter : providerFilter // ignore: cast_nullable_to_non_nullable
as ProviderFilter,namedOnly: null == namedOnly ? _self.namedOnly : namedOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
