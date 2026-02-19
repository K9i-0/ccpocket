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
  String get delete => 'Delete';

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
  String get serverUnreachable => 'Server Unreachable';

  @override
  String get serverUnreachableBody => 'Could not reach the Bridge server at:';

  @override
  String get setupSteps => 'Setup Steps:';

  @override
  String get setupStep1Title => 'Install and build the Bridge server';

  @override
  String get setupStep1Command =>
      'cd packages/bridge && npm install && npm run bridge:build';

  @override
  String get setupStep2Title => 'Start the server';

  @override
  String get setupStep2Command => 'npm run bridge';

  @override
  String get setupStep3Title => 'For persistent startup, register as service';

  @override
  String get setupStep3Command => 'npm run setup';

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
  String get editSettingsThenStart => 'Edit Settings Then Start';

  @override
  String get serverRequiresApiKey => 'This server requires an API key';

  @override
  String get bridgeServerUpdated => 'Bridge Server updated';

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
  String get stopServer => 'Stop Server';

  @override
  String get update => 'Update';

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
  String get worktreeNew => 'New';

  @override
  String worktreeExisting(int count) {
    return 'Existing ($count)';
  }

  @override
  String get branchOptional => 'Branch (optional)';

  @override
  String get branchHint => 'ccpocket/<auto>';

  @override
  String get noExistingWorktrees => 'No existing worktrees';

  @override
  String get planApprovalSummary =>
      'Review the plan above and approve or continue planning';

  @override
  String get toolApprovalSummary => 'Tool execution requires approval';

  @override
  String get planApproval => 'Plan Approval';

  @override
  String get approvalRequired => 'Approval Required';

  @override
  String get viewEditPlan => 'View / Edit Plan';

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
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String get always => 'Always';

  @override
  String get messagePlaceholder => 'Message Claude...';

  @override
  String filesMentioned(int count) {
    return '$count file(s) @mentioned';
  }

  @override
  String diffLines(int count) {
    return '$count diff lines';
  }

  @override
  String get tapInterruptHoldStop => 'Tap: interrupt, Hold: stop';

  @override
  String get rewindToHere => 'Rewind to here';

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
  String get claudeIsAsking => 'Claude is asking';

  @override
  String get submitAllAnswers => 'Submit All Answers';

  @override
  String get answerAllQuestionsToSubmit => 'Answer all questions to submit';

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
  String get cancelSelection => 'Cancel selection';

  @override
  String get selectAndAttach => 'Select & attach';

  @override
  String get filterFiles => 'Filter files';

  @override
  String attachFilesAndHunks(int files, int hunks) {
    return 'Attach $files file(s), $hunks hunk(s)';
  }

  @override
  String get filterFilesTitle => 'Filter Files';

  @override
  String get noChanges => 'No changes';

  @override
  String get allFilesFilteredOut => 'All files filtered out';

  @override
  String get showAll => 'Show all';

  @override
  String get setupGuideTitle => 'Setup Guide';

  @override
  String get guideAboutTitle => 'What is CC Pocket?';

  @override
  String get guideAboutDescription =>
      'A mobile client that lets you control Claude Code and Codex from your smartphone.';

  @override
  String get guideAboutDiagramTitle => 'How it works';

  @override
  String get guideAboutDiagramPhone => 'iPhone';

  @override
  String get guideAboutDiagramBridge => 'Bridge Server';

  @override
  String get guideAboutDiagramClaude => 'Claude CLI\n/ Codex';

  @override
  String get guideAboutDiagramCaption =>
      'Start the Bridge Server on your PC,\nthen connect from your phone.';

  @override
  String get guideBridgeTitle => 'Bridge Server\nSetup';

  @override
  String get guideBridgeDescription =>
      'Let\'s start the Bridge Server on your PC.';

  @override
  String get guideBridgePrerequisites => 'Prerequisites';

  @override
  String get guideBridgePrereq1 => 'Mac / PC with Node.js installed';

  @override
  String get guideBridgePrereq2 =>
      'Claude Code CLI or Codex CLI\n(either one is fine)';

  @override
  String get guideBridgeStep1 => 'Clone the project';

  @override
  String get guideBridgeStep1Command => 'git clone <repo-url>\nnpm install';

  @override
  String get guideBridgeStep2 => 'Build';

  @override
  String get guideBridgeStep2Command => 'npm run bridge:build';

  @override
  String get guideBridgeStep3 => 'Start';

  @override
  String get guideBridgeStep3Command => 'npm run bridge';

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
      'If manually starting the Bridge Server is tedious, you can configure it to start automatically when your Mac boots.';

  @override
  String get guideLaunchdCommand => 'Setup Command';

  @override
  String get guideLaunchdCommandValue => 'npm run setup';

  @override
  String get guideLaunchdRecommendation =>
      'We recommend verifying with manual startup first, then registering with launchd once stable.';

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
  String get defaultNotRecommended => 'Default (not recommended)';

  @override
  String get imageAttached => 'Image attached';

  @override
  String get sectionBackup => 'BACKUP';

  @override
  String get backupPromptHistory => 'Backup Prompt History';

  @override
  String get restorePromptHistory => 'Restore Prompt History';

  @override
  String get backupSuccess => 'Backup completed';

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get restoreSuccess => 'Restore completed';

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get restoreConfirmTitle => 'Restore Prompt History';

  @override
  String get restoreConfirmMessage =>
      'This will replace all local prompt history with the backup. This cannot be undone.';

  @override
  String get restoreConfirmButton => 'Restore';

  @override
  String get noBackupFound => 'No backup found';

  @override
  String backupInfo(String date) {
    return 'Last backup: $date';
  }

  @override
  String backupVersionInfo(String version, String size) {
    return 'v$version · $size';
  }

  @override
  String get connectToBackup => 'Connect to Bridge to use backup';
}
