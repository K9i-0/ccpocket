// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prompt_history_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PromptHistoryState {

 List<PromptHistoryEntry> get prompts; PromptSortOrder get sortOrder; String? get projectFilter; String get searchQuery; bool get isLoading; List<String> get availableProjects;
/// Create a copy of PromptHistoryState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromptHistoryStateCopyWith<PromptHistoryState> get copyWith => _$PromptHistoryStateCopyWithImpl<PromptHistoryState>(this as PromptHistoryState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromptHistoryState&&const DeepCollectionEquality().equals(other.prompts, prompts)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.projectFilter, projectFilter) || other.projectFilter == projectFilter)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other.availableProjects, availableProjects));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(prompts),sortOrder,projectFilter,searchQuery,isLoading,const DeepCollectionEquality().hash(availableProjects));

@override
String toString() {
  return 'PromptHistoryState(prompts: $prompts, sortOrder: $sortOrder, projectFilter: $projectFilter, searchQuery: $searchQuery, isLoading: $isLoading, availableProjects: $availableProjects)';
}


}

/// @nodoc
abstract mixin class $PromptHistoryStateCopyWith<$Res>  {
  factory $PromptHistoryStateCopyWith(PromptHistoryState value, $Res Function(PromptHistoryState) _then) = _$PromptHistoryStateCopyWithImpl;
@useResult
$Res call({
 List<PromptHistoryEntry> prompts, PromptSortOrder sortOrder, String? projectFilter, String searchQuery, bool isLoading, List<String> availableProjects
});




}
/// @nodoc
class _$PromptHistoryStateCopyWithImpl<$Res>
    implements $PromptHistoryStateCopyWith<$Res> {
  _$PromptHistoryStateCopyWithImpl(this._self, this._then);

  final PromptHistoryState _self;
  final $Res Function(PromptHistoryState) _then;

/// Create a copy of PromptHistoryState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prompts = null,Object? sortOrder = null,Object? projectFilter = freezed,Object? searchQuery = null,Object? isLoading = null,Object? availableProjects = null,}) {
  return _then(_self.copyWith(
prompts: null == prompts ? _self.prompts : prompts // ignore: cast_nullable_to_non_nullable
as List<PromptHistoryEntry>,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as PromptSortOrder,projectFilter: freezed == projectFilter ? _self.projectFilter : projectFilter // ignore: cast_nullable_to_non_nullable
as String?,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,availableProjects: null == availableProjects ? _self.availableProjects : availableProjects // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [PromptHistoryState].
extension PromptHistoryStatePatterns on PromptHistoryState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PromptHistoryState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PromptHistoryState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PromptHistoryState value)  $default,){
final _that = this;
switch (_that) {
case _PromptHistoryState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PromptHistoryState value)?  $default,){
final _that = this;
switch (_that) {
case _PromptHistoryState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<PromptHistoryEntry> prompts,  PromptSortOrder sortOrder,  String? projectFilter,  String searchQuery,  bool isLoading,  List<String> availableProjects)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PromptHistoryState() when $default != null:
return $default(_that.prompts,_that.sortOrder,_that.projectFilter,_that.searchQuery,_that.isLoading,_that.availableProjects);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<PromptHistoryEntry> prompts,  PromptSortOrder sortOrder,  String? projectFilter,  String searchQuery,  bool isLoading,  List<String> availableProjects)  $default,) {final _that = this;
switch (_that) {
case _PromptHistoryState():
return $default(_that.prompts,_that.sortOrder,_that.projectFilter,_that.searchQuery,_that.isLoading,_that.availableProjects);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<PromptHistoryEntry> prompts,  PromptSortOrder sortOrder,  String? projectFilter,  String searchQuery,  bool isLoading,  List<String> availableProjects)?  $default,) {final _that = this;
switch (_that) {
case _PromptHistoryState() when $default != null:
return $default(_that.prompts,_that.sortOrder,_that.projectFilter,_that.searchQuery,_that.isLoading,_that.availableProjects);case _:
  return null;

}
}

}

/// @nodoc


class _PromptHistoryState implements PromptHistoryState {
  const _PromptHistoryState({final  List<PromptHistoryEntry> prompts = const [], this.sortOrder = PromptSortOrder.frequency, this.projectFilter, this.searchQuery = '', this.isLoading = false, final  List<String> availableProjects = const []}): _prompts = prompts,_availableProjects = availableProjects;
  

 final  List<PromptHistoryEntry> _prompts;
@override@JsonKey() List<PromptHistoryEntry> get prompts {
  if (_prompts is EqualUnmodifiableListView) return _prompts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_prompts);
}

@override@JsonKey() final  PromptSortOrder sortOrder;
@override final  String? projectFilter;
@override@JsonKey() final  String searchQuery;
@override@JsonKey() final  bool isLoading;
 final  List<String> _availableProjects;
@override@JsonKey() List<String> get availableProjects {
  if (_availableProjects is EqualUnmodifiableListView) return _availableProjects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_availableProjects);
}


/// Create a copy of PromptHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromptHistoryStateCopyWith<_PromptHistoryState> get copyWith => __$PromptHistoryStateCopyWithImpl<_PromptHistoryState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromptHistoryState&&const DeepCollectionEquality().equals(other._prompts, _prompts)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.projectFilter, projectFilter) || other.projectFilter == projectFilter)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other._availableProjects, _availableProjects));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_prompts),sortOrder,projectFilter,searchQuery,isLoading,const DeepCollectionEquality().hash(_availableProjects));

@override
String toString() {
  return 'PromptHistoryState(prompts: $prompts, sortOrder: $sortOrder, projectFilter: $projectFilter, searchQuery: $searchQuery, isLoading: $isLoading, availableProjects: $availableProjects)';
}


}

/// @nodoc
abstract mixin class _$PromptHistoryStateCopyWith<$Res> implements $PromptHistoryStateCopyWith<$Res> {
  factory _$PromptHistoryStateCopyWith(_PromptHistoryState value, $Res Function(_PromptHistoryState) _then) = __$PromptHistoryStateCopyWithImpl;
@override @useResult
$Res call({
 List<PromptHistoryEntry> prompts, PromptSortOrder sortOrder, String? projectFilter, String searchQuery, bool isLoading, List<String> availableProjects
});




}
/// @nodoc
class __$PromptHistoryStateCopyWithImpl<$Res>
    implements _$PromptHistoryStateCopyWith<$Res> {
  __$PromptHistoryStateCopyWithImpl(this._self, this._then);

  final _PromptHistoryState _self;
  final $Res Function(_PromptHistoryState) _then;

/// Create a copy of PromptHistoryState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prompts = null,Object? sortOrder = null,Object? projectFilter = freezed,Object? searchQuery = null,Object? isLoading = null,Object? availableProjects = null,}) {
  return _then(_PromptHistoryState(
prompts: null == prompts ? _self._prompts : prompts // ignore: cast_nullable_to_non_nullable
as List<PromptHistoryEntry>,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as PromptSortOrder,projectFilter: freezed == projectFilter ? _self.projectFilter : projectFilter // ignore: cast_nullable_to_non_nullable
as String?,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,availableProjects: null == availableProjects ? _self._availableProjects : availableProjects // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
