// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github_item_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GitHubItemState {

/// The list row, shown while the detail loads.
 GitHubItemSummary get summary; bool get loading; GitHubItemDetail? get detail; GitHubFailure? get failure;
/// Create a copy of GitHubItemState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubItemStateCopyWith<GitHubItemState> get copyWith => _$GitHubItemStateCopyWithImpl<GitHubItemState>(this as GitHubItemState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GitHubItemState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubItemState&&(identical(other.summary, _this.summary) || other.summary == _this.summary)&&(identical(other.loading, _this.loading) || other.loading == _this.loading)&&(identical(other.detail, _this.detail) || other.detail == _this.detail)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as GitHubItemState;
  return Object.hash(runtimeType,_this.summary,_this.loading,_this.detail,_this.failure);
}

@override
String toString() {
  final _this = this as GitHubItemState;
  return 'GitHubItemState(summary: ${_this.summary}, loading: ${_this.loading}, detail: ${_this.detail}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $GitHubItemStateCopyWith<$Res>  {
  factory $GitHubItemStateCopyWith(GitHubItemState value, $Res Function(GitHubItemState) _then) = _$GitHubItemStateCopyWithImpl;
@useResult
$Res call({
 GitHubItemSummary summary, bool loading, GitHubItemDetail? detail, GitHubFailure? failure
});


$GitHubFailureCopyWith<$Res>? get failure;

}
/// @nodoc
class _$GitHubItemStateCopyWithImpl<$Res>
    implements $GitHubItemStateCopyWith<$Res> {
  _$GitHubItemStateCopyWithImpl(this._self, this._then);

  final GitHubItemState _self;
  final $Res Function(GitHubItemState) _then;

/// Create a copy of GitHubItemState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? summary = null,Object? loading = null,Object? detail = freezed,Object? failure = freezed,}) {
  return _then(GitHubItemState(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as GitHubItemSummary,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as GitHubItemDetail?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as GitHubFailure?,
  ));
}
/// Create a copy of GitHubItemState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubFailureCopyWith<$Res>? get failure {
    if (_self.failure == null) {
    return null;
  }

  return $GitHubFailureCopyWith<$Res>(_self.failure!, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}


/// Adds pattern-matching-related methods to [GitHubItemState].
extension GitHubItemStatePatterns on GitHubItemState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubItemState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubItemState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubItemState value)  $default,){
final _that = this;
switch (_that) {
case _GitHubItemState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubItemState value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubItemState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GitHubItemSummary summary,  bool loading,  GitHubItemDetail? detail,  GitHubFailure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubItemState() when $default != null:
return $default(_that.summary,_that.loading,_that.detail,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GitHubItemSummary summary,  bool loading,  GitHubItemDetail? detail,  GitHubFailure? failure)  $default,) {final _that = this;
switch (_that) {
case _GitHubItemState():
return $default(_that.summary,_that.loading,_that.detail,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GitHubItemSummary summary,  bool loading,  GitHubItemDetail? detail,  GitHubFailure? failure)?  $default,) {final _that = this;
switch (_that) {
case _GitHubItemState() when $default != null:
return $default(_that.summary,_that.loading,_that.detail,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubItemState implements GitHubItemState {
  const _GitHubItemState({required this.summary, this.loading = true, this.detail, this.failure});
  

/// The list row, shown while the detail loads.
@override final  GitHubItemSummary summary;
@override@JsonKey() final  bool loading;
@override final  GitHubItemDetail? detail;
@override final  GitHubFailure? failure;

/// Create a copy of GitHubItemState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubItemStateCopyWith<_GitHubItemState> get copyWith => __$GitHubItemStateCopyWithImpl<_GitHubItemState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubItemState&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,summary,loading,detail,failure);
}

@override
String toString() {
    return 'GitHubItemState(summary: $summary, loading: $loading, detail: $detail, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$GitHubItemStateCopyWith<$Res> implements $GitHubItemStateCopyWith<$Res> {
  factory _$GitHubItemStateCopyWith(_GitHubItemState value, $Res Function(_GitHubItemState) _then) = __$GitHubItemStateCopyWithImpl;
@override @useResult
$Res call({
 GitHubItemSummary summary, bool loading, GitHubItemDetail? detail, GitHubFailure? failure
});


@override $GitHubFailureCopyWith<$Res>? get failure;

}
/// @nodoc
class __$GitHubItemStateCopyWithImpl<$Res>
    implements _$GitHubItemStateCopyWith<$Res> {
  __$GitHubItemStateCopyWithImpl(this._self, this._then);

  final _GitHubItemState _self;
  final $Res Function(_GitHubItemState) _then;

/// Create a copy of GitHubItemState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? summary = null,Object? loading = null,Object? detail = freezed,Object? failure = freezed,}) {
  return _then(_GitHubItemState(
summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as GitHubItemSummary,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,detail: freezed == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as GitHubItemDetail?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as GitHubFailure?,
  ));
}

/// Create a copy of GitHubItemState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubFailureCopyWith<$Res>? get failure {
    if (_self.failure == null) {
    return null;
  }

  return $GitHubFailureCopyWith<$Res>(_self.failure!, (value) {
    return _then(_self.copyWith(failure: value));
  });
}
}

// dart format on
