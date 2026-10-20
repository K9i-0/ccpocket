// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_setup_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProjectSetupState {

 bool get busy; String? get error; ProjectSetupResultMessage? get result;
/// Create a copy of ProjectSetupState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectSetupStateCopyWith<ProjectSetupState> get copyWith => _$ProjectSetupStateCopyWithImpl<ProjectSetupState>(this as ProjectSetupState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectSetupState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error)&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,busy,error,result);

@override
String toString() {
  return 'ProjectSetupState(busy: $busy, error: $error, result: $result)';
}


}

/// @nodoc
abstract mixin class $ProjectSetupStateCopyWith<$Res>  {
  factory $ProjectSetupStateCopyWith(ProjectSetupState value, $Res Function(ProjectSetupState) _then) = _$ProjectSetupStateCopyWithImpl;
@useResult
$Res call({
 bool busy, String? error, ProjectSetupResultMessage? result
});




}
/// @nodoc
class _$ProjectSetupStateCopyWithImpl<$Res>
    implements $ProjectSetupStateCopyWith<$Res> {
  _$ProjectSetupStateCopyWithImpl(this._self, this._then);

  final ProjectSetupState _self;
  final $Res Function(ProjectSetupState) _then;

/// Create a copy of ProjectSetupState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? busy = null,Object? error = freezed,Object? result = freezed,}) {
  return _then(ProjectSetupState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ProjectSetupResultMessage?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectSetupState].
extension ProjectSetupStatePatterns on ProjectSetupState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectSetupState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectSetupState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectSetupState value)  $default,){
final _that = this;
switch (_that) {
case _ProjectSetupState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectSetupState value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectSetupState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool busy,  String? error,  ProjectSetupResultMessage? result)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectSetupState() when $default != null:
return $default(_that.busy,_that.error,_that.result);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool busy,  String? error,  ProjectSetupResultMessage? result)  $default,) {final _that = this;
switch (_that) {
case _ProjectSetupState():
return $default(_that.busy,_that.error,_that.result);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool busy,  String? error,  ProjectSetupResultMessage? result)?  $default,) {final _that = this;
switch (_that) {
case _ProjectSetupState() when $default != null:
return $default(_that.busy,_that.error,_that.result);case _:
  return null;

}
}

}

/// @nodoc


class _ProjectSetupState implements ProjectSetupState {
  const _ProjectSetupState({this.busy = false, this.error, this.result});


@override@JsonKey() final  bool busy;
@override final  String? error;
@override final  ProjectSetupResultMessage? result;

/// Create a copy of ProjectSetupState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectSetupStateCopyWith<_ProjectSetupState> get copyWith => __$ProjectSetupStateCopyWithImpl<_ProjectSetupState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectSetupState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error)&&(identical(other.result, result) || other.result == result));
}


@override
int get hashCode => Object.hash(runtimeType,busy,error,result);

@override
String toString() {
  return 'ProjectSetupState(busy: $busy, error: $error, result: $result)';
}


}

/// @nodoc
abstract mixin class _$ProjectSetupStateCopyWith<$Res> implements $ProjectSetupStateCopyWith<$Res> {
  factory _$ProjectSetupStateCopyWith(_ProjectSetupState value, $Res Function(_ProjectSetupState) _then) = __$ProjectSetupStateCopyWithImpl;
@override @useResult
$Res call({
 bool busy, String? error, ProjectSetupResultMessage? result
});




}
/// @nodoc
class __$ProjectSetupStateCopyWithImpl<$Res>
    implements _$ProjectSetupStateCopyWith<$Res> {
  __$ProjectSetupStateCopyWithImpl(this._self, this._then);

  final _ProjectSetupState _self;
  final $Res Function(_ProjectSetupState) _then;

/// Create a copy of ProjectSetupState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? error = freezed,Object? result = freezed,}) {
  return _then(_ProjectSetupState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as ProjectSetupResultMessage?,
  ));
}


}

// dart format on
