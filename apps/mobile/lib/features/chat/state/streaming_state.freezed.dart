// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'streaming_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StreamingState {

/// Accumulated assistant text from stream_delta messages.
 String get text;/// Accumulated thinking text from thinking_delta messages.
 String get thinking;/// Whether we are actively receiving deltas.
 bool get isStreaming;
/// Create a copy of StreamingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StreamingStateCopyWith<StreamingState> get copyWith => _$StreamingStateCopyWithImpl<StreamingState>(this as StreamingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StreamingState&&(identical(other.text, text) || other.text == text)&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming));
}


@override
int get hashCode => Object.hash(runtimeType,text,thinking,isStreaming);

@override
String toString() {
  return 'StreamingState(text: $text, thinking: $thinking, isStreaming: $isStreaming)';
}


}

/// @nodoc
abstract mixin class $StreamingStateCopyWith<$Res>  {
  factory $StreamingStateCopyWith(StreamingState value, $Res Function(StreamingState) _then) = _$StreamingStateCopyWithImpl;
@useResult
$Res call({
 String text, String thinking, bool isStreaming
});




}
/// @nodoc
class _$StreamingStateCopyWithImpl<$Res>
    implements $StreamingStateCopyWith<$Res> {
  _$StreamingStateCopyWithImpl(this._self, this._then);

  final StreamingState _self;
  final $Res Function(StreamingState) _then;

/// Create a copy of StreamingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? thinking = null,Object? isStreaming = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as String,isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [StreamingState].
extension StreamingStatePatterns on StreamingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StreamingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StreamingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StreamingState value)  $default,){
final _that = this;
switch (_that) {
case _StreamingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StreamingState value)?  $default,){
final _that = this;
switch (_that) {
case _StreamingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  String thinking,  bool isStreaming)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StreamingState() when $default != null:
return $default(_that.text,_that.thinking,_that.isStreaming);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  String thinking,  bool isStreaming)  $default,) {final _that = this;
switch (_that) {
case _StreamingState():
return $default(_that.text,_that.thinking,_that.isStreaming);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  String thinking,  bool isStreaming)?  $default,) {final _that = this;
switch (_that) {
case _StreamingState() when $default != null:
return $default(_that.text,_that.thinking,_that.isStreaming);case _:
  return null;

}
}

}

/// @nodoc


class _StreamingState implements StreamingState {
  const _StreamingState({this.text = '', this.thinking = '', this.isStreaming = false});
  

/// Accumulated assistant text from stream_delta messages.
@override@JsonKey() final  String text;
/// Accumulated thinking text from thinking_delta messages.
@override@JsonKey() final  String thinking;
/// Whether we are actively receiving deltas.
@override@JsonKey() final  bool isStreaming;

/// Create a copy of StreamingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StreamingStateCopyWith<_StreamingState> get copyWith => __$StreamingStateCopyWithImpl<_StreamingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StreamingState&&(identical(other.text, text) || other.text == text)&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.isStreaming, isStreaming) || other.isStreaming == isStreaming));
}


@override
int get hashCode => Object.hash(runtimeType,text,thinking,isStreaming);

@override
String toString() {
  return 'StreamingState(text: $text, thinking: $thinking, isStreaming: $isStreaming)';
}


}

/// @nodoc
abstract mixin class _$StreamingStateCopyWith<$Res> implements $StreamingStateCopyWith<$Res> {
  factory _$StreamingStateCopyWith(_StreamingState value, $Res Function(_StreamingState) _then) = __$StreamingStateCopyWithImpl;
@override @useResult
$Res call({
 String text, String thinking, bool isStreaming
});




}
/// @nodoc
class __$StreamingStateCopyWithImpl<$Res>
    implements _$StreamingStateCopyWith<$Res> {
  __$StreamingStateCopyWithImpl(this._self, this._then);

  final _StreamingState _self;
  final $Res Function(_StreamingState) _then;

/// Create a copy of StreamingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? thinking = null,Object? isStreaming = null,}) {
  return _then(_StreamingState(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as String,isStreaming: null == isStreaming ? _self.isStreaming : isStreaming // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
