// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github_list_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GitHubFailure {

 GitHubFailureKind get kind; String get message;
/// Create a copy of GitHubFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubFailureCopyWith<GitHubFailure> get copyWith => _$GitHubFailureCopyWithImpl<GitHubFailure>(this as GitHubFailure, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GitHubFailure;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubFailure&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.message, _this.message) || other.message == _this.message));
}


@override
int get hashCode {
  final _this = this as GitHubFailure;
  return Object.hash(runtimeType,_this.kind,_this.message);
}

@override
String toString() {
  final _this = this as GitHubFailure;
  return 'GitHubFailure(kind: ${_this.kind}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $GitHubFailureCopyWith<$Res>  {
  factory $GitHubFailureCopyWith(GitHubFailure value, $Res Function(GitHubFailure) _then) = _$GitHubFailureCopyWithImpl;
@useResult
$Res call({
 GitHubFailureKind kind, String message
});




}
/// @nodoc
class _$GitHubFailureCopyWithImpl<$Res>
    implements $GitHubFailureCopyWith<$Res> {
  _$GitHubFailureCopyWithImpl(this._self, this._then);

  final GitHubFailure _self;
  final $Res Function(GitHubFailure) _then;

/// Create a copy of GitHubFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? message = null,}) {
  return _then(GitHubFailure(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GitHubFailureKind,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GitHubFailure].
extension GitHubFailurePatterns on GitHubFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubFailure value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubFailure() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubFailure value)  $default,){
final _that = this;
switch (_that) {
case _GitHubFailure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubFailure value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubFailure() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GitHubFailureKind kind,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubFailure() when $default != null:
return $default(_that.kind,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GitHubFailureKind kind,  String message)  $default,) {final _that = this;
switch (_that) {
case _GitHubFailure():
return $default(_that.kind,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GitHubFailureKind kind,  String message)?  $default,) {final _that = this;
switch (_that) {
case _GitHubFailure() when $default != null:
return $default(_that.kind,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubFailure implements GitHubFailure {
  const _GitHubFailure({required this.kind, this.message = ''});
  

@override final  GitHubFailureKind kind;
@override@JsonKey() final  String message;

/// Create a copy of GitHubFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubFailureCopyWith<_GitHubFailure> get copyWith => __$GitHubFailureCopyWithImpl<_GitHubFailure>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubFailure&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,message);
}

@override
String toString() {
    return 'GitHubFailure(kind: $kind, message: $message)';
}


}

/// @nodoc
abstract mixin class _$GitHubFailureCopyWith<$Res> implements $GitHubFailureCopyWith<$Res> {
  factory _$GitHubFailureCopyWith(_GitHubFailure value, $Res Function(_GitHubFailure) _then) = __$GitHubFailureCopyWithImpl;
@override @useResult
$Res call({
 GitHubFailureKind kind, String message
});




}
/// @nodoc
class __$GitHubFailureCopyWithImpl<$Res>
    implements _$GitHubFailureCopyWith<$Res> {
  __$GitHubFailureCopyWithImpl(this._self, this._then);

  final _GitHubFailure _self;
  final $Res Function(_GitHubFailure) _then;

/// Create a copy of GitHubFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? message = null,}) {
  return _then(_GitHubFailure(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GitHubFailureKind,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$GitHubTabState {

 bool get loading;/// A successful result has been applied at least once.
 bool get loaded; List<GitHubItemSummary> get items; GitHubFailure? get failure;
/// Create a copy of GitHubTabState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubTabStateCopyWith<GitHubTabState> get copyWith => _$GitHubTabStateCopyWithImpl<GitHubTabState>(this as GitHubTabState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GitHubTabState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubTabState&&(identical(other.loading, _this.loading) || other.loading == _this.loading)&&(identical(other.loaded, _this.loaded) || other.loaded == _this.loaded)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as GitHubTabState;
  return Object.hash(runtimeType,_this.loading,_this.loaded,const DeepCollectionEquality().hash(_this.items),_this.failure);
}

@override
String toString() {
  final _this = this as GitHubTabState;
  return 'GitHubTabState(loading: ${_this.loading}, loaded: ${_this.loaded}, items: ${_this.items}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $GitHubTabStateCopyWith<$Res>  {
  factory $GitHubTabStateCopyWith(GitHubTabState value, $Res Function(GitHubTabState) _then) = _$GitHubTabStateCopyWithImpl;
@useResult
$Res call({
 bool loading, bool loaded, List<GitHubItemSummary> items, GitHubFailure? failure
});


$GitHubFailureCopyWith<$Res>? get failure;

}
/// @nodoc
class _$GitHubTabStateCopyWithImpl<$Res>
    implements $GitHubTabStateCopyWith<$Res> {
  _$GitHubTabStateCopyWithImpl(this._self, this._then);

  final GitHubTabState _self;
  final $Res Function(GitHubTabState) _then;

/// Create a copy of GitHubTabState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loading = null,Object? loaded = null,Object? items = null,Object? failure = freezed,}) {
  return _then(GitHubTabState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<GitHubItemSummary>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as GitHubFailure?,
  ));
}
/// Create a copy of GitHubTabState
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


/// Adds pattern-matching-related methods to [GitHubTabState].
extension GitHubTabStatePatterns on GitHubTabState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubTabState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubTabState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubTabState value)  $default,){
final _that = this;
switch (_that) {
case _GitHubTabState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubTabState value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubTabState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loading,  bool loaded,  List<GitHubItemSummary> items,  GitHubFailure? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubTabState() when $default != null:
return $default(_that.loading,_that.loaded,_that.items,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loading,  bool loaded,  List<GitHubItemSummary> items,  GitHubFailure? failure)  $default,) {final _that = this;
switch (_that) {
case _GitHubTabState():
return $default(_that.loading,_that.loaded,_that.items,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loading,  bool loaded,  List<GitHubItemSummary> items,  GitHubFailure? failure)?  $default,) {final _that = this;
switch (_that) {
case _GitHubTabState() when $default != null:
return $default(_that.loading,_that.loaded,_that.items,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubTabState implements GitHubTabState {
  const _GitHubTabState({this.loading = false, this.loaded = false,  List<GitHubItemSummary> items = const [], this.failure}): _items = items;
  

@override@JsonKey() final  bool loading;
/// A successful result has been applied at least once.
@override@JsonKey() final  bool loaded;
 final  List<GitHubItemSummary> _items;
@override@JsonKey() List<GitHubItemSummary> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  GitHubFailure? failure;

/// Create a copy of GitHubTabState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubTabStateCopyWith<_GitHubTabState> get copyWith => __$GitHubTabStateCopyWithImpl<_GitHubTabState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubTabState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.loaded, loaded) || other.loaded == loaded)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,loading,loaded,const DeepCollectionEquality().hash(_items),failure);
}

@override
String toString() {
    return 'GitHubTabState(loading: $loading, loaded: $loaded, items: $items, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$GitHubTabStateCopyWith<$Res> implements $GitHubTabStateCopyWith<$Res> {
  factory _$GitHubTabStateCopyWith(_GitHubTabState value, $Res Function(_GitHubTabState) _then) = __$GitHubTabStateCopyWithImpl;
@override @useResult
$Res call({
 bool loading, bool loaded, List<GitHubItemSummary> items, GitHubFailure? failure
});


@override $GitHubFailureCopyWith<$Res>? get failure;

}
/// @nodoc
class __$GitHubTabStateCopyWithImpl<$Res>
    implements _$GitHubTabStateCopyWith<$Res> {
  __$GitHubTabStateCopyWithImpl(this._self, this._then);

  final _GitHubTabState _self;
  final $Res Function(_GitHubTabState) _then;

/// Create a copy of GitHubTabState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loading = null,Object? loaded = null,Object? items = null,Object? failure = freezed,}) {
  return _then(_GitHubTabState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,loaded: null == loaded ? _self.loaded : loaded // ignore: cast_nullable_to_non_nullable
as bool,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<GitHubItemSummary>,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as GitHubFailure?,
  ));
}

/// Create a copy of GitHubTabState
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

/// @nodoc
mixin _$GitHubFilters {

/// Pull requests only.
 bool get hideDrafts;/// Pull requests only.
 bool get dependabotOnly; String? get label;
/// Create a copy of GitHubFilters
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubFiltersCopyWith<GitHubFilters> get copyWith => _$GitHubFiltersCopyWithImpl<GitHubFilters>(this as GitHubFilters, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GitHubFilters;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubFilters&&(identical(other.hideDrafts, _this.hideDrafts) || other.hideDrafts == _this.hideDrafts)&&(identical(other.dependabotOnly, _this.dependabotOnly) || other.dependabotOnly == _this.dependabotOnly)&&(identical(other.label, _this.label) || other.label == _this.label));
}


@override
int get hashCode {
  final _this = this as GitHubFilters;
  return Object.hash(runtimeType,_this.hideDrafts,_this.dependabotOnly,_this.label);
}

@override
String toString() {
  final _this = this as GitHubFilters;
  return 'GitHubFilters(hideDrafts: ${_this.hideDrafts}, dependabotOnly: ${_this.dependabotOnly}, label: ${_this.label})';
}


}

/// @nodoc
abstract mixin class $GitHubFiltersCopyWith<$Res>  {
  factory $GitHubFiltersCopyWith(GitHubFilters value, $Res Function(GitHubFilters) _then) = _$GitHubFiltersCopyWithImpl;
@useResult
$Res call({
 bool hideDrafts, bool dependabotOnly, String? label
});




}
/// @nodoc
class _$GitHubFiltersCopyWithImpl<$Res>
    implements $GitHubFiltersCopyWith<$Res> {
  _$GitHubFiltersCopyWithImpl(this._self, this._then);

  final GitHubFilters _self;
  final $Res Function(GitHubFilters) _then;

/// Create a copy of GitHubFilters
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hideDrafts = null,Object? dependabotOnly = null,Object? label = freezed,}) {
  return _then(GitHubFilters(
hideDrafts: null == hideDrafts ? _self.hideDrafts : hideDrafts // ignore: cast_nullable_to_non_nullable
as bool,dependabotOnly: null == dependabotOnly ? _self.dependabotOnly : dependabotOnly // ignore: cast_nullable_to_non_nullable
as bool,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GitHubFilters].
extension GitHubFiltersPatterns on GitHubFilters {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubFilters value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubFilters() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubFilters value)  $default,){
final _that = this;
switch (_that) {
case _GitHubFilters():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubFilters value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubFilters() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool hideDrafts,  bool dependabotOnly,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubFilters() when $default != null:
return $default(_that.hideDrafts,_that.dependabotOnly,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool hideDrafts,  bool dependabotOnly,  String? label)  $default,) {final _that = this;
switch (_that) {
case _GitHubFilters():
return $default(_that.hideDrafts,_that.dependabotOnly,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool hideDrafts,  bool dependabotOnly,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _GitHubFilters() when $default != null:
return $default(_that.hideDrafts,_that.dependabotOnly,_that.label);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubFilters implements GitHubFilters {
  const _GitHubFilters({this.hideDrafts = false, this.dependabotOnly = false, this.label});
  

/// Pull requests only.
@override@JsonKey() final  bool hideDrafts;
/// Pull requests only.
@override@JsonKey() final  bool dependabotOnly;
@override final  String? label;

/// Create a copy of GitHubFilters
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubFiltersCopyWith<_GitHubFilters> get copyWith => __$GitHubFiltersCopyWithImpl<_GitHubFilters>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubFilters&&(identical(other.hideDrafts, hideDrafts) || other.hideDrafts == hideDrafts)&&(identical(other.dependabotOnly, dependabotOnly) || other.dependabotOnly == dependabotOnly)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode {
    return Object.hash(runtimeType,hideDrafts,dependabotOnly,label);
}

@override
String toString() {
    return 'GitHubFilters(hideDrafts: $hideDrafts, dependabotOnly: $dependabotOnly, label: $label)';
}


}

/// @nodoc
abstract mixin class _$GitHubFiltersCopyWith<$Res> implements $GitHubFiltersCopyWith<$Res> {
  factory _$GitHubFiltersCopyWith(_GitHubFilters value, $Res Function(_GitHubFilters) _then) = __$GitHubFiltersCopyWithImpl;
@override @useResult
$Res call({
 bool hideDrafts, bool dependabotOnly, String? label
});




}
/// @nodoc
class __$GitHubFiltersCopyWithImpl<$Res>
    implements _$GitHubFiltersCopyWith<$Res> {
  __$GitHubFiltersCopyWithImpl(this._self, this._then);

  final _GitHubFilters _self;
  final $Res Function(_GitHubFilters) _then;

/// Create a copy of GitHubFilters
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hideDrafts = null,Object? dependabotOnly = null,Object? label = freezed,}) {
  return _then(_GitHubFilters(
hideDrafts: null == hideDrafts ? _self.hideDrafts : hideDrafts // ignore: cast_nullable_to_non_nullable
as bool,dependabotOnly: null == dependabotOnly ? _self.dependabotOnly : dependabotOnly // ignore: cast_nullable_to_non_nullable
as bool,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$GitHubListState {

 GitHubTabState get prs; GitHubTabState get issues;/// `owner/name`.
 String? get repository; GitHubFilters get filters;
/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubListStateCopyWith<GitHubListState> get copyWith => _$GitHubListStateCopyWithImpl<GitHubListState>(this as GitHubListState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GitHubListState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubListState&&(identical(other.prs, _this.prs) || other.prs == _this.prs)&&(identical(other.issues, _this.issues) || other.issues == _this.issues)&&(identical(other.repository, _this.repository) || other.repository == _this.repository)&&(identical(other.filters, _this.filters) || other.filters == _this.filters));
}


@override
int get hashCode {
  final _this = this as GitHubListState;
  return Object.hash(runtimeType,_this.prs,_this.issues,_this.repository,_this.filters);
}

@override
String toString() {
  final _this = this as GitHubListState;
  return 'GitHubListState(prs: ${_this.prs}, issues: ${_this.issues}, repository: ${_this.repository}, filters: ${_this.filters})';
}


}

/// @nodoc
abstract mixin class $GitHubListStateCopyWith<$Res>  {
  factory $GitHubListStateCopyWith(GitHubListState value, $Res Function(GitHubListState) _then) = _$GitHubListStateCopyWithImpl;
@useResult
$Res call({
 GitHubTabState prs, GitHubTabState issues, String? repository, GitHubFilters filters
});


$GitHubTabStateCopyWith<$Res> get prs;$GitHubTabStateCopyWith<$Res> get issues;$GitHubFiltersCopyWith<$Res> get filters;

}
/// @nodoc
class _$GitHubListStateCopyWithImpl<$Res>
    implements $GitHubListStateCopyWith<$Res> {
  _$GitHubListStateCopyWithImpl(this._self, this._then);

  final GitHubListState _self;
  final $Res Function(GitHubListState) _then;

/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prs = null,Object? issues = null,Object? repository = freezed,Object? filters = null,}) {
  return _then(GitHubListState(
prs: null == prs ? _self.prs : prs // ignore: cast_nullable_to_non_nullable
as GitHubTabState,issues: null == issues ? _self.issues : issues // ignore: cast_nullable_to_non_nullable
as GitHubTabState,repository: freezed == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String?,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as GitHubFilters,
  ));
}
/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubTabStateCopyWith<$Res> get prs {
  
  return $GitHubTabStateCopyWith<$Res>(_self.prs, (value) {
    return _then(_self.copyWith(prs: value));
  });
}/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubTabStateCopyWith<$Res> get issues {
  
  return $GitHubTabStateCopyWith<$Res>(_self.issues, (value) {
    return _then(_self.copyWith(issues: value));
  });
}/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubFiltersCopyWith<$Res> get filters {
  
  return $GitHubFiltersCopyWith<$Res>(_self.filters, (value) {
    return _then(_self.copyWith(filters: value));
  });
}
}


/// Adds pattern-matching-related methods to [GitHubListState].
extension GitHubListStatePatterns on GitHubListState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubListState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubListState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubListState value)  $default,){
final _that = this;
switch (_that) {
case _GitHubListState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubListState value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubListState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GitHubTabState prs,  GitHubTabState issues,  String? repository,  GitHubFilters filters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubListState() when $default != null:
return $default(_that.prs,_that.issues,_that.repository,_that.filters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GitHubTabState prs,  GitHubTabState issues,  String? repository,  GitHubFilters filters)  $default,) {final _that = this;
switch (_that) {
case _GitHubListState():
return $default(_that.prs,_that.issues,_that.repository,_that.filters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GitHubTabState prs,  GitHubTabState issues,  String? repository,  GitHubFilters filters)?  $default,) {final _that = this;
switch (_that) {
case _GitHubListState() when $default != null:
return $default(_that.prs,_that.issues,_that.repository,_that.filters);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubListState extends GitHubListState {
  const _GitHubListState({this.prs = const GitHubTabState(), this.issues = const GitHubTabState(), this.repository, this.filters = const GitHubFilters()}): super._();
  

@override@JsonKey() final  GitHubTabState prs;
@override@JsonKey() final  GitHubTabState issues;
/// `owner/name`.
@override final  String? repository;
@override@JsonKey() final  GitHubFilters filters;

/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubListStateCopyWith<_GitHubListState> get copyWith => __$GitHubListStateCopyWithImpl<_GitHubListState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubListState&&(identical(other.prs, prs) || other.prs == prs)&&(identical(other.issues, issues) || other.issues == issues)&&(identical(other.repository, repository) || other.repository == repository)&&(identical(other.filters, filters) || other.filters == filters));
}


@override
int get hashCode {
    return Object.hash(runtimeType,prs,issues,repository,filters);
}

@override
String toString() {
    return 'GitHubListState(prs: $prs, issues: $issues, repository: $repository, filters: $filters)';
}


}

/// @nodoc
abstract mixin class _$GitHubListStateCopyWith<$Res> implements $GitHubListStateCopyWith<$Res> {
  factory _$GitHubListStateCopyWith(_GitHubListState value, $Res Function(_GitHubListState) _then) = __$GitHubListStateCopyWithImpl;
@override @useResult
$Res call({
 GitHubTabState prs, GitHubTabState issues, String? repository, GitHubFilters filters
});


@override $GitHubTabStateCopyWith<$Res> get prs;@override $GitHubTabStateCopyWith<$Res> get issues;@override $GitHubFiltersCopyWith<$Res> get filters;

}
/// @nodoc
class __$GitHubListStateCopyWithImpl<$Res>
    implements _$GitHubListStateCopyWith<$Res> {
  __$GitHubListStateCopyWithImpl(this._self, this._then);

  final _GitHubListState _self;
  final $Res Function(_GitHubListState) _then;

/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prs = null,Object? issues = null,Object? repository = freezed,Object? filters = null,}) {
  return _then(_GitHubListState(
prs: null == prs ? _self.prs : prs // ignore: cast_nullable_to_non_nullable
as GitHubTabState,issues: null == issues ? _self.issues : issues // ignore: cast_nullable_to_non_nullable
as GitHubTabState,repository: freezed == repository ? _self.repository : repository // ignore: cast_nullable_to_non_nullable
as String?,filters: null == filters ? _self.filters : filters // ignore: cast_nullable_to_non_nullable
as GitHubFilters,
  ));
}

/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubTabStateCopyWith<$Res> get prs {
  
  return $GitHubTabStateCopyWith<$Res>(_self.prs, (value) {
    return _then(_self.copyWith(prs: value));
  });
}/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubTabStateCopyWith<$Res> get issues {
  
  return $GitHubTabStateCopyWith<$Res>(_self.issues, (value) {
    return _then(_self.copyWith(issues: value));
  });
}/// Create a copy of GitHubListState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GitHubFiltersCopyWith<$Res> get filters {
  
  return $GitHubFiltersCopyWith<$Res>(_self.filters, (value) {
    return _then(_self.copyWith(filters: value));
  });
}
}

// dart format on
