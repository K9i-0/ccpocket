// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get notifyGoalProgress => '中间回复 · 目标进行中';

  @override
  String get notifyGoalComplete => '目标已达成';

  @override
  String get notifyGoalBlocked => '需要处理才能继续';

  @override
  String get notifyGoalBudgetLimited => '已停止：达到令牌预算';

  @override
  String get notifyGoalUsageLimited => '已停止：达到使用上限';

  @override
  String get appTitle => 'CC Pocket';

  @override
  String get projects => '多项目';

  @override
  String get manageProjects => '管理';

  @override
  String get createProject => '创建多项目';

  @override
  String get editProject => '编辑多项目';

  @override
  String get projectName => '多项目名称';

  @override
  String get sourceFolders => '源文件夹';

  @override
  String get primary => '主文件夹';

  @override
  String get makePrimary => '设为主文件夹';

  @override
  String get removeFolder => '移除文件夹';

  @override
  String get addFolder => '添加文件夹';

  @override
  String get removeWorkspaceProject => '移除多项目';

  @override
  String get noProjectsYet => '还没有多项目';

  @override
  String get unavailable => '不可用';

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
  String get protocolIncompatibleTitle => 'App 与 Bridge 版本不兼容';

  @override
  String get protocolUpdateAppBody => '请从原安装来源更新 CC Pocket，然后重新连接。';

  @override
  String get bridgeAuthRequiredTitle => 'Bridge 需要身份验证';

  @override
  String bridgeAuthRequiredBody(String host) {
    return '$host 上的 Bridge 需要 API 密钥。请在运行 Bridge 的电脑上执行下面的命令，然后扫描显示的二维码或输入 API 密钥。';
  }

  @override
  String get machineApiKeyRequired => '需要 API 密钥。请重新扫描 Bridge 二维码';

  @override
  String get bridgeAuthEnterApiKey => '输入 API 密钥';

  @override
  String get protocolUpdateBridgeBody => '请将 Bridge 更新到兼容版本，然后重新连接。';

  @override
  String get protocolUpdateBothBody =>
      '协议信息无效或不完整。请同时更新 CC Pocket 和 Bridge 后再重新连接。';

  @override
  String protocolRangeDetails(
    int appMin,
    int appMax,
    int bridgeMin,
    int bridgeMax,
  ) {
    return 'App 协议 $appMin–$appMax；Bridge 协议 $bridgeMin–$bridgeMax';
  }

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
  String get copyEntireMessage => '复制整条消息';

  @override
  String get markdownLinkOpenFailed => '无法打开此链接。';

  @override
  String get markdownLinkUnsupported => '不支持此类型的链接。';

  @override
  String get markdownFileUnavailable => '无法在此处预览此文件。';

  @override
  String get filePreviewShowSource => '查看源代码';

  @override
  String get filePreviewShowPreview => '显示预览';

  @override
  String get filePreviewRenderedHtml => 'HTML 渲染预览';

  @override
  String get filePreviewMediaUnavailable => '无法在此处播放此媒体文件。';

  @override
  String get filePreviewMediaLoadFailed => '无法加载媒体文件。';

  @override
  String get filePreviewPlay => '播放';

  @override
  String get filePreviewPause => '暂停';

  @override
  String get filePreviewRewind10 => '后退10秒';

  @override
  String get filePreviewForward10 => '前进10秒';

  @override
  String get filePreviewPlaybackSpeed => '播放速度';

  @override
  String get filePreviewMute => '静音';

  @override
  String get filePreviewUnmute => '取消静音';

  @override
  String get filePreviewVolume => '音量';

  @override
  String get filePreviewFullscreen => '进入全屏';

  @override
  String get filePreviewExitFullscreen => '退出全屏';

  @override
  String get fileTransferShareOrSave => '分享或保存';

  @override
  String get fileUploadTitle => '上传文件';

  @override
  String get fileUploadAction => '上传';

  @override
  String get fileUploadDestination => '目标位置';

  @override
  String get fileUploadConflictLabel => '存在同名文件时';

  @override
  String get fileUploadKeepBoth => '保留两者';

  @override
  String get fileUploadReplace => '替换';

  @override
  String get fileUploadSkip => '跳过';

  @override
  String get fileUploadPreparing => '正在准备…';

  @override
  String get fileUploadUploading => '正在上传…';

  @override
  String get fileUploadFinalizing => '正在验证…';

  @override
  String get fileUploadComplete => '上传完成';

  @override
  String get fileUploadSkipped => '已跳过';

  @override
  String get fileUploadTooMany => '一次最多可上传20个文件。';

  @override
  String get fileUploadTotalTooLarge => '所选文件超过1 GB总大小限制。';

  @override
  String get fileUploadSelectionFailed => '无法打开所选文件。';

  @override
  String get fileUploadFileTooLarge => '每个文件不得超过512 MB。';

  @override
  String get fileUploadErrorNotAllowed => '不允许上传到当前文件夹或使用此文件名。';

  @override
  String get fileUploadErrorTooLarge => '此文件超过Bridge上传大小限制。';

  @override
  String get fileUploadErrorUnavailable => '文件上传不可用。请更新或重启Bridge。';

  @override
  String get fileUploadErrorBridgeUpdate => '请更新Bridge以上传文件。';

  @override
  String get fileUploadErrorFailed => '无法上传文件。';

  @override
  String get fileTransferPreparing => '正在准备下载…';

  @override
  String get fileTransferDownloading => '正在下载…';

  @override
  String get fileTransferOpeningShareSheet => '正在打开分享菜单…';

  @override
  String get fileTransferErrorNotAllowed => '此文件不在当前项目中或不允许访问。';

  @override
  String get fileTransferErrorNotFound => '文件已不存在。';

  @override
  String get fileTransferErrorNotFile => '只能下载普通文件。';

  @override
  String get fileTransferErrorTooLarge => '此文件超过 Bridge 的下载大小限制。';

  @override
  String get fileTransferErrorUnavailable => '文件下载不可用。请更新或重启 Bridge。';

  @override
  String get fileTransferErrorBridgeUpdate => '请更新 Bridge 后再下载文件。';

  @override
  String get fileTransferErrorFailed => '无法下载文件。';

  @override
  String get fileTransferErrorShareFailed => '无法打开系统分享菜单。';

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
  String get setupStep2Command => 'npx --yes @ccpocket/bridge@1 setup';

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
  String get machineEditConnectionMode => '连接方式';

  @override
  String get machineEditConnectionModeAutomatic => '自动（推荐）';

  @override
  String get machineEditConnectionModeAutomaticSubtitle =>
      '不发送凭据进行检查，优先使用 HTTPS 自动连接';

  @override
  String get machineEditConnectionModeAutomaticSshSubtitle =>
      '在 SSH 隧道内使用 WS；通信由 SSH 连接加密';

  @override
  String get machineEditConnectionModeSecureOnly => '仅安全连接（WSS）';

  @override
  String get machineEditConnectionModeSecureOnlySubtitle =>
      '强制使用 TLS，绝不自动降级到 WS';

  @override
  String get machineEditConnectionModeStandardOnly => '标准（WS）';

  @override
  String get machineEditConnectionModeStandardOnlySubtitle =>
      '请仅在本地网络或 Tailscale 等 VPN 中使用';

  @override
  String get machineErrorBridgeNotFound =>
      '找不到 Bridge。请确认它正在运行，且此设备已连接到同一网络或 VPN。';

  @override
  String get machineErrorSecureConnectionUnavailable =>
      '无法建立安全连接。请检查 TLS 设置，或仅在确定需要时明确选择“标准（WS）”。';

  @override
  String get machineAutomaticWsApiKeyWarningTitle => '检测到标准连接（WS）';

  @override
  String get machineAutomaticWsApiKeyWarningBody =>
      '此 Bridge 通过未加密的 WS 找到。API 密钥将在没有传输加密的情况下发送。请仅在可信的本地网络或 VPN 中继续。';

  @override
  String get machineAutomaticWsApiKeyWarningConnect => '使用 WS 连接';

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
  String get bridgeUpdateSetupCommand => 'npx @ccpocket/bridge@1 setup';

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
  String get additionalWritableRootsTitle => '额外可用文件夹';

  @override
  String get additionalWritableRootsDescription =>
      '此会话会在 Codex config.toml 的 writable_roots 之外追加这些文件夹。';

  @override
  String get additionalWritableRootsTooltip =>
      '当这个 Codex 会话除了当前项目外还需要读取或编辑其他项目文件时使用。';

  @override
  String get additionalWritableRootsSuggestions => '最近项目';

  @override
  String get addDirectory => '添加文件夹';

  @override
  String get directoryPath => '文件夹路径';

  @override
  String get directoryPathOutsideAllowedRoots => '文件夹路径不在允许的范围内';

  @override
  String get browseDirectory => '浏览文件夹';

  @override
  String get selectDirectory => '选择';

  @override
  String get noSubdirectories => '没有子文件夹';

  @override
  String get directoryBrowserRoots => '允许的文件夹';

  @override
  String get directoryBrowserFilterHint => '筛选文件夹';

  @override
  String get directoryBrowserNoMatches => '没有匹配的文件夹';

  @override
  String get directoryBrowserBridgeUpdateRequired =>
      '此功能需要较新版本的 Bridge Server。请更新 Bridge 后重试。';

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
  String get approvalStatusPending => '待批准';

  @override
  String get approvalStatusApproved => '已批准';

  @override
  String get approvalStatusApprovedForSession => '本次会话已批准';

  @override
  String get approvalStatusRejected => '已拒绝';

  @override
  String get approvalStatusResolved => '已解决';

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
  String get permissionAutoDescriptionAntigravity =>
      '让 Antigravity 自动判断哪些操作需要审批';

  @override
  String get antigravityModelAfterStartNote => '会话开始后可以切换模型。';

  @override
  String get antigravityAuthLogin => 'Google 登录';

  @override
  String get antigravityAuthApiKey => 'API 密钥';

  @override
  String get antigravityUsageRefreshHint => '点按刷新即可获取套餐剩余用量（5 小时和每周）。';

  @override
  String get antigravityUsageApiKeyNote => '使用 API 密钥时没有套餐额度。上下文用量会显示在各会话中。';

  @override
  String get showAntigravityTabSubtitle =>
      '仅当 Bridge 机器上装有 Antigravity CLI（agy）时显示';

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
  String get claudeUltracodeDesc => '所有任务都以多代理工作流执行，令牌用量会大幅增加';

  @override
  String get claudeUltracodeOn => '开启';

  @override
  String get claudeUltracodeOff => '关闭';

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
  String get codexAutoReviewDisabledByPolicy => '已被组织的 Browser Use 政策禁用';

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
  String get antigravityMessagePlaceholder => '给 Antigravity 发消息...';

  @override
  String get queuedInputForReconnect => '已加入重连队列';

  @override
  String get queuedInputPendingDelivery => '等待发送确认';

  @override
  String get queuedInputWaitingForUsageLimit => '等待用量限制解除 · 正在确认重置时间';

  @override
  String queuedInputForUsageLimit(String time) {
    return '等待用量限制解除 · 计划于 $time 发送';
  }

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
  String get reconnecting => 'Bridge 连接暂时中断。正在自动重新连接...';

  @override
  String get reconnectingQueuedMessages => 'Bridge 连接暂时中断。正在自动重新连接；排队消息已安全保留。';

  @override
  String get disconnectedMessagesQueued => 'Bridge 当前不可用。操作会保存在此设备上，并在重连后发送。';

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
  String get pendingActionProcessingStatus => '正在恢复';

  @override
  String get pendingActionProcessingStartStatus => '准备中';

  @override
  String get pendingActionProcessingStartDescription => 'Bridge 正在准备会话';

  @override
  String get pendingActionProcessingResumeDescription => '包含大量图片的会话可能需要更长时间';

  @override
  String get pendingActionProcessingStartTitle => '正在创建新会话';

  @override
  String get pendingActionProcessingResumeTitle => '正在加载会话历史';

  @override
  String get tooltipCancelPendingAction => '取消等待中的操作';

  @override
  String get queuedLocally => '已在本地排队';

  @override
  String get processingOnBridge => 'Bridge 正在处理';

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
  String get editMessage => '编辑消息';

  @override
  String get restoreFilesToHere => '将文件恢复到此时';

  @override
  String get copyMessage => '复制消息';

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
  String get forkConversationBody => '从此回复创建一个新会话。当前会话不会改变。';

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
  String get questionLabel => '问题';

  @override
  String get answerHidden => '为保护隐私已隐藏';

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
  String get guideAboutTitle => '把电脑上的代理，\n装进口袋。';

  @override
  String get guideAboutDescription =>
      '在手机上与运行于自己 Mac / PC 上的 Codex、Claude、Antigravity 对话、审批步骤并查看变更。';

  @override
  String get guideAboutSdkNoteTitle => '关于 Claude Agent SDK';

  @override
  String get guideAboutSdkNoteBody =>
      '它相当于 Claude Code 的库版本。可以共享历史记录以及 .claude、CLAUDE.md 等配置文件，审批流程体验也大致相同。';

  @override
  String get guideAboutDiagramTitle => '工作方式';

  @override
  String get guideAboutDiagramPhone => '当前设备';

  @override
  String get guideAboutDiagramBridge => 'Bridge 服务';

  @override
  String get guideAboutDiagramClaude => 'Codex · Claude\nAntigravity';

  @override
  String get guideAboutDiagramCaption =>
      '你的代码和配置始终留在自己的机器上，Bridge 负责连接应用与本地代理。';

  @override
  String get guideBridgeTitle => '启动 Bridge 服务';

  @override
  String get guideBridgeDescription => '在终端中启动 Bridge 服务，即可从本应用或手机连接。';

  @override
  String get guideBridgePrerequisites => '前置条件';

  @override
  String get guideBridgePrereq1 => '已安装 Node.js 22.19+ 的 Mac / PC';

  @override
  String get guideBridgePrereq2 =>
      'Claude 需要设置 ANTHROPIC_API_KEY 或 BRIDGE_ALLOW_CLAUDE_OAUTH=1';

  @override
  String get guideBridgePrereq3 => '使用 Codex 或 Antigravity 时请先完成 CLI 登录';

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
  String get guideBridgeQrNote => '启动后，终端中会显示二维码和连接地址';

  @override
  String get guideConnectionTitle => '连接设备';

  @override
  String get guideConnectionDescription => '启动 Bridge 后，只需扫描二维码即可立即开始使用。';

  @override
  String get guideConnectionQr => '扫描二维码';

  @override
  String get guideConnectionQrDescription =>
      '扫描 macOS 应用或终端中的二维码，会自动填入地址和 API 密钥。';

  @override
  String get guideConnectionManual => '手动输入 / SSH';

  @override
  String get guideConnectionManualDescription =>
      '可手动输入 ws://<IP 地址>:8765 与 API 密钥，也支持通过 SSH 远程启动 Bridge。';

  @override
  String get guideConnectionRecommended => '推荐';

  @override
  String get guideTailscaleTitle => '远程访问';

  @override
  String get guideTailscaleDescription =>
      '如果要在家外使用，Tailscale（VPN）可以帮助你安全地远程连接。';

  @override
  String get guideTailscaleStep1 => '在 Mac / 电脑和手机上都安装 Tailscale';

  @override
  String get guideTailscaleStep2 => '使用同一个账号登录';

  @override
  String get guideTailscaleStep3 =>
      '使用 Tailscale IP（ws://100.x.x.x:8765）或对应二维码连接';

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
  String get guideLaunchdCommandValue => 'npx --yes @ccpocket/bridge@1 setup';

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
  String get guideReadyDescription =>
      '在 Mac 或电脑上启动 Bridge 后，扫描二维码即可开始首个会话。如果电脑不在身边，也可以先体验演示模式。';

  @override
  String get guideReadyStart => '开始使用';

  @override
  String get guideReadyHint => '你也可以随时在设置中重新打开本指南';

  @override
  String get creatingSession => '正在创建会话...';

  @override
  String get resolvingLinkedSession => '正在查找会话...';

  @override
  String get resumingLinkedSession => '正在恢复会话...';

  @override
  String get sessionUnavailableTitle => '会话不可用';

  @override
  String get sessionUnavailableDescription =>
      '当前 Bridge 上没有此会话。请从最近的会话中选择其他会话。';

  @override
  String get openRecentSessions => '打开最近的会话';

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
  String get settingsCategoryConnection => '连接与 Bridge';

  @override
  String get settingsCategoryAppearance => '外观';

  @override
  String get settingsCategoryInput => '聊天';

  @override
  String get settingsCategoryAgents => '智能体';

  @override
  String get settingsCategoryGit => 'Git 与 Diff';

  @override
  String get settingsCategoryNotifications => '通知';

  @override
  String get settingsCategoryUsage => '用量';

  @override
  String get settingsCategoryUsageSummary => 'Claude 与 Codex 套餐用量';

  @override
  String get settingsCategorySupport => '支持与分享';

  @override
  String get settingsCategorySupportSummary => '支持者、评价与分享';

  @override
  String get settingsCategoryAbout => '关于';

  @override
  String get settingsCategoryAboutSummary => '版本、更新日志与许可';

  @override
  String get settingsGroupDisplay => '显示';

  @override
  String get settingsGroupCode => '代码';

  @override
  String get settingsGroupSending => '发送消息';

  @override
  String get settingsGroupAttachments => '附件';

  @override
  String get settingsGroupPerformance => '性能';

  @override
  String get settingsGroupSessions => '会话';

  @override
  String get settingsGroupFilesAndApps => '文件与应用';

  @override
  String get settingsGroupDiffView => '差异视图';

  @override
  String get settingsEnabledAgents => '启用的智能体';

  @override
  String get settingsBridgeMachine => 'Bridge 机器';

  @override
  String get settingsNotConnected => '未连接';

  @override
  String get settingsStatusOnline => '在线';

  @override
  String get settingsStatusOffline => '离线';

  @override
  String get settingsStatusChecking => '检查中';

  @override
  String get settingsStatusDisconnectedTitle => '未连接 Bridge';

  @override
  String get settingsStatusDisconnectedBody => '连接到机器后，此处会显示 Bridge 状态和用量。';

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String get settingsSearchNoResults => '没有匹配的设置';

  @override
  String get settingsOn => '开';

  @override
  String get settingsOff => '关';

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
  String get multiPaneBreakpoint => '分栏显示宽度';

  @override
  String multiPaneBreakpointDescription(int threePaneWidth) {
    return '窗口宽度不小于此值时，会话列表与对话并排显示。宽度小于 ${threePaneWidth}pt 时打开工具，会显示在列表的位置。';
  }

  @override
  String multiPaneBreakpointCurrentSplit(int width) {
    return '当前宽度 ${width}pt · 分栏显示';
  }

  @override
  String multiPaneBreakpointCurrentSingle(int width) {
    return '当前宽度 ${width}pt · 单栏显示';
  }

  @override
  String multiPaneBreakpointMatchCurrent(int width) {
    return '按当前宽度分栏（${width}pt）';
  }

  @override
  String multiPaneBreakpointReset(int width) {
    return '恢复默认（${width}pt）';
  }

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
  String get loadingSessions => '正在加载会话列表...';

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
  String get fcmRegistrationFailed => '向 Bridge 注册通知失败';

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
  String get settingsUsageNoData => '未找到用量数据。';

  @override
  String get usageDisplayModeRemaining => '剩余';

  @override
  String get usageDisplayModeUsed => '已用';

  @override
  String get usageOpenSettingsHint => '打开用量详情';

  @override
  String get usagePaceOnTrack => '进度正常';

  @override
  String get usagePaceSlightlyAhead => '消耗稍快';

  @override
  String get usagePaceAhead => '消耗较快';

  @override
  String get usagePaceFarAhead => '消耗很快';

  @override
  String get usagePaceSlightlyBehind => '略有余量';

  @override
  String get usagePaceBehind => '余量充足';

  @override
  String get usagePaceFarBehind => '余量非常充足';

  @override
  String usagePaceExpected(int percent) {
    return '预计已用 $percent%';
  }

  @override
  String get usagePaceWillLast => '按当前速度预计可用到重置';

  @override
  String usagePaceRunsOutIn(String duration) {
    return '按当前速度预计约 $duration 后达到上限';
  }

  @override
  String get usagePaceAtLimit => '已达到上限';

  @override
  String usageCompactResetIn(String duration) {
    return '$duration后重置';
  }

  @override
  String usageCompactRunsOutIn(String duration) {
    return '$duration后达到上限';
  }

  @override
  String get settingsNewSessionTabs => '新建会话标签页';

  @override
  String get settingsNewSessionTabsDescription => '更改新建会话时显示的 AI 工具顺序。';

  @override
  String get showHiddenDirectories => '显示隐藏文件夹';

  @override
  String get showHiddenDirectoriesSubtitle => '在新建会话的文件夹浏览器中显示以 . 开头的文件夹。';

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
  String get codexWriterConflictGuidance =>
      '请关闭 Codex Desktop 或 Codex App，然后重试。';

  @override
  String resumePathNotAllowed(String path) {
    return '“$path”不在 Bridge 允许的文件夹内。请将其加入 BRIDGE_ALLOWED_DIRS（以英文逗号分隔）并重启 Bridge。';
  }

  @override
  String get clipboardNotAvailable => '无法访问剪贴板';

  @override
  String get failedToLoadImage => '加载图片失败';

  @override
  String get generatedImagePromptLabel => '提示词';

  @override
  String get generatedImageDetailsLabel => '详情';

  @override
  String get generatedImageHideDetailsLabel => '收起详情';

  @override
  String get generatedImageStatusLabel => '状态';

  @override
  String get generatedImageSavedPathLabel => '已保存文件';

  @override
  String get previousImage => '上一张图片';

  @override
  String get nextImage => '下一张图片';

  @override
  String generatedImagePositionLabel(int current, int total) {
    return '生成的图片 $current / $total';
  }

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
  String get pasteImage => '粘贴图片';

  @override
  String get voiceInputLanguage => '语音输入语言';

  @override
  String get hideVoiceInput => '隐藏语音输入按钮';

  @override
  String get hideVoiceInputSubtitle => '当你使用第三方语音输入键盘时很有帮助';

  @override
  String get openGalleryDirectly => '点击图片按钮直接打开图库';

  @override
  String get openGalleryDirectlySubtitle => '立即选择图片。长按可打开附件菜单';

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
  String get voiceInputUnavailable => '无法使用语音输入。请在设置中允许访问麦克风和语音识别。';

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
  String get claudeOAuthOptInTitle => '订阅认证需要明确启用';

  @override
  String get claudeOAuthOptInBody =>
      'Anthropic 允许用户登录托管平台上未经修改的 Claude Code，但 Agent SDK 指南仍要求第三方产品使用 API 密钥。因此 CC Pocket 默认关闭订阅认证。';

  @override
  String get claudeOAuthOptInHint =>
      '请阅读详情，在 Bridge 机器上设置该选项并重启。若要避免政策不确定性，请改用 API 密钥：';

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

  @override
  String get localUrlTitle => '本地 URL 打开方式';

  @override
  String get localUrlOriginal => '直接打开';

  @override
  String get localUrlReplace => '替换主机后打开';

  @override
  String get localUrlAsk => '打开前选择';

  @override
  String get localUrlHost => '替换主机';

  @override
  String get localUrlDescription =>
      '适用于代理消息中使用 localhost、127.0.0.1 或 [::1] 的 HTTP/HTTPS 链接。按 Bridge 连接保存，消息原文保持不变。';

  @override
  String get localUrlHostHelp =>
      '初始值为 Bridge 连接的 IP 地址或主机名。请输入此设备可通过 Wi-Fi、Tailscale 等网络访问的主机。URL 的端口和路径保持不变。Web 服务器也必须监听该网络可访问的地址。';

  @override
  String get localUrlInvalidHost =>
      '仅输入 IP 地址或主机名，不含协议、端口或路径。IPv6 地址请用 [ ] 括起。';

  @override
  String get annotateImage => '在图片上绘制';

  @override
  String get drawSketch => '绘制草图';

  @override
  String get sketchTitle => '草图';

  @override
  String get sketchApply => '应用';

  @override
  String get sketchAttach => '附加';

  @override
  String get sketchPen => '画笔';

  @override
  String get sketchEraser => '橡皮擦';

  @override
  String get sketchText => '文字';

  @override
  String get sketchArrow => '箭头';

  @override
  String get sketchRectangle => '矩形';

  @override
  String get sketchEllipse => '圆形';

  @override
  String get sketchUndo => '撤销';

  @override
  String get sketchRedo => '重做';

  @override
  String get sketchStrokeWidth => '线条粗细';

  @override
  String get sketchColor => '颜色';

  @override
  String get sketchDiscardTitle => '放弃更改？';

  @override
  String get sketchDiscardMessage => '草图的更改将不会保存。';

  @override
  String get sketchDiscard => '放弃';

  @override
  String get sketchKeepEditing => '继续编辑';

  @override
  String get sketchExportFailed => '无法导出草图，请重试。';

  @override
  String get sketchLoadFailed => '无法打开草图，已附加的图片保持不变。';

  @override
  String get sketchTextHint => '输入文字';

  @override
  String get sketchAddText => '添加文字';

  @override
  String get sketchCancel => '取消';

  @override
  String get tooltipEditSketch => '编辑草图';

  @override
  String get tooltipAttachmentOptions => '长按打开附件菜单';

  @override
  String get sketchSelect => '选择';

  @override
  String get sketchDelete => '删除';

  @override
  String get filePreviewModelLoadFailed => '无法加载3D模型。请确认GLB包含几何体和内嵌资源。';

  @override
  String get filePreviewModelTooLarge => '3D预览支持不超过50 MB的GLB文件。';

  @override
  String get filePreviewModelGestures => '拖动旋转 · 双指缩放';

  @override
  String get filePreviewModelReset => '重置视角';

  @override
  String get filePreviewModelWarning => '部分材质或功能可能无法准确显示。';

  @override
  String get saveToPhotos => '保存到照片';

  @override
  String get savedToPhotos => '已保存到照片';

  @override
  String get saveToPhotosFailed => '无法保存到照片，可能是不支持的格式。';

  @override
  String get photosPermissionDenied => '请在设置中允许添加照片，以保存图片和视频。';

  @override
  String get browserTitle => '文件';

  @override
  String get browserSearch => '搜索文件名和路径';

  @override
  String get browserBack => '返回';

  @override
  String get browserParent => '上级文件夹';

  @override
  String get browserClose => '关闭';

  @override
  String get browserAddToChat => '添加到聊天';

  @override
  String get browserRecent => '最近打开的文件';

  @override
  String get browserEmpty => '此文件夹为空';

  @override
  String get browserNoResults => '没有匹配的文件或文件夹';

  @override
  String get browserRetry => '重试';

  @override
  String get browserTimeout => '请求超时。请检查连接后重试。';

  @override
  String get browserIndexLimited => '搜索范围为已加载的文件列表。打开文件夹可查看全部项目。';

  @override
  String get browserLegacy => '请更新 Bridge 以查看完整文件夹内容。当前显示已加载的列表。';

  @override
  String get browserToggleList => '显示或隐藏文件列表';

  @override
  String get browserRefresh => '刷新';

  @override
  String get browserNotAllowed => '此文件夹超出了允许浏览的范围。';

  @override
  String get browserNotFound => '此路径已不存在。';

  @override
  String get browserUnreadable => '无法读取此文件夹。';

  @override
  String get browserCopyPath => '复制路径';

  @override
  String get browserNoRecent => '打开的文件将显示在这里。';

  @override
  String get finderReveal => '在 Finder 中显示';

  @override
  String get finderRevealLocalOnly => '无法确认 Bridge 是否运行在此 Mac 上。请检查连接后重试。';

  @override
  String get finderRevealUpdateBridge => '请更新 Bridge，以在 Finder 中显示文件。';

  @override
  String get finderRevealFailed => '无法在 Finder 中显示文件。请检查文件和 Bridge 连接。';

  @override
  String get performanceModeBridgeUpdate => '请更新Bridge以减少网络流量。当前仅在界面上隐藏详情。';

  @override
  String get liteMode => '性能模式';

  @override
  String get liteModeDescription => '减少Bridge发送的工具历史和工作过程图片。保留生成图片、附件和资源管理器图片。';

  @override
  String get chatDisplayMode => '显示模式';

  @override
  String get standardMode => '标准';

  @override
  String get followDefaultMode => '跟随设置';

  @override
  String get liteModeRunning => '运行中';

  @override
  String get liteModeWaiting => '等待批准或回答';

  @override
  String get liteModeIdle => '空闲';

  @override
  String get liteModeCompacting => '正在整理对话';

  @override
  String get liteModeStarting => '正在启动';

  @override
  String liteModeLastActivity(String elapsed) {
    return '$elapsed前收到';
  }

  @override
  String liteModeObserved(String elapsed) {
    return '监测$elapsed';
  }

  @override
  String get demoTry => '无需连接即可体验';

  @override
  String get demoTitle => '体验 CC Pocket';

  @override
  String get demoExit => '退出体验';

  @override
  String get demoRestart => '重新体验';

  @override
  String get demoDisclaimer => '离线体验 · 使用示例回复，不消耗 AI 用量，也不修改文件。';

  @override
  String get demoWelcome => '试试发送请求、批准或拒绝修改，再查看差异的流程。无需电脑或账号。';

  @override
  String get demoSuggestion => '让欢迎语更亲切一些';

  @override
  String get demoInputHint => '试着输入消息';

  @override
  String get demoInputHelp => '任何消息都会启动相同的示例流程，不会发送给 AI。';

  @override
  String get demoSend => '发送示例请求';

  @override
  String get demoProposal =>
      '此示例将把 lib/welcome.dart 中的欢迎语从“Hello”改为“Hello, Pocket!”。请选择是否允许编辑。';

  @override
  String get demoApprovalTitle => '允许此次示例编辑吗？';

  @override
  String get demoApprovalDetail => '编辑 · lib/welcome.dart\n仅修改示例数据。';

  @override
  String get demoReject => '拒绝';

  @override
  String get demoApprove => '允许一次';

  @override
  String get demoCompleted => '示例编辑已完成。请在下方查看新增和删除的行。没有修改任何实际文件。';

  @override
  String get demoRejected => '已拒绝编辑，没有任何修改。工具操作由你决定。';

  @override
  String get demoDiffSummary => '示例差异 · 新增 1 行，删除 1 行';

  @override
  String get demoFinish => '连接自己的 Bridge 后，即可使用真实项目和 AI 智能体开展工作。';

  @override
  String get demoConnect => '设置我的 Bridge';

  @override
  String liteModeDurationSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String liteModeDurationMinutes(int minutes, int seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String liteModeDurationHours(int hours, int minutes) {
    return '$hours小时$minutes分';
  }

  @override
  String liteModeDurationDays(int days, int hours) {
    return '$days天$hours小时';
  }

  @override
  String get mediaFeedbackComments => '素材指令';

  @override
  String get mediaFeedbackAtTime => '在此时刻评论';

  @override
  String get mediaFeedbackWhole => '整体';

  @override
  String get mediaFeedbackVideoHint => '对此视频的指令…';

  @override
  String get mediaFeedbackImageHint => '对此图片的指令…';

  @override
  String get mediaFeedbackDone => '完成';

  @override
  String get mediaFeedbackSendHint => '自动保存 · 发送聊天时附加到末尾';

  @override
  String get mediaFeedbackSendError => '无法附加素材。请检查连接和图片数量（最多5张）。指令已保存在草稿中。';

  @override
  String get mediaFeedbackSourceChanged => '评论后素材已更新。请检查内容和时间。';

  @override
  String get mediaFeedbackConfirmSource => '应用于更新后的素材';

  @override
  String diffCommentHint(String line) {
    return '对 $line 的评论…';
  }

  @override
  String get diffCommentOutdated => '已过时 — 评论的代码行已更改';

  @override
  String get newProject => 'Create a new project';

  @override
  String get existingProject => 'Start in an existing project';

  @override
  String get multiProjectStart => 'Start in a multi-project';

  @override
  String get multiProjectHint =>
      'Work with multiple projects, such as an app and its API, in one AI session. Folders and Git repositories remain separate.';

  @override
  String get newProjectName => 'Folder name';

  @override
  String get newProjectParent => 'Parent folder';

  @override
  String get newProjectDescription =>
      'What would you like to build? (optional)';

  @override
  String get newProjectGit => 'Track changes with Git';

  @override
  String get newProjectSettingsSource => 'Copy AI settings from';

  @override
  String get newProjectNoSource => 'None';

  @override
  String get newProjectSettingsHint =>
      'Copies instructions, shared AI settings and skills as drafts. Excludes credentials, local-only settings and history. The first message asks the AI to adapt them to this project.';

  @override
  String get newProjectCreate => '创建项目';

  @override
  String get projectSetupWorking => 'Preparing…';

  @override
  String get projectSetupCreated => 'Created';

  @override
  String get projectSetupUpdateHint =>
      'No response. Check the Bridge connection and version; older Bridges need an update. If the folder was created, open it as an existing project.';

  @override
  String get projectSetupAdaptPrompt =>
      'First inspect the AI configuration drafts in .ccpocket-bootstrap and adapt them to this new project. Remove source-specific paths, architecture and release instructions; place useful development rules and skills in their appropriate locations. Do not modify the source project. Explain executable settings such as hooks, external commands and MCP servers and obtain confirmation before enabling them. Explain the adaptations, then proceed with the requested project.';

  @override
  String get trustProject => 'Trust this project in Codex';

  @override
  String get trustProjectHint =>
      'Allows Codex to load this folder’s configuration, hooks and rules. This is separate from command execution permissions.';

  @override
  String get initializeGit => 'Initialize Git';

  @override
  String get projectSetupDone => 'Settings saved';

  @override
  String get gitNoCommits => '尚无提交';

  @override
  String get sessionProject => '项目';

  @override
  String get createProjectShort => '创建';

  @override
  String get multiProjectShort => '多项目';

  @override
  String get changeProjectLocation => '更改';

  @override
  String get chooseExistingFolder => '选择现有文件夹';

  @override
  String get defaultInputDelivery => '运行中发送的消息';

  @override
  String get defaultInputDeliverySubtitle => '发送按钮的默认操作。长按发送可使用另一种方式。';

  @override
  String get skillTriggerStyle => '技能调用符号';

  @override
  String get skillTriggerStyleSubtitle =>
      '/ 和 \$ 都可以打开技能候选。发送时会自动转换为 Claude 的 / 或 Codex 的 \$。';

  @override
  String get skillTriggerStyleBoth => '两者';

  @override
  String get skillTriggerStyleSlash => '始终 /';

  @override
  String get skillTriggerStyleDollar => '始终 \$';

  @override
  String get inputDeliverySteer => '插入';

  @override
  String get inputDeliveryQueue => '排队';

  @override
  String get inputDeliverySteerDescription => '在不停止当前回合的情况下追加指令';

  @override
  String get inputDeliveryQueueDescription => '当前回合结束后发送';

  @override
  String get sendAsSteer => '插入当前回合';

  @override
  String get sendAsQueue => '排队到下一回合';

  @override
  String get backgroundTasksRunning => '正在后台运行';

  @override
  String backgroundTasksMore(int count) {
    return '另有$count项';
  }

  @override
  String sessionCardBackgroundTasks(int count) {
    return '后台 $count';
  }

  @override
  String get liteModeBackground => '后台运行中';

  @override
  String sessionCardBackgroundAgents(int count) {
    return '子代理 $count';
  }

  @override
  String get backgroundTasksStop => '停止后台任务';

  @override
  String get recentFilterPinnedOnly => '已置顶';

  @override
  String recentFilterProjectsSummary(String name, int count) {
    return '$name +$count';
  }

  @override
  String get recentFilterPeriod => '时间';

  @override
  String get recentDateToday => '今天';

  @override
  String get recentDateYesterday => '昨天';

  @override
  String get recentDateDayBeforeYesterday => '前天';

  @override
  String get recentDateLast7Days => '最近 7 天';

  @override
  String get recentDateLast30Days => '最近 30 天';

  @override
  String get recentDateCustom => '自定义范围…';

  @override
  String get recentDateAnyTime => '全部时间';

  @override
  String get recentFilterClear => '清除';

  @override
  String get recentAdvancedSearch => '高级搜索';

  @override
  String recentAdvancedConditions(int count) {
    return '高级条件 $count';
  }

  @override
  String get recentDisplaySettings => '显示设置';

  @override
  String get recentLayout => '布局';

  @override
  String get recentLayoutList => '列表';

  @override
  String get recentLayoutGrouped => '按项目';

  @override
  String get recentCardText => '卡片显示内容';

  @override
  String get recentPinnedSection => '已置顶';

  @override
  String get recentFavoriteProjects => '收藏';

  @override
  String get recentOtherProjects => '其他项目';

  @override
  String get recentSelectFavorites => '全选收藏';

  @override
  String get recentNoFavoriteProjects => '点按 ☆ 添加收藏';

  @override
  String get recentProjectPickerTitle => '按项目筛选';

  @override
  String get recentApply => '应用';

  @override
  String get recentReset => '重置';

  @override
  String get recentKeywords => '关键词';

  @override
  String get recentKeywordsHint => '名称、提示、摘要、项目、分支';

  @override
  String get recentSearchContent => '同时搜索对话正文';

  @override
  String get recentSearchContentHint => '较慢。搜索用户与 AI 的消息';

  @override
  String get recentDateField => '比较时间';

  @override
  String get recentDateFieldModified => '最后更新';

  @override
  String get recentDateFieldCreated => '创建';

  @override
  String get recentNamedOnly => '仅已命名';

  @override
  String get recentPinnedOnly => '仅已置顶';

  @override
  String get recentAiTool => 'AI 工具';

  @override
  String get recentRequiresBridgeUpdate => '更新 Bridge 后可用';

  @override
  String recentMatchedIn(String field) {
    return '匹配：$field';
  }

  @override
  String get recentMatchName => '名称';

  @override
  String get recentMatchFirstPrompt => '首条提示';

  @override
  String get recentMatchLastPrompt => '最后提示';

  @override
  String get recentMatchSummary => '摘要';

  @override
  String get recentMatchProject => '项目';

  @override
  String get recentMatchBranch => '分支';

  @override
  String get recentMatchContent => '正文';

  @override
  String get recentFavoriteTooltip => '收藏';

  @override
  String get contextCompactionTitle => '上下文已压缩';

  @override
  String get contextCompactionManual => '手动';

  @override
  String get contextCompactionAuto => '自动';

  @override
  String contextCompactionTokens(String before, String after) {
    return '$before → $after tokens';
  }

  @override
  String get contextCompactionShowSummary => '显示摘要';

  @override
  String get contextCompactionHideSummary => '隐藏摘要';

  @override
  String get contextCompactionOpenTranscript => '查看之前的消息';

  @override
  String get contextCompactionInProgress => '正在压缩上下文…';

  @override
  String get olderHistoryTitle => '较早的消息已省略';

  @override
  String get transcriptTitle => '之前的消息';

  @override
  String get transcriptLoadOlder => '加载更早的消息';

  @override
  String get transcriptEmpty => '没有可显示的消息';

  @override
  String get transcriptLoadFailed => '无法加载消息';

  @override
  String get transcriptBridgeUpdate => '需要更新 Bridge 才能查看之前的消息。';

  @override
  String get githubIssuesAndPrs => 'Issue / PR';

  @override
  String get githubTabIssues => 'Issue';

  @override
  String get githubTabPrs => 'PR';

  @override
  String get githubDraft => 'Draft';

  @override
  String get githubFilterHideDrafts => '隐藏 Draft';

  @override
  String get githubFilterDependabotOnly => '仅 dependabot';

  @override
  String get githubFilterLabel => '标签';

  @override
  String get githubFilterAllLabels => '全部标签';

  @override
  String get githubEmptyPrs => '没有打开的 PR';

  @override
  String get githubEmptyIssues => '没有打开的 Issue';

  @override
  String get githubEmptyFiltered => '没有符合筛选条件的项目';

  @override
  String get githubOpenOnGitHub => '在 GitHub 中打开';

  @override
  String get githubRecentComments => '最近的评论';

  @override
  String get githubNoComments => '暂无评论';

  @override
  String get githubNoDescription => '没有描述';

  @override
  String get githubSelectAll => '全选';

  @override
  String get githubStartFromIssueOrPr => '从 Issue / PR 开始';

  @override
  String get githubSelect => '选择';

  @override
  String get githubDeselect => '取消选择';

  @override
  String get githubClearSelection => '清除全部选择';

  @override
  String get githubSelectAllSkipsDrafts => 'Draft 会被跳过。点按即可单独加入。';

  @override
  String githubSelectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get githubErrorGhMissingTitle => '未找到 GitHub CLI';

  @override
  String get githubErrorGhMissingBody =>
      '请在运行 Bridge 的机器上安装 GitHub CLI（gh），然后重试。';

  @override
  String get githubErrorUnauthenticatedTitle => 'GitHub CLI 未登录';

  @override
  String get githubErrorUnauthenticatedBody => '请在运行 Bridge 的机器上执行以下命令，然后重试。';

  @override
  String get githubErrorNotGithubTitle => '不是 GitHub 仓库';

  @override
  String get githubErrorNotGithubBody => '此项目的 origin 远程仓库不是 GitHub。';

  @override
  String get githubErrorFailedTitle => '无法从 GitHub 加载';

  @override
  String get githubErrorTimeoutBody => 'Bridge 没有响应。请检查连接后重试。';

  @override
  String get githubErrorUnsupportedTitle => '需要更新 Bridge';

  @override
  String get githubErrorUnsupportedBody =>
      '此 Bridge 尚不支持 Issue / PR。请将 Bridge 更新到最新版本后重试。';

  @override
  String get githubChecksSuccess => 'CI 通过';

  @override
  String get githubChecksFailure => 'CI 失败';

  @override
  String get githubChecksPending => 'CI 运行中';

  @override
  String get settingsEnabledModels => '显示的模型';

  @override
  String get settingsEnabledModelsDescription => '筛选模型选择器中显示的模型。全选时将显示所有可用模型。';

  @override
  String get settingsEnabledModelsAll => '全部模型';

  @override
  String get settingsEnabledModelsSelectAll => '全选';

  @override
  String get settingsEnabledModelsClearAll => '全部取消';

  @override
  String get settingsEnabledModelsAtLeastOne => '请至少选择一个模型';

  @override
  String get settingsEnabledModelsLoading => '正在加载模型列表…';

  @override
  String get settingsEnabledModelsUnavailable => '连接到 Bridge 后可加载可用模型列表';

  @override
  String get settingsModelPickerStyle => '模型选择方式';

  @override
  String get settingsModelPickerStyleSubtitle =>
      '点击模型名称时的显示方式。选择弹出菜单可在原地直接选择，无需再弹出底部弹窗。';

  @override
  String get modelPickerStyleBottomSheet => '底部弹窗';

  @override
  String get modelPickerStylePopupMenu => '弹出菜单';

  @override
  String handoffTo(String agent) {
    return '移交给 $agent';
  }

  @override
  String handoffConfirmBody(String source, String agent) {
    return '$source 会先写一份交接说明，然后此会话停止，由 $agent 在同一目录继续。正在运行的回合会被中断。';
  }

  @override
  String handoffInstructionLabel(String agent) {
    return '给 $agent 的指示（可选）';
  }

  @override
  String get handoffInstructionHint => '留空则继续当前任务';

  @override
  String get handoffConfirmAction => '移交';

  @override
  String handoffStarted(String agent) {
    return '已开始移交给 $agent';
  }

  @override
  String handoffCardFrom(String source) {
    return '从 $source 移交';
  }

  @override
  String handoffCardNoteRequest(String agent) {
    return '已请求给 $agent 的交接说明';
  }

  @override
  String get localBridgeTitle => '这台 Mac 的 Bridge';

  @override
  String get localBridgeSettingsSubtitle => '状态、配对与设置';

  @override
  String get localBridgeStatusRunning => '运行中';

  @override
  String localBridgeStatusDetail(String version, int port) {
    return 'v$version · 端口 $port';
  }

  @override
  String localBridgeStatusCounts(int sessions, int clients) {
    return '会话 $sessions · 已连接设备 $clients';
  }

  @override
  String get localBridgeNotRunningTitle => 'Bridge 未运行';

  @override
  String localBridgeNotRunningBody(int port) {
    return '端口 $port 没有响应。请在终端运行以下命令启动。';
  }

  @override
  String get localBridgeSecretUnavailableTitle => '无法管理此 Bridge';

  @override
  String get localBridgeSecretUnavailableBody =>
      'Bridge 正在运行，但无法读取配对信息。可能由其他用户启动，或版本过旧。';

  @override
  String get localBridgeUpdateRequiredTitle => '需要更新 Bridge';

  @override
  String get localBridgeUpdateRequiredBody =>
      '此 Bridge 尚不支持从应用管理。请更新到最新版本并重新启动。';

  @override
  String get localBridgeErrorTitle => '无法获取 Bridge 信息';

  @override
  String get localBridgeRestartRequired => '更改将在重新启动后生效';

  @override
  String get localBridgeRestartNow => '重新启动以应用';

  @override
  String get localBridgeRestarting => '正在重新启动…';

  @override
  String get localBridgeRestartConfirmTitle => '要重新启动 Bridge 吗？';

  @override
  String get localBridgeRestartConfirmBody => '已连接的设备会自动重新连接。';

  @override
  String localBridgeRestartConfirmSessions(int count) {
    return '$count 个运行中的会话将被中断。';
  }

  @override
  String get localBridgeNotSupervised =>
      '此 Bridge 是手动启动的，应用无法重新启动它。请在运行它的终端中重新启动。';

  @override
  String get localBridgeRestartFailed => 'Bridge 未能重新启动';

  @override
  String get localBridgeActionFailed => '操作失败';

  @override
  String get localBridgeInvalidSettings => '部分设置无法保存';

  @override
  String get localBridgeChangePort => '管理其他端口的 Bridge';

  @override
  String get localBridgePairingTitle => '连接手机';

  @override
  String get localBridgePairingBody => '用手机上的 CC Pocket 扫描二维码即可连接。';

  @override
  String get localBridgePairingSensitive => '二维码包含 API 密钥，共享屏幕时请注意。';

  @override
  String get localBridgePairingNoAddress =>
      '未找到其他设备可访问的地址。请连接 Wi-Fi 或 Tailscale。';

  @override
  String get localBridgeCopyLink => '复制连接链接';

  @override
  String get localBridgeShowQr => '显示二维码';

  @override
  String get localBridgeHideQr => '隐藏二维码';

  @override
  String get localBridgeRotateKey => '重新生成 API 密钥';

  @override
  String get localBridgeRotateKeyConfirmBody => '重新启动后，已配对的设备需要重新扫描二维码。';

  @override
  String get localBridgeRotateKeyDone => '已重新生成 API 密钥，重新启动后生效。';

  @override
  String get localBridgeAuthDisabled => '认证已关闭。任何能访问此端口的人都可以操作你的代理。';

  @override
  String get localBridgeToolsTitle => '所需工具';

  @override
  String get localBridgeToolsReady => '一切就绪';

  @override
  String get localBridgeToolsNotReady => '需要 Node.js、Git 以及至少一个代理';

  @override
  String get localBridgeToolsUnsupported => '需要更新 Bridge 才能检查工具';

  @override
  String get localBridgeToolReady => '可用';

  @override
  String get localBridgeToolNotInstalled => '未安装';

  @override
  String get localBridgeToolNeedsSetup => '需要设置';

  @override
  String get localBridgeToolInstall => '安装';

  @override
  String get localBridgeToolSetup => '设置';

  @override
  String get localBridgeToolDocs => '打开官方指南';

  @override
  String get localBridgeToolRecheck => '重新检查';

  @override
  String get localBridgeToolRunInTerminal => '请在终端运行后重新检查。';

  @override
  String get localBridgeToolRequired => '必需';

  @override
  String get localBridgeToolAgent => '代理';

  @override
  String get localBridgeToolOptional => '可选';

  @override
  String get localBridgeToolDescNode => '运行 Bridge 所需';

  @override
  String get localBridgeToolDescGit => '用于查看差异和分支操作';

  @override
  String get localBridgeToolDescClaude => '用于 Claude Code 会话';

  @override
  String get localBridgeToolDescCodex => '用于 Codex 会话';

  @override
  String get localBridgeToolDescAntigravity => '用于 Antigravity 会话';

  @override
  String get localBridgeToolDescGh => '用于显示 GitHub Issue 和 PR';

  @override
  String get localBridgeToolDescTailscale => '可在外安全连接';

  @override
  String get localBridgeGroupNetwork => '网络';

  @override
  String get localBridgeGroupAccess => '访问范围';

  @override
  String get localBridgeGroupAgents => '代理';

  @override
  String get localBridgeGroupSecurity => '安全';

  @override
  String get localBridgeSettingPort => '端口';

  @override
  String get localBridgeSettingHost => '监听地址';

  @override
  String get localBridgeSettingPublicWsUrl => '公开 URL';

  @override
  String get localBridgeSettingPublicWsUrlDesc => '二维码中使用的 ws:// 或 wss:// URL';

  @override
  String get localBridgeSettingAllowedDirs => '可打开项目的文件夹';

  @override
  String get localBridgeSettingReadOnlyDirs => '仅允许查看的文件夹';

  @override
  String get localBridgeSettingFileDownloadAllowAllPaths => '允许共享任何文件';

  @override
  String get localBridgeSettingFileDownloadAllowAllPathsDesc => '项目之外的文件也可以下载';

  @override
  String get localBridgeSettingInsecureNoAuth => '关闭认证';

  @override
  String get localBridgeSettingInsecureNoAuthDesc => '不推荐。任何能访问端口的人都可以操作';

  @override
  String get localBridgeSettingAllowClaudeOAuth => '使用 Claude 订阅登录';

  @override
  String get localBridgeSettingCodexAppServerMode => 'Codex app-server 共享';

  @override
  String get localBridgeSettingCodexSharedAppServerUrl => '共享 app-server URL';

  @override
  String get localBridgeSettingCodexAssistModel => 'Codex 辅助模型';

  @override
  String get localBridgeSettingCodexAssistReasoningEffort => 'Codex 辅助推理强度';

  @override
  String get localBridgeSettingNotifyGoalTurnCompleted => '同时通知 Goal 的中间回合';

  @override
  String get localBridgeSettingAntigravityApiKey => 'Antigravity API 密钥';

  @override
  String get localBridgeCodexModePrivate => '不共享';

  @override
  String get localBridgeCodexModeManaged => '由 Bridge 启动';

  @override
  String get localBridgeCodexModeExternal => '使用外部 app-server';

  @override
  String localBridgeSettingLockedByEnv(String env) {
    return '由环境变量 $env 指定';
  }

  @override
  String get localBridgeSettingNotSet => '未设置';

  @override
  String get localBridgeSettingConfigured => '已设置';

  @override
  String get localBridgeSettingResetToDefault => '恢复默认';

  @override
  String get localBridgeAllowedDirsAll => '所有文件夹（不限制）';

  @override
  String get localBridgeAddFolder => '添加文件夹';

  @override
  String get localBridgePermissionsTitle => 'macOS 权限';

  @override
  String get localBridgePermissionsFooter =>
      '在“完全磁盘访问权限”和“屏幕录制”列表中显示为“CC Pocket”。更改在重新启动 Bridge 后生效。';

  @override
  String get localBridgePermissionsDialogTitle => '检查 macOS 权限';

  @override
  String get localBridgePermissionsDialogBody =>
      'Bridge 已启动。为避免代理中途停下，请在系统设置中开启缺少的权限。之后也可以在此页面更改。';

  @override
  String get localBridgePermissionLoginItem => '后台运行';

  @override
  String get localBridgePermissionLoginItemDesc => '登录时启动 Bridge，关闭应用后仍继续运行';

  @override
  String get localBridgePermissionFullDisk => '完全磁盘访问权限';

  @override
  String get localBridgePermissionFullDiskDesc =>
      '让代理处理“文稿”“桌面”“下载”或外置磁盘中的项目时，不再在 Mac 上弹出确认对话框';

  @override
  String get localBridgePermissionScreenCapture => '屏幕录制';

  @override
  String get localBridgePermissionScreenCaptureDesc => '用于从手机截取这台 Mac 的屏幕';

  @override
  String get localBridgePermissionLocalNetwork => '本地网络';

  @override
  String get localBridgePermissionLocalNetworkDesc =>
      '代理连接同一网络中的设备（开发服务器、测试设备等）时使用';

  @override
  String get localBridgePermissionRequired => '必需';

  @override
  String get localBridgePermissionRecommended => '推荐';

  @override
  String get localBridgePermissionOptional => '可选';

  @override
  String get localBridgePermissionGranted => '已允许';

  @override
  String get localBridgePermissionMissing => '未允许';

  @override
  String get localBridgePermissionUnknown => '请在系统设置中查看状态';

  @override
  String get localBridgePermissionOpenSettings => '打开设置';

  @override
  String get guideLocalBridgeStepPermissions => '允许 macOS 权限';

  @override
  String get guideLocalBridgeStepPermissionsDetail =>
      '启动后会出现提示，引导你在系统设置中开启完全磁盘访问权限等。之后可随时在 Bridge 管理页面查看。';

  @override
  String get localBridgeSettingPortDesc => '手机等设备连接的端口号（默认：8765）';

  @override
  String get localBridgeSettingHostDesc =>
      '接受连接的地址。0.0.0.0 表示所有网络，127.0.0.1 表示仅限这台 Mac（默认：0.0.0.0）';

  @override
  String get localBridgeSettingAllowedDirsDesc =>
      '只有这些文件夹内的文件夹可以作为项目打开（默认：主文件夹）';

  @override
  String get localBridgeSettingReadOnlyDirsDesc =>
      '即使在项目之外，也只允许预览、下载文件以及在 Finder 中显示';

  @override
  String get localBridgeSettingAllowClaudeOAuthDesc =>
      '使用 Claude 订阅而不是 API 密钥运行 Claude Code。请先确认服务条款方面的风险再开启';

  @override
  String get localBridgeSettingAntigravityApiKeyDesc =>
      'Antigravity 使用的 Gemini API 密钥。未设置时使用 agy 的 Google 登录';

  @override
  String get localBridgeSettingCodexAppServerModeDesc =>
      '是否与终端中的 Codex 共享 Codex app-server（实验性）';

  @override
  String get localBridgeSettingCodexSharedAppServerUrlDesc =>
      '共享 app-server 的 ws:// URL。使用外部 app-server 时必填';

  @override
  String get localBridgeSettingCodexAssistModelDesc => '用于自动生成会话名称和撰写提交信息的模型';

  @override
  String get localBridgeSettingCodexAssistReasoningEffortDesc =>
      '上述辅助功能的推理强度（默认：none）';

  @override
  String get localBridgeSettingNotifyGoalTurnCompletedDesc =>
      '即使 Codex Goal 仍在进行，也会在每个回合结束时通知';

  @override
  String get localBridgeChooseFolder => '选择文件夹…';

  @override
  String get localBridgeFolderPathLabel => '输入路径添加';

  @override
  String get localBridgeFoldersEmpty => '尚未添加文件夹';

  @override
  String get localBridgeFolderSuggestionsTitle => '常用文件夹';

  @override
  String get localBridgeFolderSuggestionAdded => '已添加';

  @override
  String get localBridgeFolderSuggestionTmpTitle => '临时文件夹';

  @override
  String get localBridgeFolderSuggestionTmpDesc => '代理经常把截图和生成的文件放在这里';

  @override
  String get localBridgeFolderSuggestionAntigravityTitle => 'Antigravity 产物';

  @override
  String get localBridgeFolderSuggestionAntigravityDesc =>
      'Antigravity 在这里保存计划文档和生成的图片';

  @override
  String get localBridgeUnsavedChanges => '有未保存的更改';

  @override
  String get localBridgeDiscard => '放弃';

  @override
  String get localBridgeSaved => '已保存';

  @override
  String get localBridgeLogsTitle => '日志';

  @override
  String get localBridgeLogsSubtitle => 'Bridge 的最近输出';

  @override
  String get localBridgeLogsEmpty => '没有日志';

  @override
  String get localBridgeConnectHere => '从此应用连接';

  @override
  String get localBridgeStart => '启动 Bridge';

  @override
  String get localBridgeStop => '停止';

  @override
  String get localBridgeStarting => '正在启动…（首次启动可能需要约 1 分钟）';

  @override
  String get localBridgeStopping => '正在停止…';

  @override
  String get localBridgeStartBody => '点击按钮即可在这台 Mac 上启动 Bridge。';

  @override
  String get localBridgeManagedNote => '关闭应用后 Bridge 仍会继续运行，并在登录时自动启动。';

  @override
  String get localBridgeManualStartHint => '也可以从终端启动。';

  @override
  String get localBridgeStopConfirmTitle => '要停止 Bridge 吗？';

  @override
  String get localBridgeStopConfirmBody => '已连接的设备将断开，并取消登录时自动启动。';

  @override
  String get localBridgeRequiresApproval =>
      '请在系统设置的“通用 > 登录项与扩展”中允许“CC Pocket Bridge”。';

  @override
  String get localBridgeNodeMissing => '未找到 Node.js。安装后会自动启动。';

  @override
  String localBridgeNodeTooOld(String version) {
    return 'Node.js $version 版本过旧。更新到 22.19 或更高版本后会自动启动。';
  }

  @override
  String localBridgePortInUse(int port) {
    return '端口 $port 正被其他程序占用。';
  }

  @override
  String get localBridgeStartFailed => '未能确认 Bridge 已启动';

  @override
  String get localBridgeSafeMode => '保存的设置导致无法启动，目前以默认设置运行。请检查设置后重新启动。';

  @override
  String get guideLocalBridgeTitle => '在这台 Mac 上\n运行 Bridge';

  @override
  String get guideLocalBridgeDescription =>
      'Bridge 是连接手机与这台 Mac 上代理的小型服务器。在 macOS 上可以由应用启动和管理。';

  @override
  String get guideLocalBridgeStep1 => '点击“启动 Bridge”';

  @override
  String get guideLocalBridgeStep1Detail => '关闭应用后仍会继续运行，并在登录时自动启动。';

  @override
  String get guideLocalBridgeStep2 => '检查所需工具';

  @override
  String get guideLocalBridgeStep2Detail =>
      '查看 Node.js、Git 以及 Codex、Claude Code、Antigravity 等的安装状态和可复制的安装命令。';

  @override
  String get guideLocalBridgeStep3 => '在本机连接或用手机扫码';

  @override
  String get guideLocalBridgeStep3Detail => '点击“从此应用连接”即可立即使用，或用手机扫描同一界面的二维码。';

  @override
  String get guideLocalBridgeOpen => '打开 Bridge 管理';

  @override
  String get guideBridgeMacAppNote =>
      '如果使用 Mac，安装 macOS 版 CC Pocket 后可由应用启动 Bridge，无需下面的命令。';

  @override
  String bridgeAuthRequiredLocalBody(String host) {
    return '$host 的 Bridge 需要 API 密钥。可以在这台 Mac 的 Bridge 管理界面中连接此应用。';
  }

  @override
  String get localBridgeUnregister => '取消自动启动';

  @override
  String guideStepProgress(int current, int total) {
    return 'STEP $current / $total';
  }

  @override
  String get guideCopyLink => '复制链接';

  @override
  String get guideSendToMac => '发送到 Mac';

  @override
  String get guideSendToPc => '发送到电脑';

  @override
  String get guideOpenWebsite => '打开页面';

  @override
  String guideShareMacDownloadMessage(String url) {
    return 'CC Pocket for macOS: $url';
  }

  @override
  String guideShareBridgeCommandMessage(String command) {
    return 'CC Pocket Bridge:\n$command';
  }

  @override
  String get guideAboutDesktopTitle => '欢迎使用 CC Pocket';

  @override
  String get guideAboutMacDescription =>
      '在这台 Mac 上使用 Codex、Claude 和 Antigravity，并在手机上无缝接续同一会话。';

  @override
  String get guideAboutDesktopDescription =>
      '通过本桌面应用或手机控制运行在你机器上的 Codex、Claude 和 Antigravity。';

  @override
  String get guideAboutDiagramDesktop => 'Mac 与手机';

  @override
  String get guideAboutHighlightLocal => '代码与凭证始终保留在本地机器';

  @override
  String get guideAboutHighlightMac => 'Mac 用户只需安装 macOS 应用，无需终端配置';

  @override
  String get guideAboutHighlightMacLocal => '直接在此 Mac 应用中启动并管理 Bridge';

  @override
  String get guideAboutHighlightHandoff => '在 CLI、桌面端和手机间无缝继续同一会话';

  @override
  String get guideHostSetupTitle => '准备你的 Mac 或电脑';

  @override
  String get guideHostSetupDescription =>
      '选择你的主机环境。如果你使用 Mac，安装 macOS 应用是最省心的方式。';

  @override
  String get guideHostTabMac => 'Mac（推荐）';

  @override
  String get guideHostTabCli => 'Linux / Windows / CLI';

  @override
  String get guideMacRecommendTitle => 'macOS 版 CC Pocket';

  @override
  String get guideMacRecommendSubtitle =>
      '无需终端命令或守护进程配置，在 Mac 上安装应用即可一键启动 Bridge。';

  @override
  String get guideMacBenefit1 => '一键启动 Bridge，并支持登录时自动启动';

  @override
  String get guideMacBenefit2 => '自动检测 Node.js、Git 及各代理 CLI 安装状态';

  @override
  String get guideMacBenefit3 => '应用内直接显示配对二维码，扫码即连';

  @override
  String get guideMacInstallMethodDownload => '下载页面（.dmg）';

  @override
  String get guideMacInstallMethodHomebrew => '使用 Homebrew 安装';

  @override
  String get guideMacAppleSiliconNote =>
      '支持 Apple Silicon Mac（macOS 13 及以上）。若使用 Intel Mac 或偏好终端，请切换至 Linux / Windows / CLI 标签页。';

  @override
  String get guideMacAfterInstallTitle => '安装后的 3 个步骤';

  @override
  String get guideMacAfterInstallStep1 =>
      '在 Mac 上打开 CC Pocket，点击“此 Mac 上的 Bridge”';

  @override
  String get guideMacAfterInstallStep2 => '点击“启动 Bridge”，按提示检查所需工具';

  @override
  String get guideMacAfterInstallStep3 => '用这部手机扫描显示的二维码';

  @override
  String get guideCliPrerequisitesNote =>
      '需要 Node.js 22.19+ 以及至少一个代理 CLI（Codex、Claude 或 Antigravity）。';

  @override
  String get guideCliRunTitle => '在终端中启动 Bridge';

  @override
  String get guideCliAutostartToggle => '可选：配置开机后台自动启动';

  @override
  String get guideCliAuthToggle => '各代理认证说明';

  @override
  String get guideCliAuthCodex => 'Codex：提前通过 codex CLI 登录（或设置 OPENAI_API_KEY）';

  @override
  String get guideCliAuthClaude =>
      'Claude：设置 ANTHROPIC_API_KEY（订阅登录需显式设置 BRIDGE_ALLOW_CLAUDE_OAUTH=1）';

  @override
  String get guideCliAuthAntigravity =>
      'Antigravity：提前通过 agy CLI 登录（或设置 Gemini API 密钥）';

  @override
  String get guideTailscaleSectionTitle => '想在外出时远程使用？（Tailscale）';

  @override
  String get guideReadyScanQr => '扫描二维码并连接';

  @override
  String get guideReadyLater => '稍后连接并返回首页';

  @override
  String get guideReadyDesktopTitle => '在手机上继续协作';

  @override
  String get guideReadyDesktopDescription =>
      '一切就绪！在 iOS 或 Android 上安装 CC Pocket 并扫码配对，随时随地继续同一会话。';

  @override
  String get guideMobileAppCardTitle => 'CC Pocket 手机版（iOS / Android）';

  @override
  String get guideMobileAppCardBody => '打开安装页面即可前往 App Store / Google Play 下载。';

  @override
  String get guideDesktopLocalConnectTip =>
      '连接本机 Bridge 时，请使用 ws://127.0.0.1:8765 以及启动时显示的 API 密钥。';

  @override
  String get settingsCategoryLocalBridge => '此 Mac 上的 Bridge';

  @override
  String get settingsCategoryShortcuts => '键盘快捷键';

  @override
  String get settingsCategoryShortcutsSummary => '导航、会话与视图快捷键';

  @override
  String get settingsConnectedBridgeSectionTitle => '已连接的 Bridge';

  @override
  String get settingsConnectedToThisMacBadge => '已连接到此 Mac 的本地 Bridge';

  @override
  String get settingsOpenLocalBridgeAction => '打开此 Mac 的 Bridge 设置';

  @override
  String get settingsEditBridgeMachine => '编辑连接设置';

  @override
  String get settingsReconnectBridge => '重新连接';

  @override
  String get settingsCopyBridgeUrl => '复制 URL';

  @override
  String get settingsSwitchBridge => '切换 Bridge';

  @override
  String get settingsBridgeDiagnosticsTitle => '已连接的 Bridge 信息';

  @override
  String get settingsBridgeEndpointLabel => '端点';

  @override
  String get settingsBridgeTransportLabel => '传输方式';

  @override
  String get settingsBridgeTransportSecure => 'WSS（加密）';

  @override
  String get settingsBridgeTransportStandard => 'WS（标准）';

  @override
  String get settingsBridgeTransportSshTunnel => 'SSH 隧道';

  @override
  String get settingsBridgeProtocolLabel => '协议';

  @override
  String get settingsBridgeAllowedDirsLabel => '允许的目录';

  @override
  String get settingsBridgeAllowedDirsAll => '无限制 (*)';

  @override
  String get settingsConnectedBridgeToolsTitle => '已连接主机的工具';

  @override
  String get settingsConnectedBridgeToolsError => '无法从已连接的主机获取工具状态';

  @override
  String get settingsCheckForUpdates => '检查更新…';

  @override
  String get settingsCheckingForUpdates => '正在检查更新…';

  @override
  String get settingsUpToDate => '已是最新版本';

  @override
  String get settingsUpdateCheckFailed => '检查更新失败';

  @override
  String get shortcutsDialogTitle => '键盘快捷键';

  @override
  String get shortcutsGroupApplication => '应用程序';

  @override
  String get shortcutsGroupNavigation => '导航';

  @override
  String get shortcutsGroupSession => '会话';

  @override
  String get shortcutsGroupViewPanes => '视图与面板';

  @override
  String get shortcutsGroupComposer => '输入框与编辑';

  @override
  String get shortcutOpenSettings => '打开设置';

  @override
  String get shortcutOpenLocalBridge => '此 Mac 上的 Bridge 设置';

  @override
  String get shortcutShowShortcuts => '显示键盘快捷键';

  @override
  String get shortcutNewSession => '新建会话';

  @override
  String get shortcutQuickSearch => '快速搜索 / 切换会话';

  @override
  String get shortcutSwitchSessionNumber => '切换到第 1–9 个会话';

  @override
  String get shortcutCloseActive => '关闭当前浮层、会话或窗口';

  @override
  String get shortcutRefresh => '刷新会话列表 / 历史记录';

  @override
  String get shortcutApproveTool => '批准待处理的工具调用';

  @override
  String get shortcutPermissionMode => '打开权限模式菜单';

  @override
  String get shortcutStopGeneration => '停止生成';

  @override
  String get shortcutToggleSidebar => '切换侧边栏';

  @override
  String get shortcutToggleGitPane => '切换 Git 差异面板';

  @override
  String get shortcutToggleExplorerPane => '切换文件浏览器面板';

  @override
  String get shortcutToggleGalleryPane => '切换图库面板';

  @override
  String get shortcutZoomIn => '放大文字';

  @override
  String get shortcutZoomOut => '缩小文字';

  @override
  String get shortcutZoomReset => '实际大小';

  @override
  String get shortcutSendMessage => '发送消息';

  @override
  String get shortcutInsertNewline => '插入换行';

  @override
  String get shortcutFindInBrowser => '在文件浏览器中查找';

  @override
  String get shortcutDismissOverlay => '关闭弹窗或面板';

  @override
  String get menuFile => '文件';

  @override
  String get menuView => '视图';

  @override
  String get menuSession => '会话';

  @override
  String get menuNewSession => '新建会话';

  @override
  String get menuCloseWindow => '关闭窗口';

  @override
  String get menuCloseSession => '关闭会话';

  @override
  String get menuCloseSettings => '关闭设置';

  @override
  String get menuReconnect => '重新连接 / 刷新';

  @override
  String get menuDisconnect => '断开连接';

  @override
  String get menuToggleSidebar => '切换侧边栏';

  @override
  String get menuQuickSearch => '快速搜索';

  @override
  String get menuGitDiff => 'Git 差异';

  @override
  String get menuFileExplorer => '文件浏览器';

  @override
  String get menuGallery => '图库';

  @override
  String get menuActualSize => '实际大小';

  @override
  String get menuZoomIn => '放大';

  @override
  String get menuZoomOut => '缩小';

  @override
  String get menuStopGeneration => '停止生成';

  @override
  String get menuPermissionMode => '权限模式…';

  @override
  String get menuLocalBridgeSettings => '此 Mac 上的 Bridge…';

  @override
  String get menuCheckForUpdates => '检查更新…';

  @override
  String get menuKeyboardShortcuts => '键盘快捷键';

  @override
  String get menuSetupGuide => '设置指南';

  @override
  String get menuChangelog => '更新日志';

  @override
  String get menuGitHubRepo => 'GitHub 仓库';

  @override
  String get plainText => '纯文本';

  @override
  String get resizeSidebar => '调整侧边栏宽度';

  @override
  String get resizeRightPane => '调整右侧面板宽度';

  @override
  String get displayPresetAll => '全部';

  @override
  String get displayPresetRecommended => '推荐';

  @override
  String get displayPresetCustom => '自定义';

  @override
  String displayPresetCustomSummary(int enabled, int total) {
    return '自定义 ($enabled/$total)';
  }

  @override
  String get displayPresetAllDescription => '显示所有工具调用、代码差异和执行结果。';

  @override
  String get displayPresetRecommendedDescription =>
      '保留任务、思考和子代理进度，同时减少 Bridge 发送的工具日志和过程图片。';

  @override
  String get displayPresetCustomDescription => '已自定义要接收和显示的对话项目。';

  @override
  String get displayItemsSectionTitle => '显示项目';

  @override
  String get displayItemsAlwaysVisibleNote => '消息正文、计划、审批、提问、生成的图片和错误始终显示。';

  @override
  String get displayItemTasks => '任务 / TODO';

  @override
  String get displayItemTasksSubtitle => '任务列表与进度清单';

  @override
  String get displayItemThinking => 'Thinking（思考）';

  @override
  String get displayItemThinkingSubtitle => '思考过程与流式显示';

  @override
  String get displayItemSubagents => '子代理 / Swarm';

  @override
  String get displayItemSubagentsSubtitle => '子代理启动、摘要和 Swarm 对话';

  @override
  String get displayItemCodeEdits => '代码编辑与差异';

  @override
  String get displayItemCodeEditsSubtitle => '文件创建、编辑及行内差异';

  @override
  String get displayItemOtherTools => '其他工具调用';

  @override
  String get displayItemOtherToolsSubtitle => '命令执行、文件读取、搜索、MCP 等';

  @override
  String get displayItemToolResults => '工具输出与附带图片';

  @override
  String get displayItemToolResultsSubtitle => '工具输出正文及截图等过程图片';
}
