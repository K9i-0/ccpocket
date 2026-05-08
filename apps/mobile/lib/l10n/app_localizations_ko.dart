// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'CC Pocket';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get remove => '제거';

  @override
  String get removeProjectTitle => '프로젝트 제거';

  @override
  String removeProjectConfirm(Object name) {
    return '최근 프로젝트에서 \"$name\"을 제거할까요?';
  }

  @override
  String get rename => '이름 변경';

  @override
  String get renameSession => '세션 이름 변경';

  @override
  String get sessionNameHint => '세션 이름';

  @override
  String get clearName => '이름 지우기';

  @override
  String get connect => '연결';

  @override
  String get copy => '복사';

  @override
  String get copied => '복사됨';

  @override
  String get copiedToClipboard => '클립보드에 복사됨';

  @override
  String get lineCopied => '줄이 복사됨';

  @override
  String get start => '시작';

  @override
  String get stop => '중지';

  @override
  String get send => '보내기';

  @override
  String get settings => '설정';

  @override
  String get gallery => '갤러리';

  @override
  String get git => 'Git';

  @override
  String get explorer => 'Explorer';

  @override
  String get gitUnavailableTip => 'Git을 찾을 수 없음 — Git 기능을 사용할 수 없습니다';

  @override
  String get gitUnavailableTitle => 'Git을 사용할 수 없음';

  @override
  String get gitUnavailableHint => '이 프로젝트에서는 Git 기능을 사용할 수 없습니다';

  @override
  String get autoModeFallbackDefaultTip =>
      '이 환경에서는 Auto mode를 사용할 수 없어 Default mode로 전환했습니다';

  @override
  String galleryWithCount(int count) {
    return '갤러리 ($count)';
  }

  @override
  String get disconnect => '연결 해제';

  @override
  String get back => '뒤로';

  @override
  String get next => '다음';

  @override
  String get done => '완료';

  @override
  String get skip => '건너뛰기';

  @override
  String get edit => '편집';

  @override
  String get share => '공유';

  @override
  String get all => '전체';

  @override
  String get none => '없음';

  @override
  String get serverUnreachable => '서버에 연결할 수 없음';

  @override
  String get serverUnreachableBody => '다음 Bridge 서버에 연결할 수 없습니다:';

  @override
  String get setupSteps => '설정 단계:';

  @override
  String get setupStep1Title => 'Bridge 서버 시작';

  @override
  String get setupStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get setupStep2Title => '항상 실행하려면 서비스로 등록';

  @override
  String get setupStep2Command => 'npx --yes @ccpocket/bridge@latest setup';

  @override
  String get setupNetworkHint => '두 기기가 같은 네트워크에 있는지 확인하세요(또는 Tailscale 사용).';

  @override
  String get connectAnyway => '그래도 연결';

  @override
  String get stopSession => '세션 중지';

  @override
  String get stopSessionConfirm => '이 세션을 중지할까요? Claude 프로세스가 종료됩니다.';

  @override
  String get startNewWithSameSettings => '같은 설정으로 새로 시작';

  @override
  String get copyResumeCommand => '재개 명령 복사';

  @override
  String get copyResumeCommandSubtitle => 'macOS / Linux에서 이어서 작업';

  @override
  String get resumeCommandCopied => '재개 명령이 복사됨';

  @override
  String get editSettingsThenStart => '설정을 편집한 뒤 시작';

  @override
  String get serverRequiresApiKey => '이 서버에는 API 키가 필요합니다';

  @override
  String get bridgeServerUpdated => 'Bridge 서버가 업데이트됨';

  @override
  String get bridgeUpdateStarted =>
      'Bridge를 업데이트하고 있습니다. 이 연결을 닫고 컴퓨터 목록으로 돌아갑니다.';

  @override
  String get bridgeUpdateReconnectHint =>
      'Bridge 서버가 업데이트되었습니다. 컴퓨터 목록에서 다시 연결하세요.';

  @override
  String get failedToUpdateServer => '서버 업데이트 실패';

  @override
  String get bridgeServerStarted => 'Bridge 서버가 시작됨';

  @override
  String get failedToStartServer => '서버 시작 실패';

  @override
  String get bridgeServerStopped => 'Bridge 서버가 중지됨';

  @override
  String get failedToStopServer => '서버 중지 실패';

  @override
  String get sshPassword => 'SSH 비밀번호';

  @override
  String sshPasswordPrompt(String machineName) {
    return '$machineName의 SSH 비밀번호 입력';
  }

  @override
  String get password => '비밀번호';

  @override
  String get deleteMachine => '컴퓨터 삭제';

  @override
  String deleteMachineConfirm(String displayName) {
    return '\"$displayName\"을 삭제할까요? 저장된 인증 정보가 모두 제거됩니다.';
  }

  @override
  String get connectToBridgeServer => 'Bridge 서버에 연결';

  @override
  String get orConnectManually => '또는 수동으로 연결';

  @override
  String get serverUrl => '서버 URL';

  @override
  String get serverUrlHint => 'ws://<host-ip>:8765';

  @override
  String get apiKeyOptional => 'API 키(선택 사항)';

  @override
  String get apiKeyHint => '인증이 없으면 비워 두세요';

  @override
  String get scanQrCode => 'QR 코드 스캔';

  @override
  String get setupGuide => '설정 가이드';

  @override
  String get showSessions => '왼쪽 패널 표시';

  @override
  String get hideSessions => '왼쪽 패널 숨기기';

  @override
  String get workspaceLandingSelectSessionMessage => '왼쪽 패널에서 세션을 선택하세요.';

  @override
  String get workspaceLandingCreateSessionMessage =>
      '왼쪽 패널의 새로 만들기에서 세션을 만드세요.';

  @override
  String get workspaceLandingDisconnectedMessage =>
      'Bridge가 연결되어 있지 않습니다. 왼쪽 패널에서 연결하거나 설정 가이드를 열어 컴퓨터를 설정하세요.';

  @override
  String get running => '실행 중';

  @override
  String get recentSessions => '최근 세션';

  @override
  String get search => '검색';

  @override
  String get searchSessions => '세션 검색...';

  @override
  String get sessionDisplayModeFirst => '처음';

  @override
  String get sessionDisplayModeLast => '마지막';

  @override
  String get sessionDisplayModeSummary => '요약';

  @override
  String get allAiTools => '모든 AI 도구';

  @override
  String get allProjects => '모든 프로젝트';

  @override
  String get named => '이름 있음';

  @override
  String get machines => '컴퓨터';

  @override
  String get refreshStatus => '상태 새로고침';

  @override
  String get add => '추가';

  @override
  String get noSavedMachinesDescription =>
      '저장된 컴퓨터가 없습니다.\n추가하면 빠르게 연결하거나 Bridge 서버를 원격으로 시작할 수 있습니다.';

  @override
  String get readyToStart => '시작할 준비 완료';

  @override
  String get readyToStartDescription => '+ 버튼을 눌러 새 세션을 만들고 Claude로 코딩을 시작하세요.';

  @override
  String get newSession => '새 세션';

  @override
  String get neverConnected => '연결한 적 없음';

  @override
  String get justNow => '방금';

  @override
  String minutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String daysAgo(int days) {
    return '$days일 전';
  }

  @override
  String get unfavorite => '즐겨찾기 해제';

  @override
  String get favorite => '즐겨찾기';

  @override
  String get updateBridge => 'Bridge 업데이트';

  @override
  String get bridgeIsUpToDate => 'Bridge가 최신 상태입니다';

  @override
  String get bridgeUpdateAvailable => '업데이트 사용 가능';

  @override
  String get bridgeUpdateRequiresSetup => 'SSH 및 Bridge 자동 시작 설정이 필요합니다';

  @override
  String get bridgeVersionUnknown => 'Bridge 버전 알 수 없음';

  @override
  String bridgeVersionCurrentExpected(String current, String expected) {
    return '현재 v$current, 권장 v$expected+';
  }

  @override
  String bridgeVersionCurrentLatest(String current, String latest) {
    return '현재 v$current, 최신 v$latest';
  }

  @override
  String get bridgeLatestVersionChecking => '최신 Bridge 버전 확인 중...';

  @override
  String get bridgeLatestVersionUnavailable => '최신 Bridge 버전을 확인할 수 없습니다';

  @override
  String get bridgeLatestVersionRetry => '최신 버전 확인 재시도';

  @override
  String get bridgeUpdateSetupTitle => 'Bridge 업데이트 준비';

  @override
  String get bridgeUpdateSetupDescription =>
      '앱에서 Bridge를 업데이트하려면 컴퓨터의 SSH 접속과 Bridge 자동 시작 설정이 필요합니다.';

  @override
  String get bridgeUpdateSetupEnableSsh => 'Bridge 연결 설정에서 SSH를 활성화하세요.';

  @override
  String get bridgeUpdateSetupRunCommand => '대상 컴퓨터에서 설정 명령을 실행하세요.';

  @override
  String get bridgeUpdateSetupCommand => 'npx @ccpocket/bridge@latest setup';

  @override
  String get stopServer => '서버 중지';

  @override
  String get update => '업데이트';

  @override
  String get download => '다운로드';

  @override
  String appUpdateAvailable(String version) {
    return 'v$version 사용 가능';
  }

  @override
  String get macosNativeAppBannerTitle => '네이티브 macOS 앱 사용';

  @override
  String get macosNativeAppBannerSubtitle =>
      'CC Pocket은 네이티브 데스크톱 앱에서 macOS에 최적화되어 있습니다. GitHub Releases에서 설치하세요.';

  @override
  String get openGitHubReleases => 'GitHub Releases 열기';

  @override
  String get macosNativeAppSettingsTitle => 'macOS 네이티브 앱';

  @override
  String get macosNativeAppSettingsSubtitle =>
      'macOS에 최적화되어 있으므로 Mac에서는 권장됩니다.';

  @override
  String get supportBannerTitle => 'CC Pocket이 도움이 되었나요?';

  @override
  String get supportBannerSubtitle => '후원은 지속적인 개발에 도움이 됩니다.';

  @override
  String get supportBannerAction => '후원 보기';

  @override
  String get offline => '오프라인';

  @override
  String get unreachable => '연결 불가';

  @override
  String get checking => '확인 중...';

  @override
  String get recentProjects => '최근 프로젝트';

  @override
  String get orEnterPath => '또는 경로 입력';

  @override
  String get projectPath => '프로젝트 경로';

  @override
  String get projectPathHint => '/path/to/your/project';

  @override
  String get permission => '권한';

  @override
  String get approval => '승인';

  @override
  String get restart => '재시작';

  @override
  String get worktree => 'Worktree';

  @override
  String get advanced => '고급';

  @override
  String get modelOptional => '모델(선택 사항)';

  @override
  String get effort => 'Effort';

  @override
  String get defaultLabel => '기본값';

  @override
  String get codexProfilePrecedenceNote => '선택한 프로필에 같은 설정이 있으면 아래 옵션보다 우선합니다.';

  @override
  String get maxTurns => '최대 턴 수';

  @override
  String get maxTurnsHint => '예: 8';

  @override
  String get maxTurnsError => '0보다 큰 정수여야 합니다';

  @override
  String get maxBudgetUsd => '최대 예산(USD)';

  @override
  String get maxBudgetHint => '예: 1.00';

  @override
  String get maxBudgetError => '0 이상의 숫자여야 합니다';

  @override
  String get fallbackModel => '대체 모델';

  @override
  String get forkSessionOnResume => '재개 시 세션 포크';

  @override
  String get persistSessionHistory => '세션 기록 유지';

  @override
  String get model => '모델';

  @override
  String get sandbox => '샌드박스';

  @override
  String get reasoning => '추론';

  @override
  String get webSearch => '웹 검색';

  @override
  String get networkAccess => '네트워크 액세스';

  @override
  String get additionalWritableRootsTitle => '추가로 접근할 디렉터리';

  @override
  String get additionalWritableRootsDescription =>
      '이 세션의 Codex config.toml writable_roots에 더해 추가됩니다.';

  @override
  String get additionalWritableRootsTooltip =>
      '선택한 프로젝트 외의 파일도 읽거나 편집해야 할 때 사용하세요.';

  @override
  String get additionalWritableRootsSuggestions => '최근 프로젝트';

  @override
  String get addDirectory => '디렉터리 추가';

  @override
  String get directoryPath => '디렉터리 경로';

  @override
  String get worktreeNew => '새로 만들기';

  @override
  String worktreeExisting(int count) {
    return '기존 ($count)';
  }

  @override
  String get branchOptional => '브랜치(선택 사항)';

  @override
  String get branchHint => 'feature/...';

  @override
  String get noExistingWorktrees => '기존 worktree 없음';

  @override
  String get planApprovalSummary => '위 계획을 검토해 승인하거나 계속 수정하세요';

  @override
  String get planApprovalSummaryCard => '계획을 검토해 승인하거나 계속 수정하세요';

  @override
  String get toolApprovalSummary => '도구 실행에 승인이 필요합니다';

  @override
  String get planApproval => '계획 승인';

  @override
  String get approvalRequired => '승인 필요';

  @override
  String get viewEditPlan => '계획 보기';

  @override
  String get keepPlanning => '계획 계속하기';

  @override
  String get keepPlanningHint => '무엇을 변경할까요...';

  @override
  String get sendFeedbackKeepPlanning => '피드백을 보내고 계획 계속하기';

  @override
  String get acceptAndClear => '수락하고 지우기';

  @override
  String get acceptPlan => '계획 수락';

  @override
  String get continuePlanning => '계속 계획';

  @override
  String get reject => '거부';

  @override
  String get approve => '승인';

  @override
  String get always => '항상';

  @override
  String get approveOnce => '한 번 허용';

  @override
  String get approveForSession => '이 세션에서 허용';

  @override
  String get approveAlways => '영구 허용';

  @override
  String get approveAlwaysSub => '허용';

  @override
  String get approveSessionMain => '이 세션';

  @override
  String get approveSessionSub => '허용';

  @override
  String get permissionDefaultDescription => '표준 권한 확인';

  @override
  String get permissionAutoDescription => '내장 안전 확인으로 Claude가 승인을 자동 처리합니다';

  @override
  String get permissionAcceptEditsDescription => '파일 편집 자동 승인';

  @override
  String get permissionPlanDescription => '변경 실행 전에 분석하고 계획';

  @override
  String get permissionBypassDescription => '대부분의 승인 확인 없이 실행';

  @override
  String get executionDefaultDescription => '표준 권한 확인';

  @override
  String get executionAcceptEditsDescription => '파일 편집 자동 승인';

  @override
  String get executionFullAccessDescription => '대부분의 승인 확인 없이 실행';

  @override
  String get codexPlanModeDescription => '먼저 계획을 작성한 뒤 승인 후 실행';

  @override
  String get sandboxRestrictedDescription => '제한된 환경에서 명령 실행';

  @override
  String get sandboxNativeDescription => '네이티브로 명령 실행';

  @override
  String get sandboxNativeCautionDescription => '네이티브로 명령 실행(주의)';

  @override
  String get sheetSubtitleApproval => '승인이 필요한 작업을 제어합니다';

  @override
  String get sheetSubtitleSandboxCodex =>
      '안전을 위해 샌드박스가 기본으로 켜져 있습니다. 끄면 전체 시스템 액세스가 허용됩니다.';

  @override
  String get sheetSubtitleSandboxClaude =>
      'Claude는 기본적으로 네이티브로 실행됩니다. 샌드박스를 켜면 액세스가 제한됩니다.';

  @override
  String get sheetSubtitleModel => '모델마다 속도, 성능, 비용이 다릅니다.';

  @override
  String get sheetSubtitleEffort => 'Effort가 높을수록 더 철저히 분석하지만 시간이 더 걸립니다.';

  @override
  String get claudeEffortLowDesc => '더 빠른 응답, 덜 철저함';

  @override
  String get claudeEffortMediumDesc => '속도와 품질의 균형';

  @override
  String get claudeEffortHighDesc => '더 철저한 분석';

  @override
  String get claudeEffortMaxDesc => '가장 철저하지만 가장 느림';

  @override
  String get reasoningEffortMinimalDesc => '가장 빠름, 분석 최소';

  @override
  String get reasoningEffortLowDesc => '더 빠른 응답, 덜 철저함';

  @override
  String get reasoningEffortMediumDesc => '속도와 품질의 균형';

  @override
  String get reasoningEffortHighDesc => '더 철저한 분석';

  @override
  String get reasoningEffortXhighDesc => '가장 철저하지만 가장 느림';

  @override
  String get changePermissionModeTitle => '권한 모드 변경';

  @override
  String changePermissionModeBody(String mode) {
    return '$mode(으)로 전환하면 세션이 재시작됩니다. 대화는 유지됩니다.';
  }

  @override
  String get changeExecutionModeTitle => '실행 모드 변경';

  @override
  String changeExecutionModeBody(String mode) {
    return '$mode(으)로 전환하면 세션이 재시작됩니다. 대화는 유지됩니다.';
  }

  @override
  String get changeApprovalPolicyTitle => '승인 정책 변경';

  @override
  String changeApprovalPolicyBody(String mode) {
    return '$mode(으)로 전환하면 세션이 재시작됩니다. 대화는 유지됩니다.';
  }

  @override
  String get codexApprovalUntrustedDescription =>
      '신뢰할 수 있는 명령만 자동 실행하고 나머지는 확인';

  @override
  String get codexApprovalOnRequestDescription => '에이전트가 승인이 필요하다고 판단할 때만 확인';

  @override
  String get codexApprovalOnFailureDescription =>
      '먼저 묻지 않고 실행하고 명령 실패 시에만 확인(사용 중단 예정)';

  @override
  String get codexApprovalNeverDescription => '승인을 묻지 않고 실패는 즉시 반환';

  @override
  String get codexAutoReview => '자동 리뷰';

  @override
  String get codexAutoReviewDescription => 'Codex가 승인 요청을 자동으로 검토';

  @override
  String get codexAutoReviewUnavailableDescription => '승인이 비활성화되어 있으면 사용할 수 없음';

  @override
  String get enablePlanModeTitle => 'Plan Mode 활성화';

  @override
  String get disablePlanModeTitle => 'Plan Mode 비활성화';

  @override
  String get enablePlanModeBody => 'Plan Mode를 활성화하면 세션이 재시작됩니다. 대화는 유지됩니다.';

  @override
  String get disablePlanModeBody => 'Plan Mode를 비활성화하면 세션이 재시작됩니다. 대화는 유지됩니다.';

  @override
  String get changeSandboxModeTitle => '샌드박스 모드 변경';

  @override
  String changeSandboxModeBody(String mode) {
    return '$mode(으)로 전환하면 세션이 재시작됩니다. 대화는 유지됩니다.';
  }

  @override
  String get messagePlaceholder => 'Claude에게 메시지...';

  @override
  String get codexMessagePlaceholder => 'Codex에게 메시지...';

  @override
  String get queuedInputForReconnect => '재연결 대기열에 추가됨';

  @override
  String get queuedInputPendingDelivery => '전송 확인 중';

  @override
  String get queuedInputForNextTurn => '다음 턴 대기열에 추가됨';

  @override
  String get sessionCardQueuedInput => '대기 중';

  @override
  String queuedInputImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미지 $count개',
    );
    return '$_temp0';
  }

  @override
  String get tooltipSteerQueuedMessage => '대기 중인 메시지를 지시로 보내기';

  @override
  String get tooltipMoveQueuedMessageToInput => '대기 중인 메시지를 입력창으로 이동';

  @override
  String get tooltipCancelQueuedMessage => '대기 중인 메시지 취소';

  @override
  String get reconnecting => '재연결 중...';

  @override
  String get reconnectingQueuedMessages => '재연결 중... 대기 중인 메시지는 자동으로 전송됩니다';

  @override
  String get disconnectedMessagesQueued => '연결 끊김 - 메시지를 재연결 대기열에 추가할 수 있습니다';

  @override
  String get sessionQueuedForReconnect => '세션을 재연결 대기열에 추가했습니다';

  @override
  String get resumeAlreadyQueued => '재개가 이미 대기열에 있습니다';

  @override
  String get resumeQueuedForReconnect => '재개를 재연결 대기열에 추가했습니다';

  @override
  String get pendingActionWillCreateOnReconnect => 'Bridge가 재연결되면 생성합니다';

  @override
  String get pendingActionWillResumeOnReconnect => 'Bridge가 재연결되면 재개합니다';

  @override
  String get pendingActionStatus => '대기 중';

  @override
  String get tooltipCancelPendingAction => '대기 중인 작업 취소';

  @override
  String get queuedLocally => '로컬에서 대기 중';

  @override
  String get offlinePendingNewSessionTitle => '새 세션 대기 중';

  @override
  String get offlinePendingResumeTitle => '재개 대기 중';

  @override
  String diffLines(int count) {
    return 'diff $count줄';
  }

  @override
  String changedLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '변경된 줄 $count개',
      one: '변경된 줄 $count개',
    );
    return '$_temp0';
  }

  @override
  String hunkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '변경 블록 $count개',
      one: '변경 블록 $count개',
    );
    return '$_temp0';
  }

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 $count개',
      one: '파일 $count개',
    );
    return '$_temp0';
  }

  @override
  String get tapInterruptHoldStop => '탭: 중단, 길게 누르기: 정지';

  @override
  String get rewind => '되돌리기';

  @override
  String get rewindToHere => '여기로 되돌리기';

  @override
  String get rewindModeConversationAndCode => '대화와 코드 복원';

  @override
  String get rewindModeConversationOnly => '대화만 복원';

  @override
  String get rewindModeCodeOnly => '코드만 복원';

  @override
  String get rewindConfirmTitle => '되돌리기 확인';

  @override
  String rewindConfirmBody(Object mode) {
    return '모드: $mode\n\n이 작업은 취소할 수 없습니다. 계속할까요?';
  }

  @override
  String get rewindCannotRewindFiles => '파일을 되돌릴 수 없습니다';

  @override
  String get codexRewindConfirmTitle => '대화를 되돌릴까요?';

  @override
  String get codexRewindConfirmBody =>
      '채팅을 이 메시지 직전으로 복원하고, 메시지를 입력창에 다시 넣습니다. 파일 변경 사항은 그대로 유지됩니다.';

  @override
  String get fork => '분기';

  @override
  String get forkConversation => '대화 분기';

  @override
  String get forkConversationTitle => '대화를 분기할까요?';

  @override
  String get forkConversationBody =>
      '이 응답 시점에서 새 Codex 세션을 만듭니다. 현재 세션은 변경되지 않습니다.';

  @override
  String get forkTargetNotFound => '분기할 사용자 메시지를 찾을 수 없습니다';

  @override
  String get tapToRetry => '탭하여 재시도';

  @override
  String diffSummaryAddedRemoved(int added, int removed) {
    return '+$added/-$removed줄';
  }

  @override
  String lineCountSummary(int count) {
    return '$count줄';
  }

  @override
  String get toolResult => '도구 결과';

  @override
  String get answered => '응답 완료';

  @override
  String agentIsAsking(Object agent) {
    return '$agent 질문 중';
  }

  @override
  String get submitAllAnswers => '모든 답변 제출';

  @override
  String submitWithCount(int count) {
    return '제출($count개 선택)';
  }

  @override
  String get selectOptionsToSubmit => '제출할 옵션 선택';

  @override
  String get typeYourAnswer => '답변을 입력하세요...';

  @override
  String get orTypeCustomAnswer => '또는 직접 답변 입력...';

  @override
  String get otherAnswer => '기타 답변...';

  @override
  String get selectAllThatApply => '해당하는 항목 모두 선택';

  @override
  String get noScreenshotsYet => '아직 스크린샷 없음';

  @override
  String get screenshotButtonHint => '채팅 도구 모음의 스크린샷 버튼으로 캡처하세요.';

  @override
  String get screenshotsWillAppearHere => 'Claude 세션의 스크린샷이 여기에 표시됩니다.';

  @override
  String allWithCount(int count) {
    return '전체 ($count)';
  }

  @override
  String get noImages => '이미지 없음';

  @override
  String get failedToDeleteImage => '이미지 삭제 실패';

  @override
  String get failedToDownloadImage => '이미지 다운로드 실패';

  @override
  String get failedToShareImage => '이미지 공유 실패';

  @override
  String get deleteScreenshot => '스크린샷을 삭제할까요?';

  @override
  String get cannotBeUndone => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get changes => '변경 사항';

  @override
  String get refresh => '새로고침';

  @override
  String get diffCompareSideBySide => '나란히';

  @override
  String get diffCompareSlider => '슬라이더';

  @override
  String get diffCompareOverlay => '오버레이';

  @override
  String get diffCompareToggle => '토글';

  @override
  String get diffBefore => '이전';

  @override
  String get diffAfter => '이후';

  @override
  String get diffNewFile => '새 파일';

  @override
  String get diffDeleted => '삭제됨';

  @override
  String get diffNoImage => '이미지 없음';

  @override
  String get noChanges => '변경 없음';

  @override
  String get showAll => '모두 보기';

  @override
  String get setupGuideTitle => '설정 가이드';

  @override
  String get guideAboutTitle => 'CC Pocket이란?';

  @override
  String get guideAboutDescription =>
      'Bridge Server를 통해 스마트폰에서 Codex와 Claude를 사용할 수 있는 모바일 클라이언트입니다.';

  @override
  String get guideAboutSdkNoteTitle => 'Claude Agent SDK에 대해';

  @override
  String get guideAboutSdkNoteBody =>
      'Claude Code의 라이브러리 버전입니다. .claude 및 CLAUDE.md 같은 기록과 프로젝트 설정 파일을 공유할 수 있으며 승인 흐름도 거의 동일합니다.';

  @override
  String get guideAboutDiagramTitle => '작동 방식';

  @override
  String get guideAboutDiagramPhone => 'iPhone';

  @override
  String get guideAboutDiagramBridge => 'Bridge 서버';

  @override
  String get guideAboutDiagramClaude => 'Codex CLI\n/ Claude Agent SDK';

  @override
  String get guideAboutDiagramCaption =>
      'PC의 Bridge 서버가 Codex CLI와 Claude Agent SDK에 연결되고,\n휴대폰은 Bridge에 연결됩니다.';

  @override
  String get guideBridgeTitle => 'Bridge 서버\n설정';

  @override
  String get guideBridgeDescription =>
      'PC에서 Bridge 서버를 시작하세요. Claude를 사용하려면 ANTHROPIC_API_KEY도 설정하세요.';

  @override
  String get guideBridgePrerequisites => '필수 조건';

  @override
  String get guideBridgePrereq1 => 'Node.js가 설치된 Mac / PC';

  @override
  String get guideBridgePrereq2 => 'Claude를 사용한다면 ANTHROPIC_API_KEY 설정';

  @override
  String get guideBridgePrereq3 => 'Codex를 사용한다면 Codex 인증 완료';

  @override
  String get guideBridgeStep1 => 'npx로 실행(권장)';

  @override
  String get guideBridgeStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get guideBridgeStep2 => '또는 전역 설치';

  @override
  String get guideBridgeStep2Command =>
      'npm install -g @ccpocket/bridge\nccpocket-bridge';

  @override
  String get guideBridgeQrNote => '시작하면 터미널에 QR 코드가 표시됩니다';

  @override
  String get guideConnectionTitle => '연결 방법';

  @override
  String get guideConnectionDescription => '같은 Wi-Fi 네트워크에 있으면 바로 연결할 수 있습니다.';

  @override
  String get guideConnectionQr => 'QR 코드 스캔';

  @override
  String get guideConnectionQrDescription =>
      '터미널에 표시된 QR 코드를 스캔하세요. 가장 쉬운 방법입니다.';

  @override
  String get guideConnectionMdns => '자동 검색(mDNS)';

  @override
  String get guideConnectionMdnsDescription => '같은 LAN의 Bridge 서버를 자동으로 찾습니다.';

  @override
  String get guideConnectionManual => '수동 입력';

  @override
  String get guideConnectionManualDescription =>
      'ws://<IP address>:8765 형식으로 직접 입력합니다.';

  @override
  String get guideConnectionRecommended => '권장';

  @override
  String get guideTailscaleTitle => '원격 접속';

  @override
  String get guideTailscaleDescription =>
      '집 밖에서 사용하려면 Tailscale(VPN)로 안전하게 원격 연결할 수 있습니다.';

  @override
  String get guideTailscaleStep1 => 'Mac과 iPhone 모두에 Tailscale 설치';

  @override
  String get guideTailscaleStep2 => '같은 계정으로 로그인';

  @override
  String get guideTailscaleStep3 =>
      'Bridge URL에 Tailscale IP 사용\n(예: ws://100.x.x.x:8765)';

  @override
  String get guideTailscaleWebsite => 'Tailscale 웹사이트';

  @override
  String get guideTailscaleWebsiteHint => '자세한 설정 방법은 공식 사이트를 확인하세요.';

  @override
  String get guideLaunchdTitle => '자동 시작 설정';

  @override
  String get guideLaunchdDescription =>
      'Bridge 서버를 매번 직접 시작하기 번거롭다면 컴퓨터 부팅 시 자동으로 시작되도록 설정할 수 있습니다.';

  @override
  String get guideLaunchdCommand => '설정 명령';

  @override
  String get guideLaunchdCommandValue =>
      'npx --yes @ccpocket/bridge@latest setup';

  @override
  String get guideLaunchdRecommendation =>
      '먼저 수동 시작으로 확인한 뒤 안정되면 서비스로 등록하는 것을 권장합니다.';

  @override
  String get guideAutostartMacDescription =>
      'launchd에 등록합니다. 셸 환경(nvm, Homebrew 등)이 자동으로 상속됩니다.';

  @override
  String get guideAutostartLinuxDescription =>
      'systemd 사용자 서비스를 만듭니다. Raspberry Pi 및 다른 Linux 호스트에서 작동합니다.';

  @override
  String get guideReadyTitle => '준비 완료!';

  @override
  String get guideReadyDescription => 'Bridge 서버를 시작하고\nQR 코드를 스캔하여\n시작하세요.';

  @override
  String get guideReadyStart => '시작하기';

  @override
  String get guideReadyHint => '이 가이드는 설정에서 언제든 다시 볼 수 있습니다.';

  @override
  String get creatingSession => '세션 생성 중...';

  @override
  String get copyForAgent => '에이전트용 복사';

  @override
  String get messageHistory => '메시지 기록';

  @override
  String get viewChanges => '변경 사항 보기';

  @override
  String get screenshot => '스크린샷';

  @override
  String get debug => '디버그';

  @override
  String get logs => '로그';

  @override
  String get viewApplicationLogs => '애플리케이션 로그 보기';

  @override
  String get mockPreview => '모의 미리보기';

  @override
  String get viewMockChatScenarios => '모의 채팅 시나리오 보기';

  @override
  String get updateTrack => '업데이트 트랙';

  @override
  String get updateTrackDescription => '변경 적용을 위해 앱을 재시작하세요';

  @override
  String get updateTrackStable => 'Stable';

  @override
  String get updateTrackStaging => 'Staging';

  @override
  String get updateDownloaded => '업데이트가 다운로드되었습니다. 적용하려면 앱을 재시작하세요.';

  @override
  String get promptHistory => '프롬프트 기록';

  @override
  String get frequent => '자주 사용';

  @override
  String get recent => '최근';

  @override
  String get searchHint => '검색...';

  @override
  String get noMatchingPrompts => '일치하는 프롬프트 없음';

  @override
  String get noPromptHistoryYet => '아직 프롬프트 기록 없음';

  @override
  String get promptHistoryFilters => '필터';

  @override
  String get promptHistoryFilterThisDevice => '이 기기에서 사용한 기록';

  @override
  String get promptHistoryFilterThisProject => '열려 있는 프로젝트';

  @override
  String get promptHistoryFilterThisBridge => '연결된 Bridge';

  @override
  String get promptHistoryFilterFavorites => '즐겨찾기';

  @override
  String get promptHistoryFilterCommands => '명령 및 스킬';

  @override
  String get promptHistoryOpenProjectEmptyHint =>
      '열려 있는 프로젝트 필터는 새 앱에서 기록한 내역에만 적용됩니다.';

  @override
  String get promptHistorySectionTitle => '프롬프트 기록';

  @override
  String get promptHistorySyncTitle => '프롬프트 기록 동기화';

  @override
  String get promptHistoryReplaceTitle => '이전 방식 기록으로 Bridge 덮어쓰기';

  @override
  String get promptHistoryReplaceSubtitle =>
      '이전 방식 기록은 앱에서 관리했습니다. 새 방식은 Bridge에서 기록을 관리합니다. 기본 기기에서 이미 마이그레이션했다면 보통 필요하지 않습니다. 보조 기기에서 Bridge 기록을 실수로 초기화한 경우, 연결된 Bridge 기록을 이 기기의 이전 방식 기록으로 덮어씁니다.';

  @override
  String get promptHistoryReplaceConfirmAction => '덮어쓰기';

  @override
  String get promptHistoryReplaceDismissAction => '이미 마이그레이션함';

  @override
  String get promptHistoryNotSyncedYet => '아직 동기화되지 않음';

  @override
  String promptHistoryLatestSync(String time) {
    return '마지막 동기화: $time';
  }

  @override
  String promptHistorySyncedBridges(int count) {
    return '$count개 Bridge 동기화됨';
  }

  @override
  String promptHistorySyncSummaryWithFailures(int synced, int failed) {
    return '$synced개 동기화, $failed개 실패';
  }

  @override
  String promptHistoryBridgeId(String id) {
    return 'Bridge ID: $id';
  }

  @override
  String promptHistoryOtherBridgeRegistrations(String registrations) {
    return '다른 등록: $registrations';
  }

  @override
  String get promptHistoryNoSyncTime => '동기화 시간 없음';

  @override
  String get approvalQueue => '승인 대기열';

  @override
  String get resetQueue => '대기열 초기화';

  @override
  String get swipeSkip => '건너뛰기';

  @override
  String get swipeSend => '보내기';

  @override
  String get swipeDismiss => '닫기';

  @override
  String get swipeApprove => '승인';

  @override
  String get swipeReject => '거부';

  @override
  String get allClear => '모두 완료!';

  @override
  String itemsProcessed(int count) {
    return '$count개 처리됨';
  }

  @override
  String bestStreak(int count) {
    return '최고 연속 기록: $count';
  }

  @override
  String get tryAgain => '다시 시도';

  @override
  String get waitingForTasks => '작업 대기 중';

  @override
  String get agentReadyForPrompt => '에이전트가 다음 프롬프트를 기다리고 있습니다.';

  @override
  String get backToSessions => '세션으로 돌아가기';

  @override
  String get working => '작업 중...';

  @override
  String get waitingForApprovalRequests => '에이전트의 승인 요청을 기다리는 중입니다.';

  @override
  String get noActiveSessions => '활성 세션 없음';

  @override
  String get startSessionToBegin => '승인 요청을 받으려면 세션을 시작하세요.';

  @override
  String get settingsTitle => '설정';

  @override
  String get sectionGeneral => '일반';

  @override
  String get sectionConnectionAccounts => '연결 및 계정';

  @override
  String get sectionNotifications => '알림';

  @override
  String get sectionSupport => '후원';

  @override
  String get sectionEditor => '편집기';

  @override
  String get textDensity => '텍스트 밀도';

  @override
  String get textDensityDescription =>
      '시스템 텍스트 크기에 앱 배율을 곱합니다. 100%는 OS 설정을 그대로 유지합니다.';

  @override
  String get indentSize => '들여쓰기 크기';

  @override
  String get indentSizeSubtitle => '목록 들여쓰기 공백 수';

  @override
  String get gitDiffInteractionMode => 'Git diff 제스처';

  @override
  String get gitDiffQuickActions => '빠른 작업';

  @override
  String get gitDiffQuickActionsDescription =>
      '한 손가락으로 가로 스와이프해 변경 블록을 stage, unstage 또는 revert합니다. 긴 줄은 줄바꿈됩니다.';

  @override
  String get gitDiffScrollFirst => '먼저 스크롤';

  @override
  String get gitDiffScrollFirstDescription =>
      '변경 블록 단위로 가로 스크롤할 수 있도록 긴 줄은 줄바꿈하지 않습니다. Git 작업은 길게 누르기 메뉴나 하단 버튼을 사용하세요.';

  @override
  String get remoteGitStatusBadge => '동기화되지 않은 Git 커밋을 연한 배지로 표시';

  @override
  String get remoteGitStatusBadgeDescription =>
      'fetch 후 현재 브랜치에 push 또는 pull 가능한 커밋이 있으면 세션 화면의 Git 버튼에 연한 배지를 표시합니다.';

  @override
  String get sectionAbout => '정보';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get appIconTitle => '앱 아이콘';

  @override
  String get appIconMonthlySupporterPerk => '월간 Supporter 혜택입니다.';

  @override
  String appIconSettingsSubtitle(String device) {
    return '$device 홈 화면에 표시되는 아이콘을 변경할 수 있습니다.';
  }

  @override
  String get appIconSupporterDialogTitle => '월간 Supporter 혜택';

  @override
  String get appIconSupporterSectionLabel => '월간 Supporter 혜택';

  @override
  String get appIconPickerTitle => '앱 아이콘 선택';

  @override
  String get appIconPickerSubtitle => '홈 화면에 표시할 아이콘을 선택하세요.';

  @override
  String get appIconOptionDefaultTitle => '다크';

  @override
  String get appIconOptionDefaultSubtitle => '표준 CC Pocket 아이콘입니다.';

  @override
  String get appIconOptionLightOutlineTitle => '라이트';

  @override
  String get appIconOptionLightOutlineSubtitle => '밝은 외곽선이 있는 더 밝은 변형입니다.';

  @override
  String get appIconOptionCopperEmeraldTitle => '메탈릭';

  @override
  String get appIconOptionCopperEmeraldSubtitle => '광택 마감의 특별 에디션입니다.';

  @override
  String get language => '언어';

  @override
  String get languageSystem => '시스템 기본값';

  @override
  String get voiceInput => '음성 입력';

  @override
  String get pushNotifications => '푸시 알림';

  @override
  String get pushNotificationsSubtitle => 'Bridge를 통해 세션 알림 받기';

  @override
  String get pushNotificationsUnavailable => 'Firebase 설정 후 사용 가능';

  @override
  String get version => '버전';

  @override
  String get loading => '로딩 중...';

  @override
  String get setupGuideSubtitle => '처음이라면 여기서 시작하세요';

  @override
  String get openSourceLicenses => '오픈소스 라이선스';

  @override
  String get githubRepository => 'GitHub 저장소';

  @override
  String get changelog => '변경 로그';

  @override
  String get changelogTitle => '변경 로그';

  @override
  String get showAllMain => '모두 보기(main)';

  @override
  String get changelogFetchError => '변경 로그를 불러오지 못했습니다';

  @override
  String get fcmBridgeNotInitialized => 'Bridge가 초기화되지 않음';

  @override
  String get fcmTokenFailed => 'FCM 토큰을 가져오지 못했습니다';

  @override
  String get fcmEnabled => '알림 활성화됨';

  @override
  String get fcmEnabledPending => 'Bridge 재연결 후 등록됩니다';

  @override
  String get fcmDisabled => '알림 비활성화됨';

  @override
  String get fcmDisabledPending => 'Bridge 재연결 후 등록 해제됩니다';

  @override
  String get pushPrivacyMode => '개인정보 보호 모드';

  @override
  String get pushPrivacyModeSubtitle => '알림에서 프로젝트 이름과 내용을 숨깁니다';

  @override
  String get updateNotificationLanguage => '알림 언어 업데이트';

  @override
  String get notificationLanguageUpdated => '알림 언어가 업데이트됨';

  @override
  String get defaultNotRecommended => '기본값(권장하지 않음)';

  @override
  String get imageAttached => '이미지 첨부됨';

  @override
  String get usageConnectToView => '사용량을 보려면 Bridge에 연결하세요';

  @override
  String get usageFetchFailed => '가져오기 실패';

  @override
  String get usageFiveHour => '5시간';

  @override
  String get usageSevenDay => '7일';

  @override
  String get settingsUsageSectionTitle => '사용량';

  @override
  String get settingsUsageNoCodexData => 'Codex 사용량 데이터를 찾을 수 없습니다.';

  @override
  String get usageDisplayModeRemaining => '남은 양';

  @override
  String get usageDisplayModeUsed => '사용량';

  @override
  String get settingsClaudeUsageDescription => '브라우저에서 Claude 공식 결제 페이지를 엽니다.';

  @override
  String get settingsClaudeApiBilling => 'API 키 결제';

  @override
  String get settingsClaudeSubscriptionUsage => '구독 사용량';

  @override
  String get settingsNewSessionTabs => '새 세션 탭';

  @override
  String get settingsNewSessionTabsDescription => '새 세션에 표시할 AI 도구와 순서를 선택하세요.';

  @override
  String get showBridgeNameInSessionList => 'Bridge 이름 표시';

  @override
  String get showBridgeNameInSessionListSubtitle =>
      '여러 Bridge가 등록되어 있을 때 세션 목록에 연결된 Bridge 이름을 표시합니다.';

  @override
  String get autoRenameCodexSessions => '자동 Rename (Codex)';

  @override
  String get autoRenameCodexSessionsSubtitle =>
      '첫 에이전트 응답 후 Codex 세션 이름을 자동으로 지정합니다';

  @override
  String get autoRenameClaudeSessions => '자동 Rename (Claude)';

  @override
  String get autoRenameClaudeSessionsSubtitle =>
      '첫 에이전트 응답 후 Claude 세션 이름을 자동으로 지정합니다. API Key 결제 사용 시 추가 종량 요금이 발생합니다.';

  @override
  String get newSessionTabCodex => 'Codex';

  @override
  String get newSessionTabClaudeCode => 'Claude';

  @override
  String usageResetAt(String time) {
    return '초기화: $time';
  }

  @override
  String get usageAlreadyReset => '이미 초기화됨';

  @override
  String attachedImages(int count) {
    return '첨부 이미지 ($count)';
  }

  @override
  String get attachedImagesNoCount => '첨부 이미지';

  @override
  String get failedToFetchImages => '이미지를 가져올 수 없음';

  @override
  String get responseTimedOut => '응답 시간 초과';

  @override
  String failedToFetchImagesWithError(String error) {
    return '이미지 가져오기 실패: $error';
  }

  @override
  String get retry => '재시도';

  @override
  String get clipboardNotAvailable => '클립보드를 사용할 수 없습니다';

  @override
  String get failedToLoadImage => '이미지 로드 실패';

  @override
  String get noImageInClipboard => '클립보드에 이미지가 없습니다';

  @override
  String get failedToReadClipboard => '클립보드 읽기 실패';

  @override
  String imageLimitReached(int max) {
    return '최대 $max개 이미지까지 허용됩니다';
  }

  @override
  String imageLimitTruncated(int max, int dropped) {
    return '처음 $max개 이미지만 첨부됨($dropped개 제외)';
  }

  @override
  String get selectFromGallery => '갤러리에서 선택';

  @override
  String get pasteFromClipboard => '클립보드에서 붙여넣기';

  @override
  String get voiceInputLanguage => '음성 입력 언어';

  @override
  String get hideVoiceInput => '음성 입력 버튼 숨기기';

  @override
  String get hideVoiceInputSubtitle => '타사 음성 입력 키보드를 사용할 때 유용합니다';

  @override
  String get archive => '보관';

  @override
  String get archiveConfirm => '이 세션을 보관할까요?';

  @override
  String get archiveConfirmMessage =>
      '이 세션은 목록에서 숨겨집니다. Claude Code에서는 계속 열 수 있습니다.';

  @override
  String get sessionArchived => '세션이 보관됨';

  @override
  String get archiveFailed => '세션 보관 실패';

  @override
  String archiveFailedWithError(String error) {
    return '세션 보관 실패: $error';
  }

  @override
  String get noRecentSessions => '최근 세션 없음';

  @override
  String get noSessionsMatchFilters => '현재 필터와 일치하는 세션 없음';

  @override
  String get adjustFiltersAndSearch => '필터나 검색어를 변경해 보세요';

  @override
  String get tooltipDisplayMode => '카드에 표시할 메시지 변경';

  @override
  String get tooltipProviderFilter => 'AI 도구로 필터';

  @override
  String get tooltipProjectFilter => '프로젝트로 필터';

  @override
  String get tooltipNamedOnly => '이름을 붙인 세션만';

  @override
  String get tooltipIndent => '들여쓰기 증가';

  @override
  String get tooltipDedent => '들여쓰기 감소';

  @override
  String get tooltipSlashCommand => '명령 또는 스킬 삽입';

  @override
  String get tooltipMention => '파일 또는 플러그인 멘션';

  @override
  String get tooltipDollarMention => '스킬 또는 앱 삽입';

  @override
  String get tooltipPermissionMode => '권한 모드';

  @override
  String get tooltipAttachImage => '이미지 첨부';

  @override
  String get tooltipPromptHistory => '프롬프트 기록 열기';

  @override
  String get tooltipVoiceInput => '음성 입력 시작';

  @override
  String get tooltipStopRecording => '녹음 중지';

  @override
  String get tooltipSendMessage => '메시지 보내기';

  @override
  String get tooltipRemoveImage => '이미지 제거';

  @override
  String get tooltipClearDiff => 'diff 선택 지우기';

  @override
  String get showMore => '더 보기';

  @override
  String get showLess => '접기';

  @override
  String get authErrorTitle => 'Claude 로그인이 필요합니다';

  @override
  String get authErrorBody => 'Bridge 컴퓨터에서 Claude에 다시 로그인해야 합니다.';

  @override
  String get authErrorPrimaryCommandLabel => '1단계';

  @override
  String get authErrorSecondaryCommandLabel => '2단계';

  @override
  String get authErrorAlternativeLabel => '셸 대안';

  @override
  String get apiKeyRequiredTitle => 'API 키 필요';

  @override
  String get apiKeyRequiredBody =>
      'Anthropic의 현재 Claude Agent SDK 문서는 타사 제품의 Claude 구독 로그인을 허용하지 않습니다. 대신 API 키를 사용하세요.';

  @override
  String get apiKeyRequiredHint => 'API 키 받기:';

  @override
  String get authHelpTitle => '인증 문제 해결';

  @override
  String get authHelpFetchError => '문제 해결 가이드를 불러오지 못했습니다';

  @override
  String get authHelpButton => '단계 보기';

  @override
  String get authHelpLanguageJa => '日本語';

  @override
  String get authHelpLanguageEn => 'English';

  @override
  String get authHelpLanguageZhHans => '简体中文';

  @override
  String get authHelpLanguageKo => '한국어';

  @override
  String get terminalApp => '터미널 앱';

  @override
  String get terminalAppSubtitle => '외부 터미널 앱에서 프로젝트 열기';

  @override
  String get terminalAppNone => '설정되지 않음';

  @override
  String get terminalAppCustom => '사용자 지정';

  @override
  String get terminalAppName => '앱 이름';

  @override
  String get terminalUrlTemplate => 'URL 템플릿';

  @override
  String get terminalUrlTemplateHint => '변수: host, user, port, project_path';

  @override
  String get terminalSshUser => 'SSH 사용자';

  @override
  String get terminalSshUserHint => '기본값은 컴퓨터의 SSH 사용자';

  @override
  String get openInTerminal => '터미널에서 열기';

  @override
  String get terminalAppNotInstalled => '터미널 앱을 열 수 없습니다';

  @override
  String get terminalAppExperimental => '미리보기';

  @override
  String get terminalAppExperimentalNote =>
      '이 기능은 미리보기입니다. 프리셋이 모든 앱이나 구성에서 작동하지 않을 수 있습니다. 새 프리셋 기여는 GitHub에서 환영합니다!';

  @override
  String get sectionSpread => 'CC Pocket이 마음에 드시나요?';

  @override
  String get spreadAppealMessage =>
      'CC Pocket은 아직 사용자층이 작아, 더 많은 사용자 없이는 지속적인 개발이 어렵습니다. 마음에 드신다면 스토어 평점이나 지인에게 공유해 주시면 큰 도움이 됩니다.';

  @override
  String get shareApp => '친구와 공유';

  @override
  String get shareAppSubtitle => '친구와 동료에게 알려주세요';

  @override
  String shareText(String url) {
    return 'CC Pocket: Claude & Codex\n휴대폰에서 코딩 에이전트를 제어하세요 📱\n#ccpocket\n$url';
  }

  @override
  String get starOnGithub => 'GitHub에서 Star';

  @override
  String get rateOnStore => 'App Store에서 평가';

  @override
  String get rateOnStoreAndroid => 'Google Play에서 평가';

  @override
  String get supporterTitle => 'Supporter';

  @override
  String get supporterMonthlyTitle => '월간 Supporter';

  @override
  String get supporterCoffeeTitle => '음료 한 잔 후원';

  @override
  String get supporterLunchTitle => '점심 후원';

  @override
  String get supporterStatusActive => 'CC Pocket을 후원해 주셔서 감사합니다.';

  @override
  String get supporterStatusInactive =>
      'CC Pocket은 계속 무료로 사용할 수 있습니다. 여기에서 지속적인 개발을 후원할 수 있습니다.';

  @override
  String get supporterStatusLoading => 'Supporter 상태 확인 중...';

  @override
  String get supportEntryInactiveTitle => '후원';

  @override
  String get supportEntryInactiveSubtitle =>
      'CC Pocket이 유용했다면 지속적인 개발을 후원해 주세요.';

  @override
  String get supportEntryOneTimeTitle => '후원해 주셔서 감사합니다';

  @override
  String get supportEntryOneTimeSubtitle => 'CC Pocket을 후원해 주셔서 감사합니다.';

  @override
  String get supportEntryActiveTitle => '후원 중';

  @override
  String supportEntryActiveSubtitle(String date) {
    return '$date부터 CC Pocket을 후원 중입니다.';
  }

  @override
  String get supporterMonthlyDescription => '앱을 계속 개선하기 위한 정기 후원입니다.';

  @override
  String get supporterMonthlyPerkLabel => '대체 앱 아이콘 혜택 포함';

  @override
  String get supporterCoffeeDescription => '음료 한 잔을 사주고 싶은 마음이라면 큰 힘이 됩니다.';

  @override
  String get supporterLunchDescription => '점심 한 끼를 사주고 싶은 마음이라면 큰 힘이 됩니다.';

  @override
  String get supporterBuyButton => '후원하기';

  @override
  String get supporterActiveButton => '활성';

  @override
  String get supporterRestoreButton => '복원';

  @override
  String get supporterRetryButton => '재시도';

  @override
  String get supporterProductsUnavailable => '현재 사용할 수 있는 후원 옵션이 없습니다.';

  @override
  String get supporterRestoreNoticeTitle => '복원 안내';

  @override
  String get supporterRestoreNoticeBody =>
      '복원은 같은 Apple ID 또는 Google 계정에서 작동합니다. Supporter 상태는 iOS와 Android 간에 공유되지 않습니다.';

  @override
  String get supporterSummaryTitle => '후원 요약';

  @override
  String supporterSummarySinceChip(String date) {
    return '$date부터';
  }

  @override
  String supporterSummaryStreakChip(String duration) {
    return '연속: $duration';
  }

  @override
  String supporterSummaryOneTimeCount(int count) {
    return '일회성 ×$count';
  }

  @override
  String supporterSummaryCoffeeCount(int count) {
    return '음료 ×$count';
  }

  @override
  String supporterSummaryLunchCount(int count) {
    return '점심 ×$count';
  }

  @override
  String get supporterSummaryLessThanMonth => '1개월 미만';

  @override
  String supporterSummaryDurationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개월',
      one: '1개월',
    );
    return '$_temp0';
  }

  @override
  String get supporterSummarySinceLabel => '시작';

  @override
  String get supporterSummaryStreakLabel => '후원 기간';

  @override
  String get supporterSummaryOngoingLabel => '후원 중';

  @override
  String get supporterSummarySupportPeriodLabel => '후원 기간';

  @override
  String get supporterImpactTitle => '후원으로 가능해지는 것';

  @override
  String get supporterImpactBody =>
      'CC Pocket이 마음에 드신다면 지속적인 개발을 후원해 주시면 감사하겠습니다. 앱은 계속 무료 OSS로 유지됩니다.';

  @override
  String get supporterImpactAiTitle => '개발 및 운영 비용';

  @override
  String get supporterImpactAiBody => 'AI 사용량, 기기 확인, 테스트, 배포에는 지속적인 비용이 듭니다.';

  @override
  String get supporterImpactDevicesTitle => '기기 테스트';

  @override
  String get supporterImpactDevicesBody =>
      '휴대폰, 태블릿, 플랫폼 업데이트 전반에서 앱을 안정적으로 유지합니다.';

  @override
  String get supporterImpactMotivationTitle => '계속 만들 수 있는 동력';

  @override
  String get supporterImpactMotivationBody =>
      '앱이 유용하다는 사실은 새 기능과 개선을 계속 배포하는 데 큰 힘이 됩니다.';

  @override
  String get supporterPackagesTitle => '후원 방법 선택';

  @override
  String get supporterSubscriptionGroupTitle => '월간 후원';

  @override
  String get supporterSubscriptionGroupBody => '지속적으로 후원해 주시면 정말 감사하겠습니다.';

  @override
  String get supporterOneTimeGroupTitle => '일회성 후원';

  @override
  String get supporterOneTimeGroupBody =>
      '점심 한 끼나 음료 한 잔을 사주고 싶은 마음이라면 큰 힘이 됩니다.';

  @override
  String get supporterPurchaseInfoTitle => '구매 안내';

  @override
  String get supporterPurchaseInfoBody =>
      '복원은 같은 Apple ID 또는 Google 계정에서 작동합니다. Supporter 상태는 iOS와 Android 간에 공유되지 않습니다.';

  @override
  String get supporterPurchaseInfoLink => '자세히 보기';

  @override
  String get supporterPrivacyPolicyLink => '개인정보 처리방침';

  @override
  String get supporterTermsOfUseLink => '이용 약관(Apple 표준 EULA)';

  @override
  String get supporterLearnMoreTitle => '구매와 후원 안내';

  @override
  String get supporterLearnMoreBody =>
      'CC Pocket이 무료로 유지되는 이유, 복원 방식, Supporter 포함 내용을 확인하세요.';

  @override
  String get supporterOpenLinkFailed => '안내 페이지를 열 수 없습니다.';

  @override
  String get supporterPurchaseSuccess => 'CC Pocket을 후원해 주셔서 감사합니다!';

  @override
  String get supporterPurchaseCancelled => '구매가 취소되었습니다.';

  @override
  String supporterPurchaseFailed(String message) {
    return '구매 실패: $message';
  }

  @override
  String get supporterRestoreSuccess => '구매 정보를 복원했습니다.';

  @override
  String supporterRestoreFailed(String message) {
    return '복원 실패: $message';
  }

  @override
  String get gitDiscardAllChangesTitle => '모든 변경 사항을 버릴까요?';

  @override
  String get gitDiscardVisibleUnstagedChangesMessage =>
      '현재 표시된 모든 스테이징되지 않은 변경 사항을 버립니다.';

  @override
  String get gitDiscardChangeTitle => '이 변경 사항을 버릴까요?';

  @override
  String get gitDiscardFileUnstagedChangesMessage =>
      '이 파일의 모든 스테이징되지 않은 변경 사항을 버립니다.';

  @override
  String get gitDiscardHunkUnstagedChangesMessage =>
      '이 헝크의 스테이징되지 않은 변경 사항을 버립니다.';

  @override
  String get googleSearchSelectionAction => 'Google 검색';

  @override
  String get approvalQuestionNotificationTitle => '질문이 있습니다 - ccpocket';

  @override
  String get approvalRequiredNotificationTitle => '승인 대기 중 - ccpocket';

  @override
  String get exitPlanModeNotificationBody => '작성된 계획을 확인해야 합니다';
}
