// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CC Pocket';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get removeProjectTitle => '移除项目';

  @override
  String removeProjectConfirm(Object name) {
    return '要从最近项目中移除“$name”吗？';
  }

  @override
  String get rename => '重命名';

  @override
  String get renameSession => '重命名会话';

  @override
  String get sessionNameHint => '会话名称';

  @override
  String get clearName => '清除名称';

  @override
  String get connect => '连接';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get lineCopied => '已复制此行';

  @override
  String get start => '开始';

  @override
  String get stop => '停止';

  @override
  String get send => '发送';

  @override
  String get settings => '设置';

  @override
  String get gallery => '图库';

  @override
  String galleryWithCount(int count) {
    return '图库 ($count)';
  }

  @override
  String get disconnect => '断开连接';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get done => '完成';

  @override
  String get skip => '跳过';

  @override
  String get edit => '编辑';

  @override
  String get share => '分享';

  @override
  String get all => '全部';

  @override
  String get none => '无';

  @override
  String get serverUnreachable => '无法连接服务器';

  @override
  String get serverUnreachableBody => '无法访问以下 Bridge 服务器：';

  @override
  String get setupSteps => '设置步骤：';

  @override
  String get setupStep1Title => '启动 Bridge 服务器';

  @override
  String get setupStep1Command => 'npx @ccpocket/bridge@latest';

  @override
  String get setupStep2Title => '如需常驻运行，请注册为服务';

  @override
  String get setupStep2Command => 'npx @ccpocket/bridge@latest setup';

  @override
  String get setupNetworkHint => '请确认两台设备位于同一网络中（或使用 Tailscale）。';

  @override
  String get connectAnyway => '仍然连接';

  @override
  String get stopSession => '停止会话';

  @override
  String get stopSessionConfirm => '要停止此会话吗？Claude 进程将被终止。';

  @override
  String get startNewWithSameSettings => '使用相同设置新建';

  @override
  String get copyResumeCommand => '复制恢复命令';

  @override
  String get copyResumeCommandSubtitle => '交接到 macOS / Linux';

  @override
  String get resumeCommandCopied => '恢复命令已复制';

  @override
  String get editSettingsThenStart => '先修改设置再开始';

  @override
  String get serverRequiresApiKey => '此服务器需要 API 密钥';

  @override
  String get bridgeServerUpdated => 'Bridge 服务已更新';

  @override
  String get failedToUpdateServer => '更新服务器失败';

  @override
  String get bridgeServerStarted => 'Bridge 服务已启动';

  @override
  String get failedToStartServer => '启动服务器失败';

  @override
  String get bridgeServerStopped => 'Bridge 服务已停止';

  @override
  String get failedToStopServer => '停止服务器失败';

  @override
  String get sshPassword => 'SSH 密码';

  @override
  String sshPasswordPrompt(String machineName) {
    return '请输入 $machineName 的 SSH 密码';
  }

  @override
  String get password => '密码';

  @override
  String get deleteMachine => '删除机器';

  @override
  String deleteMachineConfirm(String displayName) {
    return '要删除“$displayName”吗？这会移除所有已保存的凭据。';
  }

  @override
  String get connectToBridgeServer => '连接到 Bridge 服务';

  @override
  String get orConnectManually => '或手动连接';

  @override
  String get serverUrl => '服务器 URL';

  @override
  String get serverUrlHint => 'ws://<host-ip>:8765';

  @override
  String get apiKeyOptional => 'API 密钥（可选）';

  @override
  String get apiKeyHint => '如果没有认证可留空';

  @override
  String get scanQrCode => '扫描二维码';

  @override
  String get setupGuide => '设置指南';

  @override
  String get readyToStart => '准备就绪';

  @override
  String get readyToStartDescription => '点击 + 按钮创建新会话，并开始用 Claude 编码。';

  @override
  String get newSession => '新建会话';

  @override
  String get neverConnected => '从未连接';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String daysAgo(int days) {
    return '$days 天前';
  }

  @override
  String get unfavorite => '取消收藏';

  @override
  String get favorite => '收藏';

  @override
  String get updateBridge => '更新 Bridge';

  @override
  String get stopServer => '停止服务器';

  @override
  String get update => '更新';

  @override
  String get offline => '离线';

  @override
  String get unreachable => '不可达';

  @override
  String get checking => '检查中...';

  @override
  String get recentProjects => '最近项目';

  @override
  String get orEnterPath => '或输入路径';

  @override
  String get projectPath => '项目路径';

  @override
  String get projectPathHint => '/path/to/your/project';

  @override
  String get permission => '权限';

  @override
  String get approval => '审批';

  @override
  String get restart => '重启';

  @override
  String get worktree => '工作树';

  @override
  String get advanced => '高级';

  @override
  String get modelOptional => '模型（可选）';

  @override
  String get effort => 'Effort';

  @override
  String get defaultLabel => '默认';

  @override
  String get maxTurns => '最大轮数';

  @override
  String get maxTurnsHint => '例如：8';

  @override
  String get maxTurnsError => '必须输入大于 0 的整数';

  @override
  String get maxBudgetUsd => '最大预算（USD）';

  @override
  String get maxBudgetHint => '例如：1.00';

  @override
  String get maxBudgetError => '必须输入大于等于 0 的数字';

  @override
  String get fallbackModel => '回退模型';

  @override
  String get forkSessionOnResume => '恢复时分叉会话';

  @override
  String get persistSessionHistory => '保留会话历史';

  @override
  String get model => '模型';

  @override
  String get sandbox => '沙箱';

  @override
  String get reasoning => 'Reasoning';

  @override
  String get webSearch => 'Web Search';

  @override
  String get networkAccess => '网络访问';

  @override
  String get worktreeNew => '新建';

  @override
  String worktreeExisting(int count) {
    return '已有 ($count)';
  }

  @override
  String get branchOptional => '分支（可选）';

  @override
  String get branchHint => 'feature/...';

  @override
  String get noExistingWorktrees => '没有现有 worktree';

  @override
  String get planApprovalSummary => '请查看上方计划，并选择批准或继续规划';

  @override
  String get planApprovalSummaryCard => '请查看计划，并选择批准或继续规划';

  @override
  String get toolApprovalSummary => '执行工具需要批准';

  @override
  String get planApproval => '计划批准';

  @override
  String get approvalRequired => '需要批准';

  @override
  String get viewEditPlan => '查看 / 编辑计划';

  @override
  String get keepPlanning => '继续规划';

  @override
  String get keepPlanningHint => '需要改什么...';

  @override
  String get sendFeedbackKeepPlanning => '发送反馈并继续规划';

  @override
  String get acceptAndClear => '批准并清除';

  @override
  String get acceptPlan => '批准计划';

  @override
  String get reject => '拒绝';

  @override
  String get approve => '批准';

  @override
  String get always => '始终';

  @override
  String get approveOnce => '仅此一次';

  @override
  String get approveForSession => '本次会话期间允许';

  @override
  String get approveAlways => '始终允许';

  @override
  String get approveAlwaysSub => '';

  @override
  String get approveSessionMain => '本次会话允许';

  @override
  String get approveSessionSub => '';

  @override
  String get permissionDefaultDescription => '标准权限提示';

  @override
  String get permissionAcceptEditsDescription => '自动批准文件编辑';

  @override
  String get permissionPlanDescription => '仅分析和规划，不执行';

  @override
  String get permissionBypassDescription => '跳过所有权限提示';

  @override
  String get executionDefaultDescription => '标准权限提示';

  @override
  String get executionAcceptEditsDescription => '自动批准文件编辑';

  @override
  String get executionFullAccessDescription => '跳过大多数审批提示';

  @override
  String get codexPlanModeDescription => '先起草计划，再等待批准后执行';

  @override
  String get sandboxRestrictedDescription => '在受限环境中运行命令';

  @override
  String get sandboxNativeDescription => '在原生环境中运行命令';

  @override
  String get sandboxNativeCautionDescription => '在原生环境中运行命令（谨慎）';

  @override
  String get sheetSubtitleApproval => '控制哪些操作需要你的审批';

  @override
  String get sheetSubtitleSandboxCodex => 'Codex 默认启用沙箱以确保安全。禁用后将允许完全访问系统。';

  @override
  String get sheetSubtitleSandboxClaude => 'Claude Code 默认在原生环境运行。启用沙箱将限制系统访问。';

  @override
  String get sheetSubtitleModel => '不同模型在速度、能力和成本上各有差异。';

  @override
  String get sheetSubtitleEffort => '更高的 Effort 会进行更深入的分析，但需要更多时间和成本。';

  @override
  String get claudeEffortLowDesc => '更快响应，分析较少';

  @override
  String get claudeEffortMediumDesc => '速度与质量的平衡';

  @override
  String get claudeEffortHighDesc => '更深入的分析';

  @override
  String get claudeEffortMaxDesc => '最深入，最慢';

  @override
  String get reasoningEffortMinimalDesc => '最快，分析最少';

  @override
  String get reasoningEffortLowDesc => '更快响应，分析较少';

  @override
  String get reasoningEffortMediumDesc => '速度与质量的平衡';

  @override
  String get reasoningEffortHighDesc => '更深入的分析';

  @override
  String get reasoningEffortXhighDesc => '最深入，最慢';

  @override
  String get changePermissionModeTitle => '更改权限模式';

  @override
  String changePermissionModeBody(String mode) {
    return '切换到 $mode 会重启当前会话。你的对话会被保留。';
  }

  @override
  String get changeExecutionModeTitle => 'Execution Mode を変更';

  @override
  String changeExecutionModeBody(String mode) {
    return '$mode に切り替えるとセッションが再起動します。会話は保持されます。';
  }

  @override
  String get enablePlanModeTitle => '启用 Plan Mode';

  @override
  String get disablePlanModeTitle => '关闭 Plan Mode';

  @override
  String get enablePlanModeBody => '启用 Plan Mode 会重启当前会话。你的对话会被保留。';

  @override
  String get disablePlanModeBody => '关闭 Plan Mode 会重启当前会话。你的对话会被保留。';

  @override
  String get changeSandboxModeTitle => '更改沙箱模式';

  @override
  String changeSandboxModeBody(String mode) {
    return '切换到 $mode 会重启当前会话。你的对话会被保留。';
  }

  @override
  String get messagePlaceholder => '给 Claude 发消息...';

  @override
  String diffLines(int count) {
    return '$count 行 diff';
  }

  @override
  String changedLines(int count) {
    return '$count 行变更';
  }

  @override
  String hunkCount(int count) {
    return '$count 个 hunk';
  }

  @override
  String fileCount(int count) {
    return '$count 个文件';
  }

  @override
  String get tapInterruptHoldStop => '点按：中断，长按：停止';

  @override
  String get rewindToHere => '回退到这里';

  @override
  String get tapToRetry => '点按重试';

  @override
  String diffSummaryAddedRemoved(int added, int removed) {
    return '+$added/-$removed 行';
  }

  @override
  String lineCountSummary(int count) {
    return '$count 行';
  }

  @override
  String get toolResult => '工具结果';

  @override
  String get answered => '已回答';

  @override
  String get claudeIsAsking => 'Claude 正在提问';

  @override
  String get submitAllAnswers => '提交全部答案';

  @override
  String submitWithCount(int count) {
    return '提交（已选择 $count 项）';
  }

  @override
  String get selectOptionsToSubmit => '请选择要提交的选项';

  @override
  String get typeYourAnswer => '输入你的回答...';

  @override
  String get orTypeCustomAnswer => '或输入自定义回答...';

  @override
  String get otherAnswer => '其他回答...';

  @override
  String get selectAllThatApply => '选择所有适用项';

  @override
  String get noScreenshotsYet => '还没有截图';

  @override
  String get screenshotButtonHint => '使用聊天工具栏中的截图按钮来捕获截图。';

  @override
  String get screenshotsWillAppearHere => 'Claude 会话中的截图会显示在这里。';

  @override
  String allWithCount(int count) {
    return '全部 ($count)';
  }

  @override
  String get noImages => '没有图片';

  @override
  String get failedToDeleteImage => '删除图片失败';

  @override
  String get failedToDownloadImage => '下载图片失败';

  @override
  String get failedToShareImage => '分享图片失败';

  @override
  String get deleteScreenshot => '要删除截图吗？';

  @override
  String get cannotBeUndone => '此操作无法撤销。';

  @override
  String get changes => '变更';

  @override
  String get refresh => '刷新';

  @override
  String get diffCompareSideBySide => '并排';

  @override
  String get diffCompareSlider => '滑块';

  @override
  String get diffCompareOverlay => '叠加';

  @override
  String get diffCompareToggle => '切换';

  @override
  String get diffBefore => '变更前';

  @override
  String get diffAfter => '变更后';

  @override
  String get diffNewFile => '新文件';

  @override
  String get diffDeleted => '已删除';

  @override
  String get diffNoImage => '没有图片';

  @override
  String get noChanges => '没有变更';

  @override
  String get showAll => '显示全部';

  @override
  String get setupGuideTitle => '设置指南';

  @override
  String get guideAboutTitle => '什么是 CC Pocket？';

  @override
  String get guideAboutDescription =>
      '一款可让你通过智能手机控制 Claude Code 和 Codex 的移动客户端。';

  @override
  String get guideAboutDiagramTitle => '工作方式';

  @override
  String get guideAboutDiagramPhone => 'iPhone';

  @override
  String get guideAboutDiagramBridge => 'Bridge 服务';

  @override
  String get guideAboutDiagramClaude => 'Claude CLI\n/ Codex';

  @override
  String get guideAboutDiagramCaption => '先在你的电脑上启动 Bridge 服务，\n然后从手机连接。';

  @override
  String get guideBridgeTitle => 'Bridge 服务\n设置';

  @override
  String get guideBridgeDescription => '先在你的电脑上启动 Bridge 服务。';

  @override
  String get guideBridgePrerequisites => '前置条件';

  @override
  String get guideBridgePrereq1 => '已安装 Node.js 的 Mac / PC';

  @override
  String get guideBridgePrereq2 => 'Claude Code CLI 或 Codex CLI\n（二选一即可）';

  @override
  String get guideBridgeStep1 => '使用 npx 运行（推荐）';

  @override
  String get guideBridgeStep1Command => 'npx @ccpocket/bridge@latest';

  @override
  String get guideBridgeStep2 => '或全局安装';

  @override
  String get guideBridgeStep2Command =>
      'npm install -g @ccpocket/bridge\nccpocket-bridge';

  @override
  String get guideBridgeQrNote => '启动后，终端中会显示二维码';

  @override
  String get guideConnectionTitle => '连接方式';

  @override
  String get guideConnectionDescription => '如果处于同一个 Wi-Fi 网络下，你可以立即连接。';

  @override
  String get guideConnectionQr => '扫描二维码';

  @override
  String get guideConnectionQrDescription => '只需扫描终端中显示的二维码。最简单的方法。';

  @override
  String get guideConnectionMdns => '自动发现（mDNS）';

  @override
  String get guideConnectionMdnsDescription => '自动查找同一局域网中的 Bridge 服务。';

  @override
  String get guideConnectionManual => '手动输入';

  @override
  String get guideConnectionManualDescription =>
      '直接输入 `ws://<IP 地址>:8765` 格式的地址。';

  @override
  String get guideConnectionRecommended => '推荐';

  @override
  String get guideTailscaleTitle => '远程访问';

  @override
  String get guideTailscaleDescription =>
      '如果要在家外使用，Tailscale（VPN）可以帮助你安全地远程连接。';

  @override
  String get guideTailscaleStep1 => '在 Mac 和 iPhone 上都安装 Tailscale';

  @override
  String get guideTailscaleStep2 => '使用同一个账号登录';

  @override
  String get guideTailscaleStep3 =>
      '在 Bridge URL 中使用 Tailscale IP\n（例如：ws://100.x.x.x:8765）';

  @override
  String get guideTailscaleWebsite => 'Tailscale 官网';

  @override
  String get guideTailscaleWebsiteHint => '访问官网获取更详细的设置说明。';

  @override
  String get guideLaunchdTitle => '自动启动设置';

  @override
  String get guideLaunchdDescription =>
      '如果每次手动启动 Bridge 服务太麻烦，你可以将它配置为设备开机时自动启动。';

  @override
  String get guideLaunchdCommand => '设置命令';

  @override
  String get guideLaunchdCommandValue => 'npx @ccpocket/bridge@latest setup';

  @override
  String get guideLaunchdRecommendation => '建议先通过手动启动验证一切正常，再在稳定后注册为服务。';

  @override
  String get guideAutostartMacDescription =>
      '使用 launchd 注册。Shell 环境（nvm、Homebrew 等）会自动继承。';

  @override
  String get guideAutostartLinuxDescription =>
      '创建 systemd 用户服务。适用于 Raspberry Pi 及其他 Linux 主机。';

  @override
  String get guideReadyTitle => '全部就绪！';

  @override
  String get guideReadyDescription => '启动 Bridge 服务并\n扫描二维码，\n马上开始。';

  @override
  String get guideReadyStart => '开始使用';

  @override
  String get guideReadyHint => '你也可以随时在设置中重新打开本指南';

  @override
  String get creatingSession => '正在创建会话...';

  @override
  String get copyForAgent => '复制给 Agent';

  @override
  String get messageHistory => '消息历史';

  @override
  String get viewChanges => '查看变更';

  @override
  String get screenshot => '截图';

  @override
  String get debug => '调试';

  @override
  String get logs => '日志';

  @override
  String get viewApplicationLogs => '查看应用日志';

  @override
  String get mockPreview => 'Mock 预览';

  @override
  String get viewMockChatScenarios => '查看 Mock 聊天场景';

  @override
  String get updateTrack => '更新轨道';

  @override
  String get updateTrackDescription => '更改后重启应用以生效';

  @override
  String get updateTrackStable => '稳定版';

  @override
  String get updateTrackStaging => '预发布版';

  @override
  String get updateDownloaded => '更新已下载。请重启应用以生效。';

  @override
  String get promptHistory => '提示词历史';

  @override
  String get frequent => '常用';

  @override
  String get recent => '最近';

  @override
  String get searchHint => '搜索...';

  @override
  String get noMatchingPrompts => '没有匹配的提示词';

  @override
  String get noPromptHistoryYet => '还没有提示词历史';

  @override
  String get approvalQueue => '审批队列';

  @override
  String get resetQueue => '重置队列';

  @override
  String get swipeSkip => '跳过';

  @override
  String get swipeSend => '发送';

  @override
  String get swipeDismiss => '忽略';

  @override
  String get swipeApprove => '批准';

  @override
  String get swipeReject => '拒绝';

  @override
  String get allClear => '全部处理完！';

  @override
  String itemsProcessed(int count) {
    return '已处理 $count 项';
  }

  @override
  String bestStreak(int count) {
    return '最佳连击：$count';
  }

  @override
  String get tryAgain => '再试一次';

  @override
  String get waitingForTasks => '正在等待任务';

  @override
  String get agentReadyForPrompt => 'Agent 已准备好接收你的下一个提示。';

  @override
  String get backToSessions => '返回会话列表';

  @override
  String get working => '进行中...';

  @override
  String get waitingForApprovalRequests => '正在等待 Agent 发来的审批请求。';

  @override
  String get noActiveSessions => '没有活动中的会话';

  @override
  String get startSessionToBegin => '启动一个会话后，即可开始接收审批请求。';

  @override
  String get settingsTitle => '设置';

  @override
  String get sectionGeneral => '通用';

  @override
  String get sectionEditor => '编辑器';

  @override
  String get indentSize => '缩进大小';

  @override
  String get indentSizeSubtitle => '列表缩进使用的空格数';

  @override
  String get sectionAbout => '关于';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get voiceInput => '语音输入';

  @override
  String get pushNotifications => '推送通知';

  @override
  String get pushNotificationsSubtitle => '通过 Bridge 接收会话通知';

  @override
  String get pushNotificationsUnavailable => '完成 Firebase 设置后可用';

  @override
  String get version => '版本';

  @override
  String get loading => '加载中...';

  @override
  String get setupGuideSubtitle => '第一次使用？从这里开始';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get githubRepository => 'GitHub 仓库';

  @override
  String get changelog => '更新日志';

  @override
  String get changelogTitle => '更新日志';

  @override
  String get showAllMain => '显示全部（main）';

  @override
  String get changelogFetchError => '加载更新日志失败';

  @override
  String get fcmBridgeNotInitialized => 'Bridge 尚未初始化';

  @override
  String get fcmTokenFailed => '获取 FCM Token 失败';

  @override
  String get fcmEnabled => '通知已启用';

  @override
  String get fcmEnabledPending => 'Bridge 重新连接后将自动注册';

  @override
  String get fcmDisabled => '通知已禁用';

  @override
  String get fcmDisabledPending => 'Bridge 重新连接后将自动取消注册';

  @override
  String get pushPrivacyMode => '隐私模式';

  @override
  String get pushPrivacyModeSubtitle => '在通知中隐藏项目名称和内容';

  @override
  String get updateNotificationLanguage => '更新通知语言';

  @override
  String get notificationLanguageUpdated => '通知语言已更新';

  @override
  String get defaultNotRecommended => '默认（不推荐）';

  @override
  String get imageAttached => '图片已附加';

  @override
  String get sectionBackup => '备份';

  @override
  String get backupPromptHistory => '备份提示词历史';

  @override
  String get restorePromptHistory => '恢复提示词历史';

  @override
  String get backupSuccess => '备份完成';

  @override
  String backupFailed(String error) {
    return '备份失败：$error';
  }

  @override
  String get restoreSuccess => '恢复完成';

  @override
  String restoreFailed(String error) {
    return '恢复失败：$error';
  }

  @override
  String get restoreConfirmTitle => '恢复提示词历史';

  @override
  String get restoreConfirmMessage => '这将使用备份替换本地所有提示词历史，且无法撤销。';

  @override
  String get restoreConfirmButton => '恢复';

  @override
  String get noBackupFound => '未找到备份';

  @override
  String backupInfo(String date) {
    return '上次备份：$date';
  }

  @override
  String backupVersionInfo(String version, String size) {
    return 'v$version · $size';
  }

  @override
  String get connectToBackup => '连接到 Bridge 后才能使用备份';

  @override
  String get usageConnectToView => '连接到 Bridge 后查看用量';

  @override
  String get usageFetchFailed => '获取失败';

  @override
  String get usageFiveHour => '5 小时';

  @override
  String get usageSevenDay => '7 天';

  @override
  String usageResetAt(String time) {
    return '重置时间：$time';
  }

  @override
  String get usageAlreadyReset => '已重置';

  @override
  String attachedImages(int count) {
    return '已附加图片 ($count)';
  }

  @override
  String get attachedImagesNoCount => '已附加图片';

  @override
  String get failedToFetchImages => '无法获取图片';

  @override
  String get responseTimedOut => '响应超时';

  @override
  String failedToFetchImagesWithError(String error) {
    return '获取图片失败：$error';
  }

  @override
  String get retry => '重试';

  @override
  String get clipboardNotAvailable => '无法访问剪贴板';

  @override
  String get failedToLoadImage => '加载图片失败';

  @override
  String get noImageInClipboard => '剪贴板中没有图片';

  @override
  String get failedToReadClipboard => '读取剪贴板失败';

  @override
  String imageLimitReached(int max) {
    return '最多允许 $max 张图片';
  }

  @override
  String imageLimitTruncated(int max, int dropped) {
    return '仅附加前 $max 张图片（忽略了 $dropped 张）';
  }

  @override
  String get selectFromGallery => '从图库选择';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get voiceInputLanguage => '语音输入语言';

  @override
  String get hideVoiceInput => '隐藏语音输入按钮';

  @override
  String get hideVoiceInputSubtitle => '当你使用第三方语音输入键盘时很有帮助';

  @override
  String get archive => '归档';

  @override
  String get archiveConfirm => '要归档此会话吗？';

  @override
  String get archiveConfirmMessage => '此会话会从列表中隐藏，但你仍然可以在 Claude Code 中访问它。';

  @override
  String get sessionArchived => '会话已归档';

  @override
  String get archiveFailed => '归档会话失败';

  @override
  String archiveFailedWithError(String error) {
    return '归档会话失败：$error';
  }

  @override
  String get noRecentSessions => '没有最近会话';

  @override
  String get noSessionsMatchFilters => '没有会话匹配当前筛选条件';

  @override
  String get adjustFiltersAndSearch => '试试修改筛选条件或搜索词';

  @override
  String get tooltipDisplayMode => '切换卡片上显示的消息';

  @override
  String get tooltipProviderFilter => '按 AI 工具筛选';

  @override
  String get tooltipProjectFilter => '按项目筛选';

  @override
  String get tooltipNamedOnly => '只显示你已命名的会话';

  @override
  String get tooltipIndent => '增加缩进';

  @override
  String get tooltipDedent => '减少缩进';

  @override
  String get tooltipSlashCommand => '斜杠命令';

  @override
  String get tooltipMention => '提及文件';

  @override
  String get tooltipPermissionMode => '权限模式';

  @override
  String get tooltipAttachImage => '附加图片';

  @override
  String get tooltipPromptHistory => '提示词历史';

  @override
  String get tooltipVoiceInput => '语音输入';

  @override
  String get tooltipStopRecording => '停止录音';

  @override
  String get tooltipSendMessage => '发送消息';

  @override
  String get tooltipRemoveImage => '移除图片';

  @override
  String get tooltipClearDiff => '清除 diff 选择';

  @override
  String get showMore => '显示更多';

  @override
  String get showLess => '显示更少';

  @override
  String get authErrorTitle => '需要重新登录 Claude';

  @override
  String get authErrorBody => 'Bridge 机器上的 Claude Code 需要重新登录。';

  @override
  String get authErrorPrimaryCommandLabel => '步骤 1';

  @override
  String get authErrorSecondaryCommandLabel => '步骤 2';

  @override
  String get authErrorAlternativeLabel => 'Shell 方式';

  @override
  String get apiKeyRequiredTitle => '需要 API 密钥';

  @override
  String get apiKeyRequiredBody => '由于 Anthropic 策略方面的限制，目前订阅制认证受限。请改用 API 密钥。';

  @override
  String get apiKeyRequiredHint => '在此获取 API 密钥：';

  @override
  String get authHelpTitle => '认证故障排查';

  @override
  String get authHelpFetchError => '加载故障排查指南失败';

  @override
  String get authHelpButton => '查看步骤';

  @override
  String get authHelpLanguageJa => '日本語';

  @override
  String get authHelpLanguageEn => 'English';

  @override
  String get authHelpLanguageZhHans => '简体中文';

  @override
  String get terminalApp => '终端应用';

  @override
  String get terminalAppSubtitle => '在外部终端应用中打开项目';

  @override
  String get terminalAppNone => '未配置';

  @override
  String get terminalAppCustom => '自定义';

  @override
  String get terminalAppName => '应用名称';

  @override
  String get terminalUrlTemplate => 'URL 模板';

  @override
  String get terminalUrlTemplateHint => '变量：host、user、port、project_path';

  @override
  String get terminalSshUser => 'SSH 用户';

  @override
  String get terminalSshUserHint => '默认使用机器的 SSH 用户';

  @override
  String get openInTerminal => '在终端中打开';

  @override
  String get terminalAppNotInstalled => '无法打开终端应用';

  @override
  String get terminalAppExperimental => '实验性';

  @override
  String get terminalAppExperimentalNote =>
      '此功能仍为实验性功能。预设不一定适用于所有应用或配置。欢迎在 GitHub 上贡献新的预设！';

  @override
  String get sectionSpread => '喜欢 CC POCKET 吗？';

  @override
  String get shareApp => '分享给朋友';

  @override
  String get shareAppSubtitle => '告诉你的朋友和同事';

  @override
  String shareText(String url) {
    return 'CC Pocket: Claude Code & Codex\n用手机控制你的编程 Agent 📱\n#ccpocket\n$url';
  }

  @override
  String get starOnGithub => '在 GitHub 点星';

  @override
  String get rateOnStore => '在 App Store 评分';

  @override
  String get rateOnStoreAndroid => '在 Google Play 评分';
}
