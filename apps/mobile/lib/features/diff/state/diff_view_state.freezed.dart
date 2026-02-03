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
 String? get error;
/// Create a copy of DiffViewState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiffViewStateCopyWith<DiffViewState> get copyWith => _$DiffViewStateCopyWithImpl<DiffViewState>(this as DiffViewState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiffViewState&&const DeepCollectionEquality().equals(other.files, files)&&const DeepCollectionEquality().equals(other.hiddenFileIndices, hiddenFileIndices)&&const DeepCollectionEquality().equals(other.collapsedFileIndices, collapsedFileIndices)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(files),const DeepCollectionEquality().hash(hiddenFileIndices),const DeepCollectionEquality().hash(collapsedFileIndices),loading,error);

@override
String toString() {
  return 'DiffViewState(files: $files, hiddenFileIndices: $hiddenFileIndices, collapsedFileIndices: $collapsedFileIndices, loading: $loading, error: $error)';
}


}

/// @nodoc
abstract mixin class $DiffViewStateCopyWith<$Res>  {
  factory $DiffViewStateCopyWith(DiffViewState value, $Res Function(DiffViewState) _then) = _$DiffViewStateCopyWithImpl;
@useResult
$Res call({
 List<DiffFile> files, Set<int> hiddenFileIndices, Set<int> collapsedFileIndices, bool loading, String? error
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
@pragma('vm:prefer-inline') @override $Res call({Object? files = null,Object? hiddenFileIndices = null,Object? collapsedFileIndices = null,Object? loading = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
files: null == files ? _self.files : files // ignore: cast_nullable_to_non_nullable
as List<DiffFile>,hiddenFileIndices: null == hiddenFileIndices ? _self.hiddenFileIndices : hiddenFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,collapsedFileIndices: null == collapsedFileIndices ? _self.collapsedFileIndices : collapsedFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DiffFile> files,  Set<int> hiddenFileIndices,  Set<int> collapsedFileIndices,  bool loading,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiffViewState() when $default != null:
return $default(_that.files,_that.hiddenFileIndices,_that.collapsedFileIndices,_that.loading,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DiffFile> files,  Set<int> hiddenFileIndices,  Set<int> collapsedFileIndices,  bool loading,  String? error)  $default,) {final _that = this;
switch (_that) {
case _DiffViewState():
return $default(_that.files,_that.hiddenFileIndices,_that.collapsedFileIndices,_that.loading,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DiffFile> files,  Set<int> hiddenFileIndices,  Set<int> collapsedFileIndices,  bool loading,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _DiffViewState() when $default != null:
return $default(_that.files,_that.hiddenFileIndices,_that.collapsedFileIndices,_that.loading,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _DiffViewState implements DiffViewState {
  const _DiffViewState({final  List<DiffFile> files = const [], final  Set<int> hiddenFileIndices = const {}, final  Set<int> collapsedFileIndices = const {}, this.loading = false, this.error}): _files = files,_hiddenFileIndices = hiddenFileIndices,_collapsedFileIndices = collapsedFileIndices;
  

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

/// Create a copy of DiffViewState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiffViewStateCopyWith<_DiffViewState> get copyWith => __$DiffViewStateCopyWithImpl<_DiffViewState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiffViewState&&const DeepCollectionEquality().equals(other._files, _files)&&const DeepCollectionEquality().equals(other._hiddenFileIndices, _hiddenFileIndices)&&const DeepCollectionEquality().equals(other._collapsedFileIndices, _collapsedFileIndices)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_files),const DeepCollectionEquality().hash(_hiddenFileIndices),const DeepCollectionEquality().hash(_collapsedFileIndices),loading,error);

@override
String toString() {
  return 'DiffViewState(files: $files, hiddenFileIndices: $hiddenFileIndices, collapsedFileIndices: $collapsedFileIndices, loading: $loading, error: $error)';
}


}

/// @nodoc
abstract mixin class _$DiffViewStateCopyWith<$Res> implements $DiffViewStateCopyWith<$Res> {
  factory _$DiffViewStateCopyWith(_DiffViewState value, $Res Function(_DiffViewState) _then) = __$DiffViewStateCopyWithImpl;
@override @useResult
$Res call({
 List<DiffFile> files, Set<int> hiddenFileIndices, Set<int> collapsedFileIndices, bool loading, String? error
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
@override @pragma('vm:prefer-inline') $Res call({Object? files = null,Object? hiddenFileIndices = null,Object? collapsedFileIndices = null,Object? loading = null,Object? error = freezed,}) {
  return _then(_DiffViewState(
files: null == files ? _self._files : files // ignore: cast_nullable_to_non_nullable
as List<DiffFile>,hiddenFileIndices: null == hiddenFileIndices ? _self._hiddenFileIndices : hiddenFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,collapsedFileIndices: null == collapsedFileIndices ? _self._collapsedFileIndices : collapsedFileIndices // ignore: cast_nullable_to_non_nullable
as Set<int>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
