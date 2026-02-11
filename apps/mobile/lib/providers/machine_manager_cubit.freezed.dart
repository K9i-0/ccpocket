// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine_manager_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MachineManagerState {

/// List of machines with their current status
 List<MachineWithStatus> get machines;/// Whether we're loading/refreshing
 bool get isLoading;/// ID of machine currently being started
 String? get startingMachineId;/// ID of machine currently being updated
 String? get updatingMachineId;/// Error message if any
 String? get error;/// Success message if any
 String? get successMessage;
/// Create a copy of MachineManagerState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineManagerStateCopyWith<MachineManagerState> get copyWith => _$MachineManagerStateCopyWithImpl<MachineManagerState>(this as MachineManagerState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MachineManagerState&&const DeepCollectionEquality().equals(other.machines, machines)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.startingMachineId, startingMachineId) || other.startingMachineId == startingMachineId)&&(identical(other.updatingMachineId, updatingMachineId) || other.updatingMachineId == updatingMachineId)&&(identical(other.error, error) || other.error == error)&&(identical(other.successMessage, successMessage) || other.successMessage == successMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(machines),isLoading,startingMachineId,updatingMachineId,error,successMessage);

@override
String toString() {
  return 'MachineManagerState(machines: $machines, isLoading: $isLoading, startingMachineId: $startingMachineId, updatingMachineId: $updatingMachineId, error: $error, successMessage: $successMessage)';
}


}

/// @nodoc
abstract mixin class $MachineManagerStateCopyWith<$Res>  {
  factory $MachineManagerStateCopyWith(MachineManagerState value, $Res Function(MachineManagerState) _then) = _$MachineManagerStateCopyWithImpl;
@useResult
$Res call({
 List<MachineWithStatus> machines, bool isLoading, String? startingMachineId, String? updatingMachineId, String? error, String? successMessage
});




}
/// @nodoc
class _$MachineManagerStateCopyWithImpl<$Res>
    implements $MachineManagerStateCopyWith<$Res> {
  _$MachineManagerStateCopyWithImpl(this._self, this._then);

  final MachineManagerState _self;
  final $Res Function(MachineManagerState) _then;

/// Create a copy of MachineManagerState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? machines = null,Object? isLoading = null,Object? startingMachineId = freezed,Object? updatingMachineId = freezed,Object? error = freezed,Object? successMessage = freezed,}) {
  return _then(_self.copyWith(
machines: null == machines ? _self.machines : machines // ignore: cast_nullable_to_non_nullable
as List<MachineWithStatus>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,startingMachineId: freezed == startingMachineId ? _self.startingMachineId : startingMachineId // ignore: cast_nullable_to_non_nullable
as String?,updatingMachineId: freezed == updatingMachineId ? _self.updatingMachineId : updatingMachineId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,successMessage: freezed == successMessage ? _self.successMessage : successMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MachineManagerState].
extension MachineManagerStatePatterns on MachineManagerState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MachineManagerState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MachineManagerState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MachineManagerState value)  $default,){
final _that = this;
switch (_that) {
case _MachineManagerState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MachineManagerState value)?  $default,){
final _that = this;
switch (_that) {
case _MachineManagerState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MachineWithStatus> machines,  bool isLoading,  String? startingMachineId,  String? updatingMachineId,  String? error,  String? successMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MachineManagerState() when $default != null:
return $default(_that.machines,_that.isLoading,_that.startingMachineId,_that.updatingMachineId,_that.error,_that.successMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MachineWithStatus> machines,  bool isLoading,  String? startingMachineId,  String? updatingMachineId,  String? error,  String? successMessage)  $default,) {final _that = this;
switch (_that) {
case _MachineManagerState():
return $default(_that.machines,_that.isLoading,_that.startingMachineId,_that.updatingMachineId,_that.error,_that.successMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MachineWithStatus> machines,  bool isLoading,  String? startingMachineId,  String? updatingMachineId,  String? error,  String? successMessage)?  $default,) {final _that = this;
switch (_that) {
case _MachineManagerState() when $default != null:
return $default(_that.machines,_that.isLoading,_that.startingMachineId,_that.updatingMachineId,_that.error,_that.successMessage);case _:
  return null;

}
}

}

/// @nodoc


class _MachineManagerState implements MachineManagerState {
  const _MachineManagerState({final  List<MachineWithStatus> machines = const [], this.isLoading = false, this.startingMachineId, this.updatingMachineId, this.error, this.successMessage}): _machines = machines;
  

/// List of machines with their current status
 final  List<MachineWithStatus> _machines;
/// List of machines with their current status
@override@JsonKey() List<MachineWithStatus> get machines {
  if (_machines is EqualUnmodifiableListView) return _machines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_machines);
}

/// Whether we're loading/refreshing
@override@JsonKey() final  bool isLoading;
/// ID of machine currently being started
@override final  String? startingMachineId;
/// ID of machine currently being updated
@override final  String? updatingMachineId;
/// Error message if any
@override final  String? error;
/// Success message if any
@override final  String? successMessage;

/// Create a copy of MachineManagerState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineManagerStateCopyWith<_MachineManagerState> get copyWith => __$MachineManagerStateCopyWithImpl<_MachineManagerState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MachineManagerState&&const DeepCollectionEquality().equals(other._machines, _machines)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.startingMachineId, startingMachineId) || other.startingMachineId == startingMachineId)&&(identical(other.updatingMachineId, updatingMachineId) || other.updatingMachineId == updatingMachineId)&&(identical(other.error, error) || other.error == error)&&(identical(other.successMessage, successMessage) || other.successMessage == successMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_machines),isLoading,startingMachineId,updatingMachineId,error,successMessage);

@override
String toString() {
  return 'MachineManagerState(machines: $machines, isLoading: $isLoading, startingMachineId: $startingMachineId, updatingMachineId: $updatingMachineId, error: $error, successMessage: $successMessage)';
}


}

/// @nodoc
abstract mixin class _$MachineManagerStateCopyWith<$Res> implements $MachineManagerStateCopyWith<$Res> {
  factory _$MachineManagerStateCopyWith(_MachineManagerState value, $Res Function(_MachineManagerState) _then) = __$MachineManagerStateCopyWithImpl;
@override @useResult
$Res call({
 List<MachineWithStatus> machines, bool isLoading, String? startingMachineId, String? updatingMachineId, String? error, String? successMessage
});




}
/// @nodoc
class __$MachineManagerStateCopyWithImpl<$Res>
    implements _$MachineManagerStateCopyWith<$Res> {
  __$MachineManagerStateCopyWithImpl(this._self, this._then);

  final _MachineManagerState _self;
  final $Res Function(_MachineManagerState) _then;

/// Create a copy of MachineManagerState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? machines = null,Object? isLoading = null,Object? startingMachineId = freezed,Object? updatingMachineId = freezed,Object? error = freezed,Object? successMessage = freezed,}) {
  return _then(_MachineManagerState(
machines: null == machines ? _self._machines : machines // ignore: cast_nullable_to_non_nullable
as List<MachineWithStatus>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,startingMachineId: freezed == startingMachineId ? _self.startingMachineId : startingMachineId // ignore: cast_nullable_to_non_nullable
as String?,updatingMachineId: freezed == updatingMachineId ? _self.updatingMachineId : updatingMachineId // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,successMessage: freezed == successMessage ? _self.successMessage : successMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
