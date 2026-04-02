// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'explore_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ExploreState {

 String get projectPath; String get currentPath; List<String> get allFiles; List<ExploreEntry> get visibleEntries; ExploreStatus get status; String? get error;
/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExploreStateCopyWith<ExploreState> get copyWith => _$ExploreStateCopyWithImpl<ExploreState>(this as ExploreState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExploreState&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.currentPath, currentPath) || other.currentPath == currentPath)&&const DeepCollectionEquality().equals(other.allFiles, allFiles)&&const DeepCollectionEquality().equals(other.visibleEntries, visibleEntries)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,projectPath,currentPath,const DeepCollectionEquality().hash(allFiles),const DeepCollectionEquality().hash(visibleEntries),status,error);

@override
String toString() {
  return 'ExploreState(projectPath: $projectPath, currentPath: $currentPath, allFiles: $allFiles, visibleEntries: $visibleEntries, status: $status, error: $error)';
}


}

/// @nodoc
abstract mixin class $ExploreStateCopyWith<$Res>  {
  factory $ExploreStateCopyWith(ExploreState value, $Res Function(ExploreState) _then) = _$ExploreStateCopyWithImpl;
@useResult
$Res call({
 String projectPath, String currentPath, List<String> allFiles, List<ExploreEntry> visibleEntries, ExploreStatus status, String? error
});




}
/// @nodoc
class _$ExploreStateCopyWithImpl<$Res>
    implements $ExploreStateCopyWith<$Res> {
  _$ExploreStateCopyWithImpl(this._self, this._then);

  final ExploreState _self;
  final $Res Function(ExploreState) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? projectPath = null,Object? currentPath = null,Object? allFiles = null,Object? visibleEntries = null,Object? status = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
projectPath: null == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String,currentPath: null == currentPath ? _self.currentPath : currentPath // ignore: cast_nullable_to_non_nullable
as String,allFiles: null == allFiles ? _self.allFiles : allFiles // ignore: cast_nullable_to_non_nullable
as List<String>,visibleEntries: null == visibleEntries ? _self.visibleEntries : visibleEntries // ignore: cast_nullable_to_non_nullable
as List<ExploreEntry>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ExploreStatus,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExploreState].
extension ExploreStatePatterns on ExploreState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExploreState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExploreState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExploreState value)  $default,){
final _that = this;
switch (_that) {
case _ExploreState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExploreState value)?  $default,){
final _that = this;
switch (_that) {
case _ExploreState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String projectPath,  String currentPath,  List<String> allFiles,  List<ExploreEntry> visibleEntries,  ExploreStatus status,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExploreState() when $default != null:
return $default(_that.projectPath,_that.currentPath,_that.allFiles,_that.visibleEntries,_that.status,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String projectPath,  String currentPath,  List<String> allFiles,  List<ExploreEntry> visibleEntries,  ExploreStatus status,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ExploreState():
return $default(_that.projectPath,_that.currentPath,_that.allFiles,_that.visibleEntries,_that.status,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String projectPath,  String currentPath,  List<String> allFiles,  List<ExploreEntry> visibleEntries,  ExploreStatus status,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ExploreState() when $default != null:
return $default(_that.projectPath,_that.currentPath,_that.allFiles,_that.visibleEntries,_that.status,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ExploreState implements ExploreState {
  const _ExploreState({required this.projectPath, this.currentPath = '', final  List<String> allFiles = const [], final  List<ExploreEntry> visibleEntries = const [], this.status = ExploreStatus.loading, this.error}): _allFiles = allFiles,_visibleEntries = visibleEntries;
  

@override final  String projectPath;
@override@JsonKey() final  String currentPath;
 final  List<String> _allFiles;
@override@JsonKey() List<String> get allFiles {
  if (_allFiles is EqualUnmodifiableListView) return _allFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_allFiles);
}

 final  List<ExploreEntry> _visibleEntries;
@override@JsonKey() List<ExploreEntry> get visibleEntries {
  if (_visibleEntries is EqualUnmodifiableListView) return _visibleEntries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_visibleEntries);
}

@override@JsonKey() final  ExploreStatus status;
@override final  String? error;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExploreStateCopyWith<_ExploreState> get copyWith => __$ExploreStateCopyWithImpl<_ExploreState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExploreState&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.currentPath, currentPath) || other.currentPath == currentPath)&&const DeepCollectionEquality().equals(other._allFiles, _allFiles)&&const DeepCollectionEquality().equals(other._visibleEntries, _visibleEntries)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,projectPath,currentPath,const DeepCollectionEquality().hash(_allFiles),const DeepCollectionEquality().hash(_visibleEntries),status,error);

@override
String toString() {
  return 'ExploreState(projectPath: $projectPath, currentPath: $currentPath, allFiles: $allFiles, visibleEntries: $visibleEntries, status: $status, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ExploreStateCopyWith<$Res> implements $ExploreStateCopyWith<$Res> {
  factory _$ExploreStateCopyWith(_ExploreState value, $Res Function(_ExploreState) _then) = __$ExploreStateCopyWithImpl;
@override @useResult
$Res call({
 String projectPath, String currentPath, List<String> allFiles, List<ExploreEntry> visibleEntries, ExploreStatus status, String? error
});




}
/// @nodoc
class __$ExploreStateCopyWithImpl<$Res>
    implements _$ExploreStateCopyWith<$Res> {
  __$ExploreStateCopyWithImpl(this._self, this._then);

  final _ExploreState _self;
  final $Res Function(_ExploreState) _then;

/// Create a copy of ExploreState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? projectPath = null,Object? currentPath = null,Object? allFiles = null,Object? visibleEntries = null,Object? status = null,Object? error = freezed,}) {
  return _then(_ExploreState(
projectPath: null == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String,currentPath: null == currentPath ? _self.currentPath : currentPath // ignore: cast_nullable_to_non_nullable
as String,allFiles: null == allFiles ? _self._allFiles : allFiles // ignore: cast_nullable_to_non_nullable
as List<String>,visibleEntries: null == visibleEntries ? _self._visibleEntries : visibleEntries // ignore: cast_nullable_to_non_nullable
as List<ExploreEntry>,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ExploreStatus,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
