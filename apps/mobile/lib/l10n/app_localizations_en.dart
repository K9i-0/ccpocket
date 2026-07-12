// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CC Pocket';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get removeProjectTitle => 'Remove Project';

  @override
  String removeProjectConfirm(Object name) {
    return 'Remove \"$name\" from recent projects?';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renameSession => 'Rename Session';

  @override
  String get sessionNameHint => 'Session name';

  @override
  String get clearName => 'Clear name';

  @override
  String get connect => 'Connect';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get lineCopied => 'Line copied';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get send => 'Send';

  @override
  String get settings => 'Settings';

  @override
  String get gallery => 'Gallery';

  @override
  String get git => 'Git';

  @override
  String get explorer => 'Explorer';

  @override
  String get gitUnavailableTip =>
      'Git not detected — Git features are unavailable';

  @override
  String get gitUnavailableTitle => 'Git Not Available';

  @override
  String get gitUnavailableHint =>
      'Git features are not available for this project';

  @override
  String get autoModeFallbackDefaultTip =>
      'Auto mode is not available in this environment, so Default mode was selected';

  @override
  String galleryWithCount(int count) {
    return 'Gallery ($count)';
  }

  @override
  String get disconnect => 'Disconnect';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String get skip => 'Skip';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get all => 'All';

  @override
  String get none => 'None';

  @override
  String get dismissKeyboard => 'Dismiss keyboard';

  @override
  String get serverUnreachable => 'Server Unreachable';

  @override
  String get serverUnreachableBody => 'Could not reach the Bridge server at:';

  @override
  String get setupSteps => 'Setup Steps:';

  @override
  String get setupStep1Title => 'Start the Bridge server';

  @override
  String get setupStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get setupStep2Title => 'For persistent startup, register as service';

  @override
  String get setupStep2Command => 'npx --yes @ccpocket/bridge@latest setup';

  @override
  String get setupNetworkHint =>
      'Make sure both devices are on the same network (or use Tailscale).';

  @override
  String get connectAnyway => 'Connect Anyway';

  @override
  String get stopSession => 'Stop Session';

  @override
  String get stopSessionConfirm =>
      'Stop this session? The Claude process will be terminated.';

  @override
  String get startNewWithSameSettings => 'Start New with Same Settings';

  @override
  String get copyResumeCommand => 'Copy Resume Command';

  @override
  String get copyResumeCommandSubtitle => 'Hand off to macOS / Linux';

  @override
  String get resumeCommandCopied => 'Resume command copied';

  @override
  String get editSettingsThenStart => 'Edit Settings Then Start';

  @override
  String get serverRequiresApiKey => 'This server requires an API key';

  @override
  String get bridgeServerUpdated => 'Bridge Server updated';

  @override
  String get bridgeUpdateStarted =>
      'Updating Bridge. Closing this connection and returning to the machine list.';

  @override
  String get bridgeUpdateReconnectHint =>
      'Bridge Server updated. Reconnect from the machine list.';

  @override
  String get failedToUpdateServer => 'Failed to update server';

  @override
  String get bridgeServerStarted => 'Bridge Server started';

  @override
  String get failedToStartServer => 'Failed to start server';

  @override
  String get bridgeServerStopped => 'Bridge Server stopped';

  @override
  String get failedToStopServer => 'Failed to stop server';

  @override
  String get sshPassword => 'SSH Password';

  @override
  String sshPasswordPrompt(String machineName) {
    return 'Enter SSH password for $machineName';
  }

  @override
  String get password => 'Password';

  @override
  String get machineEditAddTitle => 'Add Machine';

  @override
  String get machineEditEditTitle => 'Edit Machine';

  @override
  String get machineEditDismissKeyboardTooltip => 'Dismiss keyboard';

  @override
  String get machineEditBasicInfo => 'Basic Info';

  @override
  String get machineEditName => 'Name';

  @override
  String get machineEditNameHint => 'Home Mac';

  @override
  String get machineEditHostLabel => 'Host (IP or hostname)';

  @override
  String get machineEditHostHint => '100.64.1.2';

  @override
  String get machineEditPort => 'Port';

  @override
  String get machineEditBridgePortHint => '8765';

  @override
  String get machineEditApiKey => 'API Key';

  @override
  String get machineEditOptional => 'Optional';

  @override
  String get machineEditUseSecureConnection => 'Use secure connection';

  @override
  String get machineEditUseSecureConnectionSubtitle =>
      'Connect with WSS and use HTTPS for health checks';

  @override
  String get machineEditSshConfiguration => 'SSH Configuration';

  @override
  String get machineEditEnableSshRemoteStartup => 'Enable SSH remote startup';

  @override
  String get machineEditEnableSshRemoteStartupSubtitle =>
      'Remotely start Bridge Server when offline';

  @override
  String get machineEditSshUsername => 'SSH Username';

  @override
  String get machineEditSshUsernameHint => 'myuser';

  @override
  String get machineEditSshPort => 'SSH Port';

  @override
  String get machineEditSshPortHint => '22';

  @override
  String get machineEditTargetAuthentication => 'Target Authentication';

  @override
  String get machineEditPrivateKey => 'Private Key';

  @override
  String get machineEditSshPrivateKeyPem => 'SSH Private Key (PEM)';

  @override
  String get machineEditOpenSshPrivateKeyHint =>
      '-----BEGIN OPENSSH PRIVATE KEY-----';

  @override
  String get machineEditSavedPrivateKeyIndicator =>
      'Private key is saved. Enter a new one to replace it.';

  @override
  String get machineEditUseSshJumpHost => 'Use SSH jump host';

  @override
  String get machineEditUseSshJumpHostSubtitle =>
      'Connect through a bastion or intermediate SSH host';

  @override
  String get machineEditSshJumpHost => 'SSH Jump Host';

  @override
  String get machineEditJumpHost => 'Jump Host';

  @override
  String get machineEditJumpHostHint => 'bastion.example.com';

  @override
  String get machineEditJumpPort => 'Jump Port';

  @override
  String get machineEditJumpUsername => 'Jump Username';

  @override
  String get machineEditJumpUsernameHint => 'Defaults to SSH Username';

  @override
  String get machineEditJumpHostAuthentication => 'Jump Host Authentication';

  @override
  String get machineEditJumpHostAuthenticationSubtitle =>
      'Leave blank to reuse target SSH credentials';

  @override
  String get machineEditJumpPassword => 'Jump Password';

  @override
  String get machineEditSavedJumpHostPasswordIndicator =>
      'Jump host password is saved. Enter a new one to replace it.';

  @override
  String get machineEditJumpPrivateKeyPem => 'Jump Private Key (PEM)';

  @override
  String get machineEditSavedJumpHostPrivateKeyIndicator =>
      'Jump host private key is saved. Enter a new one to replace it.';

  @override
  String get machineEditTesting => 'Testing...';

  @override
  String get machineEditTestConnection => 'Test Connection';

  @override
  String get machineEditConnectionSuccessful => 'Connection successful!';

  @override
  String get machineEditFillSshCredentials => 'Please fill in SSH credentials';

  @override
  String get machineEditAddAndConnect => 'Add & Connect';

  @override
  String get deleteMachine => 'Delete Machine';

  @override
  String deleteMachineConfirm(String displayName) {
    return 'Delete \"$displayName\"? This will remove all saved credentials.';
  }

  @override
  String get connectToBridgeServer => 'Connect to Bridge Server';

  @override
  String get orConnectManually => 'or connect manually';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'ws://<host-ip>:8765';

  @override
  String get apiKeyOptional => 'API Key (optional)';

  @override
  String get apiKeyHint => 'Leave empty if no auth';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get setupGuide => 'Setup Guide';

  @override
  String get showSessions => 'Show left pane';

  @override
  String get hideSessions => 'Hide left pane';

  @override
  String get workspaceLandingSelectSessionMessage =>
      'Select a session in the left pane.';

  @override
  String get workspaceLandingCreateSessionMessage =>
      'Create a session from New in the left pane.';

  @override
  String get workspaceLandingDisconnectedMessage =>
      'Bridge is not connected. Connect from the left pane, or open Setup Guide to configure a machine.';

  @override
  String get running => 'Running';

  @override
  String get recentSessions => 'Recent Sessions';

  @override
  String get search => 'Search';

  @override
  String get searchSessions => 'Search sessions...';

  @override
  String get sessionDisplayModeFirst => 'First';

  @override
  String get sessionDisplayModeLast => 'Last';

  @override
  String get sessionDisplayModeSummary => 'Summary';

  @override
  String get allAiTools => 'All AI Tools';

  @override
  String get allProjects => 'All Projects';

  @override
  String get named => 'Named';

  @override
  String get machines => 'Machines';

  @override
  String get refreshStatus => 'Refresh status';

  @override
  String get add => 'Add';

  @override
  String get noSavedMachinesDescription =>
      'No saved machines.\nAdd one to quickly connect or remotely start the Bridge Server.';

  @override
  String get readyToStart => 'Ready to start';

  @override
  String get readyToStartDescription =>
      'Press the + button to create a new session and start coding with Claude.';

  @override
  String get newSession => 'New Session';

  @override
  String get neverConnected => 'Never connected';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String get favorite => 'Favorite';

  @override
  String get updateBridge => 'Update Bridge';

  @override
  String get bridgeIsUpToDate => 'Bridge is up to date';

  @override
  String get bridgeUpdateAvailable => 'Update available';

  @override
  String get bridgeUpdateRequiresSetup =>
      'Requires SSH and Bridge auto-start setup';

  @override
  String get bridgeVersionUnknown => 'Bridge version unknown';

  @override
  String bridgeVersionCurrentExpected(String current, String expected) {
    return 'Current v$current, recommended v$expected+';
  }

  @override
  String bridgeVersionCurrentLatest(String current, String latest) {
    return 'Current v$current, latest v$latest';
  }

  @override
  String get bridgeLatestVersionChecking => 'Checking latest Bridge version...';

  @override
  String get bridgeLatestVersionUnavailable =>
      'Could not check latest Bridge version';

  @override
  String get bridgeLatestVersionRetry => 'Retry latest version check';

  @override
  String get bridgeUpdateSetupTitle => 'Prepare Bridge updates';

  @override
  String get bridgeUpdateSetupDescription =>
      'To update Bridge from this app, the machine needs SSH access and Bridge auto-start setup.';

  @override
  String get bridgeUpdateSetupEnableSsh =>
      'Enable SSH in the Bridge connection settings.';

  @override
  String get bridgeUpdateSetupRunCommand =>
      'Run the setup command on the target machine.';

  @override
  String get bridgeUpdateSetupCommand => 'npx @ccpocket/bridge@latest setup';

  @override
  String get stopServer => 'Stop Server';

  @override
  String get update => 'Update';

  @override
  String get download => 'Download';

  @override
  String appUpdateAvailable(String version) {
    return 'v$version is available';
  }

  @override
  String get macosNativeAppBannerTitle => 'Use the native macOS app';

  @override
  String get macosNativeAppBannerSubtitle =>
      'CC Pocket is optimized for macOS in the native desktop app. Install it from GitHub Releases.';

  @override
  String get openGitHubReleases => 'Open GitHub Releases';

  @override
  String get macosNativeAppSettingsTitle => 'macOS native app';

  @override
  String get macosNativeAppSettingsSubtitle =>
      'Recommended on Mac because it is optimized for macOS.';

  @override
  String get supportBannerTitle => 'CC Pocket has been useful';

  @override
  String get supportBannerSubtitle =>
      'Support can help keep development moving.';

  @override
  String get supportBannerAction => 'View support';

  @override
  String get offline => 'Offline';

  @override
  String get unreachable => 'Unreachable';

  @override
  String get checking => 'Checking...';

  @override
  String get recentProjects => 'Recent Projects';

  @override
  String get orEnterPath => 'or enter path';

  @override
  String get projectPath => 'Project Path';

  @override
  String get projectPathHint => '/path/to/your/project';

  @override
  String get permission => 'Permission';

  @override
  String get approval => 'Approval';

  @override
  String get restart => 'Restart';

  @override
  String get worktree => 'Worktree';

  @override
  String get advanced => 'Advanced';

  @override
  String get modelOptional => 'Model (optional)';

  @override
  String get effort => 'Effort';

  @override
  String get defaultLabel => 'Default';

  @override
  String get codexProfilePrecedenceNote =>
      'If the selected profile includes the same setting, it takes precedence over the options below.';

  @override
  String get maxTurns => 'Max Turns';

  @override
  String get maxTurnsHint => 'e.g. 8';

  @override
  String get maxTurnsError => 'Must be an integer > 0';

  @override
  String get maxBudgetUsd => 'Max Budget (USD)';

  @override
  String get maxBudgetHint => 'e.g. 1.00';

  @override
  String get maxBudgetError => 'Must be a number >= 0';

  @override
  String get fallbackModel => 'Fallback Model';

  @override
  String get forkSessionOnResume => 'Fork Session on Resume';

  @override
  String get persistSessionHistory => 'Persist Session History';

  @override
  String get model => 'Model';

  @override
  String get sandbox => 'Sandbox';

  @override
  String get reasoning => 'Reasoning';

  @override
  String get webSearch => 'Web Search';

  @override
  String get networkAccess => 'Network Access';

  @override
  String get additionalWritableRootsTitle =>
      'Additional accessible directories';

  @override
  String get additionalWritableRootsDescription =>
      'These are added on top of writable_roots from Codex config.toml for this session.';

  @override
  String get additionalWritableRootsTooltip =>
      'Use this when this Codex session needs to read or edit files from another project in addition to the selected project.';

  @override
  String get additionalWritableRootsSuggestions => 'Recent projects';

  @override
  String get addDirectory => 'Add directory';

  @override
  String get directoryPath => 'Directory path';

  @override
  String get worktreeNew => 'New';

  @override
  String worktreeExisting(int count) {
    return 'Existing ($count)';
  }

  @override
  String get branchOptional => 'Branch (optional)';

  @override
  String get branchHint => 'feature/...';

  @override
  String get noExistingWorktrees => 'No existing worktrees';

  @override
  String get planApprovalSummary =>
      'Review the plan above and approve or continue planning';

  @override
  String get planApprovalSummaryCard =>
      'Review the plan and approve or continue planning';

  @override
  String get toolApprovalSummary => 'Tool execution requires approval';

  @override
  String get planApproval => 'Plan Approval';

  @override
  String get approvalRequired => 'Approval Required';

  @override
  String get viewEditPlan => 'View Plan';

  @override
  String get keepPlanning => 'Keep Planning';

  @override
  String get keepPlanningHint => 'What should be changed...';

  @override
  String get sendFeedbackKeepPlanning => 'Send feedback & keep planning';

  @override
  String get acceptAndClear => 'Accept & Clear';

  @override
  String get acceptPlan => 'Accept Plan';

  @override
  String get continuePlanning => 'Keep Planning';

  @override
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String get always => 'Always';

  @override
  String get approveOnce => 'Allow Once';

  @override
  String get approveForSession => 'Allow for This Session';

  @override
  String get approveAlways => 'Permanently';

  @override
  String get approveAlwaysSub => 'allow';

  @override
  String get approveSessionMain => 'This Session';

  @override
  String get approveSessionSub => 'allow';

  @override
  String get permissionDefaultDescription => 'Standard permission prompts';

  @override
  String get permissionAutoDescription =>
      'Let Claude auto-handle approvals with built-in safety checks';

  @override
  String get permissionAcceptEditsDescription => 'Auto-approve file edits';

  @override
  String get permissionPlanDescription =>
      'Analyze and plan before executing changes';

  @override
  String get permissionBypassDescription => 'Run without most approval prompts';

  @override
  String get executionDefaultDescription => 'Standard permission prompts';

  @override
  String get executionAcceptEditsDescription => 'Auto-approve file edits';

  @override
  String get executionFullAccessDescription =>
      'Run without most approval prompts';

  @override
  String get codexPlanModeDescription =>
      'Draft a plan first, then wait for approval before executing';

  @override
  String get sandboxRestrictedDescription =>
      'Run commands in restricted environment';

  @override
  String get sandboxNativeDescription => 'Run commands natively';

  @override
  String get sandboxNativeCautionDescription =>
      'Run commands natively (CAUTION)';

  @override
  String get sheetSubtitleApproval =>
      'Controls which actions require your approval';

  @override
  String get sheetSubtitleSandboxCodex =>
      'Sandbox is on by default for safety. Disabling allows full system access.';

  @override
  String get sheetSubtitleSandboxClaude =>
      'Claude runs natively by default. Enabling sandbox restricts access.';

  @override
  String get sheetSubtitleModel =>
      'Different models vary in speed, capability, and cost.';

  @override
  String get sheetSubtitleEffort =>
      'Higher effort produces more thorough analysis but takes longer.';

  @override
  String get claudeEffortLowDesc => 'Faster responses, less thorough';

  @override
  String get claudeEffortMediumDesc => 'Balanced speed and quality';

  @override
  String get claudeEffortHighDesc => 'More thorough analysis';

  @override
  String get claudeEffortXHighDesc => 'Extended reasoning for complex work';

  @override
  String get claudeEffortMaxDesc => 'Most thorough, slowest';

  @override
  String get reasoningEffortNoneDesc => 'No reasoning';

  @override
  String get reasoningEffortMinimalDesc => 'Fastest, least analysis';

  @override
  String get reasoningEffortLowDesc => 'Faster responses, less thorough';

  @override
  String get reasoningEffortMediumDesc => 'Balanced speed and quality';

  @override
  String get reasoningEffortHighDesc => 'More thorough analysis';

  @override
  String get reasoningEffortXhighDesc => 'Most thorough, slowest';

  @override
  String get changePermissionModeTitle => 'Change Permission Mode';

  @override
  String changePermissionModeBody(String mode) {
    return 'Switching to $mode will restart the session. Your conversation will be preserved.';
  }

  @override
  String get changeExecutionModeTitle => 'Change Execution Mode';

  @override
  String changeExecutionModeBody(String mode) {
    return 'Switching to $mode will restart the session. Your conversation will be preserved.';
  }

  @override
  String get changeApprovalPolicyTitle => 'Change Approval Policy';

  @override
  String changeApprovalPolicyBody(String mode) {
    return 'Switching to $mode will restart the session. Your conversation will be preserved.';
  }

  @override
  String get codexApprovalUntrustedDescription =>
      'Auto-run only trusted commands; ask for everything else';

  @override
  String get codexApprovalOnRequestDescription =>
      'Ask only when the agent decides approval is needed';

  @override
  String get codexApprovalOnFailureDescription =>
      'Run without asking first; ask only when a command fails (Deprecated)';

  @override
  String get codexApprovalNeverDescription =>
      'Never ask for approval; failures are returned immediately';

  @override
  String get codexAutoReview => 'Auto Review';

  @override
  String get codexAutoReviewDescription =>
      'Let Codex review approval requests automatically';

  @override
  String get codexAutoReviewUnavailableDescription =>
      'Unavailable when approvals are disabled';

  @override
  String get enablePlanModeTitle => 'Enable Plan Mode';

  @override
  String get disablePlanModeTitle => 'Disable Plan Mode';

  @override
  String get enablePlanModeBody =>
      'Enabling Plan Mode will restart the session. Your conversation will be preserved.';

  @override
  String get disablePlanModeBody =>
      'Disabling Plan Mode will restart the session. Your conversation will be preserved.';

  @override
  String get changeSandboxModeTitle => 'Change Sandbox Mode';

  @override
  String changeSandboxModeBody(String mode) {
    return 'Switching to $mode will restart the session. Your conversation will be preserved.';
  }

  @override
  String get messagePlaceholder => 'Message Claude...';

  @override
  String get codexMessagePlaceholder => 'Message Codex...';

  @override
  String get queuedInputForReconnect => 'Queued for reconnect';

  @override
  String get queuedInputPendingDelivery => 'Pending delivery';

  @override
  String get queuedInputForNextTurn => 'Queued for next turn';

  @override
  String get sessionCardQueuedInput => 'Queued';

  @override
  String queuedInputImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '$count image',
    );
    return '$_temp0';
  }

  @override
  String get tooltipSteerQueuedMessage => 'Steer queued message';

  @override
  String get tooltipMoveQueuedMessageToInput => 'Move queued message to input';

  @override
  String get tooltipCancelQueuedMessage => 'Cancel queued message';

  @override
  String get reconnecting => 'Reconnecting...';

  @override
  String get reconnectingQueuedMessages =>
      'Reconnecting... queued messages will be sent automatically';

  @override
  String get disconnectedMessagesQueued =>
      'Disconnected - messages can be queued for reconnect';

  @override
  String get sessionQueuedForReconnect => 'Session queued for reconnect';

  @override
  String get resumeAlreadyQueued => 'Resume is already queued';

  @override
  String get resumeQueuedForReconnect => 'Resume queued for reconnect';

  @override
  String get pendingActionWillCreateOnReconnect =>
      'Will create when the bridge reconnects';

  @override
  String get pendingActionWillResumeOnReconnect =>
      'Will resume when the bridge reconnects';

  @override
  String get pendingActionStatus => 'Pending';

  @override
  String get tooltipCancelPendingAction => 'Cancel pending action';

  @override
  String get queuedLocally => 'Queued locally';

  @override
  String get offlinePendingNewSessionTitle => 'New session pending';

  @override
  String get offlinePendingResumeTitle => 'Resume pending';

  @override
  String diffLines(int count) {
    return '$count diff lines';
  }

  @override
  String changedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changed lines',
      one: '$count changed line',
    );
    return '$_temp0';
  }

  @override
  String hunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hunks',
      one: '$count hunk',
    );
    return '$_temp0';
  }

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '$count file',
    );
    return '$_temp0';
  }

  @override
  String get tapInterruptHoldStop => 'Tap: interrupt, Hold: stop';

  @override
  String get rewind => 'Rewind';

  @override
  String get rewindToHere => 'Rewind to here';

  @override
  String get rewindModeConversationAndCode => 'Restore conversation & code';

  @override
  String get rewindModeConversationOnly => 'Restore conversation only';

  @override
  String get rewindModeCodeOnly => 'Restore code only';

  @override
  String get rewindConfirmTitle => 'Confirm Rewind';

  @override
  String rewindConfirmBody(Object mode) {
    return 'Mode: $mode\n\nThis action cannot be undone. Proceed?';
  }

  @override
  String get rewindCannotRewindFiles => 'Cannot rewind files';

  @override
  String get codexRewindConfirmTitle => 'Rewind conversation?';

  @override
  String get codexRewindConfirmBody =>
      'Restore the chat to just before this message and put the message back in the composer. File changes stay untouched.';

  @override
  String get fork => 'Fork';

  @override
  String get forkConversation => 'Fork conversation';

  @override
  String get forkConversationTitle => 'Fork conversation?';

  @override
  String get forkConversationBody =>
      'Create a new Codex session from this response. The current session will remain unchanged.';

  @override
  String get forkTargetNotFound => 'Cannot find a user turn to fork from';

  @override
  String get tapToRetry => 'Tap to retry';

  @override
  String diffSummaryAddedRemoved(int added, int removed) {
    return '+$added/-$removed lines';
  }

  @override
  String lineCountSummary(int count) {
    return '$count lines';
  }

  @override
  String get toolResult => 'Tool Result';

  @override
  String get answered => 'Answered';

  @override
  String agentIsAsking(Object agent) {
    return '$agent is asking';
  }

  @override
  String get submitAllAnswers => 'Submit All Answers';

  @override
  String submitWithCount(int count) {
    return 'Submit ($count selected)';
  }

  @override
  String get selectOptionsToSubmit => 'Select options to submit';

  @override
  String get typeYourAnswer => 'Type your answer...';

  @override
  String get orTypeCustomAnswer => 'Or type a custom answer...';

  @override
  String get otherAnswer => 'Other answer...';

  @override
  String get selectAllThatApply => 'Select all that apply';

  @override
  String get noScreenshotsYet => 'No screenshots yet';

  @override
  String get screenshotButtonHint =>
      'Use the screenshot button in the chat toolbar to capture screenshots.';

  @override
  String get screenshotsWillAppearHere =>
      'Screenshots from Claude sessions will appear here.';

  @override
  String allWithCount(int count) {
    return 'All ($count)';
  }

  @override
  String get noImages => 'No images';

  @override
  String get failedToDeleteImage => 'Failed to delete image';

  @override
  String get failedToDownloadImage => 'Failed to download image';

  @override
  String get failedToShareImage => 'Failed to share image';

  @override
  String get deleteScreenshot => 'Delete screenshot?';

  @override
  String get cannotBeUndone => 'This action cannot be undone.';

  @override
  String get changes => 'Changes';

  @override
  String get refresh => 'Refresh';

  @override
  String get diffCompareSideBySide => 'Side by Side';

  @override
  String get diffCompareSlider => 'Slider';

  @override
  String get diffCompareOverlay => 'Overlay';

  @override
  String get diffCompareToggle => 'Toggle';

  @override
  String get diffBefore => 'Before';

  @override
  String get diffAfter => 'After';

  @override
  String get diffNewFile => 'New file';

  @override
  String get diffDeleted => 'Deleted';

  @override
  String get diffNoImage => 'No image';

  @override
  String get noChanges => 'No changes';

  @override
  String get showAll => 'Show all';

  @override
  String get setupGuideTitle => 'Setup Guide';

  @override
  String get guideAboutTitle => 'What is CC Pocket?';

  @override
  String get guideAboutDescription =>
      'A mobile client that lets you use Codex and Claude from your smartphone through the Bridge Server.';

  @override
  String get guideAboutSdkNoteTitle => 'About Claude Agent SDK';

  @override
  String get guideAboutSdkNoteBody =>
      'It is the library version of Claude Code. It can share history and project config files such as .claude and CLAUDE.md, and the approval flow feels mostly the same.';

  @override
  String get guideAboutDiagramTitle => 'How it works';

  @override
  String get guideAboutDiagramPhone => 'iPhone';

  @override
  String get guideAboutDiagramBridge => 'Bridge Server';

  @override
  String get guideAboutDiagramClaude => 'Codex CLI\n/ Claude Agent SDK';

  @override
  String get guideAboutDiagramCaption =>
      'The Bridge Server on your PC connects to Codex CLI and Claude Agent SDK,\nthen your phone connects to the Bridge.';

  @override
  String get guideBridgeTitle => 'Bridge Server\nSetup';

  @override
  String get guideBridgeDescription =>
      'Start the Bridge Server on your PC. If you want to use Claude, set ANTHROPIC_API_KEY too.';

  @override
  String get guideBridgePrerequisites => 'Prerequisites';

  @override
  String get guideBridgePrereq1 => 'Mac / PC with Node.js installed';

  @override
  String get guideBridgePrereq2 => 'If you use Claude, set ANTHROPIC_API_KEY';

  @override
  String get guideBridgePrereq3 =>
      'If you use Codex, complete Codex authentication';

  @override
  String get guideBridgeStep1 => 'Run with npx (recommended)';

  @override
  String get guideBridgeStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get guideBridgeStep2 => 'Or install globally';

  @override
  String get guideBridgeStep2Command =>
      'npm install -g @ccpocket/bridge\nccpocket-bridge';

  @override
  String get guideBridgeQrNote =>
      'A QR code will appear in the terminal when started';

  @override
  String get guideConnectionTitle => 'Connection Methods';

  @override
  String get guideConnectionDescription =>
      'If on the same Wi-Fi network, you can connect right away.';

  @override
  String get guideConnectionQr => 'QR Code Scan';

  @override
  String get guideConnectionQrDescription =>
      'Just scan the QR code displayed in the terminal. The easiest method.';

  @override
  String get guideConnectionMdns => 'Auto-discovery (mDNS)';

  @override
  String get guideConnectionMdnsDescription =>
      'Automatically finds Bridge Servers on the same LAN.';

  @override
  String get guideConnectionManual => 'Manual Entry';

  @override
  String get guideConnectionManualDescription =>
      'Enter directly in the format ws://<IP address>:8765.';

  @override
  String get guideConnectionRecommended => 'Recommended';

  @override
  String get guideTailscaleTitle => 'Remote Access';

  @override
  String get guideTailscaleDescription =>
      'To use from outside your home, Tailscale (a VPN) enables secure remote connections.';

  @override
  String get guideTailscaleStep1 => 'Install Tailscale on both Mac and iPhone';

  @override
  String get guideTailscaleStep2 => 'Log in with the same account';

  @override
  String get guideTailscaleStep3 =>
      'Use Tailscale IP for Bridge URL\n(e.g. ws://100.x.x.x:8765)';

  @override
  String get guideTailscaleWebsite => 'Tailscale Website';

  @override
  String get guideTailscaleWebsiteHint =>
      'Visit the official site for detailed setup instructions.';

  @override
  String get guideLaunchdTitle => 'Auto-start Setup';

  @override
  String get guideLaunchdDescription =>
      'If manually starting the Bridge Server is tedious, you can configure it to start automatically when your machine boots.';

  @override
  String get guideLaunchdCommand => 'Setup Command';

  @override
  String get guideLaunchdCommandValue =>
      'npx --yes @ccpocket/bridge@latest setup';

  @override
  String get guideLaunchdRecommendation =>
      'We recommend verifying with manual startup first, then registering as a service once stable.';

  @override
  String get guideAutostartMacDescription =>
      'Registers with launchd. Shell environment (nvm, Homebrew, etc.) is inherited automatically.';

  @override
  String get guideAutostartLinuxDescription =>
      'Creates a systemd user service. Works with Raspberry Pi and other Linux hosts.';

  @override
  String get guideReadyTitle => 'All Set!';

  @override
  String get guideReadyDescription =>
      'Start the Bridge Server and\nscan the QR code to\nget started.';

  @override
  String get guideReadyStart => 'Let\'s Get Started';

  @override
  String get guideReadyHint =>
      'You can revisit this guide anytime from Settings';

  @override
  String get creatingSession => 'Creating session...';

  @override
  String get copyForAgent => 'Copy for Agent';

  @override
  String get messageHistory => 'Message History';

  @override
  String get viewChanges => 'View Changes';

  @override
  String get screenshot => 'Screenshot';

  @override
  String get debug => 'Debug';

  @override
  String get logs => 'Logs';

  @override
  String get viewApplicationLogs => 'View application logs';

  @override
  String get mockPreview => 'Mock Preview';

  @override
  String get viewMockChatScenarios => 'View mock chat scenarios';

  @override
  String get updateTrack => 'Update Track';

  @override
  String get updateTrackDescription => 'Restart app after changing to apply';

  @override
  String get updateTrackStable => 'Stable';

  @override
  String get updateTrackStaging => 'Staging';

  @override
  String get updateDownloaded => 'Update downloaded. Restart app to apply.';

  @override
  String get promptHistory => 'Prompt History';

  @override
  String get frequent => 'Frequent';

  @override
  String get recent => 'Recent';

  @override
  String get searchHint => 'Search...';

  @override
  String get noMatchingPrompts => 'No matching prompts';

  @override
  String get noPromptHistoryYet => 'No prompt history yet';

  @override
  String get promptHistoryFilters => 'Filters';

  @override
  String get promptHistoryFilterThisDevice => 'Used on this device';

  @override
  String get promptHistoryFilterThisProject => 'Open project';

  @override
  String get promptHistoryFilterThisBridge => 'Connected Bridge';

  @override
  String get promptHistoryFilterFavorites => 'Favorites';

  @override
  String get promptHistoryFilterCommands => 'Commands and skills';

  @override
  String get promptHistoryOpenProjectEmptyHint =>
      'Open project filtering only works for history recorded by the newer app.';

  @override
  String get promptHistorySectionTitle => 'Prompt History';

  @override
  String get promptHistorySyncTitle => 'Sync prompt history';

  @override
  String get promptHistoryReplaceTitle =>
      'Overwrite Bridge with old-format history';

  @override
  String get promptHistoryReplaceSubtitle =>
      'Old-format history was managed by the app. The new format is managed by Bridge. This is usually unnecessary if you already migrated on your main device. Use it when a secondary device accidentally initialized Bridge history; it overwrites the connected Bridge history with this device\'s old-format history.';

  @override
  String get promptHistoryReplaceConfirmAction => 'Overwrite';

  @override
  String get promptHistoryReplaceDismissAction => 'Already migrated';

  @override
  String get promptHistoryNotSyncedYet => 'Not synced yet';

  @override
  String promptHistoryLatestSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String promptHistorySyncedBridges(int count) {
    return 'Synced Bridges: $count';
  }

  @override
  String promptHistorySyncSummaryWithFailures(int synced, int failed) {
    return '$synced synced, $failed failed';
  }

  @override
  String promptHistoryBridgeId(String id) {
    return 'Bridge ID: $id';
  }

  @override
  String promptHistoryOtherBridgeRegistrations(String registrations) {
    return 'Other registrations: $registrations';
  }

  @override
  String get promptHistoryNoSyncTime => 'No sync time';

  @override
  String get approvalQueue => 'Approval Queue';

  @override
  String get resetQueue => 'Reset queue';

  @override
  String get swipeSkip => 'SKIP';

  @override
  String get swipeSend => 'SEND';

  @override
  String get swipeDismiss => 'DISMISS';

  @override
  String get swipeApprove => 'APPROVE';

  @override
  String get swipeReject => 'REJECT';

  @override
  String get allClear => 'All Clear!';

  @override
  String itemsProcessed(int count) {
    return '$count items processed';
  }

  @override
  String bestStreak(int count) {
    return 'Best streak: $count';
  }

  @override
  String get tryAgain => 'Try Again';

  @override
  String get waitingForTasks => 'Waiting for tasks';

  @override
  String get agentReadyForPrompt => 'The agent is ready for your next prompt.';

  @override
  String get backToSessions => 'Back to Sessions';

  @override
  String get working => 'Working...';

  @override
  String get waitingForApprovalRequests =>
      'Waiting for approval requests from the agent.';

  @override
  String get noActiveSessions => 'No active sessions';

  @override
  String get startSessionToBegin =>
      'Start a session to begin receiving approval requests.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionGeneral => 'GENERAL';

  @override
  String get sectionConnectionAccounts => 'Connection & Accounts';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get sectionSupport => 'Support';

  @override
  String get sectionEditor => 'EDITOR';

  @override
  String get textDensity => 'Text density';

  @override
  String get textDensityDescription =>
      'Multiplies the system text size by this app scale. 100% keeps the OS setting unchanged.';

  @override
  String get codeFontSize => 'Code font size';

  @override
  String get codeFontFamily => 'Code font';

  @override
  String get codeFontPreview => 'Preview';

  @override
  String get indentSize => 'Indent size';

  @override
  String get indentSizeSubtitle => 'Number of spaces for list indentation';

  @override
  String get gitDiffInteractionMode => 'Git diff gestures';

  @override
  String get gitDiffQuickActions => 'Quick actions';

  @override
  String get gitDiffQuickActionsDescription =>
      'One-finger horizontal swipes stage, unstage, or revert hunks. Long lines wrap.';

  @override
  String get gitDiffScrollFirst => 'Scroll first';

  @override
  String get gitDiffScrollFirstDescription =>
      'Long lines stay unwrapped for hunk-level horizontal scrolling. Use long press menus or the bottom buttons for Git actions.';

  @override
  String get imagePasteShortcut => 'Image paste shortcut';

  @override
  String get imagePasteShortcutCtrlV => 'Ctrl+V';

  @override
  String get imagePasteShortcutCtrlVDescription =>
      'Recommended on macOS. Keeps Cmd+V for normal paste and dictation tools.';

  @override
  String get imagePasteShortcutCommandV => 'Cmd+V';

  @override
  String get imagePasteShortcutCommandVDescription =>
      'May conflict with dictation apps, clipboard managers, and text expanders.';

  @override
  String get gitDiffFocusAutoLandscape => 'Rotate diff focus mode to landscape';

  @override
  String get gitDiffFocusAutoLandscapeDescription =>
      'On mobile layouts, entering diff focus mode locks the screen to landscape. Exiting focus mode restores normal rotation.';

  @override
  String get remoteGitStatusBadge =>
      'Show a subtle badge for unsynced Git commits';

  @override
  String get remoteGitStatusBadgeDescription =>
      'Shows a lighter badge on the session Git button when the current branch can push or pull after fetch.';

  @override
  String get sectionAbout => 'ABOUT';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appIconTitle => 'App Icon';

  @override
  String get appIconMonthlySupporterPerk => 'This is a Monthly Supporter perk.';

  @override
  String appIconSettingsSubtitle(String device) {
    return 'Change the icon on your $device Home Screen.';
  }

  @override
  String get appIconSupporterDialogTitle => 'Monthly Supporter Perk';

  @override
  String get appIconSupporterSectionLabel => 'Monthly Supporter Perk';

  @override
  String get appIconPickerTitle => 'Choose app icon';

  @override
  String get appIconPickerSubtitle =>
      'Pick the icon shown on your home screen.';

  @override
  String get appIconOptionDefaultTitle => 'Dark';

  @override
  String get appIconOptionDefaultSubtitle => 'The standard CC Pocket icon.';

  @override
  String get appIconOptionLightOutlineTitle => 'Light';

  @override
  String get appIconOptionLightOutlineSubtitle =>
      'A brighter variation with a lighter outline.';

  @override
  String get appIconOptionCopperEmeraldTitle => 'Metallic';

  @override
  String get appIconOptionCopperEmeraldSubtitle =>
      'A special edition with a glossy finish.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get voiceInput => 'Voice Input';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get pushNotificationsSubtitle =>
      'Receive session notifications via Bridge';

  @override
  String get pushNotificationsUnavailable => 'Available after Firebase setup';

  @override
  String get version => 'Version';

  @override
  String get loading => 'Loading...';

  @override
  String get setupGuideSubtitle => 'New here? Start with this';

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get githubRepository => 'GitHub Repository';

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogTitle => 'Changelog';

  @override
  String get showAllMain => 'Show all (main)';

  @override
  String get changelogFetchError => 'Failed to load changelog';

  @override
  String get fcmBridgeNotInitialized => 'Bridge not initialized';

  @override
  String get fcmTokenFailed => 'Failed to get FCM token';

  @override
  String get fcmEnabled => 'Notifications enabled';

  @override
  String get fcmEnabledPending => 'Will register after Bridge reconnects';

  @override
  String get fcmDisabled => 'Notifications disabled';

  @override
  String get fcmDisabledPending => 'Will unregister after Bridge reconnects';

  @override
  String get pushPrivacyMode => 'Privacy mode';

  @override
  String get pushPrivacyModeSubtitle =>
      'Hide project names and content from notifications';

  @override
  String get updateNotificationLanguage => 'Update notification language';

  @override
  String get notificationLanguageUpdated => 'Notification language updated';

  @override
  String get defaultNotRecommended => 'Default (not recommended)';

  @override
  String get imageAttached => 'Image attached';

  @override
  String get usageConnectToView => 'Connect to Bridge to view usage';

  @override
  String get usageFetchFailed => 'Failed to fetch';

  @override
  String get usageFiveHour => '5 hours';

  @override
  String get usageSevenDay => '7 days';

  @override
  String get settingsUsageSectionTitle => 'Usage';

  @override
  String get settingsUsageNoCodexData => 'No Codex usage data found.';

  @override
  String get usageDisplayModeRemaining => 'Remaining';

  @override
  String get usageDisplayModeUsed => 'Used';

  @override
  String get settingsClaudeUsageDescription =>
      'Open Claude\'s official billing pages in your browser.';

  @override
  String get settingsClaudeApiBilling => 'API Key billing';

  @override
  String get settingsClaudeSubscriptionUsage => 'Subscription usage';

  @override
  String get settingsNewSessionTabs => 'New Session Tabs';

  @override
  String get settingsNewSessionTabsDescription =>
      'Choose which AI tools appear for new sessions and change their order.';

  @override
  String get showBridgeNameInSessionList => 'Show Bridge name';

  @override
  String get showBridgeNameInSessionListSubtitle =>
      'Show the connected Bridge name in the session list when multiple Bridges are registered.';

  @override
  String get autoRenameCodexSessions => 'Auto Rename (Codex)';

  @override
  String get autoRenameCodexSessionsSubtitle =>
      'Name Codex sessions automatically after the first agent response';

  @override
  String get autoRenameClaudeSessions => 'Auto Rename (Claude)';

  @override
  String get autoRenameClaudeSessionsSubtitle =>
      'Name Claude sessions automatically after the first agent response. Uses an additional Claude request when API key billing is active.';

  @override
  String get newSessionTabCodex => 'Codex';

  @override
  String get newSessionTabClaudeCode => 'Claude';

  @override
  String usageResetAt(String time) {
    return 'Reset: $time';
  }

  @override
  String get usageAlreadyReset => 'Already reset';

  @override
  String attachedImages(int count) {
    return 'Attached Images ($count)';
  }

  @override
  String get attachedImagesNoCount => 'Attached Images';

  @override
  String get failedToFetchImages => 'Could not fetch images';

  @override
  String get responseTimedOut => 'Response timed out';

  @override
  String failedToFetchImagesWithError(String error) {
    return 'Failed to fetch images: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get clipboardNotAvailable => 'Cannot access clipboard';

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String get noImageInClipboard => 'No image in clipboard';

  @override
  String get failedToReadClipboard => 'Failed to read clipboard';

  @override
  String imageLimitReached(int max) {
    return 'Maximum $max images allowed';
  }

  @override
  String imageLimitTruncated(int max, int dropped) {
    return 'Only first $max images attached ($dropped dropped)';
  }

  @override
  String get selectFromGallery => 'Select from Gallery';

  @override
  String get pasteFromClipboard => 'Paste from Clipboard';

  @override
  String get voiceInputLanguage => 'Voice Input Language';

  @override
  String get hideVoiceInput => 'Hide voice input button';

  @override
  String get hideVoiceInputSubtitle =>
      'Useful when using a third-party voice input keyboard';

  @override
  String get archive => 'Archive';

  @override
  String get archiveConfirm => 'Archive this session?';

  @override
  String get archiveConfirmMessage =>
      'This session will be hidden from the list. You can still access it from Claude Code.';

  @override
  String get sessionArchived => 'Session archived';

  @override
  String get archiveFailed => 'Failed to archive session';

  @override
  String archiveFailedWithError(String error) {
    return 'Failed to archive session: $error';
  }

  @override
  String get noRecentSessions => 'No recent sessions';

  @override
  String get noSessionsMatchFilters => 'No sessions match the current filters';

  @override
  String get adjustFiltersAndSearch => 'Try changing filters or search terms';

  @override
  String get tooltipDisplayMode => 'Change which message is shown on cards';

  @override
  String get tooltipProviderFilter => 'Filter by AI tool';

  @override
  String get tooltipProjectFilter => 'Filter by project';

  @override
  String get tooltipNamedOnly => 'Only sessions you\'ve named';

  @override
  String get tooltipIndent => 'Increase indent';

  @override
  String get tooltipDedent => 'Decrease indent';

  @override
  String get tooltipSlashCommand => 'Insert command or skill';

  @override
  String get tooltipMention => 'Mention file or plugin';

  @override
  String get tooltipDollarMention => 'Insert skill or app';

  @override
  String get tooltipPermissionMode => 'Permission mode';

  @override
  String get tooltipAttachImage => 'Attach image';

  @override
  String get tooltipPromptHistory => 'Open prompt history';

  @override
  String get tooltipVoiceInput => 'Start voice input';

  @override
  String get tooltipStopRecording => 'Stop recording';

  @override
  String get tooltipSendMessage => 'Send message';

  @override
  String get tooltipRemoveImage => 'Remove image';

  @override
  String get tooltipClearDiff => 'Clear diff selection';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get authErrorTitle => 'Claude login required';

  @override
  String get authErrorBody =>
      'Claude needs to sign in again on the Bridge machine.';

  @override
  String get authErrorPrimaryCommandLabel => 'Step 1';

  @override
  String get authErrorSecondaryCommandLabel => 'Step 2';

  @override
  String get authErrorAlternativeLabel => 'Shell alternative';

  @override
  String get apiKeyRequiredTitle => 'API key required';

  @override
  String get apiKeyRequiredBody =>
      'Anthropic\'s current Claude Agent SDK docs do not permit third-party products to use Claude subscription login. Please use an API key instead.';

  @override
  String get apiKeyRequiredHint => 'Get your API key at:';

  @override
  String get authHelpTitle => 'Auth Troubleshooting';

  @override
  String get authHelpFetchError => 'Failed to load the troubleshooting guide';

  @override
  String get authHelpButton => 'View steps';

  @override
  String get authHelpLanguageJa => '日本語';

  @override
  String get authHelpLanguageEn => 'English';

  @override
  String get authHelpLanguageZhHans => 'Simplified Chinese';

  @override
  String get authHelpLanguageKo => '한국어';

  @override
  String get terminalApp => 'Terminal App';

  @override
  String get terminalAppSubtitle => 'Open projects in an external terminal app';

  @override
  String get terminalAppNone => 'Not configured';

  @override
  String get terminalAppCustom => 'Custom';

  @override
  String get terminalAppName => 'App Name';

  @override
  String get terminalUrlTemplate => 'URL Template';

  @override
  String get terminalUrlTemplateHint =>
      'Variables: host, user, port, project_path';

  @override
  String get terminalSshUser => 'SSH User';

  @override
  String get terminalSshUserHint => 'Defaults to machine SSH user';

  @override
  String get openInTerminal => 'Open in Terminal';

  @override
  String get terminalAppNotInstalled => 'Could not open terminal app';

  @override
  String get terminalAppExperimental => 'Preview';

  @override
  String get terminalAppExperimentalNote =>
      'This feature is in preview. Presets may not work with all apps or configurations. Contributions for new presets are welcome on GitHub!';

  @override
  String get sectionSpread => 'ENJOYING CC POCKET?';

  @override
  String get spreadAppealMessage =>
      'CC Pocket still has a small user base, and continued development is hard without more users. If you like it, a quick store rating or sharing it with someone would really help.';

  @override
  String get shareApp => 'Share with Friends';

  @override
  String get shareAppSubtitle => 'Tell your friends & colleagues';

  @override
  String shareText(String url) {
    return 'CC Pocket: Claude & Codex\nControl your coding agent from your phone 📱\n#ccpocket\n$url';
  }

  @override
  String get starOnGithub => 'Star on GitHub';

  @override
  String get rateOnStore => 'Rate on App Store';

  @override
  String get rateOnStoreAndroid => 'Rate on Google Play';

  @override
  String get supporterTitle => 'Supporter';

  @override
  String get supporterMonthlyTitle => 'Supporter Monthly';

  @override
  String get supporterMonthlyPlusTitle => 'Supporter Monthly Plus';

  @override
  String get supporterSnackTitle => 'Snack Support';

  @override
  String get supporterCoffeeTitle => 'Buy Me a Drink';

  @override
  String get supporterLunchTitle => 'Buy Me Lunch';

  @override
  String get supporterStatusActive => 'Thanks for backing CC Pocket.';

  @override
  String get supporterStatusInactive =>
      'CC Pocket stays fully free. You can support ongoing development here.';

  @override
  String get supporterStatusLoading => 'Checking supporter status...';

  @override
  String get supportEntryInactiveTitle => 'Support';

  @override
  String get supportEntryInactiveSubtitle =>
      'If CC Pocket has been useful, I\'d appreciate your support for ongoing development.';

  @override
  String get supportEntryOneTimeTitle => 'Thanks for your support';

  @override
  String get supportEntryOneTimeSubtitle => 'Thanks for supporting CC Pocket.';

  @override
  String get supportEntryActiveTitle => 'Supporting';

  @override
  String supportEntryActiveSubtitle(String date) {
    return 'Thank you. You’ve been supporting CC Pocket since $date.';
  }

  @override
  String get supporterMonthlyDescription =>
      'Ongoing support to keep the app improving.';

  @override
  String get supporterMonthlyPerkLabel => 'Includes alternate app icon perks';

  @override
  String get supporterSnackDescription =>
      'If you feel like buying me a snack, I\'d really appreciate the support.';

  @override
  String get supporterCoffeeDescription =>
      'If you feel like buying me a drink, I\'d really appreciate the support.';

  @override
  String get supporterLunchDescription =>
      'If you feel like buying me lunch, I\'d really appreciate the support.';

  @override
  String get supporterBuyButton => 'Support';

  @override
  String get supporterActiveButton => 'Active';

  @override
  String get supporterSubscribedButton => 'Subscribed';

  @override
  String get supporterRestoreButton => 'Restore';

  @override
  String get supporterRetryButton => 'Retry';

  @override
  String get supporterProductsUnavailable =>
      'No support options are currently available.';

  @override
  String get supporterRestoreNoticeTitle => 'About restore';

  @override
  String get supporterRestoreNoticeBody =>
      'Restore works with the same Apple ID or Google account. Supporter status does not carry between iOS and Android.';

  @override
  String get supporterSummaryTitle => 'Your support';

  @override
  String supporterSummarySinceChip(String date) {
    return 'Since $date';
  }

  @override
  String supporterSummaryStreakChip(String duration) {
    return 'Streak: $duration';
  }

  @override
  String supporterSummaryOneTimeCount(int count) {
    return 'One-time ×$count';
  }

  @override
  String supporterSummarySnackCount(int count) {
    return 'Snacks ×$count';
  }

  @override
  String supporterSummaryCoffeeCount(int count) {
    return 'Drinks ×$count';
  }

  @override
  String supporterSummaryLunchCount(int count) {
    return 'Lunch ×$count';
  }

  @override
  String get supporterSummaryLessThanMonth => '<1 month';

  @override
  String supporterSummaryDurationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get supporterSummarySinceLabel => 'Started';

  @override
  String get supporterSummaryStreakLabel => 'Active for';

  @override
  String get supporterSummaryOngoingLabel => 'Supporting';

  @override
  String get supporterSummarySupportPeriodLabel => 'Support period';

  @override
  String get supporterImpactTitle => 'What support helps make possible';

  @override
  String get supporterImpactBody =>
      'If you like CC Pocket, I\'d really appreciate your support for ongoing development. The app will continue as free OSS.';

  @override
  String get supporterImpactAiTitle => 'Development and operating costs';

  @override
  String get supporterImpactAiBody =>
      'AI usage, device checks, testing, and shipping all add recurring costs.';

  @override
  String get supporterImpactDevicesTitle => 'Devices and testing';

  @override
  String get supporterImpactDevicesBody =>
      'Keeping the app reliable across phones, tablets, and platform updates.';

  @override
  String get supporterImpactMotivationTitle => 'Momentum to keep building';

  @override
  String get supporterImpactMotivationBody =>
      'Knowing the app is useful makes it much easier to keep shipping new features and improvements.';

  @override
  String get supporterPackagesTitle => 'Choose a way to support';

  @override
  String get supporterSubscriptionGroupTitle => 'Monthly support';

  @override
  String get supporterSubscriptionGroupBody =>
      'I\'d really appreciate ongoing support here.';

  @override
  String get supporterOneTimeGroupTitle => 'One-time support';

  @override
  String get supporterOneTimeGroupBody =>
      'If you feel like buying me lunch or a drink, I’d really appreciate the support.';

  @override
  String get supporterPurchaseInfoTitle => 'About purchases';

  @override
  String get supporterPurchaseInfoBody =>
      'Restore works with the same Apple ID or Google account. Supporter status does not carry between iOS and Android.';

  @override
  String get supporterPurchaseInfoLink => 'Learn more';

  @override
  String get supporterPrivacyPolicyLink => 'Privacy Policy';

  @override
  String get supporterTermsOfUseLink => 'Terms of Use (Apple Standard EULA)';

  @override
  String get supporterLearnMoreTitle => 'About purchases and support';

  @override
  String get supporterLearnMoreBody =>
      'Read why CC Pocket stays free, how restore works, and what Supporter includes.';

  @override
  String get supporterOpenLinkFailed => 'Could not open the info page.';

  @override
  String get supporterPurchaseSuccess => 'Thanks for supporting CC Pocket!';

  @override
  String get supporterPurchaseCancelled => 'Purchase cancelled.';

  @override
  String supporterPurchaseFailed(String message) {
    return 'Purchase failed: $message';
  }

  @override
  String get supporterRestoreSuccess => 'Purchases restored.';

  @override
  String supporterRestoreFailed(String message) {
    return 'Restore failed: $message';
  }

  @override
  String get gitDiscardAllChangesTitle => 'Discard all changes?';

  @override
  String get gitDiscardVisibleUnstagedChangesMessage =>
      'Discard all visible unstaged changes.';

  @override
  String get gitDiscardChangeTitle => 'Discard this change?';

  @override
  String get gitDiscardFileUnstagedChangesMessage =>
      'Discard all unstaged changes in this file.';

  @override
  String get gitDiscardHunkUnstagedChangesMessage =>
      'Discard unstaged changes in this hunk.';

  @override
  String get googleSearchSelectionAction => 'Search with Google';

  @override
  String get approvalQuestionNotificationTitle => 'Question - ccpocket';

  @override
  String get approvalRequiredNotificationTitle =>
      'Approval Required - ccpocket';

  @override
  String get exitPlanModeNotificationBody =>
      'The generated plan needs your review';

  @override
  String get renderErrorFallback => 'This content couldn\'t be displayed.';
}
