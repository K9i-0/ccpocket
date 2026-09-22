// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workspace_navigation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WorkspaceNavigationState {

 WorkspaceSessionSelection? get selection; String? get liveSessionId; int get sessionEntry; WorkspaceToolPaneData? get tool; int get toolEntry; WorkspaceCenterOverlay get overlay; int get overlayEntry; bool get settingsFocusSupport; bool get settingsFocusConnection; bool get settingsFocusUsage; bool get centerInFront;
/// Create a copy of WorkspaceNavigationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkspaceNavigationStateCopyWith<WorkspaceNavigationState> get copyWith => _$WorkspaceNavigationStateCopyWithImpl<WorkspaceNavigationState>(this as WorkspaceNavigationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkspaceNavigationState&&(identical(other.selection, selection) || other.selection == selection)&&(identical(other.liveSessionId, liveSessionId) || other.liveSessionId == liveSessionId)&&(identical(other.sessionEntry, sessionEntry) || other.sessionEntry == sessionEntry)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.toolEntry, toolEntry) || other.toolEntry == toolEntry)&&(identical(other.overlay, overlay) || other.overlay == overlay)&&(identical(other.overlayEntry, overlayEntry) || other.overlayEntry == overlayEntry)&&(identical(other.settingsFocusSupport, settingsFocusSupport) || other.settingsFocusSupport == settingsFocusSupport)&&(identical(other.settingsFocusConnection, settingsFocusConnection) || other.settingsFocusConnection == settingsFocusConnection)&&(identical(other.settingsFocusUsage, settingsFocusUsage) || other.settingsFocusUsage == settingsFocusUsage)&&(identical(other.centerInFront, centerInFront) || other.centerInFront == centerInFront));
}


@override
int get hashCode => Object.hash(runtimeType,selection,liveSessionId,sessionEntry,tool,toolEntry,overlay,overlayEntry,settingsFocusSupport,settingsFocusConnection,settingsFocusUsage,centerInFront);

@override
String toString() {
  return 'WorkspaceNavigationState(selection: $selection, liveSessionId: $liveSessionId, sessionEntry: $sessionEntry, tool: $tool, toolEntry: $toolEntry, overlay: $overlay, overlayEntry: $overlayEntry, settingsFocusSupport: $settingsFocusSupport, settingsFocusConnection: $settingsFocusConnection, settingsFocusUsage: $settingsFocusUsage, centerInFront: $centerInFront)';
}


}

/// @nodoc
abstract mixin class $WorkspaceNavigationStateCopyWith<$Res>  {
  factory $WorkspaceNavigationStateCopyWith(WorkspaceNavigationState value, $Res Function(WorkspaceNavigationState) _then) = _$WorkspaceNavigationStateCopyWithImpl;
@useResult
$Res call({
 WorkspaceSessionSelection? selection, String? liveSessionId, int sessionEntry, WorkspaceToolPaneData? tool, int toolEntry, WorkspaceCenterOverlay overlay, int overlayEntry, bool settingsFocusSupport, bool settingsFocusConnection, bool settingsFocusUsage, bool centerInFront
});




}
/// @nodoc
class _$WorkspaceNavigationStateCopyWithImpl<$Res>
    implements $WorkspaceNavigationStateCopyWith<$Res> {
  _$WorkspaceNavigationStateCopyWithImpl(this._self, this._then);

  final WorkspaceNavigationState _self;
  final $Res Function(WorkspaceNavigationState) _then;

/// Create a copy of WorkspaceNavigationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selection = freezed,Object? liveSessionId = freezed,Object? sessionEntry = null,Object? tool = freezed,Object? toolEntry = null,Object? overlay = null,Object? overlayEntry = null,Object? settingsFocusSupport = null,Object? settingsFocusConnection = null,Object? settingsFocusUsage = null,Object? centerInFront = null,}) {
  return _then(WorkspaceNavigationState(
selection: freezed == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as WorkspaceSessionSelection?,liveSessionId: freezed == liveSessionId ? _self.liveSessionId : liveSessionId // ignore: cast_nullable_to_non_nullable
as String?,sessionEntry: null == sessionEntry ? _self.sessionEntry : sessionEntry // ignore: cast_nullable_to_non_nullable
as int,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as WorkspaceToolPaneData?,toolEntry: null == toolEntry ? _self.toolEntry : toolEntry // ignore: cast_nullable_to_non_nullable
as int,overlay: null == overlay ? _self.overlay : overlay // ignore: cast_nullable_to_non_nullable
as WorkspaceCenterOverlay,overlayEntry: null == overlayEntry ? _self.overlayEntry : overlayEntry // ignore: cast_nullable_to_non_nullable
as int,settingsFocusSupport: null == settingsFocusSupport ? _self.settingsFocusSupport : settingsFocusSupport // ignore: cast_nullable_to_non_nullable
as bool,settingsFocusConnection: null == settingsFocusConnection ? _self.settingsFocusConnection : settingsFocusConnection // ignore: cast_nullable_to_non_nullable
as bool,settingsFocusUsage: null == settingsFocusUsage ? _self.settingsFocusUsage : settingsFocusUsage // ignore: cast_nullable_to_non_nullable
as bool,centerInFront: null == centerInFront ? _self.centerInFront : centerInFront // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkspaceNavigationState].
extension WorkspaceNavigationStatePatterns on WorkspaceNavigationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkspaceNavigationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkspaceNavigationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkspaceNavigationState value)  $default,){
final _that = this;
switch (_that) {
case _WorkspaceNavigationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkspaceNavigationState value)?  $default,){
final _that = this;
switch (_that) {
case _WorkspaceNavigationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WorkspaceSessionSelection? selection,  String? liveSessionId,  int sessionEntry,  WorkspaceToolPaneData? tool,  int toolEntry,  WorkspaceCenterOverlay overlay,  int overlayEntry,  bool settingsFocusSupport,  bool settingsFocusConnection,  bool settingsFocusUsage,  bool centerInFront)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkspaceNavigationState() when $default != null:
return $default(_that.selection,_that.liveSessionId,_that.sessionEntry,_that.tool,_that.toolEntry,_that.overlay,_that.overlayEntry,_that.settingsFocusSupport,_that.settingsFocusConnection,_that.settingsFocusUsage,_that.centerInFront);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WorkspaceSessionSelection? selection,  String? liveSessionId,  int sessionEntry,  WorkspaceToolPaneData? tool,  int toolEntry,  WorkspaceCenterOverlay overlay,  int overlayEntry,  bool settingsFocusSupport,  bool settingsFocusConnection,  bool settingsFocusUsage,  bool centerInFront)  $default,) {final _that = this;
switch (_that) {
case _WorkspaceNavigationState():
return $default(_that.selection,_that.liveSessionId,_that.sessionEntry,_that.tool,_that.toolEntry,_that.overlay,_that.overlayEntry,_that.settingsFocusSupport,_that.settingsFocusConnection,_that.settingsFocusUsage,_that.centerInFront);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WorkspaceSessionSelection? selection,  String? liveSessionId,  int sessionEntry,  WorkspaceToolPaneData? tool,  int toolEntry,  WorkspaceCenterOverlay overlay,  int overlayEntry,  bool settingsFocusSupport,  bool settingsFocusConnection,  bool settingsFocusUsage,  bool centerInFront)?  $default,) {final _that = this;
switch (_that) {
case _WorkspaceNavigationState() when $default != null:
return $default(_that.selection,_that.liveSessionId,_that.sessionEntry,_that.tool,_that.toolEntry,_that.overlay,_that.overlayEntry,_that.settingsFocusSupport,_that.settingsFocusConnection,_that.settingsFocusUsage,_that.centerInFront);case _:
  return null;

}
}

}

/// @nodoc


class _WorkspaceNavigationState implements WorkspaceNavigationState {
  const _WorkspaceNavigationState({this.selection, this.liveSessionId, this.sessionEntry = 0, this.tool, this.toolEntry = 0, this.overlay = WorkspaceCenterOverlay.none, this.overlayEntry = 0, this.settingsFocusSupport = false, this.settingsFocusConnection = false, this.settingsFocusUsage = false, this.centerInFront = false});
  

@override final  WorkspaceSessionSelection? selection;
@override final  String? liveSessionId;
@override@JsonKey() final  int sessionEntry;
@override final  WorkspaceToolPaneData? tool;
@override@JsonKey() final  int toolEntry;
@override@JsonKey() final  WorkspaceCenterOverlay overlay;
@override@JsonKey() final  int overlayEntry;
@override@JsonKey() final  bool settingsFocusSupport;
@override@JsonKey() final  bool settingsFocusConnection;
@override@JsonKey() final  bool settingsFocusUsage;
@override@JsonKey() final  bool centerInFront;

/// Create a copy of WorkspaceNavigationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkspaceNavigationStateCopyWith<_WorkspaceNavigationState> get copyWith => __$WorkspaceNavigationStateCopyWithImpl<_WorkspaceNavigationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkspaceNavigationState&&(identical(other.selection, selection) || other.selection == selection)&&(identical(other.liveSessionId, liveSessionId) || other.liveSessionId == liveSessionId)&&(identical(other.sessionEntry, sessionEntry) || other.sessionEntry == sessionEntry)&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.toolEntry, toolEntry) || other.toolEntry == toolEntry)&&(identical(other.overlay, overlay) || other.overlay == overlay)&&(identical(other.overlayEntry, overlayEntry) || other.overlayEntry == overlayEntry)&&(identical(other.settingsFocusSupport, settingsFocusSupport) || other.settingsFocusSupport == settingsFocusSupport)&&(identical(other.settingsFocusConnection, settingsFocusConnection) || other.settingsFocusConnection == settingsFocusConnection)&&(identical(other.settingsFocusUsage, settingsFocusUsage) || other.settingsFocusUsage == settingsFocusUsage)&&(identical(other.centerInFront, centerInFront) || other.centerInFront == centerInFront));
}


@override
int get hashCode => Object.hash(runtimeType,selection,liveSessionId,sessionEntry,tool,toolEntry,overlay,overlayEntry,settingsFocusSupport,settingsFocusConnection,settingsFocusUsage,centerInFront);

@override
String toString() {
  return 'WorkspaceNavigationState(selection: $selection, liveSessionId: $liveSessionId, sessionEntry: $sessionEntry, tool: $tool, toolEntry: $toolEntry, overlay: $overlay, overlayEntry: $overlayEntry, settingsFocusSupport: $settingsFocusSupport, settingsFocusConnection: $settingsFocusConnection, settingsFocusUsage: $settingsFocusUsage, centerInFront: $centerInFront)';
}


}

/// @nodoc
abstract mixin class _$WorkspaceNavigationStateCopyWith<$Res> implements $WorkspaceNavigationStateCopyWith<$Res> {
  factory _$WorkspaceNavigationStateCopyWith(_WorkspaceNavigationState value, $Res Function(_WorkspaceNavigationState) _then) = __$WorkspaceNavigationStateCopyWithImpl;
@override @useResult
$Res call({
 WorkspaceSessionSelection? selection, String? liveSessionId, int sessionEntry, WorkspaceToolPaneData? tool, int toolEntry, WorkspaceCenterOverlay overlay, int overlayEntry, bool settingsFocusSupport, bool settingsFocusConnection, bool settingsFocusUsage, bool centerInFront
});




}
/// @nodoc
class __$WorkspaceNavigationStateCopyWithImpl<$Res>
    implements _$WorkspaceNavigationStateCopyWith<$Res> {
  __$WorkspaceNavigationStateCopyWithImpl(this._self, this._then);

  final _WorkspaceNavigationState _self;
  final $Res Function(_WorkspaceNavigationState) _then;

/// Create a copy of WorkspaceNavigationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selection = freezed,Object? liveSessionId = freezed,Object? sessionEntry = null,Object? tool = freezed,Object? toolEntry = null,Object? overlay = null,Object? overlayEntry = null,Object? settingsFocusSupport = null,Object? settingsFocusConnection = null,Object? settingsFocusUsage = null,Object? centerInFront = null,}) {
  return _then(_WorkspaceNavigationState(
selection: freezed == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as WorkspaceSessionSelection?,liveSessionId: freezed == liveSessionId ? _self.liveSessionId : liveSessionId // ignore: cast_nullable_to_non_nullable
as String?,sessionEntry: null == sessionEntry ? _self.sessionEntry : sessionEntry // ignore: cast_nullable_to_non_nullable
as int,tool: freezed == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as WorkspaceToolPaneData?,toolEntry: null == toolEntry ? _self.toolEntry : toolEntry // ignore: cast_nullable_to_non_nullable
as int,overlay: null == overlay ? _self.overlay : overlay // ignore: cast_nullable_to_non_nullable
as WorkspaceCenterOverlay,overlayEntry: null == overlayEntry ? _self.overlayEntry : overlayEntry // ignore: cast_nullable_to_non_nullable
as int,settingsFocusSupport: null == settingsFocusSupport ? _self.settingsFocusSupport : settingsFocusSupport // ignore: cast_nullable_to_non_nullable
as bool,settingsFocusConnection: null == settingsFocusConnection ? _self.settingsFocusConnection : settingsFocusConnection // ignore: cast_nullable_to_non_nullable
as bool,settingsFocusUsage: null == settingsFocusUsage ? _self.settingsFocusUsage : settingsFocusUsage // ignore: cast_nullable_to_non_nullable
as bool,centerInFront: null == centerInFront ? _self.centerInFront : centerInFront // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
