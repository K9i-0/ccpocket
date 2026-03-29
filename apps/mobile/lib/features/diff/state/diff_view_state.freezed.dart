// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diff_view_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DiffViewState {

/// Parsed diff files.
 List<DiffFile> get files;/// Indices of files hidden by the filter.
 Set<int> get hiddenFileIndices;/// Indices of files whose hunks are collapsed.
 Set<int> get collapsedFileIndices;/// Whether a diff request is in progress.
 bool get loading;/// Error message from parsing or server request.
 String? get error;/// Error code for categorized error handling (e.g. 'git_not_available').
 String? get errorCode;/// Whether selection mode is active.
 bool get selectionMode;/// Selected hunk keys in the format "$fileIdx:$hunkIdx".
 Set<String> get selectedHunkKeys;/// Indices of image files currently loading on demand.
 Set<int> get loadingImageIndices;/// Current diff view mode: unstaged (working-tree) or staged (index).
 DiffViewMode get viewMode;/// Whether a stage/unstage operation is in progress.
 bool get staging;/// Commits ahead of upstream (pushable).
 int get commitsAhead;/// Commits behind upstream (pullable).
 int get commitsBehind;/// Whether the branch has a configured upstream.
 bool get hasUpstream;/// Whether a fetch is in progress.
 bool get fetching;/// Whether a pull is in progress.
 bool get pulling;
/// Create a copy of DiffViewState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiffViewStateCopyWith<DiffViewState> get copyWith => _$DiffViewStateCopyWithImpl<DiffViewState>(this as DiffViewState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffViewState&&const DeepCollectionEquality().equals(other.files, files)&&const DeepCollectionEquality().equals(other.hiddenFileIndices, hiddenFileIndices)&&const DeepCollectionEquality().equals(other.collapsedFileIndices, collapsedFileIndices)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.selectionMode, selectionMode) || other.selectionMode == selectionMode)&&const DeepCollectionEquality().equals(other.selectedHunkKeys, selectedHunkKeys)&&const DeepCollectionEquality().equals(other.loadingImageIndices, loadingImageIndices)&&(identical(other.viewMode, viewMode) || other.viewMode == viewMode)&&(identical(other.staging, staging) || other.staging == staging)&&(identical(other.commitsAhead, commitsAhead) || other.commitsAhead == commitsAhead)&&(identical(other.commitsBehind, commitsBehind) || other.commitsBehind == commitsBehind)&&(identical(other.hasUpstream, hasUpstream) || other.hasUpstream == hasUpstream)&&(identical(other.fetching, fetching) || other.fetching == fetching)&&(identical(other.pulling, pulling) || other.pulling == pulling));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(files),const DeepCollectionEquality().hash(hiddenFileIndices),const DeepCollectionEquality().hash(collapsedFileIndices),loading,error,errorCode,selectionMode,const DeepCollectionEquality().hash(selectedHunkKeys),const DeepCollectionEquality().hash(loadingImageIndices),viewMode,staging,commitsAhead,commitsBehind,hasUpstream,fetching,pulling);

@override
String toString() {
  return 'DiffViewState(files: $files, hiddenFileIndices: $hiddenFileIndices, collapsedFileIndices: $collapsedFileIndices, loading: $loading, error: $error, errorCode: $errorCode, selectionMode: $selectionMode, selectedHunkKeys: $selectedHunkKeys, loadingImageIndices: $loadingImageIndices, viewMode: $viewMode, staging: $staging, commitsAhead: $commitsAhead, commitsBehind: $commitsBehind, hasUpstream: $hasUpstream, fetching: $fetching, pulling: $pulling)';
}


}

/// @nodoc
abstract mixin class $DiffViewStateCopyWith<$Res>  {
  factory $DiffViewStateCopyWith(DiffViewState value, $Res Function(DiffViewState) _then) = _$DiffViewStateCopyWithImpl;
@useResult
$Res call({
 List<DiffFile> files, Set<int> hiddenFileIndices, Set<int> collapsedFileIndices, bool loading, String? error, String? errorCode, bool selectionMode, Set<String> selectedHunkKeys, Set<int> loadingImageIndices, DiffViewMode viewMode, bool staging, int commitsAhead, int commitsBehind, bool hasUpstream, bool fetching, bool pulling
});




}
/// @nodoc
class _$DiffViewStateCopyWithImpl<$Res>
    implements $DiffViewStateCopyWith<$Res> {
  _$DiffViewStateCopyWithImpl(this._self, this._then);

  final DiffViewState _self;
  final $Res Function(DiffViewState) _then;

/// Create a copy of DiffViewState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? files = null,Object? hiddenFileIndices = null,Object? collapsedFileIndices = null,Object? loading = null,Object? error = freezed,Object? errorCode = freezed,Object? selectionMode = null,Object? selectedHunkKeys = null,Object? loadingImageIndices = null,Object? viewMode = null,Object? staging = null,Object? commitsAhead = null,Object? commitsBehind = null,Object? hasUpstream = null,Object? fetching = null,Object? pulling = null,}) {
  return _then(_self.copyWith(
files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<DiffFile>,hiddenFileIndices: null == hiddenFileIndices ? _self.hiddenFileIndices : hiddenFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,collapsedFileIndices: null == collapsedFileIndices ? _self.collapsedFileIndices : collapsedFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,selectionMode: null == selectionMode ? _self.selectionMode : selectionMode // ignore: cast_nullable_to_non_nullable
as bool,selectedHunkKeys: null == selectedHunkKeys ? _self.selectedHunkKeys : selectedHunkKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,loadingImageIndices: null == loadingImageIndices ? _self.loadingImageIndices : loadingImageIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,viewMode: null == viewMode ? _self.viewMode : viewMode // ignore: cast_nullable_to_non_nullable
as DiffViewMode,staging: null == staging ? _self.staging : staging // ignore: cast_nullable_to_non_nullable
as bool,commitsAhead: null == commitsAhead ? _self.commitsAhead : commitsAhead // ignore: cast_nullable_to_non_nullable
as int,commitsBehind: null == commitsBehind ? _self.commitsBehind : commitsBehind // ignore: cast_nullable_to_non_nullable
as int,hasUpstream: null == hasUpstream ? _self.hasUpstream : hasUpstream // ignore: cast_nullable_to_non_nullable
as bool,fetching: null == fetching ? _self.fetching : fetching // ignore: cast_nullable_to_non_nullable
as bool,pulling: null == pulling ? _self.pulling : pulling // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DiffViewState].
extension DiffViewStatePatterns on DiffViewState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiffViewState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiffViewState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiffViewState value)  $default,){
final _that = this;
switch (_that) {
case _DiffViewState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiffViewState value)?  $default,){
final _that = this;
switch (_that) {
case _DiffViewState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DiffFile> files,  Set<int> hiddenFileIndices,  Set<int> collapsedFileIndices,  bool loading,  String? error,  String? errorCode,  bool selectionMode,  Set<String> selectedHunkKeys,  Set<int> loadingImageIndices,  DiffViewMode viewMode,  bool staging,  int commitsAhead,  int commitsBehind,  bool hasUpstream,  bool fetching,  bool pulling)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiffViewState() when $default != null:
return $default(_that.files,_that.hiddenFileIndices,_that.collapsedFileIndices,_that.loading,_that.error,_that.errorCode,_that.selectionMode,_that.selectedHunkKeys,_that.loadingImageIndices,_that.viewMode,_that.staging,_that.commitsAhead,_that.commitsBehind,_that.hasUpstream,_that.fetching,_that.pulling);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DiffFile> files,  Set<int> hiddenFileIndices,  Set<int> collapsedFileIndices,  bool loading,  String? error,  String? errorCode,  bool selectionMode,  Set<String> selectedHunkKeys,  Set<int> loadingImageIndices,  DiffViewMode viewMode,  bool staging,  int commitsAhead,  int commitsBehind,  bool hasUpstream,  bool fetching,  bool pulling)  $default,) {final _that = this;
switch (_that) {
case _DiffViewState():
return $default(_that.files,_that.hiddenFileIndices,_that.collapsedFileIndices,_that.loading,_that.error,_that.errorCode,_that.selectionMode,_that.selectedHunkKeys,_that.loadingImageIndices,_that.viewMode,_that.staging,_that.commitsAhead,_that.commitsBehind,_that.hasUpstream,_that.fetching,_that.pulling);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DiffFile> files,  Set<int> hiddenFileIndices,  Set<int> collapsedFileIndices,  bool loading,  String? error,  String? errorCode,  bool selectionMode,  Set<String> selectedHunkKeys,  Set<int> loadingImageIndices,  DiffViewMode viewMode,  bool staging,  int commitsAhead,  int commitsBehind,  bool hasUpstream,  bool fetching,  bool pulling)?  $default,) {final _that = this;
switch (_that) {
case _DiffViewState() when $default != null:
return $default(_that.files,_that.hiddenFileIndices,_that.collapsedFileIndices,_that.loading,_that.error,_that.errorCode,_that.selectionMode,_that.selectedHunkKeys,_that.loadingImageIndices,_that.viewMode,_that.staging,_that.commitsAhead,_that.commitsBehind,_that.hasUpstream,_that.fetching,_that.pulling);case _:
  return null;

}
}

}

/// @nodoc


class _DiffViewState implements DiffViewState {
  const _DiffViewState({final  List<DiffFile> files = const [], final  Set<int> hiddenFileIndices = const {}, final  Set<int> collapsedFileIndices = const {}, this.loading = false, this.error, this.errorCode, this.selectionMode = false, final  Set<String> selectedHunkKeys = const {}, final  Set<int> loadingImageIndices = const {}, this.viewMode = DiffViewMode.all, this.staging = false, this.commitsAhead = 0, this.commitsBehind = 0, this.hasUpstream = false, this.fetching = false, this.pulling = false}): _files = files,_hiddenFileIndices = hiddenFileIndices,_collapsedFileIndices = collapsedFileIndices,_selectedHunkKeys = selectedHunkKeys,_loadingImageIndices = loadingImageIndices;
  

/// Parsed diff files.
 final  List<DiffFile> _files;
/// Parsed diff files.
@override@JsonKey() List<DiffFile> get files {
  if (_files is EqualUnmodifiableListView) return _files;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_files);
}

/// Indices of files hidden by the filter.
 final  Set<int> _hiddenFileIndices;
/// Indices of files hidden by the filter.
@override@JsonKey() Set<int> get hiddenFileIndices {
  if (_hiddenFileIndices is EqualUnmodifiableSetView) return _hiddenFileIndices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_hiddenFileIndices);
}

/// Indices of files whose hunks are collapsed.
 final  Set<int> _collapsedFileIndices;
/// Indices of files whose hunks are collapsed.
@override@JsonKey() Set<int> get collapsedFileIndices {
  if (_collapsedFileIndices is EqualUnmodifiableSetView) return _collapsedFileIndices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_collapsedFileIndices);
}

/// Whether a diff request is in progress.
@override@JsonKey() final  bool loading;
/// Error message from parsing or server request.
@override final  String? error;
/// Error code for categorized error handling (e.g. 'git_not_available').
@override final  String? errorCode;
/// Whether selection mode is active.
@override@JsonKey() final  bool selectionMode;
/// Selected hunk keys in the format "$fileIdx:$hunkIdx".
 final  Set<String> _selectedHunkKeys;
/// Selected hunk keys in the format "$fileIdx:$hunkIdx".
@override@JsonKey() Set<String> get selectedHunkKeys {
  if (_selectedHunkKeys is EqualUnmodifiableSetView) return _selectedHunkKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedHunkKeys);
}

/// Indices of image files currently loading on demand.
 final  Set<int> _loadingImageIndices;
/// Indices of image files currently loading on demand.
@override@JsonKey() Set<int> get loadingImageIndices {
  if (_loadingImageIndices is EqualUnmodifiableSetView) return _loadingImageIndices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_loadingImageIndices);
}

/// Current diff view mode: unstaged (working-tree) or staged (index).
@override@JsonKey() final  DiffViewMode viewMode;
/// Whether a stage/unstage operation is in progress.
@override@JsonKey() final  bool staging;
/// Commits ahead of upstream (pushable).
@override@JsonKey() final  int commitsAhead;
/// Commits behind upstream (pullable).
@override@JsonKey() final  int commitsBehind;
/// Whether the branch has a configured upstream.
@override@JsonKey() final  bool hasUpstream;
/// Whether a fetch is in progress.
@override@JsonKey() final  bool fetching;
/// Whether a pull is in progress.
@override@JsonKey() final  bool pulling;

/// Create a copy of DiffViewState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiffViewStateCopyWith<_DiffViewState> get copyWith => __$DiffViewStateCopyWithImpl<_DiffViewState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiffViewState&&const DeepCollectionEquality().equals(other._files, _files)&&const DeepCollectionEquality().equals(other._hiddenFileIndices, _hiddenFileIndices)&&const DeepCollectionEquality().equals(other._collapsedFileIndices, _collapsedFileIndices)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.selectionMode, selectionMode) || other.selectionMode == selectionMode)&&const DeepCollectionEquality().equals(other._selectedHunkKeys, _selectedHunkKeys)&&const DeepCollectionEquality().equals(other._loadingImageIndices, _loadingImageIndices)&&(identical(other.viewMode, viewMode) || other.viewMode == viewMode)&&(identical(other.staging, staging) || other.staging == staging)&&(identical(other.commitsAhead, commitsAhead) || other.commitsAhead == commitsAhead)&&(identical(other.commitsBehind, commitsBehind) || other.commitsBehind == commitsBehind)&&(identical(other.hasUpstream, hasUpstream) || other.hasUpstream == hasUpstream)&&(identical(other.fetching, fetching) || other.fetching == fetching)&&(identical(other.pulling, pulling) || other.pulling == pulling));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_files),const DeepCollectionEquality().hash(_hiddenFileIndices),const DeepCollectionEquality().hash(_collapsedFileIndices),loading,error,errorCode,selectionMode,const DeepCollectionEquality().hash(_selectedHunkKeys),const DeepCollectionEquality().hash(_loadingImageIndices),viewMode,staging,commitsAhead,commitsBehind,hasUpstream,fetching,pulling);

@override
String toString() {
  return 'DiffViewState(files: $files, hiddenFileIndices: $hiddenFileIndices, collapsedFileIndices: $collapsedFileIndices, loading: $loading, error: $error, errorCode: $errorCode, selectionMode: $selectionMode, selectedHunkKeys: $selectedHunkKeys, loadingImageIndices: $loadingImageIndices, viewMode: $viewMode, staging: $staging, commitsAhead: $commitsAhead, commitsBehind: $commitsBehind, hasUpstream: $hasUpstream, fetching: $fetching, pulling: $pulling)';
}


}

/// @nodoc
abstract mixin class _$DiffViewStateCopyWith<$Res> implements $DiffViewStateCopyWith<$Res> {
  factory _$DiffViewStateCopyWith(_DiffViewState value, $Res Function(_DiffViewState) _then) = __$DiffViewStateCopyWithImpl;
@override @useResult
$Res call({
 List<DiffFile> files, Set<int> hiddenFileIndices, Set<int> collapsedFileIndices, bool loading, String? error, String? errorCode, bool selectionMode, Set<String> selectedHunkKeys, Set<int> loadingImageIndices, DiffViewMode viewMode, bool staging, int commitsAhead, int commitsBehind, bool hasUpstream, bool fetching, bool pulling
});




}
/// @nodoc
class __$DiffViewStateCopyWithImpl<$Res>
    implements _$DiffViewStateCopyWith<$Res> {
  __$DiffViewStateCopyWithImpl(this._self, this._then);

  final _DiffViewState _self;
  final $Res Function(_DiffViewState) _then;

/// Create a copy of DiffViewState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? files = null,Object? hiddenFileIndices = null,Object? collapsedFileIndices = null,Object? loading = null,Object? error = freezed,Object? errorCode = freezed,Object? selectionMode = null,Object? selectedHunkKeys = null,Object? loadingImageIndices = null,Object? viewMode = null,Object? staging = null,Object? commitsAhead = null,Object? commitsBehind = null,Object? hasUpstream = null,Object? fetching = null,Object? pulling = null,}) {
  return _then(_DiffViewState(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<DiffFile>,hiddenFileIndices: null == hiddenFileIndices ? _self._hiddenFileIndices : hiddenFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,collapsedFileIndices: null == collapsedFileIndices ? _self._collapsedFileIndices : collapsedFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,selectionMode: null == selectionMode ? _self.selectionMode : selectionMode // ignore: cast_nullable_to_non_nullable
as bool,selectedHunkKeys: null == selectedHunkKeys ? _self._selectedHunkKeys : selectedHunkKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,loadingImageIndices: null == loadingImageIndices ? _self._loadingImageIndices : loadingImageIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,viewMode: null == viewMode ? _self.viewMode : viewMode // ignore: cast_nullable_to_non_nullable
as DiffViewMode,staging: null == staging ? _self.staging : staging // ignore: cast_nullable_to_non_nullable
as bool,commitsAhead: null == commitsAhead ? _self.commitsAhead : commitsAhead // ignore: cast_nullable_to_non_nullable
as int,commitsBehind: null == commitsBehind ? _self.commitsBehind : commitsBehind // ignore: cast_nullable_to_non_nullable
as int,hasUpstream: null == hasUpstream ? _self.hasUpstream : hasUpstream // ignore: cast_nullable_to_non_nullable
as bool,fetching: null == fetching ? _self.fetching : fetching // ignore: cast_nullable_to_non_nullable
as bool,pulling: null == pulling ? _self.pulling : pulling // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
