// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'branch_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BranchState {

/// Current branch name.
 String? get current;/// All branches (unfiltered).
 List<String> get branches;/// Search query for filtering.
 String get query;/// Whether a branch list request is in progress.
 bool get loading;/// Error message.
 String? get error;/// Whether a branch creation is in progress.
 bool get creating;
/// Create a copy of BranchState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchStateCopyWith<BranchState> get copyWith => _$BranchStateCopyWithImpl<BranchState>(this as BranchState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchState&&(identical(other.current, current) || other.current == current)&&const DeepCollectionEquality().equals(other.branches, branches)&&(identical(other.query, query) || other.query == query)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error)&&(identical(other.creating, creating) || other.creating == creating));
}


@override
int get hashCode => Object.hash(runtimeType,current,const DeepCollectionEquality().hash(branches),query,loading,error,creating);

@override
String toString() {
  return 'BranchState(current: $current, branches: $branches, query: $query, loading: $loading, error: $error, creating: $creating)';
}


}

/// @nodoc
abstract mixin class $BranchStateCopyWith<$Res>  {
  factory $BranchStateCopyWith(BranchState value, $Res Function(BranchState) _then) = _$BranchStateCopyWithImpl;
@useResult
$Res call({
 String? current, List<String> branches, String query, bool loading, String? error, bool creating
});




}
/// @nodoc
class _$BranchStateCopyWithImpl<$Res>
    implements $BranchStateCopyWith<$Res> {
  _$BranchStateCopyWithImpl(this._self, this._then);

  final BranchState _self;
  final $Res Function(BranchState) _then;

/// Create a copy of BranchState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? current = freezed,Object? branches = null,Object? query = null,Object? loading = null,Object? error = freezed,Object? creating = null,}) {
  return _then(_self.copyWith(
current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String?,branches: null == branches ? _self.branches : branches // ignore: cast_nullable_to_non_nullable
as List<String>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,creating: null == creating ? _self.creating : creating // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BranchState].
extension BranchStatePatterns on BranchState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BranchState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BranchState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BranchState value)  $default,){
final _that = this;
switch (_that) {
case _BranchState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BranchState value)?  $default,){
final _that = this;
switch (_that) {
case _BranchState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? current,  List<String> branches,  String query,  bool loading,  String? error,  bool creating)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BranchState() when $default != null:
return $default(_that.current,_that.branches,_that.query,_that.loading,_that.error,_that.creating);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? current,  List<String> branches,  String query,  bool loading,  String? error,  bool creating)  $default,) {final _that = this;
switch (_that) {
case _BranchState():
return $default(_that.current,_that.branches,_that.query,_that.loading,_that.error,_that.creating);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? current,  List<String> branches,  String query,  bool loading,  String? error,  bool creating)?  $default,) {final _that = this;
switch (_that) {
case _BranchState() when $default != null:
return $default(_that.current,_that.branches,_that.query,_that.loading,_that.error,_that.creating);case _:
  return null;

}
}

}

/// @nodoc


class _BranchState implements BranchState {
  const _BranchState({this.current, final  List<String> branches = const [], this.query = '', this.loading = false, this.error, this.creating = false}): _branches = branches;
  

/// Current branch name.
@override final  String? current;
/// All branches (unfiltered).
 final  List<String> _branches;
/// All branches (unfiltered).
@override@JsonKey() List<String> get branches {
  if (_branches is EqualUnmodifiableListView) return _branches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_branches);
}

/// Search query for filtering.
@override@JsonKey() final  String query;
/// Whether a branch list request is in progress.
@override@JsonKey() final  bool loading;
/// Error message.
@override final  String? error;
/// Whether a branch creation is in progress.
@override@JsonKey() final  bool creating;

/// Create a copy of BranchState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BranchStateCopyWith<_BranchState> get copyWith => __$BranchStateCopyWithImpl<_BranchState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BranchState&&(identical(other.current, current) || other.current == current)&&const DeepCollectionEquality().equals(other._branches, _branches)&&(identical(other.query, query) || other.query == query)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.error, error) || other.error == error)&&(identical(other.creating, creating) || other.creating == creating));
}


@override
int get hashCode => Object.hash(runtimeType,current,const DeepCollectionEquality().hash(_branches),query,loading,error,creating);

@override
String toString() {
  return 'BranchState(current: $current, branches: $branches, query: $query, loading: $loading, error: $error, creating: $creating)';
}


}

/// @nodoc
abstract mixin class _$BranchStateCopyWith<$Res> implements $BranchStateCopyWith<$Res> {
  factory _$BranchStateCopyWith(_BranchState value, $Res Function(_BranchState) _then) = __$BranchStateCopyWithImpl;
@override @useResult
$Res call({
 String? current, List<String> branches, String query, bool loading, String? error, bool creating
});




}
/// @nodoc
class __$BranchStateCopyWithImpl<$Res>
    implements _$BranchStateCopyWith<$Res> {
  __$BranchStateCopyWithImpl(this._self, this._then);

  final _BranchState _self;
  final $Res Function(_BranchState) _then;

/// Create a copy of BranchState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? current = freezed,Object? branches = null,Object? query = null,Object? loading = null,Object? error = freezed,Object? creating = null,}) {
  return _then(_BranchState(
current: freezed == current ? _self.current : current // ignore: cast_nullable_to_non_nullable
as String?,branches: null == branches ? _self._branches : branches // ignore: cast_nullable_to_non_nullable
as List<String>,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,creating: null == creating ? _self.creating : creating // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
