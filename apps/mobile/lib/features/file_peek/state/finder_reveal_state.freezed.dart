// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'finder_reveal_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FinderRevealState {

 bool get busy; String? get errorCode;
/// Create a copy of FinderRevealState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FinderRevealStateCopyWith<FinderRevealState> get copyWith => _$FinderRevealStateCopyWithImpl<FinderRevealState>(this as FinderRevealState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FinderRevealState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}


@override
int get hashCode => Object.hash(runtimeType,busy,errorCode);

@override
String toString() {
  return 'FinderRevealState(busy: $busy, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class $FinderRevealStateCopyWith<$Res>  {
  factory $FinderRevealStateCopyWith(FinderRevealState value, $Res Function(FinderRevealState) _then) = _$FinderRevealStateCopyWithImpl;
@useResult
$Res call({
 bool busy, String? errorCode
});




}
/// @nodoc
class _$FinderRevealStateCopyWithImpl<$Res>
    implements $FinderRevealStateCopyWith<$Res> {
  _$FinderRevealStateCopyWithImpl(this._self, this._then);

  final FinderRevealState _self;
  final $Res Function(FinderRevealState) _then;

/// Create a copy of FinderRevealState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? busy = null,Object? errorCode = freezed,}) {
  return _then(FinderRevealState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FinderRevealState].
extension FinderRevealStatePatterns on FinderRevealState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FinderRevealState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FinderRevealState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FinderRevealState value)  $default,){
final _that = this;
switch (_that) {
case _FinderRevealState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FinderRevealState value)?  $default,){
final _that = this;
switch (_that) {
case _FinderRevealState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool busy,  String? errorCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FinderRevealState() when $default != null:
return $default(_that.busy,_that.errorCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool busy,  String? errorCode)  $default,) {final _that = this;
switch (_that) {
case _FinderRevealState():
return $default(_that.busy,_that.errorCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool busy,  String? errorCode)?  $default,) {final _that = this;
switch (_that) {
case _FinderRevealState() when $default != null:
return $default(_that.busy,_that.errorCode);case _:
  return null;

}
}

}

/// @nodoc


class _FinderRevealState implements FinderRevealState {
  const _FinderRevealState({this.busy = false, this.errorCode});


@override@JsonKey() final  bool busy;
@override final  String? errorCode;

/// Create a copy of FinderRevealState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FinderRevealStateCopyWith<_FinderRevealState> get copyWith => __$FinderRevealStateCopyWithImpl<_FinderRevealState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FinderRevealState&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}


@override
int get hashCode => Object.hash(runtimeType,busy,errorCode);

@override
String toString() {
  return 'FinderRevealState(busy: $busy, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class _$FinderRevealStateCopyWith<$Res> implements $FinderRevealStateCopyWith<$Res> {
  factory _$FinderRevealStateCopyWith(_FinderRevealState value, $Res Function(_FinderRevealState) _then) = __$FinderRevealStateCopyWithImpl;
@override @useResult
$Res call({
 bool busy, String? errorCode
});




}
/// @nodoc
class __$FinderRevealStateCopyWithImpl<$Res>
    implements _$FinderRevealStateCopyWith<$Res> {
  __$FinderRevealStateCopyWithImpl(this._self, this._then);

  final _FinderRevealState _self;
  final $Res Function(_FinderRevealState) _then;

/// Create a copy of FinderRevealState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? busy = null,Object? errorCode = freezed,}) {
  return _then(_FinderRevealState(
busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
