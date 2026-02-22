// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatSessionState {

// Process status
 ProcessStatus get status;// Messages
 List<ChatEntry> get entries;// Approval / AskUserQuestion
 ApprovalState get approval;// Session metadata
 String? get claudeSessionId; String? get projectPath; String? get gitBranch;// Flags
 bool get pastHistoryLoaded; bool get bulkLoading; bool get inPlanMode; bool get collapseToolResults;// Permission mode selected by the user
 PermissionMode get permissionMode;// Sandbox mode for Codex sessions
 SandboxMode get sandboxMode;// Approval policy for Codex sessions
 ApprovalPolicy get approvalPolicy;// Tool use IDs hidden by tool_use_summary (subagent compression)
 Set<String> get hiddenToolUseIds;// Rewind preview (dry-run result)
 RewindPreviewMessage? get rewindPreview;// Cost tracking
 double get totalCost; Duration? get totalDuration;// Slash commands available in this session
 List<SlashCommand> get slashCommands;
/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSessionStateCopyWith<ChatSessionState> get copyWith => _$ChatSessionStateCopyWithImpl<ChatSessionState>(this as ChatSessionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSessionState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.entries, entries)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.claudeSessionId, claudeSessionId) || other.claudeSessionId == claudeSessionId)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.pastHistoryLoaded, pastHistoryLoaded) || other.pastHistoryLoaded == pastHistoryLoaded)&&(identical(other.bulkLoading, bulkLoading) || other.bulkLoading == bulkLoading)&&(identical(other.inPlanMode, inPlanMode) || other.inPlanMode == inPlanMode)&&(identical(other.collapseToolResults, collapseToolResults) || other.collapseToolResults == collapseToolResults)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.sandboxMode, sandboxMode) || other.sandboxMode == sandboxMode)&&(identical(other.approvalPolicy, approvalPolicy) || other.approvalPolicy == approvalPolicy)&&const DeepCollectionEquality().equals(other.hiddenToolUseIds, hiddenToolUseIds)&&(identical(other.rewindPreview, rewindPreview) || other.rewindPreview == rewindPreview)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost)&&(identical(other.totalDuration, totalDuration) || other.totalDuration == totalDuration)&&const DeepCollectionEquality().equals(other.slashCommands, slashCommands));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(entries),approval,claudeSessionId,projectPath,gitBranch,pastHistoryLoaded,bulkLoading,inPlanMode,collapseToolResults,permissionMode,sandboxMode,approvalPolicy,const DeepCollectionEquality().hash(hiddenToolUseIds),rewindPreview,totalCost,totalDuration,const DeepCollectionEquality().hash(slashCommands));

@override
String toString() {
  return 'ChatSessionState(status: $status, entries: $entries, approval: $approval, claudeSessionId: $claudeSessionId, projectPath: $projectPath, gitBranch: $gitBranch, pastHistoryLoaded: $pastHistoryLoaded, bulkLoading: $bulkLoading, inPlanMode: $inPlanMode, collapseToolResults: $collapseToolResults, permissionMode: $permissionMode, sandboxMode: $sandboxMode, approvalPolicy: $approvalPolicy, hiddenToolUseIds: $hiddenToolUseIds, rewindPreview: $rewindPreview, totalCost: $totalCost, totalDuration: $totalDuration, slashCommands: $slashCommands)';
}


}

/// @nodoc
abstract mixin class $ChatSessionStateCopyWith<$Res>  {
  factory $ChatSessionStateCopyWith(ChatSessionState value, $Res Function(ChatSessionState) _then) = _$ChatSessionStateCopyWithImpl;
@useResult
$Res call({
 ProcessStatus status, List<ChatEntry> entries, ApprovalState approval, String? claudeSessionId, String? projectPath, String? gitBranch, bool pastHistoryLoaded, bool bulkLoading, bool inPlanMode, bool collapseToolResults, PermissionMode permissionMode, SandboxMode sandboxMode, ApprovalPolicy approvalPolicy, Set<String> hiddenToolUseIds, RewindPreviewMessage? rewindPreview, double totalCost, Duration? totalDuration, List<SlashCommand> slashCommands
});


$ApprovalStateCopyWith<$Res> get approval;

}
/// @nodoc
class _$ChatSessionStateCopyWithImpl<$Res>
    implements $ChatSessionStateCopyWith<$Res> {
  _$ChatSessionStateCopyWithImpl(this._self, this._then);

  final ChatSessionState _self;
  final $Res Function(ChatSessionState) _then;

/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? entries = null,Object? approval = null,Object? claudeSessionId = freezed,Object? projectPath = freezed,Object? gitBranch = freezed,Object? pastHistoryLoaded = null,Object? bulkLoading = null,Object? inPlanMode = null,Object? collapseToolResults = null,Object? permissionMode = null,Object? sandboxMode = null,Object? approvalPolicy = null,Object? hiddenToolUseIds = null,Object? rewindPreview = freezed,Object? totalCost = null,Object? totalDuration = freezed,Object? slashCommands = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProcessStatus,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,approval: null == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalState,claudeSessionId: freezed == claudeSessionId ? _self.claudeSessionId : claudeSessionId // ignore: cast_nullable_to_non_nullable
as String?,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,pastHistoryLoaded: null == pastHistoryLoaded ? _self.pastHistoryLoaded : pastHistoryLoaded // ignore: cast_nullable_to_non_nullable
as bool,bulkLoading: null == bulkLoading ? _self.bulkLoading : bulkLoading // ignore: cast_nullable_to_non_nullable
as bool,inPlanMode: null == inPlanMode ? _self.inPlanMode : inPlanMode // ignore: cast_nullable_to_non_nullable
as bool,collapseToolResults: null == collapseToolResults ? _self.collapseToolResults : collapseToolResults // ignore: cast_nullable_to_non_nullable
as bool,permissionMode: null == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode,sandboxMode: null == sandboxMode ? _self.sandboxMode : sandboxMode // ignore: cast_nullable_to_non_nullable
as SandboxMode,approvalPolicy: null == approvalPolicy ? _self.approvalPolicy : approvalPolicy // ignore: cast_nullable_to_non_nullable
as ApprovalPolicy,hiddenToolUseIds: null == hiddenToolUseIds ? _self.hiddenToolUseIds : hiddenToolUseIds // ignore: cast_nullable_to_non_nullable
as Set<String>,rewindPreview: freezed == rewindPreview ? _self.rewindPreview : rewindPreview // ignore: cast_nullable_to_non_nullable
as RewindPreviewMessage?,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,totalDuration: freezed == totalDuration ? _self.totalDuration : totalDuration // ignore: cast_nullable_to_non_nullable
as Duration?,slashCommands: null == slashCommands ? _self.slashCommands : slashCommands // ignore: cast_nullable_to_non_nullable
as List<SlashCommand>,
  ));
}
/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalStateCopyWith<$Res> get approval {
  
  return $ApprovalStateCopyWith<$Res>(_self.approval, (value) {
    return _then(_self.copyWith(approval: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatSessionState].
extension ChatSessionStatePatterns on ChatSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatSessionState value)  $default,){
final _that = this;
switch (_that) {
case _ChatSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProcessStatus status,  List<ChatEntry> entries,  ApprovalState approval,  String? claudeSessionId,  String? projectPath,  String? gitBranch,  bool pastHistoryLoaded,  bool bulkLoading,  bool inPlanMode,  bool collapseToolResults,  PermissionMode permissionMode,  SandboxMode sandboxMode,  ApprovalPolicy approvalPolicy,  Set<String> hiddenToolUseIds,  RewindPreviewMessage? rewindPreview,  double totalCost,  Duration? totalDuration,  List<SlashCommand> slashCommands)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatSessionState() when $default != null:
return $default(_that.status,_that.entries,_that.approval,_that.claudeSessionId,_that.projectPath,_that.gitBranch,_that.pastHistoryLoaded,_that.bulkLoading,_that.inPlanMode,_that.collapseToolResults,_that.permissionMode,_that.sandboxMode,_that.approvalPolicy,_that.hiddenToolUseIds,_that.rewindPreview,_that.totalCost,_that.totalDuration,_that.slashCommands);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProcessStatus status,  List<ChatEntry> entries,  ApprovalState approval,  String? claudeSessionId,  String? projectPath,  String? gitBranch,  bool pastHistoryLoaded,  bool bulkLoading,  bool inPlanMode,  bool collapseToolResults,  PermissionMode permissionMode,  SandboxMode sandboxMode,  ApprovalPolicy approvalPolicy,  Set<String> hiddenToolUseIds,  RewindPreviewMessage? rewindPreview,  double totalCost,  Duration? totalDuration,  List<SlashCommand> slashCommands)  $default,) {final _that = this;
switch (_that) {
case _ChatSessionState():
return $default(_that.status,_that.entries,_that.approval,_that.claudeSessionId,_that.projectPath,_that.gitBranch,_that.pastHistoryLoaded,_that.bulkLoading,_that.inPlanMode,_that.collapseToolResults,_that.permissionMode,_that.sandboxMode,_that.approvalPolicy,_that.hiddenToolUseIds,_that.rewindPreview,_that.totalCost,_that.totalDuration,_that.slashCommands);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProcessStatus status,  List<ChatEntry> entries,  ApprovalState approval,  String? claudeSessionId,  String? projectPath,  String? gitBranch,  bool pastHistoryLoaded,  bool bulkLoading,  bool inPlanMode,  bool collapseToolResults,  PermissionMode permissionMode,  SandboxMode sandboxMode,  ApprovalPolicy approvalPolicy,  Set<String> hiddenToolUseIds,  RewindPreviewMessage? rewindPreview,  double totalCost,  Duration? totalDuration,  List<SlashCommand> slashCommands)?  $default,) {final _that = this;
switch (_that) {
case _ChatSessionState() when $default != null:
return $default(_that.status,_that.entries,_that.approval,_that.claudeSessionId,_that.projectPath,_that.gitBranch,_that.pastHistoryLoaded,_that.bulkLoading,_that.inPlanMode,_that.collapseToolResults,_that.permissionMode,_that.sandboxMode,_that.approvalPolicy,_that.hiddenToolUseIds,_that.rewindPreview,_that.totalCost,_that.totalDuration,_that.slashCommands);case _:
  return null;

}
}

}

/// @nodoc


class _ChatSessionState implements ChatSessionState {
  const _ChatSessionState({this.status = ProcessStatus.starting, final  List<ChatEntry> entries = const [], this.approval = const ApprovalState.none(), this.claudeSessionId, this.projectPath, this.gitBranch, this.pastHistoryLoaded = false, this.bulkLoading = false, this.inPlanMode = false, this.collapseToolResults = false, this.permissionMode = PermissionMode.defaultMode, this.sandboxMode = SandboxMode.workspaceWrite, this.approvalPolicy = ApprovalPolicy.onRequest, final  Set<String> hiddenToolUseIds = const {}, this.rewindPreview, this.totalCost = 0.0, this.totalDuration, final  List<SlashCommand> slashCommands = const []}): _entries = entries,_hiddenToolUseIds = hiddenToolUseIds,_slashCommands = slashCommands;
  

// Process status
@override@JsonKey() final  ProcessStatus status;
// Messages
 final  List<ChatEntry> _entries;
// Messages
@override@JsonKey() List<ChatEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

// Approval / AskUserQuestion
@override@JsonKey() final  ApprovalState approval;
// Session metadata
@override final  String? claudeSessionId;
@override final  String? projectPath;
@override final  String? gitBranch;
// Flags
@override@JsonKey() final  bool pastHistoryLoaded;
@override@JsonKey() final  bool bulkLoading;
@override@JsonKey() final  bool inPlanMode;
@override@JsonKey() final  bool collapseToolResults;
// Permission mode selected by the user
@override@JsonKey() final  PermissionMode permissionMode;
// Sandbox mode for Codex sessions
@override@JsonKey() final  SandboxMode sandboxMode;
// Approval policy for Codex sessions
@override@JsonKey() final  ApprovalPolicy approvalPolicy;
// Tool use IDs hidden by tool_use_summary (subagent compression)
 final  Set<String> _hiddenToolUseIds;
// Tool use IDs hidden by tool_use_summary (subagent compression)
@override@JsonKey() Set<String> get hiddenToolUseIds {
  if (_hiddenToolUseIds is EqualUnmodifiableSetView) return _hiddenToolUseIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_hiddenToolUseIds);
}

// Rewind preview (dry-run result)
@override final  RewindPreviewMessage? rewindPreview;
// Cost tracking
@override@JsonKey() final  double totalCost;
@override final  Duration? totalDuration;
// Slash commands available in this session
 final  List<SlashCommand> _slashCommands;
// Slash commands available in this session
@override@JsonKey() List<SlashCommand> get slashCommands {
  if (_slashCommands is EqualUnmodifiableListView) return _slashCommands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_slashCommands);
}


/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatSessionStateCopyWith<_ChatSessionState> get copyWith => __$ChatSessionStateCopyWithImpl<_ChatSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatSessionState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._entries, _entries)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.claudeSessionId, claudeSessionId) || other.claudeSessionId == claudeSessionId)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.pastHistoryLoaded, pastHistoryLoaded) || other.pastHistoryLoaded == pastHistoryLoaded)&&(identical(other.bulkLoading, bulkLoading) || other.bulkLoading == bulkLoading)&&(identical(other.inPlanMode, inPlanMode) || other.inPlanMode == inPlanMode)&&(identical(other.collapseToolResults, collapseToolResults) || other.collapseToolResults == collapseToolResults)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.sandboxMode, sandboxMode) || other.sandboxMode == sandboxMode)&&(identical(other.approvalPolicy, approvalPolicy) || other.approvalPolicy == approvalPolicy)&&const DeepCollectionEquality().equals(other._hiddenToolUseIds, _hiddenToolUseIds)&&(identical(other.rewindPreview, rewindPreview) || other.rewindPreview == rewindPreview)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost)&&(identical(other.totalDuration, totalDuration) || other.totalDuration == totalDuration)&&const DeepCollectionEquality().equals(other._slashCommands, _slashCommands));
}


@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_entries),approval,claudeSessionId,projectPath,gitBranch,pastHistoryLoaded,bulkLoading,inPlanMode,collapseToolResults,permissionMode,sandboxMode,approvalPolicy,const DeepCollectionEquality().hash(_hiddenToolUseIds),rewindPreview,totalCost,totalDuration,const DeepCollectionEquality().hash(_slashCommands));

@override
String toString() {
  return 'ChatSessionState(status: $status, entries: $entries, approval: $approval, claudeSessionId: $claudeSessionId, projectPath: $projectPath, gitBranch: $gitBranch, pastHistoryLoaded: $pastHistoryLoaded, bulkLoading: $bulkLoading, inPlanMode: $inPlanMode, collapseToolResults: $collapseToolResults, permissionMode: $permissionMode, sandboxMode: $sandboxMode, approvalPolicy: $approvalPolicy, hiddenToolUseIds: $hiddenToolUseIds, rewindPreview: $rewindPreview, totalCost: $totalCost, totalDuration: $totalDuration, slashCommands: $slashCommands)';
}


}

/// @nodoc
abstract mixin class _$ChatSessionStateCopyWith<$Res> implements $ChatSessionStateCopyWith<$Res> {
  factory _$ChatSessionStateCopyWith(_ChatSessionState value, $Res Function(_ChatSessionState) _then) = __$ChatSessionStateCopyWithImpl;
@override @useResult
$Res call({
 ProcessStatus status, List<ChatEntry> entries, ApprovalState approval, String? claudeSessionId, String? projectPath, String? gitBranch, bool pastHistoryLoaded, bool bulkLoading, bool inPlanMode, bool collapseToolResults, PermissionMode permissionMode, SandboxMode sandboxMode, ApprovalPolicy approvalPolicy, Set<String> hiddenToolUseIds, RewindPreviewMessage? rewindPreview, double totalCost, Duration? totalDuration, List<SlashCommand> slashCommands
});


@override $ApprovalStateCopyWith<$Res> get approval;

}
/// @nodoc
class __$ChatSessionStateCopyWithImpl<$Res>
    implements _$ChatSessionStateCopyWith<$Res> {
  __$ChatSessionStateCopyWithImpl(this._self, this._then);

  final _ChatSessionState _self;
  final $Res Function(_ChatSessionState) _then;

/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? entries = null,Object? approval = null,Object? claudeSessionId = freezed,Object? projectPath = freezed,Object? gitBranch = freezed,Object? pastHistoryLoaded = null,Object? bulkLoading = null,Object? inPlanMode = null,Object? collapseToolResults = null,Object? permissionMode = null,Object? sandboxMode = null,Object? approvalPolicy = null,Object? hiddenToolUseIds = null,Object? rewindPreview = freezed,Object? totalCost = null,Object? totalDuration = freezed,Object? slashCommands = null,}) {
  return _then(_ChatSessionState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProcessStatus,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,approval: null == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalState,claudeSessionId: freezed == claudeSessionId ? _self.claudeSessionId : claudeSessionId // ignore: cast_nullable_to_non_nullable
as String?,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,pastHistoryLoaded: null == pastHistoryLoaded ? _self.pastHistoryLoaded : pastHistoryLoaded // ignore: cast_nullable_to_non_nullable
as bool,bulkLoading: null == bulkLoading ? _self.bulkLoading : bulkLoading // ignore: cast_nullable_to_non_nullable
as bool,inPlanMode: null == inPlanMode ? _self.inPlanMode : inPlanMode // ignore: cast_nullable_to_non_nullable
as bool,collapseToolResults: null == collapseToolResults ? _self.collapseToolResults : collapseToolResults // ignore: cast_nullable_to_non_nullable
as bool,permissionMode: null == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode,sandboxMode: null == sandboxMode ? _self.sandboxMode : sandboxMode // ignore: cast_nullable_to_non_nullable
as SandboxMode,approvalPolicy: null == approvalPolicy ? _self.approvalPolicy : approvalPolicy // ignore: cast_nullable_to_non_nullable
as ApprovalPolicy,hiddenToolUseIds: null == hiddenToolUseIds ? _self._hiddenToolUseIds : hiddenToolUseIds // ignore: cast_nullable_to_non_nullable
as Set<String>,rewindPreview: freezed == rewindPreview ? _self.rewindPreview : rewindPreview // ignore: cast_nullable_to_non_nullable
as RewindPreviewMessage?,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,totalDuration: freezed == totalDuration ? _self.totalDuration : totalDuration // ignore: cast_nullable_to_non_nullable
as Duration?,slashCommands: null == slashCommands ? _self._slashCommands : slashCommands // ignore: cast_nullable_to_non_nullable
as List<SlashCommand>,
  ));
}

/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApprovalStateCopyWith<$Res> get approval {
  
  return $ApprovalStateCopyWith<$Res>(_self.approval, (value) {
    return _then(_self.copyWith(approval: value));
  });
}
}

/// @nodoc
mixin _$ApprovalState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApprovalState()';
}


}

/// @nodoc
class $ApprovalStateCopyWith<$Res>  {
$ApprovalStateCopyWith(ApprovalState _, $Res Function(ApprovalState) __);
}


/// Adds pattern-matching-related methods to [ApprovalState].
extension ApprovalStatePatterns on ApprovalState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ApprovalNone value)?  none,TResult Function( ApprovalPermission value)?  permission,TResult Function( ApprovalAskUser value)?  askUser,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ApprovalNone() when none != null:
return none(_that);case ApprovalPermission() when permission != null:
return permission(_that);case ApprovalAskUser() when askUser != null:
return askUser(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ApprovalNone value)  none,required TResult Function( ApprovalPermission value)  permission,required TResult Function( ApprovalAskUser value)  askUser,}){
final _that = this;
switch (_that) {
case ApprovalNone():
return none(_that);case ApprovalPermission():
return permission(_that);case ApprovalAskUser():
return askUser(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ApprovalNone value)?  none,TResult? Function( ApprovalPermission value)?  permission,TResult? Function( ApprovalAskUser value)?  askUser,}){
final _that = this;
switch (_that) {
case ApprovalNone() when none != null:
return none(_that);case ApprovalPermission() when permission != null:
return permission(_that);case ApprovalAskUser() when askUser != null:
return askUser(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  none,TResult Function( String toolUseId,  PermissionRequestMessage request)?  permission,TResult Function( String toolUseId,  Map<String, dynamic> input)?  askUser,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ApprovalNone() when none != null:
return none();case ApprovalPermission() when permission != null:
return permission(_that.toolUseId,_that.request);case ApprovalAskUser() when askUser != null:
return askUser(_that.toolUseId,_that.input);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  none,required TResult Function( String toolUseId,  PermissionRequestMessage request)  permission,required TResult Function( String toolUseId,  Map<String, dynamic> input)  askUser,}) {final _that = this;
switch (_that) {
case ApprovalNone():
return none();case ApprovalPermission():
return permission(_that.toolUseId,_that.request);case ApprovalAskUser():
return askUser(_that.toolUseId,_that.input);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  none,TResult? Function( String toolUseId,  PermissionRequestMessage request)?  permission,TResult? Function( String toolUseId,  Map<String, dynamic> input)?  askUser,}) {final _that = this;
switch (_that) {
case ApprovalNone() when none != null:
return none();case ApprovalPermission() when permission != null:
return permission(_that.toolUseId,_that.request);case ApprovalAskUser() when askUser != null:
return askUser(_that.toolUseId,_that.input);case _:
  return null;

}
}

}

/// @nodoc


class ApprovalNone implements ApprovalState {
  const ApprovalNone();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalNone);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ApprovalState.none()';
}


}




/// @nodoc


class ApprovalPermission implements ApprovalState {
  const ApprovalPermission({required this.toolUseId, required this.request});
  

 final  String toolUseId;
 final  PermissionRequestMessage request;

/// Create a copy of ApprovalState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalPermissionCopyWith<ApprovalPermission> get copyWith => _$ApprovalPermissionCopyWithImpl<ApprovalPermission>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalPermission&&(identical(other.toolUseId, toolUseId) || other.toolUseId == toolUseId)&&(identical(other.request, request) || other.request == request));
}


@override
int get hashCode => Object.hash(runtimeType,toolUseId,request);

@override
String toString() {
  return 'ApprovalState.permission(toolUseId: $toolUseId, request: $request)';
}


}

/// @nodoc
abstract mixin class $ApprovalPermissionCopyWith<$Res> implements $ApprovalStateCopyWith<$Res> {
  factory $ApprovalPermissionCopyWith(ApprovalPermission value, $Res Function(ApprovalPermission) _then) = _$ApprovalPermissionCopyWithImpl;
@useResult
$Res call({
 String toolUseId, PermissionRequestMessage request
});




}
/// @nodoc
class _$ApprovalPermissionCopyWithImpl<$Res>
    implements $ApprovalPermissionCopyWith<$Res> {
  _$ApprovalPermissionCopyWithImpl(this._self, this._then);

  final ApprovalPermission _self;
  final $Res Function(ApprovalPermission) _then;

/// Create a copy of ApprovalState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? toolUseId = null,Object? request = null,}) {
  return _then(ApprovalPermission(
toolUseId: null == toolUseId ? _self.toolUseId : toolUseId // ignore: cast_nullable_to_non_nullable
as String,request: null == request ? _self.request : request // ignore: cast_nullable_to_non_nullable
as PermissionRequestMessage,
  ));
}


}

/// @nodoc


class ApprovalAskUser implements ApprovalState {
  const ApprovalAskUser({required this.toolUseId, required final  Map<String, dynamic> input}): _input = input;
  

 final  String toolUseId;
 final  Map<String, dynamic> _input;
 Map<String, dynamic> get input {
  if (_input is EqualUnmodifiableMapView) return _input;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_input);
}


/// Create a copy of ApprovalState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApprovalAskUserCopyWith<ApprovalAskUser> get copyWith => _$ApprovalAskUserCopyWithImpl<ApprovalAskUser>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalAskUser&&(identical(other.toolUseId, toolUseId) || other.toolUseId == toolUseId)&&const DeepCollectionEquality().equals(other._input, _input));
}


@override
int get hashCode => Object.hash(runtimeType,toolUseId,const DeepCollectionEquality().hash(_input));

@override
String toString() {
  return 'ApprovalState.askUser(toolUseId: $toolUseId, input: $input)';
}


}

/// @nodoc
abstract mixin class $ApprovalAskUserCopyWith<$Res> implements $ApprovalStateCopyWith<$Res> {
  factory $ApprovalAskUserCopyWith(ApprovalAskUser value, $Res Function(ApprovalAskUser) _then) = _$ApprovalAskUserCopyWithImpl;
@useResult
$Res call({
 String toolUseId, Map<String, dynamic> input
});




}
/// @nodoc
class _$ApprovalAskUserCopyWithImpl<$Res>
    implements $ApprovalAskUserCopyWith<$Res> {
  _$ApprovalAskUserCopyWithImpl(this._self, this._then);

  final ApprovalAskUser _self;
  final $Res Function(ApprovalAskUser) _then;

/// Create a copy of ApprovalState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? toolUseId = null,Object? input = null,}) {
  return _then(ApprovalAskUser(
toolUseId: null == toolUseId ? _self.toolUseId : toolUseId // ignore: cast_nullable_to_non_nullable
as String,input: null == input ? _self._input : input // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
