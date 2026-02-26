// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'CC Pocket';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get rename => '名前を変更';

  @override
  String get renameSession => 'セッション名を変更';

  @override
  String get sessionNameHint => 'セッション名';

  @override
  String get clearName => '名前をクリア';

  @override
  String get connect => '接続';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'コピーしました';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get lineCopied => '行をコピーしました';

  @override
  String get start => '開始';

  @override
  String get stop => '停止';

  @override
  String get send => '送信';

  @override
  String get settings => '設定';

  @override
  String get gallery => 'ギャラリー';

  @override
  String galleryWithCount(int count) {
    return 'ギャラリー ($count)';
  }

  @override
  String get disconnect => '切断';

  @override
  String get back => '戻る';

  @override
  String get next => '次へ';

  @override
  String get done => '完了';

  @override
  String get skip => 'スキップ';

  @override
  String get edit => '編集';

  @override
  String get share => '共有';

  @override
  String get all => 'すべて';

  @override
  String get none => 'なし';

  @override
  String get serverUnreachable => 'サーバーに接続できません';

  @override
  String get serverUnreachableBody => 'Bridge サーバーに到達できません:';

  @override
  String get setupSteps => 'セットアップ手順:';

  @override
  String get setupStep1Title => 'Bridge Server を起動';

  @override
  String get setupStep1Command => 'npx @ccpocket/bridge@latest';

  @override
  String get setupStep2Title => '常時起動したい場合はサービス登録';

  @override
  String get setupStep2Command => 'npx @ccpocket/bridge@latest setup';

  @override
  String get setupNetworkHint =>
      '両方のデバイスが同じネットワーク上にあることを確認してください（または Tailscale を使用）。';

  @override
  String get connectAnyway => '接続を続行';

  @override
  String get stopSession => 'セッションを停止';

  @override
  String get stopSessionConfirm => 'このセッションを停止しますか？ Claude プロセスが終了します。';

  @override
  String get startNewWithSameSettings => '同じ設定で新規開始';

  @override
  String get editSettingsThenStart => '設定を変更して開始';

  @override
  String get serverRequiresApiKey => 'このサーバーには API キーが必要です';

  @override
  String get bridgeServerUpdated => 'Bridge Server を更新しました';

  @override
  String get failedToUpdateServer => 'サーバーの更新に失敗しました';

  @override
  String get bridgeServerStarted => 'Bridge Server を起動しました';

  @override
  String get failedToStartServer => 'サーバーの起動に失敗しました';

  @override
  String get bridgeServerStopped => 'Bridge Server を停止しました';

  @override
  String get failedToStopServer => 'サーバーの停止に失敗しました';

  @override
  String get sshPassword => 'SSH パスワード';

  @override
  String sshPasswordPrompt(String machineName) {
    return '$machineName の SSH パスワードを入力';
  }

  @override
  String get password => 'パスワード';

  @override
  String get deleteMachine => 'マシンを削除';

  @override
  String deleteMachineConfirm(String displayName) {
    return '\"$displayName\" を削除しますか？保存された認証情報もすべて削除されます。';
  }

  @override
  String get connectToBridgeServer => 'Bridge Server に接続';

  @override
  String get orConnectManually => 'または手動で接続';

  @override
  String get serverUrl => 'サーバー URL';

  @override
  String get serverUrlHint => 'ws://<host-ip>:8765';

  @override
  String get apiKeyOptional => 'API キー（任意）';

  @override
  String get apiKeyHint => '認証なしの場合は空欄';

  @override
  String get scanQrCode => 'QR コードをスキャン';

  @override
  String get setupGuide => 'セットアップガイド';

  @override
  String get readyToStart => '準備完了';

  @override
  String get readyToStartDescription =>
      '+ ボタンを押してセッションを作成し、Claude でコーディングを始めましょう。';

  @override
  String get newSession => '新規セッション';

  @override
  String get neverConnected => '未接続';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String daysAgo(int days) {
    return '$days日前';
  }

  @override
  String get unfavorite => 'お気に入り解除';

  @override
  String get favorite => 'お気に入り';

  @override
  String get updateBridge => 'Bridge を更新';

  @override
  String get stopServer => 'サーバーを停止';

  @override
  String get update => '更新';

  @override
  String get offline => 'オフライン';

  @override
  String get unreachable => '接続不可';

  @override
  String get checking => '確認中...';

  @override
  String get recentProjects => '最近のプロジェクト';

  @override
  String get orEnterPath => 'またはパスを入力';

  @override
  String get projectPath => 'プロジェクトパス';

  @override
  String get projectPathHint => '/path/to/your/project';

  @override
  String get permission => 'パーミッション';

  @override
  String get approval => '承認';

  @override
  String get worktree => 'Worktree';

  @override
  String get advanced => '詳細設定';

  @override
  String get modelOptional => 'モデル（任意）';

  @override
  String get effort => 'Effort';

  @override
  String get defaultLabel => 'デフォルト';

  @override
  String get maxTurns => 'Max Turns';

  @override
  String get maxTurnsHint => '例: 8';

  @override
  String get maxTurnsError => '1以上の整数を入力してください';

  @override
  String get maxBudgetUsd => '最大予算 (USD)';

  @override
  String get maxBudgetHint => '例: 1.00';

  @override
  String get maxBudgetError => '0以上の数値を入力してください';

  @override
  String get fallbackModel => 'フォールバックモデル';

  @override
  String get forkSessionOnResume => '再開時にセッションを分岐';

  @override
  String get persistSessionHistory => 'セッション履歴を保持';

  @override
  String get model => 'モデル';

  @override
  String get sandbox => 'Sandbox';

  @override
  String get reasoning => 'Reasoning';

  @override
  String get webSearch => 'Web Search';

  @override
  String get networkAccess => 'ネットワークアクセス';

  @override
  String get worktreeNew => '新規';

  @override
  String worktreeExisting(int count) {
    return '既存 ($count)';
  }

  @override
  String get branchOptional => 'ブランチ（任意）';

  @override
  String get branchHint => 'ccpocket/<auto>';

  @override
  String get noExistingWorktrees => '既存の worktree はありません';

  @override
  String get planApprovalSummary => '上のプランを確認して、承認するか計画を続けてください';

  @override
  String get planApprovalSummaryCard => 'プランを確認して、承認するか計画を続けてください';

  @override
  String get toolApprovalSummary => 'ツール実行には承認が必要です';

  @override
  String get planApproval => 'プラン承認';

  @override
  String get approvalRequired => '承認が必要';

  @override
  String get viewEditPlan => 'プランを表示 / 編集';

  @override
  String get keepPlanning => '計画を続ける';

  @override
  String get keepPlanningHint => '変更点を入力...';

  @override
  String get sendFeedbackKeepPlanning => 'フィードバックを送信して計画を続ける';

  @override
  String get acceptAndClear => '承認 & クリア';

  @override
  String get acceptPlan => 'プラン承認';

  @override
  String get reject => '拒否';

  @override
  String get approve => '承認';

  @override
  String get always => '常に許可';

  @override
  String get messagePlaceholder => 'Claude にメッセージ...';

  @override
  String filesMentioned(int count) {
    return '$count ファイルを @メンション中';
  }

  @override
  String diffLines(int count) {
    return '$count 行の diff';
  }

  @override
  String get tapInterruptHoldStop => 'タップ: 中断, 長押し: 停止';

  @override
  String get rewindToHere => 'ここまで巻き戻す';

  @override
  String get tapToRetry => 'タップしてリトライ';

  @override
  String diffSummaryAddedRemoved(int added, int removed) {
    return '+$added/-$removed 行';
  }

  @override
  String lineCountSummary(int count) {
    return '$count 行';
  }

  @override
  String get toolResult => 'ツール結果';

  @override
  String get answered => '回答済み';

  @override
  String get claudeIsAsking => 'Claude が質問しています';

  @override
  String get submitAllAnswers => 'すべての回答を送信';

  @override
  String submitWithCount(int count) {
    return '送信 ($count 件選択)';
  }

  @override
  String get selectOptionsToSubmit => 'オプションを選択してください';

  @override
  String get typeYourAnswer => '回答を入力...';

  @override
  String get orTypeCustomAnswer => 'またはカスタム回答を入力...';

  @override
  String get otherAnswer => 'その他の回答...';

  @override
  String get selectAllThatApply => '該当するものをすべて選択';

  @override
  String get noScreenshotsYet => 'スクリーンショットはまだありません';

  @override
  String get screenshotButtonHint => 'チャットツールバーのスクリーンショットボタンで画面をキャプチャできます。';

  @override
  String get screenshotsWillAppearHere => 'Claude セッションのスクリーンショットがここに表示されます。';

  @override
  String allWithCount(int count) {
    return 'すべて ($count)';
  }

  @override
  String get noImages => '画像がありません';

  @override
  String get failedToDeleteImage => '画像の削除に失敗しました';

  @override
  String get failedToDownloadImage => '画像のダウンロードに失敗しました';

  @override
  String get failedToShareImage => '画像の共有に失敗しました';

  @override
  String get deleteScreenshot => 'スクリーンショットを削除しますか？';

  @override
  String get cannotBeUndone => 'この操作は取り消せません。';

  @override
  String get changes => '変更';

  @override
  String get cancelSelection => '選択をキャンセル';

  @override
  String get selectAndAttach => '選択して添付';

  @override
  String get filterFiles => 'ファイルをフィルター';

  @override
  String attachFilesAndHunks(int files, int hunks) {
    return '添付 $files ファイル, $hunks ハンク';
  }

  @override
  String get filterFilesTitle => 'ファイルをフィルター';

  @override
  String get noChanges => '変更なし';

  @override
  String get allFilesFilteredOut => 'すべてのファイルがフィルターされています';

  @override
  String get showAll => 'すべて表示';

  @override
  String get setupGuideTitle => 'セットアップガイド';

  @override
  String get guideAboutTitle => 'CC Pocket とは';

  @override
  String get guideAboutDescription =>
      'スマートフォンから Claude Code や Codex を操作できるモバイルクライアントです。';

  @override
  String get guideAboutDiagramTitle => 'しくみ';

  @override
  String get guideAboutDiagramPhone => 'iPhone';

  @override
  String get guideAboutDiagramBridge => 'Bridge Server';

  @override
  String get guideAboutDiagramClaude => 'Claude CLI\n/ Codex';

  @override
  String get guideAboutDiagramCaption =>
      'PC で Bridge Server を起動し、\nスマホから接続して使います。';

  @override
  String get guideBridgeTitle => 'Bridge Server の\nセットアップ';

  @override
  String get guideBridgeDescription => 'PC で Bridge Server を起動しましょう。';

  @override
  String get guideBridgePrerequisites => '必要なもの';

  @override
  String get guideBridgePrereq1 => 'Node.js がインストールされた Mac / PC';

  @override
  String get guideBridgePrereq2 =>
      'Claude Code CLI または Codex CLI\n（使いたい方だけでOK）';

  @override
  String get guideBridgeStep1 => 'npx で実行（推奨）';

  @override
  String get guideBridgeStep1Command => 'npx @ccpocket/bridge@latest';

  @override
  String get guideBridgeStep2 => 'またはグローバルインストール';

  @override
  String get guideBridgeStep2Command =>
      'npm install -g @ccpocket/bridge\nccpocket-bridge';

  @override
  String get guideBridgeQrNote => '起動するとターミナルに QR コードが表示されます';

  @override
  String get guideConnectionTitle => '接続方法';

  @override
  String get guideConnectionDescription => '同じ Wi-Fi ネットワーク内なら、すぐに接続できます。';

  @override
  String get guideConnectionQr => 'QR コードスキャン';

  @override
  String get guideConnectionQrDescription =>
      'ターミナルに表示された QR コードを読み取るだけ。一番簡単です。';

  @override
  String get guideConnectionMdns => '自動検出 (mDNS)';

  @override
  String get guideConnectionMdnsDescription =>
      '同一 LAN 内の Bridge Server を自動で見つけて表示します。';

  @override
  String get guideConnectionManual => '手動入力';

  @override
  String get guideConnectionManualDescription =>
      'ws://<IP アドレス>:8765 の形式で直接入力します。';

  @override
  String get guideConnectionRecommended => 'おすすめ';

  @override
  String get guideTailscaleTitle => '外出先からの接続';

  @override
  String get guideTailscaleDescription =>
      '自宅の外からも使いたい場合は、Tailscale（VPN の一種）を使えば安全にリモート接続できます。';

  @override
  String get guideTailscaleStep1 => 'Mac と iPhone の両方に Tailscale をインストール';

  @override
  String get guideTailscaleStep2 => '同じアカウントでログイン';

  @override
  String get guideTailscaleStep3 =>
      'Bridge URL に Tailscale IP を使用\n(例: ws://100.x.x.x:8765)';

  @override
  String get guideTailscaleWebsite => 'Tailscale 公式サイト';

  @override
  String get guideTailscaleWebsiteHint => '詳しいセットアップ方法は公式サイトをご覧ください。';

  @override
  String get guideLaunchdTitle => '常時起動の設定';

  @override
  String get guideLaunchdDescription =>
      '毎回手動で Bridge Server を起動するのが面倒な場合、Mac の起動時に自動で立ち上がるよう設定できます。';

  @override
  String get guideLaunchdCommand => 'セットアップコマンド';

  @override
  String get guideLaunchdCommandValue => 'npx @ccpocket/bridge@latest setup';

  @override
  String get guideLaunchdRecommendation =>
      'まずは手動起動で動作確認してから、安定したら launchd 登録がおすすめです。';

  @override
  String get guideReadyTitle => '準備完了!';

  @override
  String get guideReadyDescription =>
      'Bridge Server を起動して、\nQR コードをスキャンするところから\n始めましょう。';

  @override
  String get guideReadyStart => 'さっそく始める';

  @override
  String get guideReadyHint => 'このガイドは設定画面からいつでも確認できます';

  @override
  String get creatingSession => 'セッション作成中...';

  @override
  String get copyForAgent => 'エージェント用にコピー';

  @override
  String get messageHistory => 'メッセージ履歴';

  @override
  String get viewChanges => '変更を確認';

  @override
  String get screenshot => 'スクリーンショット';

  @override
  String get debug => 'デバッグ';

  @override
  String get logs => 'ログ';

  @override
  String get viewApplicationLogs => 'アプリケーションログを表示';

  @override
  String get mockPreview => 'モックプレビュー';

  @override
  String get viewMockChatScenarios => 'モックチャットシナリオを表示';

  @override
  String get updateTrack => 'アップデートトラック';

  @override
  String get updateTrackDescription => '変更後にアプリを再起動すると反映されます';

  @override
  String get updateTrackStable => 'Stable（安定版）';

  @override
  String get updateTrackStaging => 'Staging（テスト）';

  @override
  String get updateDownloaded => 'アップデートをダウンロードしました。アプリを再起動すると反映されます。';

  @override
  String get promptHistory => 'プロンプト履歴';

  @override
  String get frequent => '頻度順';

  @override
  String get recent => '新しい順';

  @override
  String get searchHint => '検索...';

  @override
  String get noMatchingPrompts => '一致するプロンプトがありません';

  @override
  String get noPromptHistoryYet => 'プロンプト履歴はまだありません';

  @override
  String get approvalQueue => '承認キュー';

  @override
  String get resetQueue => 'キューをリセット';

  @override
  String get swipeSkip => 'スキップ';

  @override
  String get swipeSend => '送信';

  @override
  String get swipeDismiss => '却下';

  @override
  String get swipeApprove => '承認';

  @override
  String get swipeReject => '拒否';

  @override
  String get allClear => 'すべて完了!';

  @override
  String itemsProcessed(int count) {
    return '$count 件処理しました';
  }

  @override
  String bestStreak(int count) {
    return '最高連続: $count';
  }

  @override
  String get tryAgain => 'もう一度';

  @override
  String get waitingForTasks => 'タスク待ち';

  @override
  String get agentReadyForPrompt => 'エージェントは次のプロンプトを待っています。';

  @override
  String get backToSessions => 'セッション一覧に戻る';

  @override
  String get working => '処理中...';

  @override
  String get waitingForApprovalRequests => 'エージェントからの承認リクエストを待っています。';

  @override
  String get noActiveSessions => 'アクティブなセッションがありません';

  @override
  String get startSessionToBegin => 'セッションを開始して承認リクエストの受信を始めましょう。';

  @override
  String get settingsTitle => '設定';

  @override
  String get sectionGeneral => '一般';

  @override
  String get sectionAbout => '概要';

  @override
  String get theme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get language => '言語';

  @override
  String get languageSystem => '端末の設定に従う';

  @override
  String get voiceInput => '音声入力';

  @override
  String get pushNotifications => 'プッシュ通知';

  @override
  String get pushNotificationsSubtitle => 'Bridge 経由でセッション通知を受け取ります';

  @override
  String get pushNotificationsUnavailable => 'Firebase 設定後に利用できます';

  @override
  String get version => 'バージョン';

  @override
  String get loading => '読み込み中...';

  @override
  String get setupGuideSubtitle => '初めての方はこちら';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get githubRepository => 'GitHub リポジトリ';

  @override
  String get changelog => '変更履歴';

  @override
  String get changelogTitle => '変更履歴';

  @override
  String get showAllMain => 'すべて表示 (main)';

  @override
  String get changelogFetchError => '変更履歴の取得に失敗しました';

  @override
  String get fcmBridgeNotInitialized => 'Bridge が未初期化です';

  @override
  String get fcmTokenFailed => 'FCM token を取得できませんでした';

  @override
  String get fcmEnabled => '通知を有効化しました';

  @override
  String get fcmEnabledPending => 'Bridge 再接続後に通知登録します';

  @override
  String get fcmDisabled => '通知を無効化しました';

  @override
  String get fcmDisabledPending => 'Bridge 再接続後に通知解除します';

  @override
  String get pushPrivacyMode => 'プライバシーモード';

  @override
  String get pushPrivacyModeSubtitle => '通知にプロジェクト名や内容を含めない';

  @override
  String get updateNotificationLanguage => '通知言語を更新';

  @override
  String get notificationLanguageUpdated => '通知言語を更新しました';

  @override
  String get defaultNotRecommended => 'Default（非推奨）';

  @override
  String get imageAttached => '画像添付';

  @override
  String get sectionBackup => 'バックアップ';

  @override
  String get backupPromptHistory => 'プロンプト履歴をバックアップ';

  @override
  String get restorePromptHistory => 'プロンプト履歴をリストア';

  @override
  String get backupSuccess => 'バックアップが完了しました';

  @override
  String backupFailed(String error) {
    return 'バックアップに失敗しました: $error';
  }

  @override
  String get restoreSuccess => 'リストアが完了しました';

  @override
  String restoreFailed(String error) {
    return 'リストアに失敗しました: $error';
  }

  @override
  String get restoreConfirmTitle => 'プロンプト履歴のリストア';

  @override
  String get restoreConfirmMessage =>
      'ローカルのプロンプト履歴がバックアップの内容で上書きされます。この操作は元に戻せません。';

  @override
  String get restoreConfirmButton => 'リストア';

  @override
  String get noBackupFound => 'バックアップがありません';

  @override
  String backupInfo(String date) {
    return '最終バックアップ: $date';
  }

  @override
  String backupVersionInfo(String version, String size) {
    return 'v$version · $size';
  }

  @override
  String get connectToBackup => 'Bridge に接続するとバックアップが利用できます';

  @override
  String get usageConnectToView => 'Bridge に接続すると利用量を表示できます';

  @override
  String get usageFetchFailed => '取得に失敗しました';

  @override
  String get usageFiveHour => '5時間';

  @override
  String get usageSevenDay => '7日間';

  @override
  String usageResetAt(String time) {
    return 'リセット: $time';
  }

  @override
  String get usageAlreadyReset => 'リセット済み';

  @override
  String attachedImages(int count) {
    return '添付画像 ($count)';
  }

  @override
  String get attachedImagesNoCount => '添付画像';

  @override
  String get failedToFetchImages => '画像を取得できませんでした';

  @override
  String get responseTimedOut => '応答がタイムアウトしました';

  @override
  String failedToFetchImagesWithError(String error) {
    return '画像の取得に失敗しました: $error';
  }

  @override
  String get retry => 'リトライ';

  @override
  String get clipboardNotAvailable => 'クリップボードにアクセスできません';

  @override
  String get failedToLoadImage => '画像の読み込みに失敗しました';

  @override
  String get noImageInClipboard => 'クリップボードに画像がありません';

  @override
  String get failedToReadClipboard => 'クリップボードの読み取りに失敗しました';

  @override
  String get selectFromGallery => 'ギャラリーから選択';

  @override
  String get pasteFromClipboard => 'クリップボードから貼付';

  @override
  String get voiceInputLanguage => '音声入力の言語';

  @override
  String get archive => 'アーカイブ';

  @override
  String get sessionArchived => 'セッションをアーカイブしました';

  @override
  String get archiveFailed => 'セッションのアーカイブに失敗しました';

  @override
  String archiveFailedWithError(String error) {
    return 'セッションのアーカイブに失敗しました: $error';
  }

  @override
  String get noRecentSessions => '最近のセッションはありません';

  @override
  String get noSessionsMatchFilters => '現在のフィルター条件に一致するセッションがありません';

  @override
  String get adjustFiltersAndSearch => 'フィルター条件や検索語を変更してください';

  @override
  String get tooltipDisplayMode => 'カードに表示するメッセージを切替';

  @override
  String get tooltipProviderFilter => 'AIツールで絞り込み';

  @override
  String get tooltipProjectFilter => 'プロジェクトで絞り込み';

  @override
  String get tooltipNamedOnly => '名前を付けたセッションのみ';

  @override
  String get tooltipSlashCommand => 'スラッシュコマンド';

  @override
  String get tooltipPermissionMode => 'パーミッションモード';

  @override
  String get tooltipAttachImage => '画像を添付';

  @override
  String get tooltipPromptHistory => 'プロンプト履歴';

  @override
  String get tooltipVoiceInput => '音声入力';

  @override
  String get tooltipStopRecording => '録音を停止';

  @override
  String get tooltipSendMessage => 'メッセージを送信';

  @override
  String get tooltipRemoveImage => '画像を削除';

  @override
  String get tooltipClearDiff => 'Diff選択を解除';
}
