// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'commit_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CommitState {

/// Commit message entered by the user.
 String get message;/// Whether to auto-generate the commit message.
 bool get autoGenerate;/// Current status of the multi-step commit flow.
 CommitStatus get status;/// Error message if any step fails.
 String? get error;/// Commit hash after successful commit.
 String? get commitHash;/// Number of staged files.
 int get stagedFileCount;/// Number of insertions across staged files.
 int get insertions;/// Number of deletions across staged files.
 int get deletions;
/// Create a copy of CommitState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitStateCopyWith<CommitState> get copyWith => _$CommitStateCopyWithImpl<CommitState>(this as CommitState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitState&&(identical(other.message, message) || other.message == message)&&(identical(other.autoGenerate, autoGenerate) || other.autoGenerate == autoGenerate)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error)&&(identical(other.commitHash, commitHash) || other.commitHash == commitHash)&&(identical(other.stagedFileCount, stagedFileCount) || other.stagedFileCount == stagedFileCount)&&(identical(other.insertions, insertions) || other.insertions == insertions)&&(identical(other.deletions, deletions) || other.deletions == deletions));
}


@override
int get hashCode => Object.hash(runtimeType,message,autoGenerate,status,error,commitHash,stagedFileCount,insertions,deletions);

@override
String toString() {
  return 'CommitState(message: $message, autoGenerate: $autoGenerate, status: $status, error: $error, commitHash: $commitHash, stagedFileCount: $stagedFileCount, insertions: $insertions, deletions: $deletions)';
}


}

/// @nodoc
abstract mixin class $CommitStateCopyWith<$Res>  {
  factory $CommitStateCopyWith(CommitState value, $Res Function(CommitState) _then) = _$CommitStateCopyWithImpl;
@useResult
$Res call({
 String message, bool autoGenerate, CommitStatus status, String? error, String? commitHash, int stagedFileCount, int insertions, int deletions
});




}
/// @nodoc
class _$CommitStateCopyWithImpl<$Res>
    implements $CommitStateCopyWith<$Res> {
  _$CommitStateCopyWithImpl(this._self, this._then);

  final CommitState _self;
  final $Res Function(CommitState) _then;

/// Create a copy of CommitState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? autoGenerate = null,Object? status = null,Object? error = freezed,Object? commitHash = freezed,Object? stagedFileCount = null,Object? insertions = null,Object? deletions = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,autoGenerate: null == autoGenerate ? _self.autoGenerate : autoGenerate // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CommitStatus,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,commitHash: freezed == commitHash ? _self.commitHash : commitHash // ignore: cast_nullable_to_non_nullable
as String?,stagedFileCount: null == stagedFileCount ? _self.stagedFileCount : stagedFileCount // ignore: cast_nullable_to_non_nullable
as int,insertions: null == insertions ? _self.insertions : insertions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CommitState].
extension CommitStatePatterns on CommitState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitState value)  $default,){
final _that = this;
switch (_that) {
case _CommitState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitState value)?  $default,){
final _that = this;
switch (_that) {
case _CommitState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  bool autoGenerate,  CommitStatus status,  String? error,  String? commitHash,  int stagedFileCount,  int insertions,  int deletions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitState() when $default != null:
return $default(_that.message,_that.autoGenerate,_that.status,_that.error,_that.commitHash,_that.stagedFileCount,_that.insertions,_that.deletions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  bool autoGenerate,  CommitStatus status,  String? error,  String? commitHash,  int stagedFileCount,  int insertions,  int deletions)  $default,) {final _that = this;
switch (_that) {
case _CommitState():
return $default(_that.message,_that.autoGenerate,_that.status,_that.error,_that.commitHash,_that.stagedFileCount,_that.insertions,_that.deletions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  bool autoGenerate,  CommitStatus status,  String? error,  String? commitHash,  int stagedFileCount,  int insertions,  int deletions)?  $default,) {final _that = this;
switch (_that) {
case _CommitState() when $default != null:
return $default(_that.message,_that.autoGenerate,_that.status,_that.error,_that.commitHash,_that.stagedFileCount,_that.insertions,_that.deletions);case _:
  return null;

}
}

}

/// @nodoc


class _CommitState implements CommitState {
  const _CommitState({this.message = '', this.autoGenerate = true, this.status = CommitStatus.idle, this.error, this.commitHash, this.stagedFileCount = 0, this.insertions = 0, this.deletions = 0});
  

/// Commit message entered by the user.
@override@JsonKey() final  String message;
/// Whether to auto-generate the commit message.
@override@JsonKey() final  bool autoGenerate;
/// Current status of the multi-step commit flow.
@override@JsonKey() final  CommitStatus status;
/// Error message if any step fails.
@override final  String? error;
/// Commit hash after successful commit.
@override final  String? commitHash;
/// Number of staged files.
@override@JsonKey() final  int stagedFileCount;
/// Number of insertions across staged files.
@override@JsonKey() final  int insertions;
/// Number of deletions across staged files.
@override@JsonKey() final  int deletions;

/// Create a copy of CommitState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitStateCopyWith<_CommitState> get copyWith => __$CommitStateCopyWithImpl<_CommitState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitState&&(identical(other.message, message) || other.message == message)&&(identical(other.autoGenerate, autoGenerate) || other.autoGenerate == autoGenerate)&&(identical(other.status, status) || other.status == status)&&(identical(other.error, error) || other.error == error)&&(identical(other.commitHash, commitHash) || other.commitHash == commitHash)&&(identical(other.stagedFileCount, stagedFileCount) || other.stagedFileCount == stagedFileCount)&&(identical(other.insertions, insertions) || other.insertions == insertions)&&(identical(other.deletions, deletions) || other.deletions == deletions));
}


@override
int get hashCode => Object.hash(runtimeType,message,autoGenerate,status,error,commitHash,stagedFileCount,insertions,deletions);

@override
String toString() {
  return 'CommitState(message: $message, autoGenerate: $autoGenerate, status: $status, error: $error, commitHash: $commitHash, stagedFileCount: $stagedFileCount, insertions: $insertions, deletions: $deletions)';
}


}

/// @nodoc
abstract mixin class _$CommitStateCopyWith<$Res> implements $CommitStateCopyWith<$Res> {
  factory _$CommitStateCopyWith(_CommitState value, $Res Function(_CommitState) _then) = __$CommitStateCopyWithImpl;
@override @useResult
$Res call({
 String message, bool autoGenerate, CommitStatus status, String? error, String? commitHash, int stagedFileCount, int insertions, int deletions
});




}
/// @nodoc
class __$CommitStateCopyWithImpl<$Res>
    implements _$CommitStateCopyWith<$Res> {
  __$CommitStateCopyWithImpl(this._self, this._then);

  final _CommitState _self;
  final $Res Function(_CommitState) _then;

/// Create a copy of CommitState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? autoGenerate = null,Object? status = null,Object? error = freezed,Object? commitHash = freezed,Object? stagedFileCount = null,Object? insertions = null,Object? deletions = null,}) {
  return _then(_CommitState(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,autoGenerate: null == autoGenerate ? _self.autoGenerate : autoGenerate // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as CommitStatus,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,commitHash: freezed == commitHash ? _self.commitHash : commitHash // ignore: cast_nullable_to_non_nullable
as String?,stagedFileCount: null == stagedFileCount ? _self.stagedFileCount : stagedFileCount // ignore: cast_nullable_to_non_nullable
as int,insertions: null == insertions ? _self.insertions : insertions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
