// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SettingsState {

/// Theme mode: system, light, or dark.
 ThemeMode get themeMode;/// App display locale ID (e.g. 'ja', 'en').
/// Empty string means follow the device default.
 String get appLocaleId;/// Locale ID for speech recognition (e.g. 'ja-JP', 'en-US').
/// Empty string means use device default.
 String get speechLocaleId;/// Set of Machine IDs that have push notifications enabled.
 Set<String> get fcmEnabledMachines;/// Set of Machine IDs that have privacy mode enabled for push notifications.
 Set<String> get fcmPrivacyMachines;/// Currently connected Machine ID (null when disconnected).
 String? get activeMachineId;/// Whether Firebase Messaging is available in this runtime.
 bool get fcmAvailable;/// True while token registration/unregistration is being synchronized.
 bool get fcmSyncInProgress;/// Last push sync status key (resolved to localized string in UI).
 FcmStatusKey? get fcmStatusKey;/// Shorebird update track ('stable' or 'staging').
 String get shorebirdTrack;/// Indent size for list formatting (1-4 spaces).
 int get indentSize;/// App-specific multiplier applied on top of the system text scale.
 double get textScale;/// Font size used only for code-oriented surfaces.
 double get codeFontSize;/// Font family used only for code-oriented surfaces.
 CodeFontFamily get codeFontFamily;/// Whether to hide the voice input button in the chat input bar.
 bool get hideVoiceInput;/// Shortcut used to attach images from the clipboard on macOS.
 ImagePasteShortcut get imagePasteShortcut;/// How the Git diff screen maps horizontal gestures to actions.
 GitDiffInteractionMode get gitDiffInteractionMode;/// Whether Git diff focus mode should rotate mobile layouts to landscape.
 bool get gitDiffFocusAutoLandscape;/// Whether to show a subtle badge when the current branch can push/pull.
 bool get showRemoteGitStatusBadge;/// Whether to show the connected Bridge name in the session list.
 bool get showBridgeNameInSessionList;/// Selected app icon preference for monthly Supporter perks.
 AppIconVariant get selectedAppIcon;/// Whether app icon switching is supported on the current platform.
 bool get appIconSupported;/// External terminal app configuration (preset or custom URL template).
 TerminalAppConfig get terminalApp;/// Visible tabs (and their order) in the new session sheet.
 List<NewSessionTab> get newSessionTabs;/// Whether Codex usage limits are shown as remaining quota or used quota.
 UsageDisplayMode get usageDisplayMode;/// Whether new Codex sessions should be automatically named after the first turn.
 bool get autoRenameCodexSessions;/// Whether Max and Ultra appear in Codex Effort sliders when supported.
 bool get showExtendedCodexEfforts;/// Whether new Claude sessions should be automatically named after the first turn.
 bool get autoRenameClaudeSessions;
/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsStateCopyWith<SettingsState> get copyWith => _$SettingsStateCopyWithImpl<SettingsState>(this as SettingsState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.appLocaleId, appLocaleId) || other.appLocaleId == appLocaleId)&&(identical(other.speechLocaleId, speechLocaleId) || other.speechLocaleId == speechLocaleId)&&const DeepCollectionEquality().equals(other.fcmEnabledMachines, fcmEnabledMachines)&&const DeepCollectionEquality().equals(other.fcmPrivacyMachines, fcmPrivacyMachines)&&(identical(other.activeMachineId, activeMachineId) || other.activeMachineId == activeMachineId)&&(identical(other.fcmAvailable, fcmAvailable) || other.fcmAvailable == fcmAvailable)&&(identical(other.fcmSyncInProgress, fcmSyncInProgress) || other.fcmSyncInProgress == fcmSyncInProgress)&&(identical(other.fcmStatusKey, fcmStatusKey) || other.fcmStatusKey == fcmStatusKey)&&(identical(other.shorebirdTrack, shorebirdTrack) || other.shorebirdTrack == shorebirdTrack)&&(identical(other.indentSize, indentSize) || other.indentSize == indentSize)&&(identical(other.textScale, textScale) || other.textScale == textScale)&&(identical(other.codeFontSize, codeFontSize) || other.codeFontSize == codeFontSize)&&(identical(other.codeFontFamily, codeFontFamily) || other.codeFontFamily == codeFontFamily)&&(identical(other.hideVoiceInput, hideVoiceInput) || other.hideVoiceInput == hideVoiceInput)&&(identical(other.imagePasteShortcut, imagePasteShortcut) || other.imagePasteShortcut == imagePasteShortcut)&&(identical(other.gitDiffInteractionMode, gitDiffInteractionMode) || other.gitDiffInteractionMode == gitDiffInteractionMode)&&(identical(other.gitDiffFocusAutoLandscape, gitDiffFocusAutoLandscape) || other.gitDiffFocusAutoLandscape == gitDiffFocusAutoLandscape)&&(identical(other.showRemoteGitStatusBadge, showRemoteGitStatusBadge) || other.showRemoteGitStatusBadge == showRemoteGitStatusBadge)&&(identical(other.showBridgeNameInSessionList, showBridgeNameInSessionList) || other.showBridgeNameInSessionList == showBridgeNameInSessionList)&&(identical(other.selectedAppIcon, selectedAppIcon) || other.selectedAppIcon == selectedAppIcon)&&(identical(other.appIconSupported, appIconSupported) || other.appIconSupported == appIconSupported)&&(identical(other.terminalApp, terminalApp) || other.terminalApp == terminalApp)&&const DeepCollectionEquality().equals(other.newSessionTabs, newSessionTabs)&&(identical(other.usageDisplayMode, usageDisplayMode) || other.usageDisplayMode == usageDisplayMode)&&(identical(other.autoRenameCodexSessions, autoRenameCodexSessions) || other.autoRenameCodexSessions == autoRenameCodexSessions)&&(identical(other.showExtendedCodexEfforts, showExtendedCodexEfforts) || other.showExtendedCodexEfforts == showExtendedCodexEfforts)&&(identical(other.autoRenameClaudeSessions, autoRenameClaudeSessions) || other.autoRenameClaudeSessions == autoRenameClaudeSessions));
}


@override
int get hashCode => Object.hashAll([runtimeType,themeMode,appLocaleId,speechLocaleId,const DeepCollectionEquality().hash(fcmEnabledMachines),const DeepCollectionEquality().hash(fcmPrivacyMachines),activeMachineId,fcmAvailable,fcmSyncInProgress,fcmStatusKey,shorebirdTrack,indentSize,textScale,codeFontSize,codeFontFamily,hideVoiceInput,imagePasteShortcut,gitDiffInteractionMode,gitDiffFocusAutoLandscape,showRemoteGitStatusBadge,showBridgeNameInSessionList,selectedAppIcon,appIconSupported,terminalApp,const DeepCollectionEquality().hash(newSessionTabs),usageDisplayMode,autoRenameCodexSessions,showExtendedCodexEfforts,autoRenameClaudeSessions]);

@override
String toString() {
  return 'SettingsState(themeMode: $themeMode, appLocaleId: $appLocaleId, speechLocaleId: $speechLocaleId, fcmEnabledMachines: $fcmEnabledMachines, fcmPrivacyMachines: $fcmPrivacyMachines, activeMachineId: $activeMachineId, fcmAvailable: $fcmAvailable, fcmSyncInProgress: $fcmSyncInProgress, fcmStatusKey: $fcmStatusKey, shorebirdTrack: $shorebirdTrack, indentSize: $indentSize, textScale: $textScale, codeFontSize: $codeFontSize, codeFontFamily: $codeFontFamily, hideVoiceInput: $hideVoiceInput, imagePasteShortcut: $imagePasteShortcut, gitDiffInteractionMode: $gitDiffInteractionMode, gitDiffFocusAutoLandscape: $gitDiffFocusAutoLandscape, showRemoteGitStatusBadge: $showRemoteGitStatusBadge, showBridgeNameInSessionList: $showBridgeNameInSessionList, selectedAppIcon: $selectedAppIcon, appIconSupported: $appIconSupported, terminalApp: $terminalApp, newSessionTabs: $newSessionTabs, usageDisplayMode: $usageDisplayMode, autoRenameCodexSessions: $autoRenameCodexSessions, showExtendedCodexEfforts: $showExtendedCodexEfforts, autoRenameClaudeSessions: $autoRenameClaudeSessions)';
}


}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res>  {
  factory $SettingsStateCopyWith(SettingsState value, $Res Function(SettingsState) _then) = _$SettingsStateCopyWithImpl;
@useResult
$Res call({
 ThemeMode themeMode, String appLocaleId, String speechLocaleId, Set<String> fcmEnabledMachines, Set<String> fcmPrivacyMachines, String? activeMachineId, bool fcmAvailable, bool fcmSyncInProgress, FcmStatusKey? fcmStatusKey, String shorebirdTrack, int indentSize, double textScale, double codeFontSize, CodeFontFamily codeFontFamily, bool hideVoiceInput, ImagePasteShortcut imagePasteShortcut, GitDiffInteractionMode gitDiffInteractionMode, bool gitDiffFocusAutoLandscape, bool showRemoteGitStatusBadge, bool showBridgeNameInSessionList, AppIconVariant selectedAppIcon, bool appIconSupported, TerminalAppConfig terminalApp, List<NewSessionTab> newSessionTabs, UsageDisplayMode usageDisplayMode, bool autoRenameCodexSessions, bool showExtendedCodexEfforts, bool autoRenameClaudeSessions
});




}
/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? themeMode = null,Object? appLocaleId = null,Object? speechLocaleId = null,Object? fcmEnabledMachines = null,Object? fcmPrivacyMachines = null,Object? activeMachineId = freezed,Object? fcmAvailable = null,Object? fcmSyncInProgress = null,Object? fcmStatusKey = freezed,Object? shorebirdTrack = null,Object? indentSize = null,Object? textScale = null,Object? codeFontSize = null,Object? codeFontFamily = null,Object? hideVoiceInput = null,Object? imagePasteShortcut = null,Object? gitDiffInteractionMode = null,Object? gitDiffFocusAutoLandscape = null,Object? showRemoteGitStatusBadge = null,Object? showBridgeNameInSessionList = null,Object? selectedAppIcon = null,Object? appIconSupported = null,Object? terminalApp = null,Object? newSessionTabs = null,Object? usageDisplayMode = null,Object? autoRenameCodexSessions = null,Object? showExtendedCodexEfforts = null,Object? autoRenameClaudeSessions = null,}) {
  return _then(_self.copyWith(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,appLocaleId: null == appLocaleId ? _self.appLocaleId : appLocaleId // ignore: cast_nullable_to_non_nullable
as String,speechLocaleId: null == speechLocaleId ? _self.speechLocaleId : speechLocaleId // ignore: cast_nullable_to_non_nullable
as String,fcmEnabledMachines: null == fcmEnabledMachines ? _self.fcmEnabledMachines : fcmEnabledMachines // ignore: cast_nullable_to_non_nullable
as Set<String>,fcmPrivacyMachines: null == fcmPrivacyMachines ? _self.fcmPrivacyMachines : fcmPrivacyMachines // ignore: cast_nullable_to_non_nullable
as Set<String>,activeMachineId: freezed == activeMachineId ? _self.activeMachineId : activeMachineId // ignore: cast_nullable_to_non_nullable
as String?,fcmAvailable: null == fcmAvailable ? _self.fcmAvailable : fcmAvailable // ignore: cast_nullable_to_non_nullable
as bool,fcmSyncInProgress: null == fcmSyncInProgress ? _self.fcmSyncInProgress : fcmSyncInProgress // ignore: cast_nullable_to_non_nullable
as bool,fcmStatusKey: freezed == fcmStatusKey ? _self.fcmStatusKey : fcmStatusKey // ignore: cast_nullable_to_non_nullable
as FcmStatusKey?,shorebirdTrack: null == shorebirdTrack ? _self.shorebirdTrack : shorebirdTrack // ignore: cast_nullable_to_non_nullable
as String,indentSize: null == indentSize ? _self.indentSize : indentSize // ignore: cast_nullable_to_non_nullable
as int,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as double,codeFontSize: null == codeFontSize ? _self.codeFontSize : codeFontSize // ignore: cast_nullable_to_non_nullable
as double,codeFontFamily: null == codeFontFamily ? _self.codeFontFamily : codeFontFamily // ignore: cast_nullable_to_non_nullable
as CodeFontFamily,hideVoiceInput: null == hideVoiceInput ? _self.hideVoiceInput : hideVoiceInput // ignore: cast_nullable_to_non_nullable
as bool,imagePasteShortcut: null == imagePasteShortcut ? _self.imagePasteShortcut : imagePasteShortcut // ignore: cast_nullable_to_non_nullable
as ImagePasteShortcut,gitDiffInteractionMode: null == gitDiffInteractionMode ? _self.gitDiffInteractionMode : gitDiffInteractionMode // ignore: cast_nullable_to_non_nullable
as GitDiffInteractionMode,gitDiffFocusAutoLandscape: null == gitDiffFocusAutoLandscape ? _self.gitDiffFocusAutoLandscape : gitDiffFocusAutoLandscape // ignore: cast_nullable_to_non_nullable
as bool,showRemoteGitStatusBadge: null == showRemoteGitStatusBadge ? _self.showRemoteGitStatusBadge : showRemoteGitStatusBadge // ignore: cast_nullable_to_non_nullable
as bool,showBridgeNameInSessionList: null == showBridgeNameInSessionList ? _self.showBridgeNameInSessionList : showBridgeNameInSessionList // ignore: cast_nullable_to_non_nullable
as bool,selectedAppIcon: null == selectedAppIcon ? _self.selectedAppIcon : selectedAppIcon // ignore: cast_nullable_to_non_nullable
as AppIconVariant,appIconSupported: null == appIconSupported ? _self.appIconSupported : appIconSupported // ignore: cast_nullable_to_non_nullable
as bool,terminalApp: null == terminalApp ? _self.terminalApp : terminalApp // ignore: cast_nullable_to_non_nullable
as TerminalAppConfig,newSessionTabs: null == newSessionTabs ? _self.newSessionTabs : newSessionTabs // ignore: cast_nullable_to_non_nullable
as List<NewSessionTab>,usageDisplayMode: null == usageDisplayMode ? _self.usageDisplayMode : usageDisplayMode // ignore: cast_nullable_to_non_nullable
as UsageDisplayMode,autoRenameCodexSessions: null == autoRenameCodexSessions ? _self.autoRenameCodexSessions : autoRenameCodexSessions // ignore: cast_nullable_to_non_nullable
as bool,showExtendedCodexEfforts: null == showExtendedCodexEfforts ? _self.showExtendedCodexEfforts : showExtendedCodexEfforts // ignore: cast_nullable_to_non_nullable
as bool,autoRenameClaudeSessions: null == autoRenameClaudeSessions ? _self.autoRenameClaudeSessions : autoRenameClaudeSessions // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SettingsState].
extension SettingsStatePatterns on SettingsState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettingsState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettingsState value)  $default,){
final _that = this;
switch (_that) {
case _SettingsState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettingsState value)?  $default,){
final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThemeMode themeMode,  String appLocaleId,  String speechLocaleId,  Set<String> fcmEnabledMachines,  Set<String> fcmPrivacyMachines,  String? activeMachineId,  bool fcmAvailable,  bool fcmSyncInProgress,  FcmStatusKey? fcmStatusKey,  String shorebirdTrack,  int indentSize,  double textScale,  double codeFontSize,  CodeFontFamily codeFontFamily,  bool hideVoiceInput,  ImagePasteShortcut imagePasteShortcut,  GitDiffInteractionMode gitDiffInteractionMode,  bool gitDiffFocusAutoLandscape,  bool showRemoteGitStatusBadge,  bool showBridgeNameInSessionList,  AppIconVariant selectedAppIcon,  bool appIconSupported,  TerminalAppConfig terminalApp,  List<NewSessionTab> newSessionTabs,  UsageDisplayMode usageDisplayMode,  bool autoRenameCodexSessions,  bool showExtendedCodexEfforts,  bool autoRenameClaudeSessions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.themeMode,_that.appLocaleId,_that.speechLocaleId,_that.fcmEnabledMachines,_that.fcmPrivacyMachines,_that.activeMachineId,_that.fcmAvailable,_that.fcmSyncInProgress,_that.fcmStatusKey,_that.shorebirdTrack,_that.indentSize,_that.textScale,_that.codeFontSize,_that.codeFontFamily,_that.hideVoiceInput,_that.imagePasteShortcut,_that.gitDiffInteractionMode,_that.gitDiffFocusAutoLandscape,_that.showRemoteGitStatusBadge,_that.showBridgeNameInSessionList,_that.selectedAppIcon,_that.appIconSupported,_that.terminalApp,_that.newSessionTabs,_that.usageDisplayMode,_that.autoRenameCodexSessions,_that.showExtendedCodexEfforts,_that.autoRenameClaudeSessions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThemeMode themeMode,  String appLocaleId,  String speechLocaleId,  Set<String> fcmEnabledMachines,  Set<String> fcmPrivacyMachines,  String? activeMachineId,  bool fcmAvailable,  bool fcmSyncInProgress,  FcmStatusKey? fcmStatusKey,  String shorebirdTrack,  int indentSize,  double textScale,  double codeFontSize,  CodeFontFamily codeFontFamily,  bool hideVoiceInput,  ImagePasteShortcut imagePasteShortcut,  GitDiffInteractionMode gitDiffInteractionMode,  bool gitDiffFocusAutoLandscape,  bool showRemoteGitStatusBadge,  bool showBridgeNameInSessionList,  AppIconVariant selectedAppIcon,  bool appIconSupported,  TerminalAppConfig terminalApp,  List<NewSessionTab> newSessionTabs,  UsageDisplayMode usageDisplayMode,  bool autoRenameCodexSessions,  bool showExtendedCodexEfforts,  bool autoRenameClaudeSessions)  $default,) {final _that = this;
switch (_that) {
case _SettingsState():
return $default(_that.themeMode,_that.appLocaleId,_that.speechLocaleId,_that.fcmEnabledMachines,_that.fcmPrivacyMachines,_that.activeMachineId,_that.fcmAvailable,_that.fcmSyncInProgress,_that.fcmStatusKey,_that.shorebirdTrack,_that.indentSize,_that.textScale,_that.codeFontSize,_that.codeFontFamily,_that.hideVoiceInput,_that.imagePasteShortcut,_that.gitDiffInteractionMode,_that.gitDiffFocusAutoLandscape,_that.showRemoteGitStatusBadge,_that.showBridgeNameInSessionList,_that.selectedAppIcon,_that.appIconSupported,_that.terminalApp,_that.newSessionTabs,_that.usageDisplayMode,_that.autoRenameCodexSessions,_that.showExtendedCodexEfforts,_that.autoRenameClaudeSessions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThemeMode themeMode,  String appLocaleId,  String speechLocaleId,  Set<String> fcmEnabledMachines,  Set<String> fcmPrivacyMachines,  String? activeMachineId,  bool fcmAvailable,  bool fcmSyncInProgress,  FcmStatusKey? fcmStatusKey,  String shorebirdTrack,  int indentSize,  double textScale,  double codeFontSize,  CodeFontFamily codeFontFamily,  bool hideVoiceInput,  ImagePasteShortcut imagePasteShortcut,  GitDiffInteractionMode gitDiffInteractionMode,  bool gitDiffFocusAutoLandscape,  bool showRemoteGitStatusBadge,  bool showBridgeNameInSessionList,  AppIconVariant selectedAppIcon,  bool appIconSupported,  TerminalAppConfig terminalApp,  List<NewSessionTab> newSessionTabs,  UsageDisplayMode usageDisplayMode,  bool autoRenameCodexSessions,  bool showExtendedCodexEfforts,  bool autoRenameClaudeSessions)?  $default,) {final _that = this;
switch (_that) {
case _SettingsState() when $default != null:
return $default(_that.themeMode,_that.appLocaleId,_that.speechLocaleId,_that.fcmEnabledMachines,_that.fcmPrivacyMachines,_that.activeMachineId,_that.fcmAvailable,_that.fcmSyncInProgress,_that.fcmStatusKey,_that.shorebirdTrack,_that.indentSize,_that.textScale,_that.codeFontSize,_that.codeFontFamily,_that.hideVoiceInput,_that.imagePasteShortcut,_that.gitDiffInteractionMode,_that.gitDiffFocusAutoLandscape,_that.showRemoteGitStatusBadge,_that.showBridgeNameInSessionList,_that.selectedAppIcon,_that.appIconSupported,_that.terminalApp,_that.newSessionTabs,_that.usageDisplayMode,_that.autoRenameCodexSessions,_that.showExtendedCodexEfforts,_that.autoRenameClaudeSessions);case _:
  return null;

}
}

}

/// @nodoc


class _SettingsState extends SettingsState {
  const _SettingsState({this.themeMode = ThemeMode.system, this.appLocaleId = '', this.speechLocaleId = '', final  Set<String> fcmEnabledMachines = const {}, final  Set<String> fcmPrivacyMachines = const {}, this.activeMachineId, this.fcmAvailable = false, this.fcmSyncInProgress = false, this.fcmStatusKey, this.shorebirdTrack = 'stable', this.indentSize = 2, this.textScale = 1.0, this.codeFontSize = 12.0, this.codeFontFamily = CodeFontFamily.jetBrainsMono, this.hideVoiceInput = false, this.imagePasteShortcut = ImagePasteShortcut.ctrlV, this.gitDiffInteractionMode = GitDiffInteractionMode.quickActions, this.gitDiffFocusAutoLandscape = false, this.showRemoteGitStatusBadge = false, this.showBridgeNameInSessionList = true, this.selectedAppIcon = AppIconVariant.defaultIcon, this.appIconSupported = false, this.terminalApp = TerminalAppConfig.empty, final  List<NewSessionTab> newSessionTabs = defaultNewSessionTabs, this.usageDisplayMode = UsageDisplayMode.remaining, this.autoRenameCodexSessions = true, this.showExtendedCodexEfforts = false, this.autoRenameClaudeSessions = false}): _fcmEnabledMachines = fcmEnabledMachines,_fcmPrivacyMachines = fcmPrivacyMachines,_newSessionTabs = newSessionTabs,super._();
  

/// Theme mode: system, light, or dark.
@override@JsonKey() final  ThemeMode themeMode;
/// App display locale ID (e.g. 'ja', 'en').
/// Empty string means follow the device default.
@override@JsonKey() final  String appLocaleId;
/// Locale ID for speech recognition (e.g. 'ja-JP', 'en-US').
/// Empty string means use device default.
@override@JsonKey() final  String speechLocaleId;
/// Set of Machine IDs that have push notifications enabled.
 final  Set<String> _fcmEnabledMachines;
/// Set of Machine IDs that have push notifications enabled.
@override@JsonKey() Set<String> get fcmEnabledMachines {
  if (_fcmEnabledMachines is EqualUnmodifiableSetView) return _fcmEnabledMachines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_fcmEnabledMachines);
}

/// Set of Machine IDs that have privacy mode enabled for push notifications.
 final  Set<String> _fcmPrivacyMachines;
/// Set of Machine IDs that have privacy mode enabled for push notifications.
@override@JsonKey() Set<String> get fcmPrivacyMachines {
  if (_fcmPrivacyMachines is EqualUnmodifiableSetView) return _fcmPrivacyMachines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_fcmPrivacyMachines);
}

/// Currently connected Machine ID (null when disconnected).
@override final  String? activeMachineId;
/// Whether Firebase Messaging is available in this runtime.
@override@JsonKey() final  bool fcmAvailable;
/// True while token registration/unregistration is being synchronized.
@override@JsonKey() final  bool fcmSyncInProgress;
/// Last push sync status key (resolved to localized string in UI).
@override final  FcmStatusKey? fcmStatusKey;
/// Shorebird update track ('stable' or 'staging').
@override@JsonKey() final  String shorebirdTrack;
/// Indent size for list formatting (1-4 spaces).
@override@JsonKey() final  int indentSize;
/// App-specific multiplier applied on top of the system text scale.
@override@JsonKey() final  double textScale;
/// Font size used only for code-oriented surfaces.
@override@JsonKey() final  double codeFontSize;
/// Font family used only for code-oriented surfaces.
@override@JsonKey() final  CodeFontFamily codeFontFamily;
/// Whether to hide the voice input button in the chat input bar.
@override@JsonKey() final  bool hideVoiceInput;
/// Shortcut used to attach images from the clipboard on macOS.
@override@JsonKey() final  ImagePasteShortcut imagePasteShortcut;
/// How the Git diff screen maps horizontal gestures to actions.
@override@JsonKey() final  GitDiffInteractionMode gitDiffInteractionMode;
/// Whether Git diff focus mode should rotate mobile layouts to landscape.
@override@JsonKey() final  bool gitDiffFocusAutoLandscape;
/// Whether to show a subtle badge when the current branch can push/pull.
@override@JsonKey() final  bool showRemoteGitStatusBadge;
/// Whether to show the connected Bridge name in the session list.
@override@JsonKey() final  bool showBridgeNameInSessionList;
/// Selected app icon preference for monthly Supporter perks.
@override@JsonKey() final  AppIconVariant selectedAppIcon;
/// Whether app icon switching is supported on the current platform.
@override@JsonKey() final  bool appIconSupported;
/// External terminal app configuration (preset or custom URL template).
@override@JsonKey() final  TerminalAppConfig terminalApp;
/// Visible tabs (and their order) in the new session sheet.
 final  List<NewSessionTab> _newSessionTabs;
/// Visible tabs (and their order) in the new session sheet.
@override@JsonKey() List<NewSessionTab> get newSessionTabs {
  if (_newSessionTabs is EqualUnmodifiableListView) return _newSessionTabs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_newSessionTabs);
}

/// Whether Codex usage limits are shown as remaining quota or used quota.
@override@JsonKey() final  UsageDisplayMode usageDisplayMode;
/// Whether new Codex sessions should be automatically named after the first turn.
@override@JsonKey() final  bool autoRenameCodexSessions;
/// Whether Max and Ultra appear in Codex Effort sliders when supported.
@override@JsonKey() final  bool showExtendedCodexEfforts;
/// Whether new Claude sessions should be automatically named after the first turn.
@override@JsonKey() final  bool autoRenameClaudeSessions;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsStateCopyWith<_SettingsState> get copyWith => __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettingsState&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.appLocaleId, appLocaleId) || other.appLocaleId == appLocaleId)&&(identical(other.speechLocaleId, speechLocaleId) || other.speechLocaleId == speechLocaleId)&&const DeepCollectionEquality().equals(other._fcmEnabledMachines, _fcmEnabledMachines)&&const DeepCollectionEquality().equals(other._fcmPrivacyMachines, _fcmPrivacyMachines)&&(identical(other.activeMachineId, activeMachineId) || other.activeMachineId == activeMachineId)&&(identical(other.fcmAvailable, fcmAvailable) || other.fcmAvailable == fcmAvailable)&&(identical(other.fcmSyncInProgress, fcmSyncInProgress) || other.fcmSyncInProgress == fcmSyncInProgress)&&(identical(other.fcmStatusKey, fcmStatusKey) || other.fcmStatusKey == fcmStatusKey)&&(identical(other.shorebirdTrack, shorebirdTrack) || other.shorebirdTrack == shorebirdTrack)&&(identical(other.indentSize, indentSize) || other.indentSize == indentSize)&&(identical(other.textScale, textScale) || other.textScale == textScale)&&(identical(other.codeFontSize, codeFontSize) || other.codeFontSize == codeFontSize)&&(identical(other.codeFontFamily, codeFontFamily) || other.codeFontFamily == codeFontFamily)&&(identical(other.hideVoiceInput, hideVoiceInput) || other.hideVoiceInput == hideVoiceInput)&&(identical(other.imagePasteShortcut, imagePasteShortcut) || other.imagePasteShortcut == imagePasteShortcut)&&(identical(other.gitDiffInteractionMode, gitDiffInteractionMode) || other.gitDiffInteractionMode == gitDiffInteractionMode)&&(identical(other.gitDiffFocusAutoLandscape, gitDiffFocusAutoLandscape) || other.gitDiffFocusAutoLandscape == gitDiffFocusAutoLandscape)&&(identical(other.showRemoteGitStatusBadge, showRemoteGitStatusBadge) || other.showRemoteGitStatusBadge == showRemoteGitStatusBadge)&&(identical(other.showBridgeNameInSessionList, showBridgeNameInSessionList) || other.showBridgeNameInSessionList == showBridgeNameInSessionList)&&(identical(other.selectedAppIcon, selectedAppIcon) || other.selectedAppIcon == selectedAppIcon)&&(identical(other.appIconSupported, appIconSupported) || other.appIconSupported == appIconSupported)&&(identical(other.terminalApp, terminalApp) || other.terminalApp == terminalApp)&&const DeepCollectionEquality().equals(other._newSessionTabs, _newSessionTabs)&&(identical(other.usageDisplayMode, usageDisplayMode) || other.usageDisplayMode == usageDisplayMode)&&(identical(other.autoRenameCodexSessions, autoRenameCodexSessions) || other.autoRenameCodexSessions == autoRenameCodexSessions)&&(identical(other.showExtendedCodexEfforts, showExtendedCodexEfforts) || other.showExtendedCodexEfforts == showExtendedCodexEfforts)&&(identical(other.autoRenameClaudeSessions, autoRenameClaudeSessions) || other.autoRenameClaudeSessions == autoRenameClaudeSessions));
}


@override
int get hashCode => Object.hashAll([runtimeType,themeMode,appLocaleId,speechLocaleId,const DeepCollectionEquality().hash(_fcmEnabledMachines),const DeepCollectionEquality().hash(_fcmPrivacyMachines),activeMachineId,fcmAvailable,fcmSyncInProgress,fcmStatusKey,shorebirdTrack,indentSize,textScale,codeFontSize,codeFontFamily,hideVoiceInput,imagePasteShortcut,gitDiffInteractionMode,gitDiffFocusAutoLandscape,showRemoteGitStatusBadge,showBridgeNameInSessionList,selectedAppIcon,appIconSupported,terminalApp,const DeepCollectionEquality().hash(_newSessionTabs),usageDisplayMode,autoRenameCodexSessions,showExtendedCodexEfforts,autoRenameClaudeSessions]);

@override
String toString() {
  return 'SettingsState(themeMode: $themeMode, appLocaleId: $appLocaleId, speechLocaleId: $speechLocaleId, fcmEnabledMachines: $fcmEnabledMachines, fcmPrivacyMachines: $fcmPrivacyMachines, activeMachineId: $activeMachineId, fcmAvailable: $fcmAvailable, fcmSyncInProgress: $fcmSyncInProgress, fcmStatusKey: $fcmStatusKey, shorebirdTrack: $shorebirdTrack, indentSize: $indentSize, textScale: $textScale, codeFontSize: $codeFontSize, codeFontFamily: $codeFontFamily, hideVoiceInput: $hideVoiceInput, imagePasteShortcut: $imagePasteShortcut, gitDiffInteractionMode: $gitDiffInteractionMode, gitDiffFocusAutoLandscape: $gitDiffFocusAutoLandscape, showRemoteGitStatusBadge: $showRemoteGitStatusBadge, showBridgeNameInSessionList: $showBridgeNameInSessionList, selectedAppIcon: $selectedAppIcon, appIconSupported: $appIconSupported, terminalApp: $terminalApp, newSessionTabs: $newSessionTabs, usageDisplayMode: $usageDisplayMode, autoRenameCodexSessions: $autoRenameCodexSessions, showExtendedCodexEfforts: $showExtendedCodexEfforts, autoRenameClaudeSessions: $autoRenameClaudeSessions)';
}


}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res> implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(_SettingsState value, $Res Function(_SettingsState) _then) = __$SettingsStateCopyWithImpl;
@override @useResult
$Res call({
 ThemeMode themeMode, String appLocaleId, String speechLocaleId, Set<String> fcmEnabledMachines, Set<String> fcmPrivacyMachines, String? activeMachineId, bool fcmAvailable, bool fcmSyncInProgress, FcmStatusKey? fcmStatusKey, String shorebirdTrack, int indentSize, double textScale, double codeFontSize, CodeFontFamily codeFontFamily, bool hideVoiceInput, ImagePasteShortcut imagePasteShortcut, GitDiffInteractionMode gitDiffInteractionMode, bool gitDiffFocusAutoLandscape, bool showRemoteGitStatusBadge, bool showBridgeNameInSessionList, AppIconVariant selectedAppIcon, bool appIconSupported, TerminalAppConfig terminalApp, List<NewSessionTab> newSessionTabs, UsageDisplayMode usageDisplayMode, bool autoRenameCodexSessions, bool showExtendedCodexEfforts, bool autoRenameClaudeSessions
});




}
/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

/// Create a copy of SettingsState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? themeMode = null,Object? appLocaleId = null,Object? speechLocaleId = null,Object? fcmEnabledMachines = null,Object? fcmPrivacyMachines = null,Object? activeMachineId = freezed,Object? fcmAvailable = null,Object? fcmSyncInProgress = null,Object? fcmStatusKey = freezed,Object? shorebirdTrack = null,Object? indentSize = null,Object? textScale = null,Object? codeFontSize = null,Object? codeFontFamily = null,Object? hideVoiceInput = null,Object? imagePasteShortcut = null,Object? gitDiffInteractionMode = null,Object? gitDiffFocusAutoLandscape = null,Object? showRemoteGitStatusBadge = null,Object? showBridgeNameInSessionList = null,Object? selectedAppIcon = null,Object? appIconSupported = null,Object? terminalApp = null,Object? newSessionTabs = null,Object? usageDisplayMode = null,Object? autoRenameCodexSessions = null,Object? showExtendedCodexEfforts = null,Object? autoRenameClaudeSessions = null,}) {
  return _then(_SettingsState(
themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as ThemeMode,appLocaleId: null == appLocaleId ? _self.appLocaleId : appLocaleId // ignore: cast_nullable_to_non_nullable
as String,speechLocaleId: null == speechLocaleId ? _self.speechLocaleId : speechLocaleId // ignore: cast_nullable_to_non_nullable
as String,fcmEnabledMachines: null == fcmEnabledMachines ? _self._fcmEnabledMachines : fcmEnabledMachines // ignore: cast_nullable_to_non_nullable
as Set<String>,fcmPrivacyMachines: null == fcmPrivacyMachines ? _self._fcmPrivacyMachines : fcmPrivacyMachines // ignore: cast_nullable_to_non_nullable
as Set<String>,activeMachineId: freezed == activeMachineId ? _self.activeMachineId : activeMachineId // ignore: cast_nullable_to_non_nullable
as String?,fcmAvailable: null == fcmAvailable ? _self.fcmAvailable : fcmAvailable // ignore: cast_nullable_to_non_nullable
as bool,fcmSyncInProgress: null == fcmSyncInProgress ? _self.fcmSyncInProgress : fcmSyncInProgress // ignore: cast_nullable_to_non_nullable
as bool,fcmStatusKey: freezed == fcmStatusKey ? _self.fcmStatusKey : fcmStatusKey // ignore: cast_nullable_to_non_nullable
as FcmStatusKey?,shorebirdTrack: null == shorebirdTrack ? _self.shorebirdTrack : shorebirdTrack // ignore: cast_nullable_to_non_nullable
as String,indentSize: null == indentSize ? _self.indentSize : indentSize // ignore: cast_nullable_to_non_nullable
as int,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as double,codeFontSize: null == codeFontSize ? _self.codeFontSize : codeFontSize // ignore: cast_nullable_to_non_nullable
as double,codeFontFamily: null == codeFontFamily ? _self.codeFontFamily : codeFontFamily // ignore: cast_nullable_to_non_nullable
as CodeFontFamily,hideVoiceInput: null == hideVoiceInput ? _self.hideVoiceInput : hideVoiceInput // ignore: cast_nullable_to_non_nullable
as bool,imagePasteShortcut: null == imagePasteShortcut ? _self.imagePasteShortcut : imagePasteShortcut // ignore: cast_nullable_to_non_nullable
as ImagePasteShortcut,gitDiffInteractionMode: null == gitDiffInteractionMode ? _self.gitDiffInteractionMode : gitDiffInteractionMode // ignore: cast_nullable_to_non_nullable
as GitDiffInteractionMode,gitDiffFocusAutoLandscape: null == gitDiffFocusAutoLandscape ? _self.gitDiffFocusAutoLandscape : gitDiffFocusAutoLandscape // ignore: cast_nullable_to_non_nullable
as bool,showRemoteGitStatusBadge: null == showRemoteGitStatusBadge ? _self.showRemoteGitStatusBadge : showRemoteGitStatusBadge // ignore: cast_nullable_to_non_nullable
as bool,showBridgeNameInSessionList: null == showBridgeNameInSessionList ? _self.showBridgeNameInSessionList : showBridgeNameInSessionList // ignore: cast_nullable_to_non_nullable
as bool,selectedAppIcon: null == selectedAppIcon ? _self.selectedAppIcon : selectedAppIcon // ignore: cast_nullable_to_non_nullable
as AppIconVariant,appIconSupported: null == appIconSupported ? _self.appIconSupported : appIconSupported // ignore: cast_nullable_to_non_nullable
as bool,terminalApp: null == terminalApp ? _self.terminalApp : terminalApp // ignore: cast_nullable_to_non_nullable
as TerminalAppConfig,newSessionTabs: null == newSessionTabs ? _self._newSessionTabs : newSessionTabs // ignore: cast_nullable_to_non_nullable
as List<NewSessionTab>,usageDisplayMode: null == usageDisplayMode ? _self.usageDisplayMode : usageDisplayMode // ignore: cast_nullable_to_non_nullable
as UsageDisplayMode,autoRenameCodexSessions: null == autoRenameCodexSessions ? _self.autoRenameCodexSessions : autoRenameCodexSessions // ignore: cast_nullable_to_non_nullable
as bool,showExtendedCodexEfforts: null == showExtendedCodexEfforts ? _self.showExtendedCodexEfforts : showExtendedCodexEfforts // ignore: cast_nullable_to_non_nullable
as bool,autoRenameClaudeSessions: null == autoRenameClaudeSessions ? _self.autoRenameClaudeSessions : autoRenameClaudeSessions // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
