// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsState {

/// Theme mode: system, light, or dark.
 ThemeMode get themeMode;/// App display locale ID (e.g. 'ja', 'en').
/// Empty string means follow the device default.
 String get appLocaleId;/// Locale ID for speech recognition (e.g. 'ja-JP', 'en-US').
/// Empty string means use device default.
 String get speechLocaleId;/// Set of Machine IDs that have push notifications enabled.
 Set<String> get fcmEnabledMachines;/// Currently connected Machine ID (null when disconnected).
 String? get activeMachineId;/// Whether Firebase Messaging is available in this runtime.
 bool get fcmAvailable;/// True while token registration/unregistration is being synchronized.
 bool get fcmSyncInProgress;/// Last push sync status key (resolved to localized string in UI).
 FcmStatusKey? get fcmStatusKey;
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsStateCopyWith<SettingsState> get copyWith => _$SettingsStateCopyWithImpl<SettingsState>(this as SettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.appLocaleId, appLocaleId) || other.appLocaleId == appLocaleId)&&(identical(other.speechLocaleId, speechLocaleId) || other.speechLocaleId == speechLocaleId)&&const DeepCollectionEquality().equals(other.fcmEnabledMachines, fcmEnabledMachines)&&(identical(other.activeMachineId, activeMachineId) || other.activeMachineId == activeMachineId)&&(identical(other.fcmAvailable, fcmAvailable) || other.fcmAvailable == fcmAvailable)&&(identical(other.fcmSyncInProgress, fcmSyncInProgress) || other.fcmSyncInProgress == fcmSyncInProgress)&&(identical(other.fcmStatusKey, fcmStatusKey) || other.fcmStatusKey == fcmStatusKey));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,appLocaleId,speechLocaleId,const DeepCollectionEquality().hash(fcmEnabledMachines),activeMachineId,fcmAvailable,fcmSyncInProgress,fcmStatusKey);

@override
String toString() {
  return 'SettingsState(themeMode: $themeMode, appLocaleId: $appLocaleId, speechLocaleId: $speechLocaleId, fcmEnabledMachines: $fcmEnabledMachines, activeMachineId: $activeMachineId, fcmAvailable: $fcmAvailable, fcmSyncInProgress: $fcmSyncInProgress, fcmStatusKey: $fcmStatusKey)';
}


}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res>  {
  factory $SettingsStateCopyWith(SettingsState value, $Res Function(SettingsState) _then) = _$SettingsStateCopyWithImpl;
@useResult
$Res call({
 ThemeMode themeMode, String appLocaleId, String speechLocaleId, Set<String> fcmEnabledMachines, String? activeMachineId, bool fcmAvailable, bool fcmSyncInProgress, FcmStatusKey? fcmStatusKey
});




}
/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? appLocaleId = null,Object? speechLocaleId = null,Object? fcmEnabledMachines = null,Object? activeMachineId = freezed,Object? fcmAvailable = null,Object? fcmSyncInProgress = null,Object? fcmStatusKey = freezed,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,appLocaleId: null == appLocaleId ? _self.appLocaleId : appLocaleId // ignore: cast_nullable_to_non_nullable
as String,speechLocaleId: null == speechLocaleId ? _self.speechLocaleId : speechLocaleId // ignore: cast_nullable_to_non_nullable
as String,fcmEnabledMachines: null == fcmEnabledMachines ? _self.fcmEnabledMachines : fcmEnabledMachines // ignore: cast_nullable_to_non_nullable
as Set<String>,activeMachineId: freezed == activeMachineId ? _self.activeMachineId : activeMachineId // ignore: cast_nullable_to_non_nullable
as String?,fcmAvailable: null == fcmAvailable ? _self.fcmAvailable : fcmAvailable // ignore: cast_nullable_to_non_nullable
as bool,fcmSyncInProgress: null == fcmSyncInProgress ? _self.fcmSyncInProgress : fcmSyncInProgress // ignore: cast_nullable_to_non_nullable
as bool,fcmStatusKey: freezed == fcmStatusKey ? _self.fcmStatusKey : fcmStatusKey // ignore: cast_nullable_to_non_nullable
as FcmStatusKey?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsState].
extension SettingsStatePatterns on SettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsState value)  $default,){
final _that = this;
switch (_that) {
case _SettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThemeMode themeMode,  String appLocaleId,  String speechLocaleId,  Set<String> fcmEnabledMachines,  String? activeMachineId,  bool fcmAvailable,  bool fcmSyncInProgress,  FcmStatusKey? fcmStatusKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.themeMode,_that.appLocaleId,_that.speechLocaleId,_that.fcmEnabledMachines,_that.activeMachineId,_that.fcmAvailable,_that.fcmSyncInProgress,_that.fcmStatusKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThemeMode themeMode,  String appLocaleId,  String speechLocaleId,  Set<String> fcmEnabledMachines,  String? activeMachineId,  bool fcmAvailable,  bool fcmSyncInProgress,  FcmStatusKey? fcmStatusKey)  $default,) {final _that = this;
switch (_that) {
case _SettingsState():
return $default(_that.themeMode,_that.appLocaleId,_that.speechLocaleId,_that.fcmEnabledMachines,_that.activeMachineId,_that.fcmAvailable,_that.fcmSyncInProgress,_that.fcmStatusKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThemeMode themeMode,  String appLocaleId,  String speechLocaleId,  Set<String> fcmEnabledMachines,  String? activeMachineId,  bool fcmAvailable,  bool fcmSyncInProgress,  FcmStatusKey? fcmStatusKey)?  $default,) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.themeMode,_that.appLocaleId,_that.speechLocaleId,_that.fcmEnabledMachines,_that.activeMachineId,_that.fcmAvailable,_that.fcmSyncInProgress,_that.fcmStatusKey);case _:
  return null;

}
}

}

/// @nodoc


class _SettingsState extends SettingsState {
  const _SettingsState({this.themeMode = ThemeMode.system, this.appLocaleId = '', this.speechLocaleId = 'ja-JP', final  Set<String> fcmEnabledMachines = const {}, this.activeMachineId, this.fcmAvailable = false, this.fcmSyncInProgress = false, this.fcmStatusKey}): _fcmEnabledMachines = fcmEnabledMachines,super._();
  

/// Theme mode: system, light, or dark.
@override@JsonKey() final  ThemeMode themeMode;
/// App display locale ID (e.g. 'ja', 'en').
/// Empty string means follow the device default.
@override@JsonKey() final  String appLocaleId;
/// Locale ID for speech recognition (e.g. 'ja-JP', 'en-US').
/// Empty string means use device default.
@override@JsonKey() final  String speechLocaleId;
/// Set of Machine IDs that have push notifications enabled.
 final  Set<String> _fcmEnabledMachines;
/// Set of Machine IDs that have push notifications enabled.
@override@JsonKey() Set<String> get fcmEnabledMachines {
  if (_fcmEnabledMachines is EqualUnmodifiableSetView) return _fcmEnabledMachines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_fcmEnabledMachines);
}

/// Currently connected Machine ID (null when disconnected).
@override final  String? activeMachineId;
/// Whether Firebase Messaging is available in this runtime.
@override@JsonKey() final  bool fcmAvailable;
/// True while token registration/unregistration is being synchronized.
@override@JsonKey() final  bool fcmSyncInProgress;
/// Last push sync status key (resolved to localized string in UI).
@override final  FcmStatusKey? fcmStatusKey;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsStateCopyWith<_SettingsState> get copyWith => __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.appLocaleId, appLocaleId) || other.appLocaleId == appLocaleId)&&(identical(other.speechLocaleId, speechLocaleId) || other.speechLocaleId == speechLocaleId)&&const DeepCollectionEquality().equals(other._fcmEnabledMachines, _fcmEnabledMachines)&&(identical(other.activeMachineId, activeMachineId) || other.activeMachineId == activeMachineId)&&(identical(other.fcmAvailable, fcmAvailable) || other.fcmAvailable == fcmAvailable)&&(identical(other.fcmSyncInProgress, fcmSyncInProgress) || other.fcmSyncInProgress == fcmSyncInProgress)&&(identical(other.fcmStatusKey, fcmStatusKey) || other.fcmStatusKey == fcmStatusKey));
}


@override
int get hashCode => Object.hash(runtimeType,themeMode,appLocaleId,speechLocaleId,const DeepCollectionEquality().hash(_fcmEnabledMachines),activeMachineId,fcmAvailable,fcmSyncInProgress,fcmStatusKey);

@override
String toString() {
  return 'SettingsState(themeMode: $themeMode, appLocaleId: $appLocaleId, speechLocaleId: $speechLocaleId, fcmEnabledMachines: $fcmEnabledMachines, activeMachineId: $activeMachineId, fcmAvailable: $fcmAvailable, fcmSyncInProgress: $fcmSyncInProgress, fcmStatusKey: $fcmStatusKey)';
}


}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res> implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(_SettingsState value, $Res Function(_SettingsState) _then) = __$SettingsStateCopyWithImpl;
@override @useResult
$Res call({
 ThemeMode themeMode, String appLocaleId, String speechLocaleId, Set<String> fcmEnabledMachines, String? activeMachineId, bool fcmAvailable, bool fcmSyncInProgress, FcmStatusKey? fcmStatusKey
});




}
/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? appLocaleId = null,Object? speechLocaleId = null,Object? fcmEnabledMachines = null,Object? activeMachineId = freezed,Object? fcmAvailable = null,Object? fcmSyncInProgress = null,Object? fcmStatusKey = freezed,}) {
  return _then(_SettingsState(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,appLocaleId: null == appLocaleId ? _self.appLocaleId : appLocaleId // ignore: cast_nullable_to_non_nullable
as String,speechLocaleId: null == speechLocaleId ? _self.speechLocaleId : speechLocaleId // ignore: cast_nullable_to_non_nullable
as String,fcmEnabledMachines: null == fcmEnabledMachines ? _self._fcmEnabledMachines : fcmEnabledMachines // ignore: cast_nullable_to_non_nullable
as Set<String>,activeMachineId: freezed == activeMachineId ? _self.activeMachineId : activeMachineId // ignore: cast_nullable_to_non_nullable
as String?,fcmAvailable: null == fcmAvailable ? _self.fcmAvailable : fcmAvailable // ignore: cast_nullable_to_non_nullable
as bool,fcmSyncInProgress: null == fcmSyncInProgress ? _self.fcmSyncInProgress : fcmSyncInProgress // ignore: cast_nullable_to_non_nullable
as bool,fcmStatusKey: freezed == fcmStatusKey ? _self.fcmStatusKey : fcmStatusKey // ignore: cast_nullable_to_non_nullable
as FcmStatusKey?,
  ));
}


}

// dart format on
