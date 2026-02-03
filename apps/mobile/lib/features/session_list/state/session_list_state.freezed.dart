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
 bool get isLoadingMore;/// Client-side project name filter (null = show all).
 String? get selectedProject;/// Client-side date filter.
 DateFilter get dateFilter;/// Client-side text search query.
 String get searchQuery;/// Accumulated project paths from all loaded sessions + project history.
/// Used for the "New Session" project picker.
 Set<String> get accumulatedProjectPaths;
/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionListStateCopyWith<SessionListState> get copyWith => _$SessionListStateCopyWithImpl<SessionListState>(this as SessionListState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionListState&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.selectedProject, selectedProject) || other.selectedProject == selectedProject)&&(identical(other.dateFilter, dateFilter) || other.dateFilter == dateFilter)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other.accumulatedProjectPaths, accumulatedProjectPaths));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions),hasMore,isLoadingMore,selectedProject,dateFilter,searchQuery,const DeepCollectionEquality().hash(accumulatedProjectPaths));

@override
String toString() {
  return 'SessionListState(sessions: $sessions, hasMore: $hasMore, isLoadingMore: $isLoadingMore, selectedProject: $selectedProject, dateFilter: $dateFilter, searchQuery: $searchQuery, accumulatedProjectPaths: $accumulatedProjectPaths)';
}


}

/// @nodoc
abstract mixin class $SessionListStateCopyWith<$Res>  {
  factory $SessionListStateCopyWith(SessionListState value, $Res Function(SessionListState) _then) = _$SessionListStateCopyWithImpl;
@useResult
$Res call({
 List<RecentSession> sessions, bool hasMore, bool isLoadingMore, String? selectedProject, DateFilter dateFilter, String searchQuery, Set<String> accumulatedProjectPaths
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
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,Object? hasMore = null,Object? isLoadingMore = null,Object? selectedProject = freezed,Object? dateFilter = null,Object? searchQuery = null,Object? accumulatedProjectPaths = null,}) {
  return _then(_self.copyWith(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<RecentSession>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedProject: freezed == selectedProject ? _self.selectedProject : selectedProject // ignore: cast_nullable_to_non_nullable
as String?,dateFilter: null == dateFilter ? _self.dateFilter : dateFilter // ignore: cast_nullable_to_non_nullable
as DateFilter,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,accumulatedProjectPaths: null == accumulatedProjectPaths ? _self.accumulatedProjectPaths : accumulatedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<RecentSession> sessions,  bool hasMore,  bool isLoadingMore,  String? selectedProject,  DateFilter dateFilter,  String searchQuery,  Set<String> accumulatedProjectPaths)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionListState() when $default != null:
return $default(_that.sessions,_that.hasMore,_that.isLoadingMore,_that.selectedProject,_that.dateFilter,_that.searchQuery,_that.accumulatedProjectPaths);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<RecentSession> sessions,  bool hasMore,  bool isLoadingMore,  String? selectedProject,  DateFilter dateFilter,  String searchQuery,  Set<String> accumulatedProjectPaths)  $default,) {final _that = this;
switch (_that) {
case _SessionListState():
return $default(_that.sessions,_that.hasMore,_that.isLoadingMore,_that.selectedProject,_that.dateFilter,_that.searchQuery,_that.accumulatedProjectPaths);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<RecentSession> sessions,  bool hasMore,  bool isLoadingMore,  String? selectedProject,  DateFilter dateFilter,  String searchQuery,  Set<String> accumulatedProjectPaths)?  $default,) {final _that = this;
switch (_that) {
case _SessionListState() when $default != null:
return $default(_that.sessions,_that.hasMore,_that.isLoadingMore,_that.selectedProject,_that.dateFilter,_that.searchQuery,_that.accumulatedProjectPaths);case _:
  return null;

}
}

}

/// @nodoc


class _SessionListState implements SessionListState {
  const _SessionListState({final  List<RecentSession> sessions = const [], this.hasMore = false, this.isLoadingMore = false, this.selectedProject, this.dateFilter = DateFilter.all, this.searchQuery = '', final  Set<String> accumulatedProjectPaths = const {}}): _sessions = sessions,_accumulatedProjectPaths = accumulatedProjectPaths;
  

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
/// Client-side project name filter (null = show all).
@override final  String? selectedProject;
/// Client-side date filter.
@override@JsonKey() final  DateFilter dateFilter;
/// Client-side text search query.
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


/// Create a copy of SessionListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionListStateCopyWith<_SessionListState> get copyWith => __$SessionListStateCopyWithImpl<_SessionListState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionListState&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.hasMore, hasMore) || other.hasMore == hasMore)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.selectedProject, selectedProject) || other.selectedProject == selectedProject)&&(identical(other.dateFilter, dateFilter) || other.dateFilter == dateFilter)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&const DeepCollectionEquality().equals(other._accumulatedProjectPaths, _accumulatedProjectPaths));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions),hasMore,isLoadingMore,selectedProject,dateFilter,searchQuery,const DeepCollectionEquality().hash(_accumulatedProjectPaths));

@override
String toString() {
  return 'SessionListState(sessions: $sessions, hasMore: $hasMore, isLoadingMore: $isLoadingMore, selectedProject: $selectedProject, dateFilter: $dateFilter, searchQuery: $searchQuery, accumulatedProjectPaths: $accumulatedProjectPaths)';
}


}

/// @nodoc
abstract mixin class _$SessionListStateCopyWith<$Res> implements $SessionListStateCopyWith<$Res> {
  factory _$SessionListStateCopyWith(_SessionListState value, $Res Function(_SessionListState) _then) = __$SessionListStateCopyWithImpl;
@override @useResult
$Res call({
 List<RecentSession> sessions, bool hasMore, bool isLoadingMore, String? selectedProject, DateFilter dateFilter, String searchQuery, Set<String> accumulatedProjectPaths
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
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,Object? hasMore = null,Object? isLoadingMore = null,Object? selectedProject = freezed,Object? dateFilter = null,Object? searchQuery = null,Object? accumulatedProjectPaths = null,}) {
  return _then(_SessionListState(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<RecentSession>,hasMore: null == hasMore ? _self.hasMore : hasMore // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,selectedProject: freezed == selectedProject ? _self.selectedProject : selectedProject // ignore: cast_nullable_to_non_nullable
as String?,dateFilter: null == dateFilter ? _self.dateFilter : dateFilter // ignore: cast_nullable_to_non_nullable
as DateFilter,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,accumulatedProjectPaths: null == accumulatedProjectPaths ? _self._accumulatedProjectPaths : accumulatedProjectPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

// dart format on
