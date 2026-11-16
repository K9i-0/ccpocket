// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'github_selection_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GitHubSelectedItem {

 int get number; String get title;/// Identity of the item, and what the agent receives.
 String get url; bool get isPullRequest;
/// Create a copy of GitHubSelectedItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubSelectedItemCopyWith<GitHubSelectedItem> get copyWith => _$GitHubSelectedItemCopyWithImpl<GitHubSelectedItem>(this as GitHubSelectedItem, _$identity);

  /// Serializes this GitHubSelectedItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GitHubSelectedItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubSelectedItem&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.isPullRequest, _this.isPullRequest) || other.isPullRequest == _this.isPullRequest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GitHubSelectedItem;
  return Object.hash(runtimeType,_this.number,_this.title,_this.url,_this.isPullRequest);
}

@override
String toString() {
  final _this = this as GitHubSelectedItem;
  return 'GitHubSelectedItem(number: ${_this.number}, title: ${_this.title}, url: ${_this.url}, isPullRequest: ${_this.isPullRequest})';
}


}

/// @nodoc
abstract mixin class $GitHubSelectedItemCopyWith<$Res>  {
  factory $GitHubSelectedItemCopyWith(GitHubSelectedItem value, $Res Function(GitHubSelectedItem) _then) = _$GitHubSelectedItemCopyWithImpl;
@useResult
$Res call({
 int number, String title, String url, bool isPullRequest
});




}
/// @nodoc
class _$GitHubSelectedItemCopyWithImpl<$Res>
    implements $GitHubSelectedItemCopyWith<$Res> {
  _$GitHubSelectedItemCopyWithImpl(this._self, this._then);

  final GitHubSelectedItem _self;
  final $Res Function(GitHubSelectedItem) _then;

/// Create a copy of GitHubSelectedItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? title = null,Object? url = null,Object? isPullRequest = null,}) {
  return _then(GitHubSelectedItem(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isPullRequest: null == isPullRequest ? _self.isPullRequest : isPullRequest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GitHubSelectedItem].
extension GitHubSelectedItemPatterns on GitHubSelectedItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubSelectedItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubSelectedItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubSelectedItem value)  $default,){
final _that = this;
switch (_that) {
case _GitHubSelectedItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubSelectedItem value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubSelectedItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int number,  String title,  String url,  bool isPullRequest)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubSelectedItem() when $default != null:
return $default(_that.number,_that.title,_that.url,_that.isPullRequest);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int number,  String title,  String url,  bool isPullRequest)  $default,) {final _that = this;
switch (_that) {
case _GitHubSelectedItem():
return $default(_that.number,_that.title,_that.url,_that.isPullRequest);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int number,  String title,  String url,  bool isPullRequest)?  $default,) {final _that = this;
switch (_that) {
case _GitHubSelectedItem() when $default != null:
return $default(_that.number,_that.title,_that.url,_that.isPullRequest);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GitHubSelectedItem extends GitHubSelectedItem {
  const _GitHubSelectedItem({required this.number, required this.title, required this.url, this.isPullRequest = false}): super._();
  factory _GitHubSelectedItem.fromJson(Map<String, dynamic> json) => _$GitHubSelectedItemFromJson(json);

@override final  int number;
@override final  String title;
/// Identity of the item, and what the agent receives.
@override final  String url;
@override@JsonKey() final  bool isPullRequest;

/// Create a copy of GitHubSelectedItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubSelectedItemCopyWith<_GitHubSelectedItem> get copyWith => __$GitHubSelectedItemCopyWithImpl<_GitHubSelectedItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GitHubSelectedItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubSelectedItem&&(identical(other.number, number) || other.number == number)&&(identical(other.title, title) || other.title == title)&&(identical(other.url, url) || other.url == url)&&(identical(other.isPullRequest, isPullRequest) || other.isPullRequest == isPullRequest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,number,title,url,isPullRequest);
}

@override
String toString() {
    return 'GitHubSelectedItem(number: $number, title: $title, url: $url, isPullRequest: $isPullRequest)';
}


}

/// @nodoc
abstract mixin class _$GitHubSelectedItemCopyWith<$Res> implements $GitHubSelectedItemCopyWith<$Res> {
  factory _$GitHubSelectedItemCopyWith(_GitHubSelectedItem value, $Res Function(_GitHubSelectedItem) _then) = __$GitHubSelectedItemCopyWithImpl;
@override @useResult
$Res call({
 int number, String title, String url, bool isPullRequest
});




}
/// @nodoc
class __$GitHubSelectedItemCopyWithImpl<$Res>
    implements _$GitHubSelectedItemCopyWith<$Res> {
  __$GitHubSelectedItemCopyWithImpl(this._self, this._then);

  final _GitHubSelectedItem _self;
  final $Res Function(_GitHubSelectedItem) _then;

/// Create a copy of GitHubSelectedItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? title = null,Object? url = null,Object? isPullRequest = null,}) {
  return _then(_GitHubSelectedItem(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,isPullRequest: null == isPullRequest ? _self.isPullRequest : isPullRequest // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$GitHubSelectionState {

 Map<String, List<GitHubSelectedItem>> get sessions;
/// Create a copy of GitHubSelectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitHubSelectionStateCopyWith<GitHubSelectionState> get copyWith => _$GitHubSelectionStateCopyWithImpl<GitHubSelectionState>(this as GitHubSelectionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GitHubSelectionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitHubSelectionState&&const DeepCollectionEquality().equals(other.sessions, _this.sessions));
}


@override
int get hashCode {
  final _this = this as GitHubSelectionState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.sessions));
}

@override
String toString() {
  final _this = this as GitHubSelectionState;
  return 'GitHubSelectionState(sessions: ${_this.sessions})';
}


}

/// @nodoc
abstract mixin class $GitHubSelectionStateCopyWith<$Res>  {
  factory $GitHubSelectionStateCopyWith(GitHubSelectionState value, $Res Function(GitHubSelectionState) _then) = _$GitHubSelectionStateCopyWithImpl;
@useResult
$Res call({
 Map<String, List<GitHubSelectedItem>> sessions
});




}
/// @nodoc
class _$GitHubSelectionStateCopyWithImpl<$Res>
    implements $GitHubSelectionStateCopyWith<$Res> {
  _$GitHubSelectionStateCopyWithImpl(this._self, this._then);

  final GitHubSelectionState _self;
  final $Res Function(GitHubSelectionState) _then;

/// Create a copy of GitHubSelectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,}) {
  return _then(GitHubSelectionState(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as Map<String, List<GitHubSelectedItem>>,
  ));
}

}


/// Adds pattern-matching-related methods to [GitHubSelectionState].
extension GitHubSelectionStatePatterns on GitHubSelectionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitHubSelectionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitHubSelectionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitHubSelectionState value)  $default,){
final _that = this;
switch (_that) {
case _GitHubSelectionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitHubSelectionState value)?  $default,){
final _that = this;
switch (_that) {
case _GitHubSelectionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, List<GitHubSelectedItem>> sessions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitHubSelectionState() when $default != null:
return $default(_that.sessions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, List<GitHubSelectedItem>> sessions)  $default,) {final _that = this;
switch (_that) {
case _GitHubSelectionState():
return $default(_that.sessions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, List<GitHubSelectedItem>> sessions)?  $default,) {final _that = this;
switch (_that) {
case _GitHubSelectionState() when $default != null:
return $default(_that.sessions);case _:
  return null;

}
}

}

/// @nodoc


class _GitHubSelectionState implements GitHubSelectionState {
  const _GitHubSelectionState({ Map<String, List<GitHubSelectedItem>> sessions = const {}}): _sessions = sessions;
  

 final  Map<String, List<GitHubSelectedItem>> _sessions;
@override@JsonKey() Map<String, List<GitHubSelectedItem>> get sessions {
  if (_sessions is EqualUnmodifiableMapView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_sessions);
}


/// Create a copy of GitHubSelectionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitHubSelectionStateCopyWith<_GitHubSelectionState> get copyWith => __$GitHubSelectionStateCopyWithImpl<_GitHubSelectionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitHubSelectionState&&const DeepCollectionEquality().equals(other.sessions, _sessions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions));
}

@override
String toString() {
    return 'GitHubSelectionState(sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class _$GitHubSelectionStateCopyWith<$Res> implements $GitHubSelectionStateCopyWith<$Res> {
  factory _$GitHubSelectionStateCopyWith(_GitHubSelectionState value, $Res Function(_GitHubSelectionState) _then) = __$GitHubSelectionStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, List<GitHubSelectedItem>> sessions
});




}
/// @nodoc
class __$GitHubSelectionStateCopyWithImpl<$Res>
    implements _$GitHubSelectionStateCopyWith<$Res> {
  __$GitHubSelectionStateCopyWithImpl(this._self, this._then);

  final _GitHubSelectionState _self;
  final $Res Function(_GitHubSelectionState) _then;

/// Create a copy of GitHubSelectionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,}) {
  return _then(_GitHubSelectionState(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as Map<String, List<GitHubSelectedItem>>,
  ));
}


}

// dart format on
