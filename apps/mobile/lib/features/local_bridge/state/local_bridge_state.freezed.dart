// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'local_bridge_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LocalBridgeState {

 int get port; LocalBridgePhase get phase; LocalBridgeStatus? get status; LocalBridgeConfig? get config; LocalBridgePairing? get pairing; LocalBridgeTools? get tools; bool get toolsLoading;/// The running Bridge has no `/tools` endpoint.
 bool get toolsUnsupported;/// Unsaved changes: setting key -> new value; null removes the setting
/// from the config file (back to the default).
 Map<String, Object?> get edits;/// Setting key -> problem reported by the Bridge on save.
 Map<String, String> get settingErrors; LocalBridgeBusy get busy;/// Last failed action, shown once by the screen.
 LocalBridgeFailure? get actionFailure;/// The API key was replaced and applies after a restart.
 bool get apiKeyRotated; String? get errorDetail;/// Whether the app's LaunchAgent runs the Bridge.
 LauncherRegistration get launcherRegistration;/// Port the launcher's Bridge listens on (the saved port, else 8765).
/// Starting from the app only applies while that port is shown.
 int get launcherPort;/// What the launcher last reported (missing Node, port in use, ...).
 LauncherStatus? get launcherStatus;/// Starting from the app did not bring the Bridge up in time.
 bool get startFailed;
/// Create a copy of LocalBridgeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalBridgeStateCopyWith<LocalBridgeState> get copyWith => _$LocalBridgeStateCopyWithImpl<LocalBridgeState>(this as LocalBridgeState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LocalBridgeState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalBridgeState&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.config, _this.config) || other.config == _this.config)&&(identical(other.pairing, _this.pairing) || other.pairing == _this.pairing)&&(identical(other.tools, _this.tools) || other.tools == _this.tools)&&(identical(other.toolsLoading, _this.toolsLoading) || other.toolsLoading == _this.toolsLoading)&&(identical(other.toolsUnsupported, _this.toolsUnsupported) || other.toolsUnsupported == _this.toolsUnsupported)&&const DeepCollectionEquality().equals(other.edits, _this.edits)&&const DeepCollectionEquality().equals(other.settingErrors, _this.settingErrors)&&(identical(other.busy, _this.busy) || other.busy == _this.busy)&&(identical(other.actionFailure, _this.actionFailure) || other.actionFailure == _this.actionFailure)&&(identical(other.apiKeyRotated, _this.apiKeyRotated) || other.apiKeyRotated == _this.apiKeyRotated)&&(identical(other.errorDetail, _this.errorDetail) || other.errorDetail == _this.errorDetail)&&(identical(other.launcherRegistration, _this.launcherRegistration) || other.launcherRegistration == _this.launcherRegistration)&&(identical(other.launcherPort, _this.launcherPort) || other.launcherPort == _this.launcherPort)&&(identical(other.launcherStatus, _this.launcherStatus) || other.launcherStatus == _this.launcherStatus)&&(identical(other.startFailed, _this.startFailed) || other.startFailed == _this.startFailed));
}


@override
int get hashCode {
  final _this = this as LocalBridgeState;
  return Object.hash(runtimeType,_this.port,_this.phase,_this.status,_this.config,_this.pairing,_this.tools,_this.toolsLoading,_this.toolsUnsupported,const DeepCollectionEquality().hash(_this.edits),const DeepCollectionEquality().hash(_this.settingErrors),_this.busy,_this.actionFailure,_this.apiKeyRotated,_this.errorDetail,_this.launcherRegistration,_this.launcherPort,_this.launcherStatus,_this.startFailed);
}

@override
String toString() {
  final _this = this as LocalBridgeState;
  return 'LocalBridgeState(port: ${_this.port}, phase: ${_this.phase}, status: ${_this.status}, config: ${_this.config}, pairing: ${_this.pairing}, tools: ${_this.tools}, toolsLoading: ${_this.toolsLoading}, toolsUnsupported: ${_this.toolsUnsupported}, edits: ${_this.edits}, settingErrors: ${_this.settingErrors}, busy: ${_this.busy}, actionFailure: ${_this.actionFailure}, apiKeyRotated: ${_this.apiKeyRotated}, errorDetail: ${_this.errorDetail}, launcherRegistration: ${_this.launcherRegistration}, launcherPort: ${_this.launcherPort}, launcherStatus: ${_this.launcherStatus}, startFailed: ${_this.startFailed})';
}


}

/// @nodoc
abstract mixin class $LocalBridgeStateCopyWith<$Res>  {
  factory $LocalBridgeStateCopyWith(LocalBridgeState value, $Res Function(LocalBridgeState) _then) = _$LocalBridgeStateCopyWithImpl;
@useResult
$Res call({
 int port, LocalBridgePhase phase, LocalBridgeStatus? status, LocalBridgeConfig? config, LocalBridgePairing? pairing, LocalBridgeTools? tools, bool toolsLoading, bool toolsUnsupported, Map<String, Object?> edits, Map<String, String> settingErrors, LocalBridgeBusy busy, LocalBridgeFailure? actionFailure, bool apiKeyRotated, String? errorDetail, LauncherRegistration launcherRegistration, int launcherPort, LauncherStatus? launcherStatus, bool startFailed
});




}
/// @nodoc
class _$LocalBridgeStateCopyWithImpl<$Res>
    implements $LocalBridgeStateCopyWith<$Res> {
  _$LocalBridgeStateCopyWithImpl(this._self, this._then);

  final LocalBridgeState _self;
  final $Res Function(LocalBridgeState) _then;

/// Create a copy of LocalBridgeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? port = null,Object? phase = null,Object? status = freezed,Object? config = freezed,Object? pairing = freezed,Object? tools = freezed,Object? toolsLoading = null,Object? toolsUnsupported = null,Object? edits = null,Object? settingErrors = null,Object? busy = null,Object? actionFailure = freezed,Object? apiKeyRotated = null,Object? errorDetail = freezed,Object? launcherRegistration = null,Object? launcherPort = null,Object? launcherStatus = freezed,Object? startFailed = null,}) {
  return _then(LocalBridgeState(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LocalBridgePhase,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LocalBridgeStatus?,config: freezed == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as LocalBridgeConfig?,pairing: freezed == pairing ? _self.pairing : pairing // ignore: cast_nullable_to_non_nullable
as LocalBridgePairing?,tools: freezed == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as LocalBridgeTools?,toolsLoading: null == toolsLoading ? _self.toolsLoading : toolsLoading // ignore: cast_nullable_to_non_nullable
as bool,toolsUnsupported: null == toolsUnsupported ? _self.toolsUnsupported : toolsUnsupported // ignore: cast_nullable_to_non_nullable
as bool,edits: null == edits ? _self.edits : edits // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,settingErrors: null == settingErrors ? _self.settingErrors : settingErrors // ignore: cast_nullable_to_non_nullable
as Map<String, String>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as LocalBridgeBusy,actionFailure: freezed == actionFailure ? _self.actionFailure : actionFailure // ignore: cast_nullable_to_non_nullable
as LocalBridgeFailure?,apiKeyRotated: null == apiKeyRotated ? _self.apiKeyRotated : apiKeyRotated // ignore: cast_nullable_to_non_nullable
as bool,errorDetail: freezed == errorDetail ? _self.errorDetail : errorDetail // ignore: cast_nullable_to_non_nullable
as String?,launcherRegistration: null == launcherRegistration ? _self.launcherRegistration : launcherRegistration // ignore: cast_nullable_to_non_nullable
as LauncherRegistration,launcherPort: null == launcherPort ? _self.launcherPort : launcherPort // ignore: cast_nullable_to_non_nullable
as int,launcherStatus: freezed == launcherStatus ? _self.launcherStatus : launcherStatus // ignore: cast_nullable_to_non_nullable
as LauncherStatus?,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LocalBridgeState].
extension LocalBridgeStatePatterns on LocalBridgeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocalBridgeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocalBridgeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocalBridgeState value)  $default,){
final _that = this;
switch (_that) {
case _LocalBridgeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocalBridgeState value)?  $default,){
final _that = this;
switch (_that) {
case _LocalBridgeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int port,  LocalBridgePhase phase,  LocalBridgeStatus? status,  LocalBridgeConfig? config,  LocalBridgePairing? pairing,  LocalBridgeTools? tools,  bool toolsLoading,  bool toolsUnsupported,  Map<String, Object?> edits,  Map<String, String> settingErrors,  LocalBridgeBusy busy,  LocalBridgeFailure? actionFailure,  bool apiKeyRotated,  String? errorDetail,  LauncherRegistration launcherRegistration,  int launcherPort,  LauncherStatus? launcherStatus,  bool startFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalBridgeState() when $default != null:
return $default(_that.port,_that.phase,_that.status,_that.config,_that.pairing,_that.tools,_that.toolsLoading,_that.toolsUnsupported,_that.edits,_that.settingErrors,_that.busy,_that.actionFailure,_that.apiKeyRotated,_that.errorDetail,_that.launcherRegistration,_that.launcherPort,_that.launcherStatus,_that.startFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int port,  LocalBridgePhase phase,  LocalBridgeStatus? status,  LocalBridgeConfig? config,  LocalBridgePairing? pairing,  LocalBridgeTools? tools,  bool toolsLoading,  bool toolsUnsupported,  Map<String, Object?> edits,  Map<String, String> settingErrors,  LocalBridgeBusy busy,  LocalBridgeFailure? actionFailure,  bool apiKeyRotated,  String? errorDetail,  LauncherRegistration launcherRegistration,  int launcherPort,  LauncherStatus? launcherStatus,  bool startFailed)  $default,) {final _that = this;
switch (_that) {
case _LocalBridgeState():
return $default(_that.port,_that.phase,_that.status,_that.config,_that.pairing,_that.tools,_that.toolsLoading,_that.toolsUnsupported,_that.edits,_that.settingErrors,_that.busy,_that.actionFailure,_that.apiKeyRotated,_that.errorDetail,_that.launcherRegistration,_that.launcherPort,_that.launcherStatus,_that.startFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int port,  LocalBridgePhase phase,  LocalBridgeStatus? status,  LocalBridgeConfig? config,  LocalBridgePairing? pairing,  LocalBridgeTools? tools,  bool toolsLoading,  bool toolsUnsupported,  Map<String, Object?> edits,  Map<String, String> settingErrors,  LocalBridgeBusy busy,  LocalBridgeFailure? actionFailure,  bool apiKeyRotated,  String? errorDetail,  LauncherRegistration launcherRegistration,  int launcherPort,  LauncherStatus? launcherStatus,  bool startFailed)?  $default,) {final _that = this;
switch (_that) {
case _LocalBridgeState() when $default != null:
return $default(_that.port,_that.phase,_that.status,_that.config,_that.pairing,_that.tools,_that.toolsLoading,_that.toolsUnsupported,_that.edits,_that.settingErrors,_that.busy,_that.actionFailure,_that.apiKeyRotated,_that.errorDetail,_that.launcherRegistration,_that.launcherPort,_that.launcherStatus,_that.startFailed);case _:
  return null;

}
}

}

/// @nodoc


class _LocalBridgeState extends LocalBridgeState {
  const _LocalBridgeState({required this.port, this.phase = LocalBridgePhase.loading, this.status, this.config, this.pairing, this.tools, this.toolsLoading = false, this.toolsUnsupported = false,  Map<String, Object?> edits = const <String, Object?>{},  Map<String, String> settingErrors = const <String, String>{}, this.busy = LocalBridgeBusy.none, this.actionFailure, this.apiKeyRotated = false, this.errorDetail, this.launcherRegistration = LauncherRegistration.unavailable, this.launcherPort = 8765, this.launcherStatus, this.startFailed = false}): _edits = edits,_settingErrors = settingErrors,super._();
  

@override final  int port;
@override@JsonKey() final  LocalBridgePhase phase;
@override final  LocalBridgeStatus? status;
@override final  LocalBridgeConfig? config;
@override final  LocalBridgePairing? pairing;
@override final  LocalBridgeTools? tools;
@override@JsonKey() final  bool toolsLoading;
/// The running Bridge has no `/tools` endpoint.
@override@JsonKey() final  bool toolsUnsupported;
/// Unsaved changes: setting key -> new value; null removes the setting
/// from the config file (back to the default).
 final  Map<String, Object?> _edits;
/// Unsaved changes: setting key -> new value; null removes the setting
/// from the config file (back to the default).
@override@JsonKey() Map<String, Object?> get edits {
  if (_edits is EqualUnmodifiableMapView) return _edits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_edits);
}

/// Setting key -> problem reported by the Bridge on save.
 final  Map<String, String> _settingErrors;
/// Setting key -> problem reported by the Bridge on save.
@override@JsonKey() Map<String, String> get settingErrors {
  if (_settingErrors is EqualUnmodifiableMapView) return _settingErrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settingErrors);
}

@override@JsonKey() final  LocalBridgeBusy busy;
/// Last failed action, shown once by the screen.
@override final  LocalBridgeFailure? actionFailure;
/// The API key was replaced and applies after a restart.
@override@JsonKey() final  bool apiKeyRotated;
@override final  String? errorDetail;
/// Whether the app's LaunchAgent runs the Bridge.
@override@JsonKey() final  LauncherRegistration launcherRegistration;
/// Port the launcher's Bridge listens on (the saved port, else 8765).
/// Starting from the app only applies while that port is shown.
@override@JsonKey() final  int launcherPort;
/// What the launcher last reported (missing Node, port in use, ...).
@override final  LauncherStatus? launcherStatus;
/// Starting from the app did not bring the Bridge up in time.
@override@JsonKey() final  bool startFailed;

/// Create a copy of LocalBridgeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalBridgeStateCopyWith<_LocalBridgeState> get copyWith => __$LocalBridgeStateCopyWithImpl<_LocalBridgeState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalBridgeState&&(identical(other.port, port) || other.port == port)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.status, status) || other.status == status)&&(identical(other.config, config) || other.config == config)&&(identical(other.pairing, pairing) || other.pairing == pairing)&&(identical(other.tools, tools) || other.tools == tools)&&(identical(other.toolsLoading, toolsLoading) || other.toolsLoading == toolsLoading)&&(identical(other.toolsUnsupported, toolsUnsupported) || other.toolsUnsupported == toolsUnsupported)&&const DeepCollectionEquality().equals(other.edits, _edits)&&const DeepCollectionEquality().equals(other.settingErrors, _settingErrors)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.actionFailure, actionFailure) || other.actionFailure == actionFailure)&&(identical(other.apiKeyRotated, apiKeyRotated) || other.apiKeyRotated == apiKeyRotated)&&(identical(other.errorDetail, errorDetail) || other.errorDetail == errorDetail)&&(identical(other.launcherRegistration, launcherRegistration) || other.launcherRegistration == launcherRegistration)&&(identical(other.launcherPort, launcherPort) || other.launcherPort == launcherPort)&&(identical(other.launcherStatus, launcherStatus) || other.launcherStatus == launcherStatus)&&(identical(other.startFailed, startFailed) || other.startFailed == startFailed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,port,phase,status,config,pairing,tools,toolsLoading,toolsUnsupported,const DeepCollectionEquality().hash(_edits),const DeepCollectionEquality().hash(_settingErrors),busy,actionFailure,apiKeyRotated,errorDetail,launcherRegistration,launcherPort,launcherStatus,startFailed);
}

@override
String toString() {
    return 'LocalBridgeState(port: $port, phase: $phase, status: $status, config: $config, pairing: $pairing, tools: $tools, toolsLoading: $toolsLoading, toolsUnsupported: $toolsUnsupported, edits: $edits, settingErrors: $settingErrors, busy: $busy, actionFailure: $actionFailure, apiKeyRotated: $apiKeyRotated, errorDetail: $errorDetail, launcherRegistration: $launcherRegistration, launcherPort: $launcherPort, launcherStatus: $launcherStatus, startFailed: $startFailed)';
}


}

/// @nodoc
abstract mixin class _$LocalBridgeStateCopyWith<$Res> implements $LocalBridgeStateCopyWith<$Res> {
  factory _$LocalBridgeStateCopyWith(_LocalBridgeState value, $Res Function(_LocalBridgeState) _then) = __$LocalBridgeStateCopyWithImpl;
@override @useResult
$Res call({
 int port, LocalBridgePhase phase, LocalBridgeStatus? status, LocalBridgeConfig? config, LocalBridgePairing? pairing, LocalBridgeTools? tools, bool toolsLoading, bool toolsUnsupported, Map<String, Object?> edits, Map<String, String> settingErrors, LocalBridgeBusy busy, LocalBridgeFailure? actionFailure, bool apiKeyRotated, String? errorDetail, LauncherRegistration launcherRegistration, int launcherPort, LauncherStatus? launcherStatus, bool startFailed
});




}
/// @nodoc
class __$LocalBridgeStateCopyWithImpl<$Res>
    implements _$LocalBridgeStateCopyWith<$Res> {
  __$LocalBridgeStateCopyWithImpl(this._self, this._then);

  final _LocalBridgeState _self;
  final $Res Function(_LocalBridgeState) _then;

/// Create a copy of LocalBridgeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? port = null,Object? phase = null,Object? status = freezed,Object? config = freezed,Object? pairing = freezed,Object? tools = freezed,Object? toolsLoading = null,Object? toolsUnsupported = null,Object? edits = null,Object? settingErrors = null,Object? busy = null,Object? actionFailure = freezed,Object? apiKeyRotated = null,Object? errorDetail = freezed,Object? launcherRegistration = null,Object? launcherPort = null,Object? launcherStatus = freezed,Object? startFailed = null,}) {
  return _then(_LocalBridgeState(
port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as LocalBridgePhase,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as LocalBridgeStatus?,config: freezed == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as LocalBridgeConfig?,pairing: freezed == pairing ? _self.pairing : pairing // ignore: cast_nullable_to_non_nullable
as LocalBridgePairing?,tools: freezed == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as LocalBridgeTools?,toolsLoading: null == toolsLoading ? _self.toolsLoading : toolsLoading // ignore: cast_nullable_to_non_nullable
as bool,toolsUnsupported: null == toolsUnsupported ? _self.toolsUnsupported : toolsUnsupported // ignore: cast_nullable_to_non_nullable
as bool,edits: null == edits ? _self._edits : edits // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,settingErrors: null == settingErrors ? _self._settingErrors : settingErrors // ignore: cast_nullable_to_non_nullable
as Map<String, String>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as LocalBridgeBusy,actionFailure: freezed == actionFailure ? _self.actionFailure : actionFailure // ignore: cast_nullable_to_non_nullable
as LocalBridgeFailure?,apiKeyRotated: null == apiKeyRotated ? _self.apiKeyRotated : apiKeyRotated // ignore: cast_nullable_to_non_nullable
as bool,errorDetail: freezed == errorDetail ? _self.errorDetail : errorDetail // ignore: cast_nullable_to_non_nullable
as String?,launcherRegistration: null == launcherRegistration ? _self.launcherRegistration : launcherRegistration // ignore: cast_nullable_to_non_nullable
as LauncherRegistration,launcherPort: null == launcherPort ? _self.launcherPort : launcherPort // ignore: cast_nullable_to_non_nullable
as int,launcherStatus: freezed == launcherStatus ? _self.launcherStatus : launcherStatus // ignore: cast_nullable_to_non_nullable
as LauncherStatus?,startFailed: null == startFailed ? _self.startFailed : startFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
