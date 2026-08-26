// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_link_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionLinkState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionLinkState()';
}


}

/// @nodoc
class $SessionLinkStateCopyWith<$Res>  {
$SessionLinkStateCopyWith(SessionLinkState _, $Res Function(SessionLinkState) __);
}


/// Adds pattern-matching-related methods to [SessionLinkState].
extension SessionLinkStatePatterns on SessionLinkState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SessionLinkResolving value)?  resolving,TResult Function( SessionLinkResuming value)?  resuming,TResult Function( SessionLinkOpenLive value)?  openLive,TResult Function( SessionLinkOpenResumed value)?  openResumed,TResult Function( SessionLinkOpenReadOnly value)?  openReadOnly,TResult Function( SessionLinkUnavailable value)?  unavailable,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SessionLinkResolving() when resolving != null:
return resolving(_that);case SessionLinkResuming() when resuming != null:
return resuming(_that);case SessionLinkOpenLive() when openLive != null:
return openLive(_that);case SessionLinkOpenResumed() when openResumed != null:
return openResumed(_that);case SessionLinkOpenReadOnly() when openReadOnly != null:
return openReadOnly(_that);case SessionLinkUnavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SessionLinkResolving value)  resolving,required TResult Function( SessionLinkResuming value)  resuming,required TResult Function( SessionLinkOpenLive value)  openLive,required TResult Function( SessionLinkOpenResumed value)  openResumed,required TResult Function( SessionLinkOpenReadOnly value)  openReadOnly,required TResult Function( SessionLinkUnavailable value)  unavailable,}){
final _that = this;
switch (_that) {
case SessionLinkResolving():
return resolving(_that);case SessionLinkResuming():
return resuming(_that);case SessionLinkOpenLive():
return openLive(_that);case SessionLinkOpenResumed():
return openResumed(_that);case SessionLinkOpenReadOnly():
return openReadOnly(_that);case SessionLinkUnavailable():
return unavailable(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SessionLinkResolving value)?  resolving,TResult? Function( SessionLinkResuming value)?  resuming,TResult? Function( SessionLinkOpenLive value)?  openLive,TResult? Function( SessionLinkOpenResumed value)?  openResumed,TResult? Function( SessionLinkOpenReadOnly value)?  openReadOnly,TResult? Function( SessionLinkUnavailable value)?  unavailable,}){
final _that = this;
switch (_that) {
case SessionLinkResolving() when resolving != null:
return resolving(_that);case SessionLinkResuming() when resuming != null:
return resuming(_that);case SessionLinkOpenLive() when openLive != null:
return openLive(_that);case SessionLinkOpenResumed() when openResumed != null:
return openResumed(_that);case SessionLinkOpenReadOnly() when openReadOnly != null:
return openReadOnly(_that);case SessionLinkUnavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  resolving,TResult Function()?  resuming,TResult Function( String bridgeSessionId,  String provider)?  openLive,TResult Function( SystemMessage session,  String? gitBranch)?  openResumed,TResult Function( String provider,  RecentSession recentSession,  SessionOwnershipProjection ownership,  ErrorMessage? failure)?  openReadOnly,TResult Function( String? reason,  String? recoveryAction,  ErrorMessage? failure)?  unavailable,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SessionLinkResolving() when resolving != null:
return resolving();case SessionLinkResuming() when resuming != null:
return resuming();case SessionLinkOpenLive() when openLive != null:
return openLive(_that.bridgeSessionId,_that.provider);case SessionLinkOpenResumed() when openResumed != null:
return openResumed(_that.session,_that.gitBranch);case SessionLinkOpenReadOnly() when openReadOnly != null:
return openReadOnly(_that.provider,_that.recentSession,_that.ownership,_that.failure);case SessionLinkUnavailable() when unavailable != null:
return unavailable(_that.reason,_that.recoveryAction,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  resolving,required TResult Function()  resuming,required TResult Function( String bridgeSessionId,  String provider)  openLive,required TResult Function( SystemMessage session,  String? gitBranch)  openResumed,required TResult Function( String provider,  RecentSession recentSession,  SessionOwnershipProjection ownership,  ErrorMessage? failure)  openReadOnly,required TResult Function( String? reason,  String? recoveryAction,  ErrorMessage? failure)  unavailable,}) {final _that = this;
switch (_that) {
case SessionLinkResolving():
return resolving();case SessionLinkResuming():
return resuming();case SessionLinkOpenLive():
return openLive(_that.bridgeSessionId,_that.provider);case SessionLinkOpenResumed():
return openResumed(_that.session,_that.gitBranch);case SessionLinkOpenReadOnly():
return openReadOnly(_that.provider,_that.recentSession,_that.ownership,_that.failure);case SessionLinkUnavailable():
return unavailable(_that.reason,_that.recoveryAction,_that.failure);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  resolving,TResult? Function()?  resuming,TResult? Function( String bridgeSessionId,  String provider)?  openLive,TResult? Function( SystemMessage session,  String? gitBranch)?  openResumed,TResult? Function( String provider,  RecentSession recentSession,  SessionOwnershipProjection ownership,  ErrorMessage? failure)?  openReadOnly,TResult? Function( String? reason,  String? recoveryAction,  ErrorMessage? failure)?  unavailable,}) {final _that = this;
switch (_that) {
case SessionLinkResolving() when resolving != null:
return resolving();case SessionLinkResuming() when resuming != null:
return resuming();case SessionLinkOpenLive() when openLive != null:
return openLive(_that.bridgeSessionId,_that.provider);case SessionLinkOpenResumed() when openResumed != null:
return openResumed(_that.session,_that.gitBranch);case SessionLinkOpenReadOnly() when openReadOnly != null:
return openReadOnly(_that.provider,_that.recentSession,_that.ownership,_that.failure);case SessionLinkUnavailable() when unavailable != null:
return unavailable(_that.reason,_that.recoveryAction,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class SessionLinkResolving implements SessionLinkState {
  const SessionLinkResolving();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkResolving);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionLinkState.resolving()';
}


}




/// @nodoc


class SessionLinkResuming implements SessionLinkState {
  const SessionLinkResuming();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkResuming);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'SessionLinkState.resuming()';
}


}




/// @nodoc


class SessionLinkOpenLive implements SessionLinkState {
  const SessionLinkOpenLive({required this.bridgeSessionId, required this.provider});


 final  String bridgeSessionId;
 final  String provider;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLinkOpenLiveCopyWith<SessionLinkOpenLive> get copyWith => _$SessionLinkOpenLiveCopyWithImpl<SessionLinkOpenLive>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkOpenLive&&(identical(other.bridgeSessionId, bridgeSessionId) || other.bridgeSessionId == bridgeSessionId)&&(identical(other.provider, provider) || other.provider == provider));
}


@override
int get hashCode => Object.hash(runtimeType,bridgeSessionId,provider);

@override
String toString() {
  return 'SessionLinkState.openLive(bridgeSessionId: $bridgeSessionId, provider: $provider)';
}


}

/// @nodoc
abstract mixin class $SessionLinkOpenLiveCopyWith<$Res> implements $SessionLinkStateCopyWith<$Res> {
  factory $SessionLinkOpenLiveCopyWith(SessionLinkOpenLive value, $Res Function(SessionLinkOpenLive) _then) = _$SessionLinkOpenLiveCopyWithImpl;
@useResult
$Res call({
 String bridgeSessionId, String provider
});




}
/// @nodoc
class _$SessionLinkOpenLiveCopyWithImpl<$Res>
    implements $SessionLinkOpenLiveCopyWith<$Res> {
  _$SessionLinkOpenLiveCopyWithImpl(this._self, this._then);

  final SessionLinkOpenLive _self;
  final $Res Function(SessionLinkOpenLive) _then;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? bridgeSessionId = null,Object? provider = null,}) {
  return _then(SessionLinkOpenLive(
bridgeSessionId: null == bridgeSessionId ? _self.bridgeSessionId : bridgeSessionId // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class SessionLinkOpenResumed implements SessionLinkState {
  const SessionLinkOpenResumed({required this.session, this.gitBranch});


 final  SystemMessage session;
 final  String? gitBranch;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLinkOpenResumedCopyWith<SessionLinkOpenResumed> get copyWith => _$SessionLinkOpenResumedCopyWithImpl<SessionLinkOpenResumed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkOpenResumed&&(identical(other.session, session) || other.session == session)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch));
}


@override
int get hashCode => Object.hash(runtimeType,session,gitBranch);

@override
String toString() {
  return 'SessionLinkState.openResumed(session: $session, gitBranch: $gitBranch)';
}


}

/// @nodoc
abstract mixin class $SessionLinkOpenResumedCopyWith<$Res> implements $SessionLinkStateCopyWith<$Res> {
  factory $SessionLinkOpenResumedCopyWith(SessionLinkOpenResumed value, $Res Function(SessionLinkOpenResumed) _then) = _$SessionLinkOpenResumedCopyWithImpl;
@useResult
$Res call({
 SystemMessage session, String? gitBranch
});




}
/// @nodoc
class _$SessionLinkOpenResumedCopyWithImpl<$Res>
    implements $SessionLinkOpenResumedCopyWith<$Res> {
  _$SessionLinkOpenResumedCopyWithImpl(this._self, this._then);

  final SessionLinkOpenResumed _self;
  final $Res Function(SessionLinkOpenResumed) _then;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? session = null,Object? gitBranch = freezed,}) {
  return _then(SessionLinkOpenResumed(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as SystemMessage,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class SessionLinkOpenReadOnly implements SessionLinkState {
  const SessionLinkOpenReadOnly({required this.provider, required this.recentSession, required this.ownership, this.failure});


 final  String provider;
 final  RecentSession recentSession;
 final  SessionOwnershipProjection ownership;
 final  ErrorMessage? failure;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLinkOpenReadOnlyCopyWith<SessionLinkOpenReadOnly> get copyWith => _$SessionLinkOpenReadOnlyCopyWithImpl<SessionLinkOpenReadOnly>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkOpenReadOnly&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.recentSession, recentSession) || other.recentSession == recentSession)&&(identical(other.ownership, ownership) || other.ownership == ownership)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,provider,recentSession,ownership,failure);

@override
String toString() {
  return 'SessionLinkState.openReadOnly(provider: $provider, recentSession: $recentSession, ownership: $ownership, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $SessionLinkOpenReadOnlyCopyWith<$Res> implements $SessionLinkStateCopyWith<$Res> {
  factory $SessionLinkOpenReadOnlyCopyWith(SessionLinkOpenReadOnly value, $Res Function(SessionLinkOpenReadOnly) _then) = _$SessionLinkOpenReadOnlyCopyWithImpl;
@useResult
$Res call({
 String provider, RecentSession recentSession, SessionOwnershipProjection ownership, ErrorMessage? failure
});




}
/// @nodoc
class _$SessionLinkOpenReadOnlyCopyWithImpl<$Res>
    implements $SessionLinkOpenReadOnlyCopyWith<$Res> {
  _$SessionLinkOpenReadOnlyCopyWithImpl(this._self, this._then);

  final SessionLinkOpenReadOnly _self;
  final $Res Function(SessionLinkOpenReadOnly) _then;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? provider = null,Object? recentSession = null,Object? ownership = null,Object? failure = freezed,}) {
  return _then(SessionLinkOpenReadOnly(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,recentSession: null == recentSession ? _self.recentSession : recentSession // ignore: cast_nullable_to_non_nullable
as RecentSession,ownership: null == ownership ? _self.ownership : ownership // ignore: cast_nullable_to_non_nullable
as SessionOwnershipProjection,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ErrorMessage?,
  ));
}


}

/// @nodoc


class SessionLinkUnavailable implements SessionLinkState {
  const SessionLinkUnavailable({this.reason, this.recoveryAction, this.failure});


 final  String? reason;
 final  String? recoveryAction;
 final  ErrorMessage? failure;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLinkUnavailableCopyWith<SessionLinkUnavailable> get copyWith => _$SessionLinkUnavailableCopyWithImpl<SessionLinkUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLinkUnavailable&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.recoveryAction, recoveryAction) || other.recoveryAction == recoveryAction)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode => Object.hash(runtimeType,reason,recoveryAction,failure);

@override
String toString() {
  return 'SessionLinkState.unavailable(reason: $reason, recoveryAction: $recoveryAction, failure: $failure)';
}


}

/// @nodoc
abstract mixin class $SessionLinkUnavailableCopyWith<$Res> implements $SessionLinkStateCopyWith<$Res> {
  factory $SessionLinkUnavailableCopyWith(SessionLinkUnavailable value, $Res Function(SessionLinkUnavailable) _then) = _$SessionLinkUnavailableCopyWithImpl;
@useResult
$Res call({
 String? reason, String? recoveryAction, ErrorMessage? failure
});




}
/// @nodoc
class _$SessionLinkUnavailableCopyWithImpl<$Res>
    implements $SessionLinkUnavailableCopyWith<$Res> {
  _$SessionLinkUnavailableCopyWithImpl(this._self, this._then);

  final SessionLinkUnavailable _self;
  final $Res Function(SessionLinkUnavailable) _then;

/// Create a copy of SessionLinkState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reason = freezed,Object? recoveryAction = freezed,Object? failure = freezed,}) {
  return _then(SessionLinkUnavailable(
reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,recoveryAction: freezed == recoveryAction ? _self.recoveryAction : recoveryAction // ignore: cast_nullable_to_non_nullable
as String?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as ErrorMessage?,
  ));
}


}

// dart format on
