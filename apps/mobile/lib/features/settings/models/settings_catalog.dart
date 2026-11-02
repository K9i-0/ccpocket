// Search keywords are matching aids in several languages and are never shown
// to users, so they intentionally stay as literals.
// ignore_for_file: altive_lints_plugin/avoid_hardcoded_japanese

import '../../../l10n/app_localizations.dart';

/// Top-level groups shown on the settings home screen.
///
/// The order here is the display order.
enum SettingsCategory {
  connection,
  notifications,
  usage,
  appearance,
  input,
  agents,
  git,
  support,
  about,
}

/// Runtime conditions that decide which settings are shown.
///
/// Both the category pages and the search index read the same
/// [SettingsEntry.isVisible] predicates, so they cannot drift apart.
class SettingsVisibility {
  const SettingsVisibility({
    this.hasActiveMachine = false,
    this.bridgeConnected = false,
    this.hasBridgeUrl = false,
    this.promptHistoryAvailable = false,
    this.appIconSupported = false,
    this.hideVoiceInput = false,
    this.terminalAppEnabled = false,
    this.isMacOS = false,
    this.isMobile = false,
    this.bothAgents = true,
    this.codexEnabled = true,
    this.claudeEnabled = true,
    this.fcmEnabled = false,
    this.supportAvailable = false,
    this.isIOSAppOnMac = false,
  });

  /// A Bridge machine is selected (`SettingsState.activeMachineId != null`).
  final bool hasActiveMachine;

  /// The WebSocket connection to the Bridge is currently open.
  final bool bridgeConnected;
  final bool hasBridgeUrl;
  final bool promptHistoryAvailable;
  final bool appIconSupported;
  final bool hideVoiceInput;
  final bool terminalAppEnabled;
  final bool isMacOS;
  final bool isMobile;
  final bool bothAgents;
  final bool codexEnabled;
  final bool claudeEnabled;
  final bool fcmEnabled;
  final bool supportAvailable;
  final bool isIOSAppOnMac;
}

typedef SettingsVisibilityPredicate = bool Function(SettingsVisibility v);
typedef SettingsLabelBuilder = String Function(AppLocalizations l);

/// A single searchable setting row.
class SettingsEntry {
  const SettingsEntry({
    required this.id,
    required this.category,
    required this.title,
    this.keywords = '',
    this.visibleWhen,
  });

  /// Stable identifier. Rows render a `settings_item_<id>` key.
  final String id;
  final SettingsCategory category;
  final SettingsLabelBuilder title;

  /// Extra search terms (space separated, any language).
  final String keywords;
  final SettingsVisibilityPredicate? visibleWhen;

  bool isVisible(SettingsVisibility v) => visibleWhen?.call(v) ?? true;
}

abstract final class SettingsEntryIds {
  static const bridgeMachine = 'bridge_machine';
  static const localUrl = 'local_url';
  static const bridgeUpdate = 'bridge_update';
  static const promptHistory = 'prompt_history';
  static const theme = 'theme';
  static const language = 'language';
  static const appIcon = 'app_icon';
  static const textDensity = 'text_density';
  static const codeFont = 'code_font';
  static const indentSize = 'indent_size';
  static const voiceInput = 'voice_input';
  static const hideVoiceInput = 'hide_voice_input';
  static const defaultInputDelivery = 'default_input_delivery';
  static const skillTriggerStyle = 'skill_trigger_style';
  static const openGalleryDirectly = 'open_gallery_directly';
  static const imagePasteShortcut = 'image_paste_shortcut';
  static const liteMode = 'lite_mode';
  static const enabledAgents = 'enabled_agents';
  static const newSessionTabs = 'new_session_tabs';
  static const autoRenameCodex = 'auto_rename_codex';
  static const extendedCodexEfforts = 'extended_codex_efforts';
  static const autoRenameClaude = 'auto_rename_claude';
  static const showHiddenDirectories = 'show_hidden_directories';
  static const showBridgeName = 'show_bridge_name';
  static const terminalApp = 'terminal_app';
  static const gitDiffMode = 'git_diff_mode';
  static const gitDiffAutoLandscape = 'git_diff_auto_landscape';
  static const remoteGitStatusBadge = 'remote_git_status_badge';
  static const pushNotifications = 'push_notifications';
  static const pushPrivacy = 'push_privacy';
  static const notificationLanguage = 'notification_language';
  static const usage = 'usage';
  static const supporter = 'supporter';
  static const rateApp = 'rate_app';
  static const shareApp = 'share_app';
  static const starOnGithub = 'star_on_github';
  static const version = 'version';
  static const macosNativeApp = 'macos_native_app';
  static const changelog = 'changelog';
  static const setupGuide = 'setup_guide';
  static const githubRepository = 'github_repository';
  static const licenses = 'licenses';
}

bool _activeMachine(SettingsVisibility v) => v.hasActiveMachine;

/// Every row on every settings page, in page order.
final List<SettingsEntry> settingsEntries = [
  // ── Connection ──
  SettingsEntry(
    id: SettingsEntryIds.bridgeMachine,
    category: SettingsCategory.connection,
    title: (l) => l.settingsBridgeMachine,
    keywords: 'machine host server マシン ホスト サーバー',
    visibleWhen: _activeMachine,
  ),
  SettingsEntry(
    id: SettingsEntryIds.localUrl,
    category: SettingsCategory.connection,
    title: (l) => l.localUrlTitle,
    keywords: 'localhost port browser url ポート ブラウザ',
    visibleWhen: (v) => v.hasActiveMachine && v.hasBridgeUrl,
  ),
  SettingsEntry(
    id: SettingsEntryIds.bridgeUpdate,
    category: SettingsCategory.connection,
    title: (l) => l.updateBridge,
    keywords: 'bridge version update バージョン 更新 アップデート',
    visibleWhen: _activeMachine,
  ),
  SettingsEntry(
    id: SettingsEntryIds.promptHistory,
    category: SettingsCategory.connection,
    title: (l) => l.promptHistorySectionTitle,
    keywords: 'prompt history sync 履歴 同期',
    visibleWhen: (v) => v.hasActiveMachine && v.promptHistoryAvailable,
  ),

  // ── Notifications ──
  SettingsEntry(
    id: SettingsEntryIds.pushNotifications,
    category: SettingsCategory.notifications,
    title: (l) => l.pushNotifications,
    keywords: 'push notification fcm プッシュ 通知',
    visibleWhen: _activeMachine,
  ),
  SettingsEntry(
    id: SettingsEntryIds.pushPrivacy,
    category: SettingsCategory.notifications,
    title: (l) => l.pushPrivacyMode,
    keywords: 'privacy hide content プライバシー',
    visibleWhen: (v) => v.hasActiveMachine && v.fcmEnabled,
  ),
  SettingsEntry(
    id: SettingsEntryIds.notificationLanguage,
    category: SettingsCategory.notifications,
    title: (l) => l.updateNotificationLanguage,
    keywords: 'language locale 言語',
    visibleWhen: (v) => v.hasActiveMachine && v.fcmEnabled,
  ),

  // ── Usage ──
  SettingsEntry(
    id: SettingsEntryIds.usage,
    category: SettingsCategory.usage,
    title: (l) => l.settingsUsageSectionTitle,
    keywords: 'usage limit plan quota rate 利用量 制限 プラン',
    visibleWhen: (v) => v.bridgeConnected,
  ),

  // ── Appearance ──
  SettingsEntry(
    id: SettingsEntryIds.theme,
    category: SettingsCategory.appearance,
    title: (l) => l.theme,
    keywords: 'dark light mode color ダーク ライト テーマ',
  ),
  SettingsEntry(
    id: SettingsEntryIds.language,
    category: SettingsCategory.appearance,
    title: (l) => l.language,
    keywords: 'language locale 言語 english 日本語',
  ),
  SettingsEntry(
    id: SettingsEntryIds.appIcon,
    category: SettingsCategory.appearance,
    title: (l) => l.appIconTitle,
    keywords: 'app icon アイコン',
    visibleWhen: (v) => v.appIconSupported,
  ),
  SettingsEntry(
    id: SettingsEntryIds.textDensity,
    category: SettingsCategory.appearance,
    title: (l) => l.textDensity,
    keywords: 'text scale font size 文字 サイズ 拡大',
  ),
  SettingsEntry(
    id: SettingsEntryIds.codeFont,
    category: SettingsCategory.appearance,
    title: (l) => l.codeFontFamily,
    keywords: 'code font monospace コード フォント',
  ),
  SettingsEntry(
    id: SettingsEntryIds.indentSize,
    category: SettingsCategory.appearance,
    title: (l) => l.indentSize,
    keywords: 'indent tab インデント',
  ),

  // ── Input ──
  SettingsEntry(
    id: SettingsEntryIds.voiceInput,
    category: SettingsCategory.input,
    title: (l) => l.voiceInput,
    keywords: 'voice speech microphone 音声 マイク',
    visibleWhen: (v) => !v.hideVoiceInput,
  ),
  SettingsEntry(
    id: SettingsEntryIds.hideVoiceInput,
    category: SettingsCategory.input,
    title: (l) => l.hideVoiceInput,
    keywords: 'voice microphone 音声 マイク 非表示',
  ),
  SettingsEntry(
    id: SettingsEntryIds.defaultInputDelivery,
    category: SettingsCategory.input,
    title: (l) => l.defaultInputDelivery,
    keywords: 'queue steer send 送信 キュー',
  ),
  SettingsEntry(
    id: SettingsEntryIds.skillTriggerStyle,
    category: SettingsCategory.input,
    title: (l) => l.skillTriggerStyle,
    keywords: 'skill slash dollar スキル スラッシュ',
  ),
  SettingsEntry(
    id: SettingsEntryIds.openGalleryDirectly,
    category: SettingsCategory.input,
    title: (l) => l.openGalleryDirectly,
    keywords: 'gallery photo image attachment 写真 画像 添付',
  ),
  SettingsEntry(
    id: SettingsEntryIds.imagePasteShortcut,
    category: SettingsCategory.input,
    title: (l) => l.imagePasteShortcut,
    keywords: 'paste image shortcut keyboard 貼り付け ショートカット',
    visibleWhen: (v) => v.isMacOS,
  ),
  SettingsEntry(
    id: SettingsEntryIds.liteMode,
    category: SettingsCategory.input,
    title: (l) => l.liteMode,
    keywords: 'lite performance fast 軽量 パフォーマンス',
  ),

  // ── Agents ──
  SettingsEntry(
    id: SettingsEntryIds.enabledAgents,
    category: SettingsCategory.agents,
    title: (l) => l.settingsEnabledAgents,
    keywords: 'claude codex agent エージェント',
  ),
  SettingsEntry(
    id: SettingsEntryIds.newSessionTabs,
    category: SettingsCategory.agents,
    title: (l) => l.settingsNewSessionTabs,
    keywords: 'new session tab order タブ 新規',
    visibleWhen: (v) => v.bothAgents,
  ),
  SettingsEntry(
    id: SettingsEntryIds.autoRenameCodex,
    category: SettingsCategory.agents,
    title: (l) => l.autoRenameCodexSessions,
    keywords: 'codex rename title 名前',
    visibleWhen: (v) => v.codexEnabled,
  ),
  SettingsEntry(
    id: SettingsEntryIds.extendedCodexEfforts,
    category: SettingsCategory.agents,
    title: (l) => l.showExtendedCodexEfforts,
    keywords: 'codex effort reasoning 推論',
    visibleWhen: (v) => v.codexEnabled,
  ),
  SettingsEntry(
    id: SettingsEntryIds.autoRenameClaude,
    category: SettingsCategory.agents,
    title: (l) => l.autoRenameClaudeSessions,
    keywords: 'claude rename title 名前',
    visibleWhen: (v) => v.claudeEnabled,
  ),
  SettingsEntry(
    id: SettingsEntryIds.showHiddenDirectories,
    category: SettingsCategory.agents,
    title: (l) => l.showHiddenDirectories,
    keywords: 'hidden dot folder directory 隠し フォルダ',
  ),
  SettingsEntry(
    id: SettingsEntryIds.showBridgeName,
    category: SettingsCategory.agents,
    title: (l) => l.showBridgeNameInSessionList,
    keywords: 'bridge name session list マシン名',
  ),
  SettingsEntry(
    id: SettingsEntryIds.terminalApp,
    category: SettingsCategory.agents,
    title: (l) => l.terminalApp,
    keywords: 'terminal ssh ターミナル',
    visibleWhen: (v) => v.terminalAppEnabled,
  ),

  // ── Git ──
  SettingsEntry(
    id: SettingsEntryIds.gitDiffMode,
    category: SettingsCategory.git,
    title: (l) => l.gitDiffInteractionMode,
    keywords: 'git diff scroll 差分 スクロール',
  ),
  SettingsEntry(
    id: SettingsEntryIds.gitDiffAutoLandscape,
    category: SettingsCategory.git,
    title: (l) => l.gitDiffFocusAutoLandscape,
    keywords: 'landscape rotate 横向き 回転',
  ),
  SettingsEntry(
    id: SettingsEntryIds.remoteGitStatusBadge,
    category: SettingsCategory.git,
    title: (l) => l.remoteGitStatusBadge,
    keywords: 'git remote badge push pull バッジ',
  ),

  // ── Support ──
  SettingsEntry(
    id: SettingsEntryIds.supporter,
    category: SettingsCategory.support,
    title: (l) => l.sectionSupport,
    keywords: 'supporter donate subscription サポーター 応援 寄付',
    visibleWhen: (v) => v.supportAvailable,
  ),
  SettingsEntry(
    id: SettingsEntryIds.rateApp,
    category: SettingsCategory.support,
    title: (l) => l.rateOnStore,
    keywords: 'review rate store レビュー 評価',
    visibleWhen: (v) => v.hasActiveMachine && v.isMobile,
  ),
  SettingsEntry(
    id: SettingsEntryIds.shareApp,
    category: SettingsCategory.support,
    title: (l) => l.shareApp,
    keywords: 'share sns シェア 共有',
    visibleWhen: _activeMachine,
  ),
  SettingsEntry(
    id: SettingsEntryIds.starOnGithub,
    category: SettingsCategory.support,
    title: (l) => l.starOnGithub,
    keywords: 'github star スター',
    visibleWhen: _activeMachine,
  ),

  // ── About ──
  SettingsEntry(
    id: SettingsEntryIds.version,
    category: SettingsCategory.about,
    title: (l) => l.version,
    keywords: 'version build update バージョン',
  ),
  SettingsEntry(
    id: SettingsEntryIds.macosNativeApp,
    category: SettingsCategory.about,
    title: (l) => l.macosNativeAppSettingsTitle,
    keywords: 'mac macos native desktop',
    visibleWhen: (v) => v.isIOSAppOnMac,
  ),
  SettingsEntry(
    id: SettingsEntryIds.changelog,
    category: SettingsCategory.about,
    title: (l) => l.changelog,
    keywords: 'changelog release notes 変更 履歴',
  ),
  SettingsEntry(
    id: SettingsEntryIds.setupGuide,
    category: SettingsCategory.about,
    title: (l) => l.setupGuide,
    keywords: 'setup guide help ガイド ヘルプ',
  ),
  SettingsEntry(
    id: SettingsEntryIds.githubRepository,
    category: SettingsCategory.about,
    title: (l) => l.githubRepository,
    keywords: 'github source code ソース',
  ),
  SettingsEntry(
    id: SettingsEntryIds.licenses,
    category: SettingsCategory.about,
    title: (l) => l.openSourceLicenses,
    keywords: 'license oss ライセンス',
  ),
];

SettingsEntry? settingsEntryById(String id) {
  for (final entry in settingsEntries) {
    if (entry.id == id) return entry;
  }
  return null;
}

/// Entries of [category] that are shown under [visibility].
List<SettingsEntry> visibleSettingsEntries(
  SettingsCategory category,
  SettingsVisibility visibility,
) {
  return [
    for (final entry in settingsEntries)
      if (entry.category == category && entry.isVisible(visibility)) entry,
  ];
}

/// Categories rendered inside the settings home (the status card) rather
/// than as their own page.
const Set<SettingsCategory> inlineSettingsCategories = {SettingsCategory.usage};

/// Page categories that have at least one visible entry.
List<SettingsCategory> visibleSettingsCategories(
  SettingsVisibility visibility,
) {
  return [
    for (final category in SettingsCategory.values)
      if (!inlineSettingsCategories.contains(category) &&
          visibleSettingsEntries(category, visibility).isNotEmpty)
        category,
  ];
}

/// Case-insensitive search across titles, category names and keywords.
///
/// Every whitespace-separated term in [query] must match.
List<SettingsEntry> searchSettingsEntries({
  required String query,
  required AppLocalizations l,
  required SettingsVisibility visibility,
  required String Function(SettingsCategory category) categoryTitle,
}) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) return const [];
  return [
    for (final entry in settingsEntries)
      if (entry.isVisible(visibility) &&
          _matches(
            '${entry.title(l)} ${categoryTitle(entry.category)} '
                    '${entry.keywords}'
                .toLowerCase(),
            terms,
          ))
        entry,
  ];
}

bool _matches(String haystack, List<String> terms) {
  for (final term in terms) {
    if (!haystack.contains(term)) return false;
  }
  return true;
}
