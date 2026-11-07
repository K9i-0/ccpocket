// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_transcript_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionTranscriptState {

 SessionTranscriptStatus get status; List<ChatEntry> get entries;/// Transcript index of the first loaded message; older pages end here.
 int get startIndex; bool get loadingOlder;/// An older page failed; the loaded entries stay visible.
 bool get olderFailed;
/// Create a copy of SessionTranscriptState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionTranscriptStateCopyWith<SessionTranscriptState> get copyWith => _$SessionTranscriptStateCopyWithImpl<SessionTranscriptState>(this as SessionTranscriptState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionTranscriptState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionTranscriptState&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.entries, _this.entries)&&(identical(other.startIndex, _this.startIndex) || other.startIndex == _this.startIndex)&&(identical(other.loadingOlder, _this.loadingOlder) || other.loadingOlder == _this.loadingOlder)&&(identical(other.olderFailed, _this.olderFailed) || other.olderFailed == _this.olderFailed));
}


@override
int get hashCode {
  final _this = this as SessionTranscriptState;
  return Object.hash(runtimeType,_this.status,const DeepCollectionEquality().hash(_this.entries),_this.startIndex,_this.loadingOlder,_this.olderFailed);
}

@override
String toString() {
  final _this = this as SessionTranscriptState;
  return 'SessionTranscriptState(status: ${_this.status}, entries: ${_this.entries}, startIndex: ${_this.startIndex}, loadingOlder: ${_this.loadingOlder}, olderFailed: ${_this.olderFailed})';
}


}

/// @nodoc
abstract mixin class $SessionTranscriptStateCopyWith<$Res>  {
  factory $SessionTranscriptStateCopyWith(SessionTranscriptState value, $Res Function(SessionTranscriptState) _then) = _$SessionTranscriptStateCopyWithImpl;
@useResult
$Res call({
 SessionTranscriptStatus status, List<ChatEntry> entries, int startIndex, bool loadingOlder, bool olderFailed
});




}
/// @nodoc
class _$SessionTranscriptStateCopyWithImpl<$Res>
    implements $SessionTranscriptStateCopyWith<$Res> {
  _$SessionTranscriptStateCopyWithImpl(this._self, this._then);

  final SessionTranscriptState _self;
  final $Res Function(SessionTranscriptState) _then;

/// Create a copy of SessionTranscriptState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? entries = null,Object? startIndex = null,Object? loadingOlder = null,Object? olderFailed = null,}) {
  return _then(SessionTranscriptState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionTranscriptStatus,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,startIndex: null == startIndex ? _self.startIndex : startIndex // ignore: cast_nullable_to_non_nullable
as int,loadingOlder: null == loadingOlder ? _self.loadingOlder : loadingOlder // ignore: cast_nullable_to_non_nullable
as bool,olderFailed: null == olderFailed ? _self.olderFailed : olderFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionTranscriptState].
extension SessionTranscriptStatePatterns on SessionTranscriptState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionTranscriptState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionTranscriptState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionTranscriptState value)  $default,){
final _that = this;
switch (_that) {
case _SessionTranscriptState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionTranscriptState value)?  $default,){
final _that = this;
switch (_that) {
case _SessionTranscriptState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SessionTranscriptStatus status,  List<ChatEntry> entries,  int startIndex,  bool loadingOlder,  bool olderFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionTranscriptState() when $default != null:
return $default(_that.status,_that.entries,_that.startIndex,_that.loadingOlder,_that.olderFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SessionTranscriptStatus status,  List<ChatEntry> entries,  int startIndex,  bool loadingOlder,  bool olderFailed)  $default,) {final _that = this;
switch (_that) {
case _SessionTranscriptState():
return $default(_that.status,_that.entries,_that.startIndex,_that.loadingOlder,_that.olderFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SessionTranscriptStatus status,  List<ChatEntry> entries,  int startIndex,  bool loadingOlder,  bool olderFailed)?  $default,) {final _that = this;
switch (_that) {
case _SessionTranscriptState() when $default != null:
return $default(_that.status,_that.entries,_that.startIndex,_that.loadingOlder,_that.olderFailed);case _:
  return null;

}
}

}

/// @nodoc


class _SessionTranscriptState implements SessionTranscriptState {
  const _SessionTranscriptState({this.status = SessionTranscriptStatus.loading,  List<ChatEntry> entries = const [], this.startIndex = 0, this.loadingOlder = false, this.olderFailed = false}): _entries = entries;
  

@override@JsonKey() final  SessionTranscriptStatus status;
 final  List<ChatEntry> _entries;
@override@JsonKey() List<ChatEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

/// Transcript index of the first loaded message; older pages end here.
@override@JsonKey() final  int startIndex;
@override@JsonKey() final  bool loadingOlder;
/// An older page failed; the loaded entries stay visible.
@override@JsonKey() final  bool olderFailed;

/// Create a copy of SessionTranscriptState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionTranscriptStateCopyWith<_SessionTranscriptState> get copyWith => __$SessionTranscriptStateCopyWithImpl<_SessionTranscriptState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionTranscriptState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.entries, _entries)&&(identical(other.startIndex, startIndex) || other.startIndex == startIndex)&&(identical(other.loadingOlder, loadingOlder) || other.loadingOlder == loadingOlder)&&(identical(other.olderFailed, olderFailed) || other.olderFailed == olderFailed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_entries),startIndex,loadingOlder,olderFailed);
}

@override
String toString() {
    return 'SessionTranscriptState(status: $status, entries: $entries, startIndex: $startIndex, loadingOlder: $loadingOlder, olderFailed: $olderFailed)';
}


}

/// @nodoc
abstract mixin class _$SessionTranscriptStateCopyWith<$Res> implements $SessionTranscriptStateCopyWith<$Res> {
  factory _$SessionTranscriptStateCopyWith(_SessionTranscriptState value, $Res Function(_SessionTranscriptState) _then) = __$SessionTranscriptStateCopyWithImpl;
@override @useResult
$Res call({
 SessionTranscriptStatus status, List<ChatEntry> entries, int startIndex, bool loadingOlder, bool olderFailed
});




}
/// @nodoc
class __$SessionTranscriptStateCopyWithImpl<$Res>
    implements _$SessionTranscriptStateCopyWith<$Res> {
  __$SessionTranscriptStateCopyWithImpl(this._self, this._then);

  final _SessionTranscriptState _self;
  final $Res Function(_SessionTranscriptState) _then;

/// Create a copy of SessionTranscriptState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? entries = null,Object? startIndex = null,Object? loadingOlder = null,Object? olderFailed = null,}) {
  return _then(_SessionTranscriptState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SessionTranscriptStatus,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,startIndex: null == startIndex ? _self.startIndex : startIndex // ignore: cast_nullable_to_non_nullable
as int,loadingOlder: null == loadingOlder ? _self.loadingOlder : loadingOlder // ignore: cast_nullable_to_non_nullable
as bool,olderFailed: null == olderFailed ? _self.olderFailed : olderFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
