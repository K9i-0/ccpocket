// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatSessionState {

 ProcessStatus get status; List<ChatEntry> get entries; ApprovalState get approval; String? get claudeSessionId; String? get projectPath; String? get worktreePath; String? get gitBranch; String get explorerCurrentPath; List<String> get recentPeekedFiles; bool get pastHistoryLoaded; bool get bulkLoading; bool get inPlanMode; bool get collapseToolResults; bool get sessionUnavailable; bool get sessionContextLoaded; PermissionMode get permissionMode; ExecutionMode get executionMode; CodexApprovalPolicy get codexApprovalPolicy; String get codexApprovalsReviewer; CodexPermissionsMode get codexPermissionsMode; String? get codexModel; ReasoningEffort? get codexModelReasoningEffort; CodexSpeed get codexSpeed; String? get claudeModel; ClaudeEffort? get claudeEffort; bool get claudeFastMode; bool get planMode; SandboxMode get sandboxMode; Set<String> get hiddenToolUseIds; RewindPreviewMessage? get rewindPreview; double get totalCost; Duration? get totalDuration; List<SlashCommand> get slashCommands; QueuedInputItem? get queuedInput; List<BackgroundTaskInfo> get backgroundTasks; CodexGoal? get goal; CodexRecoveryInfo? get recovery;
/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSessionStateCopyWith<ChatSessionState> get copyWith => _$ChatSessionStateCopyWithImpl<ChatSessionState>(this as ChatSessionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ChatSessionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSessionState&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.entries, _this.entries)&&(identical(other.approval, _this.approval) || other.approval == _this.approval)&&(identical(other.claudeSessionId, _this.claudeSessionId) || other.claudeSessionId == _this.claudeSessionId)&&(identical(other.projectPath, _this.projectPath) || other.projectPath == _this.projectPath)&&(identical(other.worktreePath, _this.worktreePath) || other.worktreePath == _this.worktreePath)&&(identical(other.gitBranch, _this.gitBranch) || other.gitBranch == _this.gitBranch)&&(identical(other.explorerCurrentPath, _this.explorerCurrentPath) || other.explorerCurrentPath == _this.explorerCurrentPath)&&const DeepCollectionEquality().equals(other.recentPeekedFiles, _this.recentPeekedFiles)&&(identical(other.pastHistoryLoaded, _this.pastHistoryLoaded) || other.pastHistoryLoaded == _this.pastHistoryLoaded)&&(identical(other.bulkLoading, _this.bulkLoading) || other.bulkLoading == _this.bulkLoading)&&(identical(other.inPlanMode, _this.inPlanMode) || other.inPlanMode == _this.inPlanMode)&&(identical(other.collapseToolResults, _this.collapseToolResults) || other.collapseToolResults == _this.collapseToolResults)&&(identical(other.sessionUnavailable, _this.sessionUnavailable) || other.sessionUnavailable == _this.sessionUnavailable)&&(identical(other.sessionContextLoaded, _this.sessionContextLoaded) || other.sessionContextLoaded == _this.sessionContextLoaded)&&(identical(other.permissionMode, _this.permissionMode) || other.permissionMode == _this.permissionMode)&&(identical(other.executionMode, _this.executionMode) || other.executionMode == _this.executionMode)&&(identical(other.codexApprovalPolicy, _this.codexApprovalPolicy) || other.codexApprovalPolicy == _this.codexApprovalPolicy)&&(identical(other.codexApprovalsReviewer, _this.codexApprovalsReviewer) || other.codexApprovalsReviewer == _this.codexApprovalsReviewer)&&(identical(other.codexPermissionsMode, _this.codexPermissionsMode) || other.codexPermissionsMode == _this.codexPermissionsMode)&&(identical(other.codexModel, _this.codexModel) || other.codexModel == _this.codexModel)&&(identical(other.codexModelReasoningEffort, _this.codexModelReasoningEffort) || other.codexModelReasoningEffort == _this.codexModelReasoningEffort)&&(identical(other.codexSpeed, _this.codexSpeed) || other.codexSpeed == _this.codexSpeed)&&(identical(other.claudeModel, _this.claudeModel) || other.claudeModel == _this.claudeModel)&&(identical(other.claudeEffort, _this.claudeEffort) || other.claudeEffort == _this.claudeEffort)&&(identical(other.claudeFastMode, _this.claudeFastMode) || other.claudeFastMode == _this.claudeFastMode)&&(identical(other.planMode, _this.planMode) || other.planMode == _this.planMode)&&(identical(other.sandboxMode, _this.sandboxMode) || other.sandboxMode == _this.sandboxMode)&&const DeepCollectionEquality().equals(other.hiddenToolUseIds, _this.hiddenToolUseIds)&&(identical(other.rewindPreview, _this.rewindPreview) || other.rewindPreview == _this.rewindPreview)&&(identical(other.totalCost, _this.totalCost) || other.totalCost == _this.totalCost)&&(identical(other.totalDuration, _this.totalDuration) || other.totalDuration == _this.totalDuration)&&const DeepCollectionEquality().equals(other.slashCommands, _this.slashCommands)&&(identical(other.queuedInput, _this.queuedInput) || other.queuedInput == _this.queuedInput)&&const DeepCollectionEquality().equals(other.backgroundTasks, _this.backgroundTasks)&&(identical(other.goal, _this.goal) || other.goal == _this.goal)&&(identical(other.recovery, _this.recovery) || other.recovery == _this.recovery));
}


@override
int get hashCode {
  final _this = this as ChatSessionState;
  return Object.hashAll([runtimeType,_this.status,const DeepCollectionEquality().hash(_this.entries),_this.approval,_this.claudeSessionId,_this.projectPath,_this.worktreePath,_this.gitBranch,_this.explorerCurrentPath,const DeepCollectionEquality().hash(_this.recentPeekedFiles),_this.pastHistoryLoaded,_this.bulkLoading,_this.inPlanMode,_this.collapseToolResults,_this.sessionUnavailable,_this.sessionContextLoaded,_this.permissionMode,_this.executionMode,_this.codexApprovalPolicy,_this.codexApprovalsReviewer,_this.codexPermissionsMode,_this.codexModel,_this.codexModelReasoningEffort,_this.codexSpeed,_this.claudeModel,_this.claudeEffort,_this.claudeFastMode,_this.planMode,_this.sandboxMode,const DeepCollectionEquality().hash(_this.hiddenToolUseIds),_this.rewindPreview,_this.totalCost,_this.totalDuration,const DeepCollectionEquality().hash(_this.slashCommands),_this.queuedInput,const DeepCollectionEquality().hash(_this.backgroundTasks),_this.goal,_this.recovery]);
}

@override
String toString() {
  final _this = this as ChatSessionState;
  return 'ChatSessionState(status: ${_this.status}, entries: ${_this.entries}, approval: ${_this.approval}, claudeSessionId: ${_this.claudeSessionId}, projectPath: ${_this.projectPath}, worktreePath: ${_this.worktreePath}, gitBranch: ${_this.gitBranch}, explorerCurrentPath: ${_this.explorerCurrentPath}, recentPeekedFiles: ${_this.recentPeekedFiles}, pastHistoryLoaded: ${_this.pastHistoryLoaded}, bulkLoading: ${_this.bulkLoading}, inPlanMode: ${_this.inPlanMode}, collapseToolResults: ${_this.collapseToolResults}, sessionUnavailable: ${_this.sessionUnavailable}, sessionContextLoaded: ${_this.sessionContextLoaded}, permissionMode: ${_this.permissionMode}, executionMode: ${_this.executionMode}, codexApprovalPolicy: ${_this.codexApprovalPolicy}, codexApprovalsReviewer: ${_this.codexApprovalsReviewer}, codexPermissionsMode: ${_this.codexPermissionsMode}, codexModel: ${_this.codexModel}, codexModelReasoningEffort: ${_this.codexModelReasoningEffort}, codexSpeed: ${_this.codexSpeed}, claudeModel: ${_this.claudeModel}, claudeEffort: ${_this.claudeEffort}, claudeFastMode: ${_this.claudeFastMode}, planMode: ${_this.planMode}, sandboxMode: ${_this.sandboxMode}, hiddenToolUseIds: ${_this.hiddenToolUseIds}, rewindPreview: ${_this.rewindPreview}, totalCost: ${_this.totalCost}, totalDuration: ${_this.totalDuration}, slashCommands: ${_this.slashCommands}, queuedInput: ${_this.queuedInput}, backgroundTasks: ${_this.backgroundTasks}, goal: ${_this.goal}, recovery: ${_this.recovery})';
}


}

/// @nodoc
abstract mixin class $ChatSessionStateCopyWith<$Res>  {
  factory $ChatSessionStateCopyWith(ChatSessionState value, $Res Function(ChatSessionState) _then) = _$ChatSessionStateCopyWithImpl;
@useResult
$Res call({
 ProcessStatus status, List<ChatEntry> entries, ApprovalState approval, String? claudeSessionId, String? projectPath, String? worktreePath, String? gitBranch, String explorerCurrentPath, List<String> recentPeekedFiles, bool pastHistoryLoaded, bool bulkLoading, bool inPlanMode, bool collapseToolResults, bool sessionUnavailable, bool sessionContextLoaded, PermissionMode permissionMode, ExecutionMode executionMode, CodexApprovalPolicy codexApprovalPolicy, String codexApprovalsReviewer, CodexPermissionsMode codexPermissionsMode, String? codexModel, ReasoningEffort? codexModelReasoningEffort, CodexSpeed codexSpeed, String? claudeModel, ClaudeEffort? claudeEffort, bool claudeFastMode, bool planMode, SandboxMode sandboxMode, Set<String> hiddenToolUseIds, RewindPreviewMessage? rewindPreview, double totalCost, Duration? totalDuration, List<SlashCommand> slashCommands, QueuedInputItem? queuedInput, List<BackgroundTaskInfo> backgroundTasks, CodexGoal? goal, CodexRecoveryInfo? recovery
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
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? entries = null,Object? approval = null,Object? claudeSessionId = freezed,Object? projectPath = freezed,Object? worktreePath = freezed,Object? gitBranch = freezed,Object? explorerCurrentPath = null,Object? recentPeekedFiles = null,Object? pastHistoryLoaded = null,Object? bulkLoading = null,Object? inPlanMode = null,Object? collapseToolResults = null,Object? sessionUnavailable = null,Object? sessionContextLoaded = null,Object? permissionMode = null,Object? executionMode = null,Object? codexApprovalPolicy = null,Object? codexApprovalsReviewer = null,Object? codexPermissionsMode = null,Object? codexModel = freezed,Object? codexModelReasoningEffort = freezed,Object? codexSpeed = null,Object? claudeModel = freezed,Object? claudeEffort = freezed,Object? claudeFastMode = null,Object? planMode = null,Object? sandboxMode = null,Object? hiddenToolUseIds = null,Object? rewindPreview = freezed,Object? totalCost = null,Object? totalDuration = freezed,Object? slashCommands = null,Object? queuedInput = freezed,Object? backgroundTasks = null,Object? goal = freezed,Object? recovery = freezed,}) {
  return _then(ChatSessionState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProcessStatus,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,approval: null == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalState,claudeSessionId: freezed == claudeSessionId ? _self.claudeSessionId : claudeSessionId // ignore: cast_nullable_to_non_nullable
as String?,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,explorerCurrentPath: null == explorerCurrentPath ? _self.explorerCurrentPath : explorerCurrentPath // ignore: cast_nullable_to_non_nullable
as String,recentPeekedFiles: null == recentPeekedFiles ? _self.recentPeekedFiles : recentPeekedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,pastHistoryLoaded: null == pastHistoryLoaded ? _self.pastHistoryLoaded : pastHistoryLoaded // ignore: cast_nullable_to_non_nullable
as bool,bulkLoading: null == bulkLoading ? _self.bulkLoading : bulkLoading // ignore: cast_nullable_to_non_nullable
as bool,inPlanMode: null == inPlanMode ? _self.inPlanMode : inPlanMode // ignore: cast_nullable_to_non_nullable
as bool,collapseToolResults: null == collapseToolResults ? _self.collapseToolResults : collapseToolResults // ignore: cast_nullable_to_non_nullable
as bool,sessionUnavailable: null == sessionUnavailable ? _self.sessionUnavailable : sessionUnavailable // ignore: cast_nullable_to_non_nullable
as bool,sessionContextLoaded: null == sessionContextLoaded ? _self.sessionContextLoaded : sessionContextLoaded // ignore: cast_nullable_to_non_nullable
as bool,permissionMode: null == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode,executionMode: null == executionMode ? _self.executionMode : executionMode // ignore: cast_nullable_to_non_nullable
as ExecutionMode,codexApprovalPolicy: null == codexApprovalPolicy ? _self.codexApprovalPolicy : codexApprovalPolicy // ignore: cast_nullable_to_non_nullable
as CodexApprovalPolicy,codexApprovalsReviewer: null == codexApprovalsReviewer ? _self.codexApprovalsReviewer : codexApprovalsReviewer // ignore: cast_nullable_to_non_nullable
as String,codexPermissionsMode: null == codexPermissionsMode ? _self.codexPermissionsMode : codexPermissionsMode // ignore: cast_nullable_to_non_nullable
as CodexPermissionsMode,codexModel: freezed == codexModel ? _self.codexModel : codexModel // ignore: cast_nullable_to_non_nullable
as String?,codexModelReasoningEffort: freezed == codexModelReasoningEffort ? _self.codexModelReasoningEffort : codexModelReasoningEffort // ignore: cast_nullable_to_non_nullable
as ReasoningEffort?,codexSpeed: null == codexSpeed ? _self.codexSpeed : codexSpeed // ignore: cast_nullable_to_non_nullable
as CodexSpeed,claudeModel: freezed == claudeModel ? _self.claudeModel : claudeModel // ignore: cast_nullable_to_non_nullable
as String?,claudeEffort: freezed == claudeEffort ? _self.claudeEffort : claudeEffort // ignore: cast_nullable_to_non_nullable
as ClaudeEffort?,claudeFastMode: null == claudeFastMode ? _self.claudeFastMode : claudeFastMode // ignore: cast_nullable_to_non_nullable
as bool,planMode: null == planMode ? _self.planMode : planMode // ignore: cast_nullable_to_non_nullable
as bool,sandboxMode: null == sandboxMode ? _self.sandboxMode : sandboxMode // ignore: cast_nullable_to_non_nullable
as SandboxMode,hiddenToolUseIds: null == hiddenToolUseIds ? _self.hiddenToolUseIds : hiddenToolUseIds // ignore: cast_nullable_to_non_nullable
as Set<String>,rewindPreview: freezed == rewindPreview ? _self.rewindPreview : rewindPreview // ignore: cast_nullable_to_non_nullable
as RewindPreviewMessage?,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,totalDuration: freezed == totalDuration ? _self.totalDuration : totalDuration // ignore: cast_nullable_to_non_nullable
as Duration?,slashCommands: null == slashCommands ? _self.slashCommands : slashCommands // ignore: cast_nullable_to_non_nullable
as List<SlashCommand>,queuedInput: freezed == queuedInput ? _self.queuedInput : queuedInput // ignore: cast_nullable_to_non_nullable
as QueuedInputItem?,backgroundTasks: null == backgroundTasks ? _self.backgroundTasks : backgroundTasks // ignore: cast_nullable_to_non_nullable
as List<BackgroundTaskInfo>,goal: freezed == goal ? _self.goal : goal // ignore: cast_nullable_to_non_nullable
as CodexGoal?,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as CodexRecoveryInfo?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProcessStatus status,  List<ChatEntry> entries,  ApprovalState approval,  String? claudeSessionId,  String? projectPath,  String? worktreePath,  String? gitBranch,  String explorerCurrentPath,  List<String> recentPeekedFiles,  bool pastHistoryLoaded,  bool bulkLoading,  bool inPlanMode,  bool collapseToolResults,  bool sessionUnavailable,  bool sessionContextLoaded,  PermissionMode permissionMode,  ExecutionMode executionMode,  CodexApprovalPolicy codexApprovalPolicy,  String codexApprovalsReviewer,  CodexPermissionsMode codexPermissionsMode,  String? codexModel,  ReasoningEffort? codexModelReasoningEffort,  CodexSpeed codexSpeed,  String? claudeModel,  ClaudeEffort? claudeEffort,  bool claudeFastMode,  bool planMode,  SandboxMode sandboxMode,  Set<String> hiddenToolUseIds,  RewindPreviewMessage? rewindPreview,  double totalCost,  Duration? totalDuration,  List<SlashCommand> slashCommands,  QueuedInputItem? queuedInput,  List<BackgroundTaskInfo> backgroundTasks,  CodexGoal? goal,  CodexRecoveryInfo? recovery)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatSessionState() when $default != null:
return $default(_that.status,_that.entries,_that.approval,_that.claudeSessionId,_that.projectPath,_that.worktreePath,_that.gitBranch,_that.explorerCurrentPath,_that.recentPeekedFiles,_that.pastHistoryLoaded,_that.bulkLoading,_that.inPlanMode,_that.collapseToolResults,_that.sessionUnavailable,_that.sessionContextLoaded,_that.permissionMode,_that.executionMode,_that.codexApprovalPolicy,_that.codexApprovalsReviewer,_that.codexPermissionsMode,_that.codexModel,_that.codexModelReasoningEffort,_that.codexSpeed,_that.claudeModel,_that.claudeEffort,_that.claudeFastMode,_that.planMode,_that.sandboxMode,_that.hiddenToolUseIds,_that.rewindPreview,_that.totalCost,_that.totalDuration,_that.slashCommands,_that.queuedInput,_that.backgroundTasks,_that.goal,_that.recovery);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProcessStatus status,  List<ChatEntry> entries,  ApprovalState approval,  String? claudeSessionId,  String? projectPath,  String? worktreePath,  String? gitBranch,  String explorerCurrentPath,  List<String> recentPeekedFiles,  bool pastHistoryLoaded,  bool bulkLoading,  bool inPlanMode,  bool collapseToolResults,  bool sessionUnavailable,  bool sessionContextLoaded,  PermissionMode permissionMode,  ExecutionMode executionMode,  CodexApprovalPolicy codexApprovalPolicy,  String codexApprovalsReviewer,  CodexPermissionsMode codexPermissionsMode,  String? codexModel,  ReasoningEffort? codexModelReasoningEffort,  CodexSpeed codexSpeed,  String? claudeModel,  ClaudeEffort? claudeEffort,  bool claudeFastMode,  bool planMode,  SandboxMode sandboxMode,  Set<String> hiddenToolUseIds,  RewindPreviewMessage? rewindPreview,  double totalCost,  Duration? totalDuration,  List<SlashCommand> slashCommands,  QueuedInputItem? queuedInput,  List<BackgroundTaskInfo> backgroundTasks,  CodexGoal? goal,  CodexRecoveryInfo? recovery)  $default,) {final _that = this;
switch (_that) {
case _ChatSessionState():
return $default(_that.status,_that.entries,_that.approval,_that.claudeSessionId,_that.projectPath,_that.worktreePath,_that.gitBranch,_that.explorerCurrentPath,_that.recentPeekedFiles,_that.pastHistoryLoaded,_that.bulkLoading,_that.inPlanMode,_that.collapseToolResults,_that.sessionUnavailable,_that.sessionContextLoaded,_that.permissionMode,_that.executionMode,_that.codexApprovalPolicy,_that.codexApprovalsReviewer,_that.codexPermissionsMode,_that.codexModel,_that.codexModelReasoningEffort,_that.codexSpeed,_that.claudeModel,_that.claudeEffort,_that.claudeFastMode,_that.planMode,_that.sandboxMode,_that.hiddenToolUseIds,_that.rewindPreview,_that.totalCost,_that.totalDuration,_that.slashCommands,_that.queuedInput,_that.backgroundTasks,_that.goal,_that.recovery);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProcessStatus status,  List<ChatEntry> entries,  ApprovalState approval,  String? claudeSessionId,  String? projectPath,  String? worktreePath,  String? gitBranch,  String explorerCurrentPath,  List<String> recentPeekedFiles,  bool pastHistoryLoaded,  bool bulkLoading,  bool inPlanMode,  bool collapseToolResults,  bool sessionUnavailable,  bool sessionContextLoaded,  PermissionMode permissionMode,  ExecutionMode executionMode,  CodexApprovalPolicy codexApprovalPolicy,  String codexApprovalsReviewer,  CodexPermissionsMode codexPermissionsMode,  String? codexModel,  ReasoningEffort? codexModelReasoningEffort,  CodexSpeed codexSpeed,  String? claudeModel,  ClaudeEffort? claudeEffort,  bool claudeFastMode,  bool planMode,  SandboxMode sandboxMode,  Set<String> hiddenToolUseIds,  RewindPreviewMessage? rewindPreview,  double totalCost,  Duration? totalDuration,  List<SlashCommand> slashCommands,  QueuedInputItem? queuedInput,  List<BackgroundTaskInfo> backgroundTasks,  CodexGoal? goal,  CodexRecoveryInfo? recovery)?  $default,) {final _that = this;
switch (_that) {
case _ChatSessionState() when $default != null:
return $default(_that.status,_that.entries,_that.approval,_that.claudeSessionId,_that.projectPath,_that.worktreePath,_that.gitBranch,_that.explorerCurrentPath,_that.recentPeekedFiles,_that.pastHistoryLoaded,_that.bulkLoading,_that.inPlanMode,_that.collapseToolResults,_that.sessionUnavailable,_that.sessionContextLoaded,_that.permissionMode,_that.executionMode,_that.codexApprovalPolicy,_that.codexApprovalsReviewer,_that.codexPermissionsMode,_that.codexModel,_that.codexModelReasoningEffort,_that.codexSpeed,_that.claudeModel,_that.claudeEffort,_that.claudeFastMode,_that.planMode,_that.sandboxMode,_that.hiddenToolUseIds,_that.rewindPreview,_that.totalCost,_that.totalDuration,_that.slashCommands,_that.queuedInput,_that.backgroundTasks,_that.goal,_that.recovery);case _:
  return null;

}
}

}

/// @nodoc


class _ChatSessionState implements ChatSessionState {
  const _ChatSessionState({this.status = ProcessStatus.starting,  List<ChatEntry> entries = const [], this.approval = const ApprovalState.none(), this.claudeSessionId, this.projectPath, this.worktreePath, this.gitBranch, this.explorerCurrentPath = '',  List<String> recentPeekedFiles = const [], this.pastHistoryLoaded = false, this.bulkLoading = false, this.inPlanMode = false, this.collapseToolResults = false, this.sessionUnavailable = false, this.sessionContextLoaded = false, this.permissionMode = PermissionMode.defaultMode, this.executionMode = ExecutionMode.defaultMode, this.codexApprovalPolicy = CodexApprovalPolicy.onRequest, this.codexApprovalsReviewer = 'user', this.codexPermissionsMode = CodexPermissionsMode.defaultPermissions, this.codexModel, this.codexModelReasoningEffort, this.codexSpeed = CodexSpeed.standard, this.claudeModel, this.claudeEffort, this.claudeFastMode = false, this.planMode = false, this.sandboxMode = SandboxMode.on,  Set<String> hiddenToolUseIds = const {}, this.rewindPreview, this.totalCost = 0.0, this.totalDuration,  List<SlashCommand> slashCommands = const [], this.queuedInput,  List<BackgroundTaskInfo> backgroundTasks = const [], this.goal, this.recovery}): _entries = entries,_recentPeekedFiles = recentPeekedFiles,_hiddenToolUseIds = hiddenToolUseIds,_slashCommands = slashCommands,_backgroundTasks = backgroundTasks;
  

@override@JsonKey() final  ProcessStatus status;
 final  List<ChatEntry> _entries;
@override@JsonKey() List<ChatEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

@override@JsonKey() final  ApprovalState approval;
@override final  String? claudeSessionId;
@override final  String? projectPath;
@override final  String? worktreePath;
@override final  String? gitBranch;
@override@JsonKey() final  String explorerCurrentPath;
 final  List<String> _recentPeekedFiles;
@override@JsonKey() List<String> get recentPeekedFiles {
  if (_recentPeekedFiles is EqualUnmodifiableListView) return _recentPeekedFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentPeekedFiles);
}

@override@JsonKey() final  bool pastHistoryLoaded;
@override@JsonKey() final  bool bulkLoading;
@override@JsonKey() final  bool inPlanMode;
@override@JsonKey() final  bool collapseToolResults;
@override@JsonKey() final  bool sessionUnavailable;
@override@JsonKey() final  bool sessionContextLoaded;
@override@JsonKey() final  PermissionMode permissionMode;
@override@JsonKey() final  ExecutionMode executionMode;
@override@JsonKey() final  CodexApprovalPolicy codexApprovalPolicy;
@override@JsonKey() final  String codexApprovalsReviewer;
@override@JsonKey() final  CodexPermissionsMode codexPermissionsMode;
@override final  String? codexModel;
@override final  ReasoningEffort? codexModelReasoningEffort;
@override@JsonKey() final  CodexSpeed codexSpeed;
@override final  String? claudeModel;
@override final  ClaudeEffort? claudeEffort;
@override@JsonKey() final  bool claudeFastMode;
@override@JsonKey() final  bool planMode;
@override@JsonKey() final  SandboxMode sandboxMode;
 final  Set<String> _hiddenToolUseIds;
@override@JsonKey() Set<String> get hiddenToolUseIds {
  if (_hiddenToolUseIds is EqualUnmodifiableSetView) return _hiddenToolUseIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_hiddenToolUseIds);
}

@override final  RewindPreviewMessage? rewindPreview;
@override@JsonKey() final  double totalCost;
@override final  Duration? totalDuration;
 final  List<SlashCommand> _slashCommands;
@override@JsonKey() List<SlashCommand> get slashCommands {
  if (_slashCommands is EqualUnmodifiableListView) return _slashCommands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_slashCommands);
}

@override final  QueuedInputItem? queuedInput;
 final  List<BackgroundTaskInfo> _backgroundTasks;
@override@JsonKey() List<BackgroundTaskInfo> get backgroundTasks {
  if (_backgroundTasks is EqualUnmodifiableListView) return _backgroundTasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_backgroundTasks);
}

@override final  CodexGoal? goal;
@override final  CodexRecoveryInfo? recovery;

/// Create a copy of ChatSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatSessionStateCopyWith<_ChatSessionState> get copyWith => __$ChatSessionStateCopyWithImpl<_ChatSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatSessionState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.entries, _entries)&&(identical(other.approval, approval) || other.approval == approval)&&(identical(other.claudeSessionId, claudeSessionId) || other.claudeSessionId == claudeSessionId)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch)&&(identical(other.explorerCurrentPath, explorerCurrentPath) || other.explorerCurrentPath == explorerCurrentPath)&&const DeepCollectionEquality().equals(other.recentPeekedFiles, _recentPeekedFiles)&&(identical(other.pastHistoryLoaded, pastHistoryLoaded) || other.pastHistoryLoaded == pastHistoryLoaded)&&(identical(other.bulkLoading, bulkLoading) || other.bulkLoading == bulkLoading)&&(identical(other.inPlanMode, inPlanMode) || other.inPlanMode == inPlanMode)&&(identical(other.collapseToolResults, collapseToolResults) || other.collapseToolResults == collapseToolResults)&&(identical(other.sessionUnavailable, sessionUnavailable) || other.sessionUnavailable == sessionUnavailable)&&(identical(other.sessionContextLoaded, sessionContextLoaded) || other.sessionContextLoaded == sessionContextLoaded)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.executionMode, executionMode) || other.executionMode == executionMode)&&(identical(other.codexApprovalPolicy, codexApprovalPolicy) || other.codexApprovalPolicy == codexApprovalPolicy)&&(identical(other.codexApprovalsReviewer, codexApprovalsReviewer) || other.codexApprovalsReviewer == codexApprovalsReviewer)&&(identical(other.codexPermissionsMode, codexPermissionsMode) || other.codexPermissionsMode == codexPermissionsMode)&&(identical(other.codexModel, codexModel) || other.codexModel == codexModel)&&(identical(other.codexModelReasoningEffort, codexModelReasoningEffort) || other.codexModelReasoningEffort == codexModelReasoningEffort)&&(identical(other.codexSpeed, codexSpeed) || other.codexSpeed == codexSpeed)&&(identical(other.claudeModel, claudeModel) || other.claudeModel == claudeModel)&&(identical(other.claudeEffort, claudeEffort) || other.claudeEffort == claudeEffort)&&(identical(other.claudeFastMode, claudeFastMode) || other.claudeFastMode == claudeFastMode)&&(identical(other.planMode, planMode) || other.planMode == planMode)&&(identical(other.sandboxMode, sandboxMode) || other.sandboxMode == sandboxMode)&&const DeepCollectionEquality().equals(other.hiddenToolUseIds, _hiddenToolUseIds)&&(identical(other.rewindPreview, rewindPreview) || other.rewindPreview == rewindPreview)&&(identical(other.totalCost, totalCost) || other.totalCost == totalCost)&&(identical(other.totalDuration, totalDuration) || other.totalDuration == totalDuration)&&const DeepCollectionEquality().equals(other.slashCommands, _slashCommands)&&(identical(other.queuedInput, queuedInput) || other.queuedInput == queuedInput)&&const DeepCollectionEquality().equals(other.backgroundTasks, _backgroundTasks)&&(identical(other.goal, goal) || other.goal == goal)&&(identical(other.recovery, recovery) || other.recovery == recovery));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,status,const DeepCollectionEquality().hash(_entries),approval,claudeSessionId,projectPath,worktreePath,gitBranch,explorerCurrentPath,const DeepCollectionEquality().hash(_recentPeekedFiles),pastHistoryLoaded,bulkLoading,inPlanMode,collapseToolResults,sessionUnavailable,sessionContextLoaded,permissionMode,executionMode,codexApprovalPolicy,codexApprovalsReviewer,codexPermissionsMode,codexModel,codexModelReasoningEffort,codexSpeed,claudeModel,claudeEffort,claudeFastMode,planMode,sandboxMode,const DeepCollectionEquality().hash(_hiddenToolUseIds),rewindPreview,totalCost,totalDuration,const DeepCollectionEquality().hash(_slashCommands),queuedInput,const DeepCollectionEquality().hash(_backgroundTasks),goal,recovery]);
}

@override
String toString() {
    return 'ChatSessionState(status: $status, entries: $entries, approval: $approval, claudeSessionId: $claudeSessionId, projectPath: $projectPath, worktreePath: $worktreePath, gitBranch: $gitBranch, explorerCurrentPath: $explorerCurrentPath, recentPeekedFiles: $recentPeekedFiles, pastHistoryLoaded: $pastHistoryLoaded, bulkLoading: $bulkLoading, inPlanMode: $inPlanMode, collapseToolResults: $collapseToolResults, sessionUnavailable: $sessionUnavailable, sessionContextLoaded: $sessionContextLoaded, permissionMode: $permissionMode, executionMode: $executionMode, codexApprovalPolicy: $codexApprovalPolicy, codexApprovalsReviewer: $codexApprovalsReviewer, codexPermissionsMode: $codexPermissionsMode, codexModel: $codexModel, codexModelReasoningEffort: $codexModelReasoningEffort, codexSpeed: $codexSpeed, claudeModel: $claudeModel, claudeEffort: $claudeEffort, claudeFastMode: $claudeFastMode, planMode: $planMode, sandboxMode: $sandboxMode, hiddenToolUseIds: $hiddenToolUseIds, rewindPreview: $rewindPreview, totalCost: $totalCost, totalDuration: $totalDuration, slashCommands: $slashCommands, queuedInput: $queuedInput, backgroundTasks: $backgroundTasks, goal: $goal, recovery: $recovery)';
}


}

/// @nodoc
abstract mixin class _$ChatSessionStateCopyWith<$Res> implements $ChatSessionStateCopyWith<$Res> {
  factory _$ChatSessionStateCopyWith(_ChatSessionState value, $Res Function(_ChatSessionState) _then) = __$ChatSessionStateCopyWithImpl;
@override @useResult
$Res call({
 ProcessStatus status, List<ChatEntry> entries, ApprovalState approval, String? claudeSessionId, String? projectPath, String? worktreePath, String? gitBranch, String explorerCurrentPath, List<String> recentPeekedFiles, bool pastHistoryLoaded, bool bulkLoading, bool inPlanMode, bool collapseToolResults, bool sessionUnavailable, bool sessionContextLoaded, PermissionMode permissionMode, ExecutionMode executionMode, CodexApprovalPolicy codexApprovalPolicy, String codexApprovalsReviewer, CodexPermissionsMode codexPermissionsMode, String? codexModel, ReasoningEffort? codexModelReasoningEffort, CodexSpeed codexSpeed, String? claudeModel, ClaudeEffort? claudeEffort, bool claudeFastMode, bool planMode, SandboxMode sandboxMode, Set<String> hiddenToolUseIds, RewindPreviewMessage? rewindPreview, double totalCost, Duration? totalDuration, List<SlashCommand> slashCommands, QueuedInputItem? queuedInput, List<BackgroundTaskInfo> backgroundTasks, CodexGoal? goal, CodexRecoveryInfo? recovery
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
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? entries = null,Object? approval = null,Object? claudeSessionId = freezed,Object? projectPath = freezed,Object? worktreePath = freezed,Object? gitBranch = freezed,Object? explorerCurrentPath = null,Object? recentPeekedFiles = null,Object? pastHistoryLoaded = null,Object? bulkLoading = null,Object? inPlanMode = null,Object? collapseToolResults = null,Object? sessionUnavailable = null,Object? sessionContextLoaded = null,Object? permissionMode = null,Object? executionMode = null,Object? codexApprovalPolicy = null,Object? codexApprovalsReviewer = null,Object? codexPermissionsMode = null,Object? codexModel = freezed,Object? codexModelReasoningEffort = freezed,Object? codexSpeed = null,Object? claudeModel = freezed,Object? claudeEffort = freezed,Object? claudeFastMode = null,Object? planMode = null,Object? sandboxMode = null,Object? hiddenToolUseIds = null,Object? rewindPreview = freezed,Object? totalCost = null,Object? totalDuration = freezed,Object? slashCommands = null,Object? queuedInput = freezed,Object? backgroundTasks = null,Object? goal = freezed,Object? recovery = freezed,}) {
  return _then(_ChatSessionState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ProcessStatus,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<ChatEntry>,approval: null == approval ? _self.approval : approval // ignore: cast_nullable_to_non_nullable
as ApprovalState,claudeSessionId: freezed == claudeSessionId ? _self.claudeSessionId : claudeSessionId // ignore: cast_nullable_to_non_nullable
as String?,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,explorerCurrentPath: null == explorerCurrentPath ? _self.explorerCurrentPath : explorerCurrentPath // ignore: cast_nullable_to_non_nullable
as String,recentPeekedFiles: null == recentPeekedFiles ? _self._recentPeekedFiles : recentPeekedFiles // ignore: cast_nullable_to_non_nullable
as List<String>,pastHistoryLoaded: null == pastHistoryLoaded ? _self.pastHistoryLoaded : pastHistoryLoaded // ignore: cast_nullable_to_non_nullable
as bool,bulkLoading: null == bulkLoading ? _self.bulkLoading : bulkLoading // ignore: cast_nullable_to_non_nullable
as bool,inPlanMode: null == inPlanMode ? _self.inPlanMode : inPlanMode // ignore: cast_nullable_to_non_nullable
as bool,collapseToolResults: null == collapseToolResults ? _self.collapseToolResults : collapseToolResults // ignore: cast_nullable_to_non_nullable
as bool,sessionUnavailable: null == sessionUnavailable ? _self.sessionUnavailable : sessionUnavailable // ignore: cast_nullable_to_non_nullable
as bool,sessionContextLoaded: null == sessionContextLoaded ? _self.sessionContextLoaded : sessionContextLoaded // ignore: cast_nullable_to_non_nullable
as bool,permissionMode: null == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as PermissionMode,executionMode: null == executionMode ? _self.executionMode : executionMode // ignore: cast_nullable_to_non_nullable
as ExecutionMode,codexApprovalPolicy: null == codexApprovalPolicy ? _self.codexApprovalPolicy : codexApprovalPolicy // ignore: cast_nullable_to_non_nullable
as CodexApprovalPolicy,codexApprovalsReviewer: null == codexApprovalsReviewer ? _self.codexApprovalsReviewer : codexApprovalsReviewer // ignore: cast_nullable_to_non_nullable
as String,codexPermissionsMode: null == codexPermissionsMode ? _self.codexPermissionsMode : codexPermissionsMode // ignore: cast_nullable_to_non_nullable
as CodexPermissionsMode,codexModel: freezed == codexModel ? _self.codexModel : codexModel // ignore: cast_nullable_to_non_nullable
as String?,codexModelReasoningEffort: freezed == codexModelReasoningEffort ? _self.codexModelReasoningEffort : codexModelReasoningEffort // ignore: cast_nullable_to_non_nullable
as ReasoningEffort?,codexSpeed: null == codexSpeed ? _self.codexSpeed : codexSpeed // ignore: cast_nullable_to_non_nullable
as CodexSpeed,claudeModel: freezed == claudeModel ? _self.claudeModel : claudeModel // ignore: cast_nullable_to_non_nullable
as String?,claudeEffort: freezed == claudeEffort ? _self.claudeEffort : claudeEffort // ignore: cast_nullable_to_non_nullable
as ClaudeEffort?,claudeFastMode: null == claudeFastMode ? _self.claudeFastMode : claudeFastMode // ignore: cast_nullable_to_non_nullable
as bool,planMode: null == planMode ? _self.planMode : planMode // ignore: cast_nullable_to_non_nullable
as bool,sandboxMode: null == sandboxMode ? _self.sandboxMode : sandboxMode // ignore: cast_nullable_to_non_nullable
as SandboxMode,hiddenToolUseIds: null == hiddenToolUseIds ? _self._hiddenToolUseIds : hiddenToolUseIds // ignore: cast_nullable_to_non_nullable
as Set<String>,rewindPreview: freezed == rewindPreview ? _self.rewindPreview : rewindPreview // ignore: cast_nullable_to_non_nullable
as RewindPreviewMessage?,totalCost: null == totalCost ? _self.totalCost : totalCost // ignore: cast_nullable_to_non_nullable
as double,totalDuration: freezed == totalDuration ? _self.totalDuration : totalDuration // ignore: cast_nullable_to_non_nullable
as Duration?,slashCommands: null == slashCommands ? _self._slashCommands : slashCommands // ignore: cast_nullable_to_non_nullable
as List<SlashCommand>,queuedInput: freezed == queuedInput ? _self.queuedInput : queuedInput // ignore: cast_nullable_to_non_nullable
as QueuedInputItem?,backgroundTasks: null == backgroundTasks ? _self._backgroundTasks : backgroundTasks // ignore: cast_nullable_to_non_nullable
as List<BackgroundTaskInfo>,goal: freezed == goal ? _self.goal : goal // ignore: cast_nullable_to_non_nullable
as CodexGoal?,recovery: freezed == recovery ? _self.recovery : recovery // ignore: cast_nullable_to_non_nullable
as CodexRecoveryInfo?,
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
int get hashCode {
    return Object.hash(runtimeType,toolUseId,request);
}

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
  const ApprovalAskUser({required this.toolUseId, required  Map<String, dynamic> input}): _input = input;
  

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ApprovalAskUser&&(identical(other.toolUseId, toolUseId) || other.toolUseId == toolUseId)&&const DeepCollectionEquality().equals(other.input, _input));
}


@override
int get hashCode {
    return Object.hash(runtimeType,toolUseId,const DeepCollectionEquality().hash(_input));
}

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
