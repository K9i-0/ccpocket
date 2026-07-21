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
  String get pin => '置顶会话';

  @override
  String get unpin => '取消置顶会话';

  @override
  String get pinProject => '置顶项目';

  @override
  String get unpinProject => '取消置顶项目';

  @override
  String get sessionNameHint => '会话名称';

  @override
  String get clearName => '清除名称';

  @override
  String get connect => '连接';

  @override
  String toolSuggestionTitle(Object toolName) {
    return '将 $toolName 添加到 Codex？';
  }

  @override
  String toolSuggestionInstall(Object toolName) {
    return '安装 $toolName';
  }

  @override
  String get toolSuggestionInstalling => '正在安装…';

  @override
  String get toolSuggestionNotNow => '暂不安装';

  @override
  String get toolSuggestionAuthDescription => '连接所需的应用，完成后请确认。';

  @override
  String toolSuggestionConnect(Object appName) {
    return '连接 $appName';
  }

  @override
  String get toolSuggestionComplete => '连接已完成';

  @override
  String get toolSuggestionFailed => '安装失败';

  @override
  String get toolSuggestionOpenFailed => '无法打开连接页面。';

  @override
  String get copy => '复制';

  @override
  String get markdownLinkOpenFailed => '无法打开此链接。';

  @override
  String get markdownLinkUnsupported => '不支持此类型的链接。';

  @override
  String get markdownFileUnavailable => '无法在此处预览此文件。';

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
  String get git => 'Git';

  @override
  String get explorer => '资源管理器';

  @override
  String get gitUnavailableTip => '未检测到 Git — Git 功能不可用';

  @override
  String get gitUnavailableTitle => 'Git 不可用';

  @override
  String get gitUnavailableHint => '此项目无法使用 Git 功能';

  @override
  String get autoModeFallbackDefaultTip =>
      '当前环境不支持 Auto mode，已切换为 Default mode';

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
  String get dismissKeyboard => '收起键盘';

  @override
  String get serverUnreachable => '无法连接服务器';

  @override
  String get serverUnreachableBody => '无法访问以下 Bridge 服务器：';

  @override
  String get setupSteps => '设置步骤：';

  @override
  String get setupStep1Title => '启动 Bridge 服务器';

  @override
  String get setupStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get setupStep2Title => '如需常驻运行，请注册为服务';

  @override
  String get setupStep2Command => 'npx --yes @ccpocket/bridge@latest setup';

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
  String get bridgeUpdateStarted => '正在更新 Bridge。将关闭此连接并返回机器列表。';

  @override
  String get bridgeUpdateReconnectHint => 'Bridge 服务已更新。请从机器列表重新连接。';

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
  String get machineEditAddTitle => '添加机器';

  @override
  String get machineEditEditTitle => '编辑机器';

  @override
  String get machineEditDismissKeyboardTooltip => '收起键盘';

  @override
  String get machineEditBasicInfo => '基本信息';

  @override
  String get machineEditName => '名称';

  @override
  String get machineEditNameHint => 'Home Mac';

  @override
  String get machineEditHostLabel => 'Host（IP 或主机名）';

  @override
  String get machineEditHostHint => '100.64.1.2';

  @override
  String get machineEditPort => 'Port';

  @override
  String get machineEditBridgePortHint => '8765';

  @override
  String get machineEditApiKey => 'API Key';

  @override
  String get machineEditOptional => '可选';

  @override
  String get machineEditUseSecureConnection => '使用安全连接';

  @override
  String get machineEditUseSecureConnectionSubtitle =>
      '使用 WSS 连接，并用 HTTPS 进行健康检查';

  @override
  String get machineEditSshConfiguration => 'SSH 设置';

  @override
  String get machineEditEnableSshRemoteStartup => '启用 SSH 远程启动';

  @override
  String get machineEditEnableSshRemoteStartupSubtitle =>
      '离线时远程启动 Bridge Server';

  @override
  String get machineEditSshUsername => 'SSH Username';

  @override
  String get machineEditSshUsernameHint => 'myuser';

  @override
  String get machineEditSshPort => 'SSH Port';

  @override
  String get machineEditSshPortHint => '22';

  @override
  String get machineEditTargetAuthentication => '目标认证';

  @override
  String get machineEditPrivateKey => 'Private Key';

  @override
  String get machineEditSshPrivateKeyPem => 'SSH Private Key (PEM)';

  @override
  String get machineEditOpenSshPrivateKeyHint =>
      '-----BEGIN OPENSSH PRIVATE KEY-----';

  @override
  String get machineEditSavedPrivateKeyIndicator =>
      'Private Key 已保存。输入新内容会替换它。';

  @override
  String get machineEditUseSshJumpHost => '使用 SSH Jump Host';

  @override
  String get machineEditUseSshJumpHostSubtitle => '通过 bastion 或中间 SSH 主机连接';

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
  String get machineEditJumpUsernameHint => '留空则使用 SSH Username';

  @override
  String get machineEditJumpHostAuthentication => 'Jump Host 认证';

  @override
  String get machineEditJumpHostAuthenticationSubtitle => '留空则复用目标 SSH 认证信息';

  @override
  String get machineEditJumpPassword => 'Jump Password';

  @override
  String get machineEditSavedJumpHostPasswordIndicator =>
      'Jump Host 密码已保存。输入新内容会替换它。';

  @override
  String get machineEditJumpPrivateKeyPem => 'Jump Private Key (PEM)';

  @override
  String get machineEditSavedJumpHostPrivateKeyIndicator =>
      'Jump Host Private Key 已保存。输入新内容会替换它。';

  @override
  String get machineEditTesting => '正在测试...';

  @override
  String get machineEditTestConnection => '测试连接';

  @override
  String get machineEditConnectionSuccessful => '连接成功';

  @override
  String get machineEditFillSshCredentials => '请输入 SSH 认证信息';

  @override
  String get machineEditAddAndConnect => '添加并连接';

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
  String get showSessions => '显示左侧面板';

  @override
  String get hideSessions => '隐藏左侧面板';

  @override
  String get workspaceLandingSelectSessionMessage => '请在左侧面板中选择一个会话。';

  @override
  String get workspaceLandingCreateSessionMessage => '请从左侧面板中的 New 创建一个会话。';

  @override
  String get workspaceLandingDisconnectedMessage =>
      'Bridge 尚未连接。请从左侧面板进行连接，或打开设置指南来配置机器。';

  @override
  String get running => '进行中';

  @override
  String get recentSessions => '最近会话';

  @override
  String get search => '搜索';

  @override
  String get searchSessions => '搜索会话...';

  @override
  String get sessionDisplayModeFirst => '开头';

  @override
  String get sessionDisplayModeLast => '结尾';

  @override
  String get sessionDisplayModeSummary => '摘要';

  @override
  String get allAiTools => '全部 AI 工具';

  @override
  String get allProjects => '全部项目';

  @override
  String get named => '已命名';

  @override
  String get machines => '机器';

  @override
  String get refreshStatus => '刷新状态';

  @override
  String get add => '添加';

  @override
  String get noSavedMachinesDescription =>
      '还没有已保存的机器。\n添加后即可快速连接或远程启动 Bridge Server。';

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
  String get bridgeIsUpToDate => 'Bridge 已是最新';

  @override
  String get bridgeUpdateAvailable => '有可用更新';

  @override
  String get bridgeUpdateRequiresSetup => '需要 SSH 和 Bridge 自动启动设置';

  @override
  String get bridgeVersionUnknown => '无法确认 Bridge 版本';

  @override
  String bridgeVersionCurrentExpected(String current, String expected) {
    return '当前 v$current，推荐 v$expected 以上';
  }

  @override
  String bridgeVersionCurrentLatest(String current, String latest) {
    return '当前 v$current，最新版 v$latest';
  }

  @override
  String get bridgeLatestVersionChecking => '正在检查 Bridge 最新版本...';

  @override
  String get bridgeLatestVersionUnavailable => '无法检查 Bridge 最新版本';

  @override
  String get bridgeLatestVersionRetry => '重新检查最新版本';

  @override
  String get bridgeUpdateSetupTitle => '准备 Bridge 更新';

  @override
  String get bridgeUpdateSetupDescription =>
      '要从应用更新 Bridge，需要为这台机器启用 SSH 连接并完成 Bridge 自动启动设置。';

  @override
  String get bridgeUpdateSetupEnableSsh => '在 Bridge 连接设置中启用 SSH。';

  @override
  String get bridgeUpdateSetupRunCommand => '在目标机器上运行设置命令。';

  @override
  String get bridgeUpdateSetupCommand => 'npx @ccpocket/bridge@latest setup';

  @override
  String get stopServer => '停止服务器';

  @override
  String get update => '更新';

  @override
  String get download => '下载';

  @override
  String appUpdateAvailable(String version) {
    return 'v$version 可用';
  }

  @override
  String get macosNativeAppBannerTitle => '建议使用 macOS 原生版';

  @override
  String get macosNativeAppBannerSubtitle =>
      '在 Mac 上，CC Pocket 原生桌面版针对 macOS 做了优化。可从 GitHub Releases 安装。';

  @override
  String get openGitHubReleases => '打开 GitHub Releases';

  @override
  String get macosNativeAppSettingsTitle => 'macOS 原生版';

  @override
  String get macosNativeAppSettingsSubtitle => '在 Mac 上推荐使用针对 macOS 优化的原生版。';

  @override
  String get supportBannerTitle => '如果 CC Pocket 对你有帮助';

  @override
  String get supportBannerSubtitle => '你的支持可以帮助持续开发。';

  @override
  String get supportBannerAction => '查看支持';

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
  String get codexProfilePrecedenceNote =>
      '如果所选 profile 定义了相同设置，则 profile 设置会优先于下方选项。';

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
  String get additionalWritableRootsTitle => '额外可用目录';

  @override
  String get additionalWritableRootsDescription =>
      '此会话会在 Codex config.toml 的 writable_roots 之外追加这些目录。';

  @override
  String get additionalWritableRootsTooltip =>
      '当这个 Codex 会话除了当前项目外还需要读取或编辑其他项目文件时使用。';

  @override
  String get additionalWritableRootsSuggestions => '最近项目';

  @override
  String get addDirectory => '添加目录';

  @override
  String get directoryPath => '目录路径';

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
  String get viewEditPlan => '查看计划';

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
  String get continuePlanning => '继续规划';

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
  String get permissionAutoDescription => '让 Claude 通过内置安全检查自动处理审批';

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
  String get sheetSubtitleSandboxClaude => 'Claude 默认在原生环境运行。启用沙箱将限制系统访问。';

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
  String get claudeEffortXHighDesc => '复杂工作的扩展推理';

  @override
  String get claudeEffortMaxDesc => '最深入，最慢';

  @override
  String get reasoningEffortNoneDesc => '无推理';

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
  String get reasoningEffortMaxDesc => '针对最难问题的最大推理深度';

  @override
  String get reasoningEffortUltraDesc => '最大推理并自动委派任务';

  @override
  String get reasoningEffortModelSpecificDesc => '模型特定的推理级别';

  @override
  String get changePermissionModeTitle => '更改权限模式';

  @override
  String changePermissionModeBody(String mode) {
    return '切换到 $mode 会重启当前会话。你的对话会被保留。';
  }

  @override
  String get changeExecutionModeTitle => '更改执行模式';

  @override
  String changeExecutionModeBody(String mode) {
    return '切换到 $mode 会重启当前会话。你的对话会被保留。';
  }

  @override
  String get changeApprovalPolicyTitle => '更改 Approval Policy';

  @override
  String changeApprovalPolicyBody(String mode) {
    return '切换到 $mode 会重启当前会话。你的对话会被保留。';
  }

  @override
  String get codexApprovalUntrustedDescription => '仅自动运行受信任命令，其他操作都需要确认';

  @override
  String get codexApprovalOnRequestDescription => '仅在代理判断需要时请求确认';

  @override
  String get codexApprovalOnFailureDescription => '默认直接执行，仅在失败时请求额外权限（已弃用）';

  @override
  String get codexApprovalNeverDescription => '永不请求确认，失败会立即返回';

  @override
  String get codexAutoReview => '自动审查';

  @override
  String get codexAutoReviewDescription => '让 Codex 自动审查审批请求';

  @override
  String get codexAutoReviewUnavailableDescription => '关闭审批时不可用';

  @override
  String get guardianApprovalTitle => '自动审查已批准';

  @override
  String get guardianApprovalMediumRisk => '中等风险';

  @override
  String get guardianApprovalHighRisk => '高风险';

  @override
  String get guardianApprovalDetails => '详细信息';

  @override
  String get guardianApprovalHideDetails => '收起详细信息';

  @override
  String guardianApprovalAuthorization(String authorization) {
    return '授权级别：$authorization';
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
  String get codexMessagePlaceholder => '给 Codex 发消息...';

  @override
  String get queuedInputForReconnect => '已加入重连队列';

  @override
  String get queuedInputPendingDelivery => '等待发送确认';

  @override
  String get queuedInputForNextTurn => '已排队到下一轮';

  @override
  String get sessionCardQueuedInput => '已排队';

  @override
  String queuedInputImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张图片',
    );
    return '$_temp0';
  }

  @override
  String get tooltipSteerQueuedMessage => '将排队消息作为指令发送';

  @override
  String get tooltipMoveQueuedMessageToInput => '将排队消息移到输入框';

  @override
  String get tooltipCancelQueuedMessage => '取消排队消息';

  @override
  String get reconnecting => '正在重新连接...';

  @override
  String get reconnectingQueuedMessages => '正在重新连接... 排队消息将自动发送';

  @override
  String get disconnectedMessagesQueued => '已断开连接 - 消息可排队等待重连';

  @override
  String get sessionQueuedForReconnect => '会话已加入重连队列';

  @override
  String get resumeAlreadyQueued => '恢复已在队列中';

  @override
  String get resumeQueuedForReconnect => '恢复已加入重连队列';

  @override
  String get pendingActionWillCreateOnReconnect => 'Bridge 重连后将创建';

  @override
  String get pendingActionWillResumeOnReconnect => 'Bridge 重连后将恢复';

  @override
  String get pendingActionStatus => '等待中';

  @override
  String get tooltipCancelPendingAction => '取消等待中的操作';

  @override
  String get queuedLocally => '已在本地排队';

  @override
  String get offlinePendingNewSessionTitle => '新会话等待中';

  @override
  String get offlinePendingResumeTitle => '恢复等待中';

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
  String get rewind => '回退';

  @override
  String get rewindToHere => '回退到这里';

  @override
  String get rewindModeConversationAndCode => '恢复对话和代码';

  @override
  String get rewindModeConversationOnly => '仅恢复对话';

  @override
  String get rewindModeCodeOnly => '仅恢复代码';

  @override
  String get rewindConfirmTitle => '确认回退';

  @override
  String rewindConfirmBody(Object mode) {
    return '模式：$mode\n\n此操作无法撤销。要继续吗？';
  }

  @override
  String get rewindCannotRewindFiles => '无法回退文件';

  @override
  String get codexRewindConfirmTitle => '回退对话？';

  @override
  String get codexRewindConfirmBody => '将聊天恢复到此消息之前，并把该消息放回输入框。文件更改会保留。';

  @override
  String get fork => '分叉';

  @override
  String get forkConversation => '分叉对话';

  @override
  String get forkConversationTitle => '分叉对话？';

  @override
  String get forkConversationBody => '从此回复创建一个新的 Codex 会话。当前会话不会改变。';

  @override
  String get forkTargetNotFound => '找不到可用于分叉的用户消息';

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
  String agentIsAsking(Object agent) {
    return '$agent 正在提问';
  }

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
      '一款可让你通过 Bridge 服务在智能手机上使用 Codex 和 Claude 的移动客户端。';

  @override
  String get guideAboutSdkNoteTitle => '关于 Claude Agent SDK';

  @override
  String get guideAboutSdkNoteBody =>
      '它相当于 Claude Code 的库版本。可以共享历史记录以及 .claude、CLAUDE.md 等配置文件，审批流程体验也大致相同。';

  @override
  String get guideAboutDiagramTitle => '工作方式';

  @override
  String get guideAboutDiagramPhone => 'iPhone';

  @override
  String get guideAboutDiagramBridge => 'Bridge 服务';

  @override
  String get guideAboutDiagramClaude => 'Codex CLI\n/ Claude Agent SDK';

  @override
  String get guideAboutDiagramCaption =>
      '电脑上的 Bridge 服务会连接到 Codex CLI 和 Claude Agent SDK，\n然后你的手机再连接到 Bridge。';

  @override
  String get guideBridgeTitle => 'Bridge 服务\n设置';

  @override
  String get guideBridgeDescription =>
      '先在你的电脑上启动 Bridge 服务。如果你要使用 Claude，也请先设置 ANTHROPIC_API_KEY。';

  @override
  String get guideBridgePrerequisites => '前置条件';

  @override
  String get guideBridgePrereq1 => '已安装 Node.js 的 Mac / PC';

  @override
  String get guideBridgePrereq2 => '如果使用 Claude，请设置 ANTHROPIC_API_KEY';

  @override
  String get guideBridgePrereq3 => '如果使用 Codex，请先完成 Codex 认证';

  @override
  String get guideBridgeStep1 => '使用 npx 运行（推荐）';

  @override
  String get guideBridgeStep1Command => 'npx --yes @ccpocket/bridge@latest';

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
  String get guideLaunchdCommandValue =>
      'npx --yes @ccpocket/bridge@latest setup';

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
  String get promptHistoryFilters => '筛选';

  @override
  String get promptHistoryFilterThisDevice => '在此设备使用过的历史';

  @override
  String get promptHistoryFilterThisProject => '当前打开的项目';

  @override
  String get promptHistoryFilterThisBridge => '已连接的 Bridge';

  @override
  String get promptHistoryFilterFavorites => '收藏';

  @override
  String get promptHistoryFilterCommands => '命令和技能';

  @override
  String get promptHistoryOpenProjectEmptyHint => '打开的项目筛选仅适用于新版应用记录的历史。';

  @override
  String get promptHistorySectionTitle => '提示词历史';

  @override
  String get promptHistorySyncTitle => '同步提示词历史';

  @override
  String get promptHistoryReplaceTitle => '用旧格式历史覆盖 Bridge';

  @override
  String get promptHistoryReplaceSubtitle =>
      '旧格式历史由应用管理。新格式由 Bridge 管理历史。如果你已在主设备上迁移，通常不需要此操作。仅在备用设备误初始化 Bridge 历史时使用：它会用此设备的旧格式历史覆盖已连接 Bridge 的历史。';

  @override
  String get promptHistoryReplaceConfirmAction => '覆盖';

  @override
  String get promptHistoryReplaceDismissAction => '已迁移，隐藏';

  @override
  String get promptHistoryNotSyncedYet => '尚未同步';

  @override
  String promptHistoryLatestSync(String time) {
    return '上次同步：$time';
  }

  @override
  String promptHistorySyncedBridges(int count) {
    return '已同步 $count 个 Bridge';
  }

  @override
  String promptHistorySyncSummaryWithFailures(int synced, int failed) {
    return '已同步 $synced 个，失败 $failed 个';
  }

  @override
  String promptHistoryBridgeId(String id) {
    return 'Bridge ID: $id';
  }

  @override
  String promptHistoryOtherBridgeRegistrations(String registrations) {
    return '其他注册: $registrations';
  }

  @override
  String get promptHistoryNoSyncTime => '没有同步时间';

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
  String get sectionConnectionAccounts => '连接与账户';

  @override
  String get sectionNotifications => '通知';

  @override
  String get sectionSupport => '支持';

  @override
  String get sectionEditor => '编辑器';

  @override
  String get textDensity => '文字密度';

  @override
  String get textDensityDescription => '在系统文字大小的基础上再应用此应用倍率。100% 保持系统设置不变。';

  @override
  String get codeFontSize => '代码字体大小';

  @override
  String get codeFontFamily => '代码字体';

  @override
  String get codeFontPreview => '预览';

  @override
  String get indentSize => '缩进大小';

  @override
  String get indentSizeSubtitle => '列表缩进使用的空格数';

  @override
  String get gitDiffInteractionMode => 'Git diff 手势';

  @override
  String get gitDiffQuickActions => '快捷操作';

  @override
  String get gitDiffQuickActionsDescription =>
      '单指横向滑动可暂存、取消暂存或还原 hunk。长行会自动换行。';

  @override
  String get gitDiffScrollFirst => '优先横向滚动';

  @override
  String get gitDiffScrollFirstDescription =>
      '长行不换行，可按 hunk 横向滚动。Git 操作请使用长按菜单或底部按钮。';

  @override
  String get imagePasteShortcut => '图片粘贴快捷键';

  @override
  String get imagePasteShortcutCtrlV => 'Ctrl+V';

  @override
  String get imagePasteShortcutCtrlVDescription =>
      'macOS 推荐使用。保留 Cmd+V 用于普通粘贴和听写工具。';

  @override
  String get imagePasteShortcutCommandV => 'Cmd+V';

  @override
  String get imagePasteShortcutCommandVDescription =>
      '可能会与听写应用、剪贴板管理器和文本扩展工具冲突。';

  @override
  String get gitDiffFocusAutoLandscape => '在 diff 专注模式中切换为横屏';

  @override
  String get gitDiffFocusAutoLandscapeDescription =>
      '在移动布局中，进入 diff 专注模式时会锁定为横屏。退出专注模式后恢复正常旋转。';

  @override
  String get remoteGitStatusBadge => '用浅色徽标显示未同步的 Git 提交';

  @override
  String get remoteGitStatusBadgeDescription =>
      'fetch 后，如果当前分支可 push 或 pull，会在会话页 Git 按钮上显示浅色徽标。';

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
  String get appIconTitle => '应用图标';

  @override
  String get appIconMonthlySupporterPerk => '这是月度 Supporter 特典。';

  @override
  String appIconSettingsSubtitle(String device) {
    return '可以更改 $device 主屏幕上显示的图标。';
  }

  @override
  String get appIconSupporterDialogTitle => '月度 Supporter 特典';

  @override
  String get appIconSupporterSectionLabel => '月度 Supporter 特典';

  @override
  String get appIconPickerTitle => '选择应用图标';

  @override
  String get appIconPickerSubtitle => '可以选择主屏幕上显示的图标。';

  @override
  String get appIconOptionDefaultTitle => '深色';

  @override
  String get appIconOptionDefaultSubtitle => '标准的 CC Pocket 图标。';

  @override
  String get appIconOptionLightOutlineTitle => '浅色';

  @override
  String get appIconOptionLightOutlineSubtitle => '线条更轻盈、更明亮的版本。';

  @override
  String get appIconOptionCopperEmeraldTitle => '金属感';

  @override
  String get appIconOptionCopperEmeraldSubtitle => '带有光泽感的特别版。';

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
  String get usageConnectToView => '连接到 Bridge 后查看用量';

  @override
  String get usageFetchFailed => '获取失败';

  @override
  String get usageFiveHour => '5 小时';

  @override
  String get usageSevenDay => '7 天';

  @override
  String get settingsUsageSectionTitle => '用量';

  @override
  String get settingsUsageNoCodexData => '未找到 Codex 的用量数据。';

  @override
  String get usageDisplayModeRemaining => '剩余';

  @override
  String get usageDisplayModeUsed => '已用';

  @override
  String get settingsClaudeUsageDescription => '在浏览器中打开 Claude 的官方计费页面。';

  @override
  String get settingsClaudeApiBilling => 'API Key 计费';

  @override
  String get settingsClaudeSubscriptionUsage => '订阅用量';

  @override
  String get settingsNewSessionTabs => '新建会话标签页';

  @override
  String get settingsNewSessionTabsDescription => '可修改新建会话时显示的 AI 工具选项及其排列顺序。';

  @override
  String get showBridgeNameInSessionList => '显示 Bridge 名称';

  @override
  String get showBridgeNameInSessionListSubtitle =>
      '注册多个 Bridge 时，在会话列表中显示当前连接的 Bridge 名称。';

  @override
  String get autoRenameCodexSessions => '自动 Rename (Codex)';

  @override
  String get autoRenameCodexSessionsSubtitle => '在首次智能体回复后自动为 Codex 会话命名';

  @override
  String get showExtendedCodexEfforts => '在 Effort 滑块中显示 Max / Ultra';

  @override
  String get showExtendedCodexEffortsSubtitle =>
      '当所选 Codex 模型支持时，在滑块中添加 Max 和 Ultra';

  @override
  String get autoRenameClaudeSessions => '自动 Rename (Claude)';

  @override
  String get autoRenameClaudeSessionsSubtitle =>
      '在首次智能体回复后自动为 Claude 会话命名。使用 API Key 计费时会产生额外按量费用。';

  @override
  String get newSessionTabCodex => 'Codex';

  @override
  String get newSessionTabClaudeCode => 'Claude';

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
  String get tooltipSlashCommand => '输入命令或技能';

  @override
  String get tooltipMention => '提及文件或插件';

  @override
  String get tooltipDollarMention => '输入技能或应用';

  @override
  String get tooltipPermissionMode => '权限模式';

  @override
  String get tooltipAttachImage => '附加图片';

  @override
  String get tooltipPromptHistory => '打开提示词历史';

  @override
  String get tooltipVoiceInput => '开始语音输入';

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
  String get authErrorBody => 'Bridge 机器上的 Claude 需要重新登录。';

  @override
  String get authErrorPrimaryCommandLabel => '步骤 1';

  @override
  String get authErrorSecondaryCommandLabel => '步骤 2';

  @override
  String get authErrorAlternativeLabel => 'Shell 方式';

  @override
  String get apiKeyRequiredTitle => '需要 API 密钥';

  @override
  String get apiKeyRequiredBody =>
      'Anthropic 当前的 Claude Agent SDK 文档不允许第三方产品使用 Claude 订阅登录。请改用 API 密钥。';

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
  String get authHelpLanguageKo => '한국어';

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
  String get spreadAppealMessage =>
      'CC Pocket 的用户还不多，继续开发需要更多人支持。如果你喜欢它，给商店评分（只点星也可以）或推荐给朋友都会很有帮助。';

  @override
  String get shareApp => '分享给朋友';

  @override
  String get shareAppSubtitle => '告诉你的朋友和同事';

  @override
  String shareText(String url) {
    return 'CC Pocket: Claude & Codex\n用手机控制你的编程 Agent 📱\n#ccpocket\n$url';
  }

  @override
  String get starOnGithub => '在 GitHub 点星';

  @override
  String get rateOnStore => '在 App Store 评分';

  @override
  String get rateOnStoreAndroid => '在 Google Play 评分';

  @override
  String get supporterTitle => 'Supporter';

  @override
  String get supporterMonthlyTitle => '每月支持';

  @override
  String get supporterMonthlyPlusTitle => '每月支持 Plus';

  @override
  String get supporterSnackTitle => '请吃份零食';

  @override
  String get supporterCoffeeTitle => '请喝杯饮料';

  @override
  String get supporterLunchTitle => '请吃顿午餐';

  @override
  String get supporterStatusActive => '感谢你在支持 CC Pocket。';

  @override
  String get supporterStatusInactive => '应用会继续免费开放使用。你可以在这里支持持续开发。';

  @override
  String get supporterStatusLoading => '正在检查支持状态...';

  @override
  String get supportEntryInactiveTitle => '支持一下';

  @override
  String get supportEntryInactiveSubtitle => '如果你喜欢 CC Pocket，愿意支持持续开发的话我会很开心。';

  @override
  String get supportEntryOneTimeTitle => '感谢支持';

  @override
  String get supportEntryOneTimeSubtitle => '谢谢你之前的支持。';

  @override
  String get supportEntryActiveTitle => '支持中';

  @override
  String supportEntryActiveSubtitle(String date) {
    return '感谢支持。你从 $date 开始支持 CC Pocket。';
  }

  @override
  String get supporterMonthlyDescription => '如果你愿意持续支持，帮助这个应用继续改进，我会很开心。';

  @override
  String get supporterMonthlyPerkLabel => '包含更换应用图标特典';

  @override
  String get supporterSnackDescription => '如果你想请我吃份零食，我会很感谢这份支持。';

  @override
  String get supporterCoffeeDescription => '如果你想请我喝一杯饮料，我会很感谢这份支持。';

  @override
  String get supporterLunchDescription => '如果你想请我吃一顿午餐，我会很感谢这份支持。';

  @override
  String get supporterBuyButton => '支持';

  @override
  String get supporterActiveButton => '支持中';

  @override
  String get supporterSubscribedButton => '已订阅';

  @override
  String get supporterRestoreButton => '恢复购买';

  @override
  String get supporterRetryButton => '重试';

  @override
  String get supporterProductsUnavailable => '当前没有可用的支持选项。';

  @override
  String get supporterRestoreNoticeTitle => '关于恢复';

  @override
  String get supporterRestoreNoticeBody =>
      '恢复购买仅适用于相同的 Apple ID 或 Google 账号。iOS 与 Android 之间的支持状态不会互通。';

  @override
  String get supporterSummaryTitle => '支持概览';

  @override
  String supporterSummarySinceChip(String date) {
    return '自 $date 起支持';
  }

  @override
  String supporterSummaryStreakChip(String duration) {
    return '已持续 $duration';
  }

  @override
  String supporterSummaryOneTimeCount(int count) {
    return '单次 ×$count';
  }

  @override
  String supporterSummarySnackCount(int count) {
    return '零食 ×$count';
  }

  @override
  String supporterSummaryCoffeeCount(int count) {
    return '饮料 ×$count';
  }

  @override
  String supporterSummaryLunchCount(int count) {
    return '午餐 ×$count';
  }

  @override
  String get supporterSummaryLessThanMonth => '不足 1 个月';

  @override
  String supporterSummaryDurationMonths(int count) {
    return '$count 个月';
  }

  @override
  String get supporterSummarySinceLabel => '开始支持';

  @override
  String get supporterSummaryStreakLabel => '持续时间';

  @override
  String get supporterSummaryOngoingLabel => '支持中';

  @override
  String get supporterSummarySupportPeriodLabel => '支持期间';

  @override
  String get supporterImpactTitle => '支持能带来什么';

  @override
  String get supporterImpactBody =>
      '如果你喜欢 CC Pocket，愿意支持持续开发的话我会很开心。这个应用会继续作为免费的 OSS 提供。';

  @override
  String get supporterImpactAiTitle => '开发与维护成本';

  @override
  String get supporterImpactAiBody => 'AI 使用、真机验证、测试和发布都会带来持续成本。';

  @override
  String get supporterImpactDevicesTitle => '设备与测试';

  @override
  String get supporterImpactDevicesBody => '帮助覆盖真机验证、系统适配和持续维护的成本。';

  @override
  String get supporterImpactMotivationTitle => '持续改进的动力';

  @override
  String get supporterImpactMotivationBody => '知道这个应用真的有用，会更有动力继续做新功能和改进。';

  @override
  String get supporterPackagesTitle => '选择一种支持方式';

  @override
  String get supporterSubscriptionGroupTitle => '每月支持';

  @override
  String get supporterSubscriptionGroupBody => '如果你愿意持续支持，我会很感谢。';

  @override
  String get supporterOneTimeGroupTitle => '单次支持';

  @override
  String get supporterOneTimeGroupBody => '如果你愿意请我吃顿午餐或喝杯饮料，我会很感谢这份支持。';

  @override
  String get supporterPurchaseInfoTitle => '关于购买';

  @override
  String get supporterPurchaseInfoBody =>
      '恢复购买仅适用于相同的 Apple ID 或 Google 账号。iOS 与 Android 之间的支持状态不会互通。';

  @override
  String get supporterPurchaseInfoLink => '了解更多';

  @override
  String get supporterPrivacyPolicyLink => '隐私政策';

  @override
  String get supporterTermsOfUseLink => '使用条款（Apple 标准 EULA）';

  @override
  String get supporterLearnMoreTitle => '关于购买与支持';

  @override
  String get supporterLearnMoreBody => '了解为什么 CC Pocket 保持免费，以及恢复购买与隐私设计的方式。';

  @override
  String get supporterOpenLinkFailed => '无法打开说明页面。';

  @override
  String get supporterPurchaseSuccess => '感谢你支持 CC Pocket！';

  @override
  String get supporterPurchaseCancelled => '已取消购买。';

  @override
  String supporterPurchaseFailed(String message) {
    return '购买失败：$message';
  }

  @override
  String get supporterRestoreSuccess => '已恢复购买记录。';

  @override
  String supporterRestoreFailed(String message) {
    return '恢复失败：$message';
  }

  @override
  String get gitDiscardAllChangesTitle => '要放弃所有更改吗？';

  @override
  String get gitDiscardVisibleUnstagedChangesMessage => '放弃当前显示的所有未暂存更改。';

  @override
  String get gitDiscardChangeTitle => '要放弃此更改吗？';

  @override
  String get gitDiscardFileUnstagedChangesMessage => '放弃此文件中的所有未暂存更改。';

  @override
  String get gitDiscardHunkUnstagedChangesMessage => '放弃此代码块中的未暂存更改。';

  @override
  String get googleSearchSelectionAction => '用 Google 搜索';

  @override
  String get approvalQuestionNotificationTitle => '有一个问题 - ccpocket';

  @override
  String get approvalRequiredNotificationTitle => '等待审批 - ccpocket';

  @override
  String get exitPlanModeNotificationBody => '生成的计划需要你确认';

  @override
  String get renderErrorFallback => '无法显示此内容。';
}
