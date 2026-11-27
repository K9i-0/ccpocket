// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get notifyGoalProgress => '中間応答・ゴール進行中';

  @override
  String get notifyGoalComplete => 'ゴール達成';

  @override
  String get notifyGoalBlocked => '続行に対応が必要です';

  @override
  String get notifyGoalBudgetLimited => 'トークン予算に達したため停止しました';

  @override
  String get notifyGoalUsageLimited => '利用上限に達したため停止しました';

  @override
  String get appTitle => 'CC Pocket';

  @override
  String get projects => 'マルチプロジェクト';

  @override
  String get manageProjects => '管理';

  @override
  String get createProject => 'マルチプロジェクトを作成';

  @override
  String get editProject => 'マルチプロジェクトを編集';

  @override
  String get projectName => 'マルチプロジェクト名';

  @override
  String get sourceFolders => 'ソースフォルダ';

  @override
  String get primary => 'プライマリ';

  @override
  String get makePrimary => 'プライマリにする';

  @override
  String get removeFolder => 'フォルダを削除';

  @override
  String get addFolder => 'フォルダを追加';

  @override
  String get removeWorkspaceProject => 'マルチプロジェクトを削除';

  @override
  String get noProjectsYet => 'マルチプロジェクトはまだありません';

  @override
  String get unavailable => '利用できません';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get remove => '削除';

  @override
  String get removeProjectTitle => 'プロジェクトを削除';

  @override
  String removeProjectConfirm(Object name) {
    return '「$name」を最近のプロジェクトから削除しますか？';
  }

  @override
  String get rename => '名前を変更';

  @override
  String get renameSession => 'セッション名を変更';

  @override
  String get pin => 'セッションをピン留め';

  @override
  String get unpin => 'セッションのピン留めを解除';

  @override
  String get pinProject => 'プロジェクトをピン留め';

  @override
  String get unpinProject => 'プロジェクトのピン留めを解除';

  @override
  String get sessionNameHint => 'セッション名';

  @override
  String get clearName => '名前をクリア';

  @override
  String get connect => '接続';

  @override
  String get protocolIncompatibleTitle => 'App と Bridge のバージョンに互換性がありません';

  @override
  String get protocolUpdateAppBody =>
      'CC Pocket をインストール元から更新してから、もう一度接続してください。';

  @override
  String get bridgeAuthRequiredTitle => 'Bridge の認証が必要です';

  @override
  String bridgeAuthRequiredBody(String host) {
    return '$host の Bridge が API キーを必要としています。Bridge を動かしている PC で次のコマンドを実行し、表示された QR コードを読み取るか、API キーを入力してください。';
  }

  @override
  String get machineApiKeyRequired => 'API キーが必要です。QR コードを読み直してください';

  @override
  String get bridgeAuthEnterApiKey => 'API キーを入力';

  @override
  String get protocolUpdateBridgeBody =>
      'Bridge を互換性のあるリリースへ更新してから、もう一度接続してください。';

  @override
  String get protocolUpdateBothBody =>
      'プロトコル情報が不正または不足しています。CC Pocket と Bridge の両方を更新してから再接続してください。';

  @override
  String protocolRangeDetails(
    int appMin,
    int appMax,
    int bridgeMin,
    int bridgeMax,
  ) {
    return 'App プロトコル $appMin–$appMax、Bridge プロトコル $bridgeMin–$bridgeMax';
  }

  @override
  String toolSuggestionTitle(Object toolName) {
    return 'Codex に $toolName を追加しますか？';
  }

  @override
  String toolSuggestionInstall(Object toolName) {
    return '$toolName をインストール';
  }

  @override
  String get toolSuggestionInstalling => 'インストール中…';

  @override
  String get toolSuggestionNotNow => '今回はしない';

  @override
  String get toolSuggestionAuthDescription => '必要なアプリを接続し、完了したら確認してください。';

  @override
  String toolSuggestionConnect(Object appName) {
    return '$appName を接続';
  }

  @override
  String get toolSuggestionComplete => '接続が完了しました';

  @override
  String get toolSuggestionFailed => 'インストールに失敗しました';

  @override
  String get toolSuggestionOpenFailed => '接続ページを開けませんでした。';

  @override
  String get copy => 'コピー';

  @override
  String get copyEntireMessage => 'メッセージ全体をコピー';

  @override
  String get markdownLinkOpenFailed => 'リンクを開けませんでした。';

  @override
  String get markdownLinkUnsupported => 'この種類のリンクには対応していません。';

  @override
  String get markdownFileUnavailable => 'このファイルはここではプレビューできません。';

  @override
  String get filePreviewShowSource => 'ソースを表示';

  @override
  String get filePreviewShowPreview => 'プレビューを表示';

  @override
  String get filePreviewRenderedHtml => 'HTMLレンダリングプレビュー';

  @override
  String get filePreviewMediaUnavailable => 'このメディアファイルはここでは再生できません。';

  @override
  String get filePreviewMediaLoadFailed => 'メディアファイルを読み込めませんでした。';

  @override
  String get filePreviewPlay => '再生';

  @override
  String get filePreviewPause => '一時停止';

  @override
  String get filePreviewRewind10 => '10秒戻る';

  @override
  String get filePreviewForward10 => '10秒進む';

  @override
  String get filePreviewPlaybackSpeed => '再生速度';

  @override
  String get filePreviewMute => 'ミュート';

  @override
  String get filePreviewUnmute => 'ミュート解除';

  @override
  String get filePreviewVolume => '音量';

  @override
  String get filePreviewFullscreen => '全画面表示';

  @override
  String get filePreviewExitFullscreen => '全画面表示を終了';

  @override
  String get fileTransferShareOrSave => '共有・保存';

  @override
  String get fileUploadTitle => 'ファイルをアップロード';

  @override
  String get fileUploadAction => 'アップロード';

  @override
  String get fileUploadDestination => '保存先';

  @override
  String get fileUploadConflictLabel => '同名ファイルがある場合';

  @override
  String get fileUploadKeepBoth => '両方残す';

  @override
  String get fileUploadReplace => '置き換える';

  @override
  String get fileUploadSkip => 'スキップ';

  @override
  String get fileUploadPreparing => '準備中…';

  @override
  String get fileUploadUploading => 'アップロード中…';

  @override
  String get fileUploadFinalizing => '検証中…';

  @override
  String get fileUploadComplete => 'アップロード完了';

  @override
  String get fileUploadSkipped => 'スキップ済み';

  @override
  String get fileUploadTooMany => '一度にアップロードできるのは20ファイルまでです。';

  @override
  String get fileUploadTotalTooLarge => '選択したファイルの合計が1 GBの上限を超えています。';

  @override
  String get fileUploadSelectionFailed => '選択したファイルを開けませんでした。';

  @override
  String get fileUploadFileTooLarge => '各ファイルは512 MB以下にしてください。';

  @override
  String get fileUploadErrorNotAllowed => '現在のフォルダまたはファイル名にはアップロードできません。';

  @override
  String get fileUploadErrorTooLarge => 'このファイルはBridgeのアップロード上限を超えています。';

  @override
  String get fileUploadErrorUnavailable =>
      'ファイルをアップロードできません。Bridgeを更新または再起動してください。';

  @override
  String get fileUploadErrorBridgeUpdate => 'ファイルをアップロードするにはBridgeを更新してください。';

  @override
  String get fileUploadErrorFailed => 'ファイルをアップロードできませんでした。';

  @override
  String get fileTransferPreparing => 'ダウンロードを準備中…';

  @override
  String get fileTransferDownloading => 'ダウンロード中…';

  @override
  String get fileTransferOpeningShareSheet => '共有シートを開いています…';

  @override
  String get fileTransferErrorNotAllowed =>
      'このファイルは現在のプロジェクト外にあるか、アクセスが許可されていません。';

  @override
  String get fileTransferErrorNotFound => 'ファイルが見つかりません。';

  @override
  String get fileTransferErrorNotFile => '通常のファイルのみダウンロードできます。';

  @override
  String get fileTransferErrorTooLarge => 'Bridge のダウンロード上限を超えています。';

  @override
  String get fileTransferErrorUnavailable =>
      'ファイルをダウンロードできません。Bridgeを更新または再起動してください。';

  @override
  String get fileTransferErrorBridgeUpdate => 'ファイルをダウンロードするにはBridgeを更新してください。';

  @override
  String get fileTransferErrorFailed => 'ファイルをダウンロードできませんでした。';

  @override
  String get fileTransferErrorShareFailed => 'システムの共有シートを開けませんでした。';

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
  String get git => 'Git';

  @override
  String get explorer => 'Explorer';

  @override
  String get gitUnavailableTip => 'Git未検出 — Git機能は利用できません';

  @override
  String get gitUnavailableTitle => 'Gitを利用できません';

  @override
  String get gitUnavailableHint => 'このプロジェクトではGit機能を利用できません';

  @override
  String get autoModeFallbackDefaultTip =>
      'Auto mode はこの環境で使えないため Default に切り替えました';

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
  String get dismissKeyboard => 'キーボードを閉じる';

  @override
  String get serverUnreachable => 'サーバーに接続できません';

  @override
  String get serverUnreachableBody => 'Bridge サーバーに到達できません:';

  @override
  String get setupSteps => 'セットアップ手順:';

  @override
  String get setupStep1Title => 'Bridge Server を起動';

  @override
  String get setupStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get setupStep2Title => '常時起動したい場合はサービス登録';

  @override
  String get setupStep2Command => 'npx --yes @ccpocket/bridge@1 setup';

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
  String get copyResumeCommand => '再開コマンドをコピー';

  @override
  String get copyResumeCommandSubtitle => 'mac / Linuxに引き継ぎ';

  @override
  String get resumeCommandCopied => '再開コマンドをコピーしました';

  @override
  String get editSettingsThenStart => '設定を変更して開始';

  @override
  String get serverRequiresApiKey => 'このサーバーには API キーが必要です';

  @override
  String get bridgeServerUpdated => 'Bridge Server を更新しました';

  @override
  String get bridgeUpdateStarted => 'Bridge を更新しています。接続を閉じてマシン一覧に戻ります。';

  @override
  String get bridgeUpdateReconnectHint =>
      'Bridge Server を更新しました。マシン一覧から再接続してください。';

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
  String get machineEditAddTitle => 'マシンを追加';

  @override
  String get machineEditEditTitle => 'マシンを編集';

  @override
  String get machineEditDismissKeyboardTooltip => 'キーボードを閉じる';

  @override
  String get machineEditBasicInfo => '基本情報';

  @override
  String get machineEditName => '名前';

  @override
  String get machineEditNameHint => 'Home Mac';

  @override
  String get machineEditHostLabel => 'Host（IP またはホスト名）';

  @override
  String get machineEditHostHint => '100.64.1.2';

  @override
  String get machineEditPort => 'Port';

  @override
  String get machineEditBridgePortHint => '8765';

  @override
  String get machineEditApiKey => 'API Key';

  @override
  String get machineEditOptional => '任意';

  @override
  String get machineEditUseSecureConnection => 'セキュア接続を使う';

  @override
  String get machineEditUseSecureConnectionSubtitle =>
      'WSS で接続し、ヘルスチェックに HTTPS を使います';

  @override
  String get machineEditConnectionMode => '接続方式';

  @override
  String get machineEditConnectionModeAutomatic => '自動（推奨）';

  @override
  String get machineEditConnectionModeAutomaticSubtitle =>
      '認証情報を送らずに確認し、HTTPSを優先して自動接続します';

  @override
  String get machineEditConnectionModeAutomaticSshSubtitle =>
      'SSHトンネル内ではWSを使用し、通信はSSH接続で暗号化されます';

  @override
  String get machineEditConnectionModeSecureOnly => 'セキュアのみ（WSS）';

  @override
  String get machineEditConnectionModeSecureOnlySubtitle =>
      'TLS接続を必須にし、WSへ自動的に切り替えません';

  @override
  String get machineEditConnectionModeStandardOnly => '標準（WS）';

  @override
  String get machineEditConnectionModeStandardOnlySubtitle =>
      'ローカルネットワークまたはTailscaleなどのVPN内で使用してください';

  @override
  String get machineErrorBridgeNotFound =>
      'Bridgeが見つかりません。起動状態と同じネットワークまたはVPNへの接続を確認してください';

  @override
  String get machineErrorSecureConnectionUnavailable =>
      'セキュア接続を確立できません。TLSの設定を確認するか、意図する場合のみ「標準（WS）」を選択してください';

  @override
  String get machineAutomaticWsApiKeyWarningTitle => '標準接続（WS）が見つかりました';

  @override
  String get machineAutomaticWsApiKeyWarningBody =>
      'このBridgeは暗号化されていないWSで見つかりました。APIキーは通信の暗号化なしで送信されます。信頼できるローカルネットワークまたはVPN内の場合のみ続けてください。';

  @override
  String get machineAutomaticWsApiKeyWarningConnect => 'WSで接続';

  @override
  String get machineEditSshConfiguration => 'SSH 設定';

  @override
  String get machineEditEnableSshRemoteStartup => 'SSH リモート起動を有効にする';

  @override
  String get machineEditEnableSshRemoteStartupSubtitle =>
      'オフライン時に Bridge Server をリモート起動します';

  @override
  String get machineEditSshUsername => 'SSH Username';

  @override
  String get machineEditSshUsernameHint => 'myuser';

  @override
  String get machineEditSshPort => 'SSH Port';

  @override
  String get machineEditSshPortHint => '22';

  @override
  String get machineEditTargetAuthentication => '接続先の認証';

  @override
  String get machineEditPrivateKey => 'Private Key';

  @override
  String get machineEditSshPrivateKeyPem => 'SSH Private Key (PEM)';

  @override
  String get machineEditOpenSshPrivateKeyHint =>
      '-----BEGIN OPENSSH PRIVATE KEY-----';

  @override
  String get machineEditSavedPrivateKeyIndicator =>
      'Private Key は保存済みです。新しく入力すると置き換えます。';

  @override
  String get machineEditUseSshJumpHost => 'SSH Jump Host を使う';

  @override
  String get machineEditUseSshJumpHostSubtitle => '踏み台または中継 SSH ホスト経由で接続します';

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
  String get machineEditJumpUsernameHint => '未入力なら SSH Username を使います';

  @override
  String get machineEditJumpHostAuthentication => 'Jump Host の認証';

  @override
  String get machineEditJumpHostAuthenticationSubtitle =>
      '未入力なら接続先の SSH 認証情報を再利用します';

  @override
  String get machineEditJumpPassword => 'Jump Password';

  @override
  String get machineEditSavedJumpHostPasswordIndicator =>
      'Jump Host パスワードは保存済みです。新しく入力すると置き換えます。';

  @override
  String get machineEditJumpPrivateKeyPem => 'Jump Private Key (PEM)';

  @override
  String get machineEditSavedJumpHostPrivateKeyIndicator =>
      'Jump Host Private Key は保存済みです。新しく入力すると置き換えます。';

  @override
  String get machineEditTesting => 'テスト中...';

  @override
  String get machineEditTestConnection => '接続をテスト';

  @override
  String get machineEditConnectionSuccessful => '接続に成功しました';

  @override
  String get machineEditFillSshCredentials => 'SSH 認証情報を入力してください';

  @override
  String get machineEditAddAndConnect => '追加して接続';

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
  String get showSessions => '左ペインを表示';

  @override
  String get hideSessions => '左ペインを隠す';

  @override
  String get workspaceLandingSelectSessionMessage => '左ペインでセッションを選択してください。';

  @override
  String get workspaceLandingCreateSessionMessage =>
      '左ペインの New からセッションを作成してください。';

  @override
  String get workspaceLandingDisconnectedMessage =>
      'Bridge に接続されていません。左ペインから接続するか、セットアップガイドを開いてマシンを設定してください。';

  @override
  String get running => '実行中';

  @override
  String get recentSessions => '最近のセッション';

  @override
  String get search => '検索';

  @override
  String get searchSessions => 'セッションを検索...';

  @override
  String get sessionDisplayModeFirst => '先頭';

  @override
  String get sessionDisplayModeLast => '末尾';

  @override
  String get sessionDisplayModeSummary => '要約';

  @override
  String get allAiTools => 'すべての AI ツール';

  @override
  String get allProjects => 'すべてのプロジェクト';

  @override
  String get named => '名前付き';

  @override
  String get machines => 'マシン';

  @override
  String get refreshStatus => '状態を更新';

  @override
  String get add => '追加';

  @override
  String get noSavedMachinesDescription =>
      '保存済みのマシンはありません。\n追加すると、すばやく接続したり Bridge Server をリモート起動したりできます。';

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
  String get bridgeIsUpToDate => 'Bridge は最新です';

  @override
  String get bridgeUpdateAvailable => '更新があります';

  @override
  String get bridgeUpdateRequiresSetup => 'SSH と Bridge の自動起動セットアップが必要です';

  @override
  String get bridgeVersionUnknown => 'Bridge のバージョンを確認できません';

  @override
  String bridgeVersionCurrentExpected(String current, String expected) {
    return '現在 v$current、推奨 v$expected以上';
  }

  @override
  String bridgeVersionCurrentLatest(String current, String latest) {
    return '現在 v$current、最新版 v$latest';
  }

  @override
  String get bridgeLatestVersionChecking => 'Bridge の最新版を確認中...';

  @override
  String get bridgeLatestVersionUnavailable => 'Bridge の最新版を確認できません';

  @override
  String get bridgeLatestVersionRetry => '最新版の確認を再試行';

  @override
  String get bridgeUpdateSetupTitle => 'Bridge 更新の準備';

  @override
  String get bridgeUpdateSetupDescription =>
      'このマシンで Bridge の更新機能を使うには、SSH 接続と Bridge の自動起動セットアップが必要です。';

  @override
  String get bridgeUpdateSetupEnableSsh => 'Bridge 接続設定で SSH を有効にします。';

  @override
  String get bridgeUpdateSetupRunCommand => '接続先マシンでセットアップコマンドを実行しておきます。';

  @override
  String get bridgeUpdateSetupCommand => 'npx @ccpocket/bridge@1 setup';

  @override
  String get bridgeUpdateFromDesktopApp => 'Mac の CC Pocket から再起動すると更新されます';

  @override
  String get bridgeUpdateRestartHere => '「このMacのBridge」から再起動すると更新されます';

  @override
  String get bridgeUpdateDesktopTitle => 'デスクトップ版から更新';

  @override
  String get bridgeUpdateDesktopDescription =>
      'この Bridge は Mac の CC Pocket が起動しています。そちらで再起動すると最新版になります。';

  @override
  String get bridgeUpdateDesktopStepOpen =>
      'Bridge が動いている Mac で CC Pocket を開きます。';

  @override
  String get bridgeUpdateDesktopStepRestart =>
      '設定の「このMacのBridge」を開き、「再起動」を押します。';

  @override
  String get bridgeUpdateDesktopNoSetup =>
      'この Bridge ではセットアップコマンドを実行しないでください。同じポートで Bridge がもう1つ起動します。';

  @override
  String get bridgeUpdateSetupDesktopNote =>
      'Mac の CC Pocket（デスクトップ版）で Bridge を起動している場合、この準備は不要です。セットアップコマンドは実行せず、Mac のアプリの「このMacのBridge」から再起動すると更新されます。';

  @override
  String get stopServer => 'サーバーを停止';

  @override
  String get update => '更新';

  @override
  String get download => 'ダウンロード';

  @override
  String appUpdateAvailable(String version) {
    return 'v$version が利用可能です';
  }

  @override
  String get macosNativeAppBannerTitle => 'macOS ネイティブ版をおすすめします';

  @override
  String get macosNativeAppBannerSubtitle =>
      'Mac では、macOS に最適化された CC Pocket ネイティブ版を GitHub Releases からインストールできます。';

  @override
  String get openGitHubReleases => 'GitHub Releases を開く';

  @override
  String get macosNativeAppSettingsTitle => 'macOS ネイティブ版';

  @override
  String get macosNativeAppSettingsSubtitle =>
      'macOS に最適化されているため、Mac ではネイティブ版がおすすめです。';

  @override
  String get supportBannerTitle => 'CC Pocketが役に立っていたら';

  @override
  String get supportBannerSubtitle => 'サポートで継続開発を後押しできます';

  @override
  String get supportBannerAction => 'サポートを見る';

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
  String get restart => '再起動';

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
  String get codexProfilePrecedenceNote =>
      'Profile で同じ設定を指定している場合は、以下の項目より Profile の設定が優先されます。';

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
  String get additionalWritableRootsTitle => '追加で利用できるフォルダ';

  @override
  String get additionalWritableRootsDescription =>
      'このセッションでは、Codex の config.toml の writable_roots に加えて有効になります。';

  @override
  String get additionalWritableRootsTooltip =>
      '選択中のプロジェクトに加えて、別プロジェクトのファイルも読み書きしたいときに使います。';

  @override
  String get additionalWritableRootsSuggestions => '最近のプロジェクト';

  @override
  String get addDirectory => 'フォルダを追加';

  @override
  String get directoryPath => 'フォルダのパス';

  @override
  String get directoryPathOutsideAllowedRoots => '許可されたフォルダの外側のパスです';

  @override
  String get browseDirectory => 'フォルダを参照';

  @override
  String get selectDirectory => '選択';

  @override
  String get noSubdirectories => 'サブフォルダはありません';

  @override
  String get directoryBrowserRoots => '許可されたフォルダ';

  @override
  String get directoryBrowserFilterHint => 'フォルダ名で絞り込み';

  @override
  String get directoryBrowserNoMatches => '一致するフォルダはありません';

  @override
  String get directoryBrowserBridgeUpdateRequired =>
      'この機能には新しい Bridge Server が必要です。Bridge を更新して、もう一度お試しください。';

  @override
  String get worktreeNew => '新規';

  @override
  String worktreeExisting(int count) {
    return '既存 ($count)';
  }

  @override
  String get branchOptional => 'ブランチ（任意）';

  @override
  String get branchHint => 'feature/...';

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
  String get approvalStatusPending => '承認待ち';

  @override
  String get approvalStatusApproved => '承認済み';

  @override
  String get approvalStatusApprovedForSession => 'セッション中承認済み';

  @override
  String get approvalStatusRejected => '拒否済み';

  @override
  String get approvalStatusResolved => '解決済み';

  @override
  String get viewEditPlan => 'プランを表示';

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
  String get continuePlanning => '計画を続ける';

  @override
  String get reject => '拒否';

  @override
  String get approve => '承認';

  @override
  String get always => '常に許可';

  @override
  String get approveOnce => '今回だけ許可';

  @override
  String get approveForSession => 'このセッション中は許可';

  @override
  String get approveAlways => '常に許可';

  @override
  String get approveAlwaysSub => '';

  @override
  String get approveSessionMain => 'セッション中許可';

  @override
  String get approveSessionSub => '';

  @override
  String get permissionDefaultDescription => '標準の承認フローです';

  @override
  String get permissionAutoDescription => 'Claude が安全チェック付きで承認を自動処理します';

  @override
  String get permissionAutoDescriptionAntigravity =>
      'Antigravity が承認の要否を自動で判断します';

  @override
  String get antigravityModelAfterStartNote => 'モデルはセッション開始後に切り替えられます。';

  @override
  String get antigravityAuthLogin => 'Google ログイン';

  @override
  String get antigravityAuthApiKey => 'APIキー';

  @override
  String get antigravityUsagePlanNote =>
      'プランの残量は Antigravity 側で確認してください。コンテキスト使用量は各セッションに表示されます。';

  @override
  String get antigravityUsageApiKeyNote =>
      'APIキーでの利用にはプランの枠がありません。コンテキスト使用量は各セッションに表示されます。';

  @override
  String get showAntigravityTabSubtitle =>
      'Bridge のマシンに Antigravity CLI（agy）があるときだけ表示されます';

  @override
  String get permissionAcceptEditsDescription => 'ファイル編集を自動で承認します';

  @override
  String get permissionPlanDescription => '変更を実行する前に分析と計画を行います';

  @override
  String get permissionBypassDescription => 'ほとんどの承認確認なしで実行します';

  @override
  String get executionDefaultDescription => '標準の承認フローです';

  @override
  String get executionAcceptEditsDescription => 'ファイル編集を自動で承認します';

  @override
  String get executionFullAccessDescription => 'ほとんどの承認確認なしで実行します';

  @override
  String get codexPlanModeDescription => '先にプランを作成し、承認後に実行を開始します';

  @override
  String get sandboxRestrictedDescription => '制限された環境でコマンドを実行します';

  @override
  String get sandboxNativeDescription => 'ネイティブ環境でコマンドを実行します';

  @override
  String get sandboxNativeCautionDescription => 'ネイティブ環境でコマンドを実行します（注意）';

  @override
  String get sheetSubtitleApproval => 'どの操作に承認が必要かを制御します';

  @override
  String get sheetSubtitleSandboxCodex =>
      'Codex は安全のためデフォルトで Sandbox が有効です。無効にするとシステムへのフルアクセスが可能になります。';

  @override
  String get sheetSubtitleSandboxClaude =>
      'Claude はデフォルトでネイティブ実行です。Sandbox を有効にするとアクセスが制限されます。';

  @override
  String get sheetSubtitleModel => 'モデルによって速度・能力・コストが異なります。';

  @override
  String get sheetSubtitleEffort => '高い Effort はより丁寧な分析を行いますが、時間とコストが増えます。';

  @override
  String get claudeEffortLowDesc => '高速な応答、分析は少なめ';

  @override
  String get claudeEffortMediumDesc => '速度と品質のバランス';

  @override
  String get claudeEffortHighDesc => 'より丁寧な分析';

  @override
  String get claudeEffortXHighDesc => '複雑な作業向けの拡張推論';

  @override
  String get claudeEffortMaxDesc => '最も丁寧、最も遅い';

  @override
  String get claudeUltracodeDesc =>
      'すべてのタスクをマルチエージェントのワークフローで進める。トークン消費が大幅に増える';

  @override
  String get claudeUltracodeOn => 'オン';

  @override
  String get claudeUltracodeOff => 'オフ';

  @override
  String get reasoningEffortNoneDesc => '推論なし';

  @override
  String get reasoningEffortMinimalDesc => '最速、分析は最小限';

  @override
  String get reasoningEffortLowDesc => '高速な応答、分析は少なめ';

  @override
  String get reasoningEffortMediumDesc => '速度と品質のバランス';

  @override
  String get reasoningEffortHighDesc => 'より丁寧な分析';

  @override
  String get reasoningEffortXhighDesc => '最も丁寧、最も遅い';

  @override
  String get reasoningEffortMaxDesc => '最も難しい問題向けの最大推論';

  @override
  String get reasoningEffortUltraDesc => '最大推論と自動タスク委譲';

  @override
  String get reasoningEffortModelSpecificDesc => 'モデル固有の推論レベル';

  @override
  String get changePermissionModeTitle => 'Permission Mode を変更';

  @override
  String changePermissionModeBody(String mode) {
    return '$mode に切り替えるとセッションが再起動します。会話は保持されます。';
  }

  @override
  String get changeExecutionModeTitle => 'Execution Mode を変更';

  @override
  String changeExecutionModeBody(String mode) {
    return '$mode に切り替えるとセッションが再起動します。会話は保持されます。';
  }

  @override
  String get changeApprovalPolicyTitle => 'Approval Policy を変更';

  @override
  String changeApprovalPolicyBody(String mode) {
    return '$mode に切り替えるとセッションが再起動します。会話は保持されます。';
  }

  @override
  String get codexApprovalUntrustedDescription =>
      'trusted コマンドだけ自動実行し、それ以外は確認します';

  @override
  String get codexApprovalOnRequestDescription => '必要だと判断した操作だけ確認します';

  @override
  String get codexApprovalOnFailureDescription =>
      '通常は確認せず実行し、失敗時だけ追加権限を確認します（非推奨）';

  @override
  String get codexApprovalNeverDescription => '確認せず実行し、失敗時も承認を求めません';

  @override
  String get codexAutoReview => '自動レビュー';

  @override
  String get codexAutoReviewDescription => '承認リクエストを Codex が自動レビューします';

  @override
  String get codexAutoReviewDisabledByPolicy => '組織の Browser Use ポリシーにより無効です';

  @override
  String get codexAutoReviewUnavailableDescription =>
      'Never Ask では承認リクエストが発生しないため利用できません';

  @override
  String get guardianApprovalTitle => '自動レビューで承認';

  @override
  String get guardianApprovalMediumRisk => '中リスク';

  @override
  String get guardianApprovalHighRisk => '高リスク';

  @override
  String get guardianApprovalDetails => '詳細';

  @override
  String get guardianApprovalHideDetails => '詳細を閉じる';

  @override
  String guardianApprovalAuthorization(String authorization) {
    return '承認レベル: $authorization';
  }

  @override
  String get enablePlanModeTitle => 'Plan Mode を有効化';

  @override
  String get disablePlanModeTitle => 'Plan Mode を無効化';

  @override
  String get enablePlanModeBody => 'Plan Mode を有効化するとセッションが再起動します。会話は保持されます。';

  @override
  String get disablePlanModeBody => 'Plan Mode を無効化するとセッションが再起動します。会話は保持されます。';

  @override
  String get changeSandboxModeTitle => 'Sandbox Mode を変更';

  @override
  String changeSandboxModeBody(String mode) {
    return '$mode に切り替えるとセッションが再起動します。会話は保持されます。';
  }

  @override
  String get messagePlaceholder => 'Claude にメッセージ...';

  @override
  String get codexMessagePlaceholder => 'Codex にメッセージ...';

  @override
  String get antigravityMessagePlaceholder => 'Antigravity にメッセージ...';

  @override
  String get queuedInputForReconnect => '再接続待ちキュー';

  @override
  String get queuedInputPendingDelivery => '送信確認中';

  @override
  String get queuedInputWaitingForUsageLimit => '利用上限の解除待ち · 解除時刻を確認中';

  @override
  String queuedInputForUsageLimit(String time) {
    return '利用上限の解除待ち · $time に送信予定';
  }

  @override
  String get queuedInputForNextTurn => '次のターンに送信予定';

  @override
  String get sessionCardQueuedInput => 'キュー中';

  @override
  String queuedInputImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '画像$count枚',
    );
    return '$_temp0';
  }

  @override
  String get tooltipSteerQueuedMessage => 'キュー中のメッセージを指示として送信';

  @override
  String get tooltipMoveQueuedMessageToInput => 'キュー中のメッセージを入力欄へ移動';

  @override
  String get tooltipCancelQueuedMessage => 'キュー中のメッセージをキャンセル';

  @override
  String get reconnecting => 'Bridge との接続が一時的に切れました。自動で再接続しています...';

  @override
  String get reconnectingQueuedMessages =>
      'Bridge との接続が一時的に切れました。自動で再接続しています。待機中のメッセージは保持されています。';

  @override
  String get disconnectedMessagesQueued =>
      'Bridge に接続できません。操作は端末に保存され、再接続後に送信されます。';

  @override
  String get sessionQueuedForReconnect => 'セッションを再接続待ちキューに追加しました';

  @override
  String get resumeAlreadyQueued => '再開はすでにキューに入っています';

  @override
  String get resumeQueuedForReconnect => '再開を再接続待ちキューに追加しました';

  @override
  String get pendingActionWillCreateOnReconnect => 'Bridge 再接続後に作成します';

  @override
  String get pendingActionWillResumeOnReconnect => 'Bridge 再接続後に再開します';

  @override
  String get pendingActionStatus => '待機中';

  @override
  String get pendingActionProcessingStatus => '復元中';

  @override
  String get pendingActionProcessingStartStatus => '準備中';

  @override
  String get pendingActionProcessingStartDescription => 'Bridge でセッションを準備しています';

  @override
  String get pendingActionProcessingResumeDescription =>
      '画像が多いセッションは時間がかかることがあります';

  @override
  String get pendingActionProcessingStartTitle => '新規セッションを作成中';

  @override
  String get pendingActionProcessingResumeTitle => 'セッション履歴を読み込んでいます';

  @override
  String get tooltipCancelPendingAction => '待機中の操作をキャンセル';

  @override
  String get queuedLocally => 'ローカルでキュー中';

  @override
  String get processingOnBridge => 'Bridge で処理中';

  @override
  String get offlinePendingNewSessionTitle => '新規セッション待機中';

  @override
  String get offlinePendingResumeTitle => '再開待機中';

  @override
  String diffLines(int count) {
    return '$count 行の diff';
  }

  @override
  String changedLines(int count) {
    return '変更$count行';
  }

  @override
  String hunkCount(int count) {
    return '$countハンク';
  }

  @override
  String fileCount(int count) {
    return '$countファイル';
  }

  @override
  String get tapInterruptHoldStop => 'タップ: 中断, 長押し: 停止';

  @override
  String get rewind => '巻き戻す';

  @override
  String get rewindToHere => 'ここまで巻き戻す';

  @override
  String get editMessage => 'メッセージを編集';

  @override
  String get restoreFilesToHere => 'この時点のファイルに戻す';

  @override
  String get copyMessage => 'メッセージをコピー';

  @override
  String get rewindModeConversationAndCode => '会話とコードを復元';

  @override
  String get rewindModeConversationOnly => '会話のみ復元';

  @override
  String get rewindModeCodeOnly => 'コードのみ復元';

  @override
  String get rewindConfirmTitle => '巻き戻しの確認';

  @override
  String rewindConfirmBody(Object mode) {
    return 'モード: $mode\n\nこの操作は元に戻せません。実行しますか？';
  }

  @override
  String get rewindCannotRewindFiles => 'ファイルを巻き戻せません';

  @override
  String get codexRewindConfirmTitle => '会話を巻き戻しますか？';

  @override
  String get codexRewindConfirmBody =>
      'このメッセージの直前までチャットを戻し、メッセージを入力欄に戻します。ファイル変更はそのまま残ります。';

  @override
  String get fork => '分岐';

  @override
  String get forkConversation => '会話を分岐';

  @override
  String get forkConversationTitle => '会話を分岐しますか？';

  @override
  String get forkConversationBody => 'この応答時点から新しいセッションを作成します。現在のセッションは変更されません。';

  @override
  String get forkTargetNotFound => '分岐元のユーザー発言が見つかりません';

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
  String agentIsAsking(Object agent) {
    return '$agent が質問しています';
  }

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
  String get questionLabel => '質問';

  @override
  String get answerHidden => 'プライバシー保護のため非表示';

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
  String get refresh => '更新';

  @override
  String get diffCompareSideBySide => '並べて比較';

  @override
  String get diffCompareSlider => 'スライダー';

  @override
  String get diffCompareOverlay => 'オーバーレイ';

  @override
  String get diffCompareToggle => 'トグル';

  @override
  String get diffBefore => '変更前';

  @override
  String get diffAfter => '変更後';

  @override
  String get diffNewFile => '新規ファイル';

  @override
  String get diffDeleted => '削除済み';

  @override
  String get diffNoImage => '画像なし';

  @override
  String get noChanges => '変更なし';

  @override
  String get showAll => 'すべて表示';

  @override
  String get setupGuideTitle => 'セットアップガイド';

  @override
  String get guideAboutTitle => 'PC のエージェントを、\nポケットから。';

  @override
  String get guideAboutDescription =>
      '自分の Mac / PC で動く Codex・Claude・Antigravity に、スマホからチャットや承認ができるクライアントです。';

  @override
  String get guideAboutSdkNoteTitle => 'Claude Agent SDK について';

  @override
  String get guideAboutSdkNoteBody =>
      'Claude Code のライブラリ版です。履歴や .claude、CLAUDE.md などの設定ファイルを共有でき、承認フローもおおよそ同じ感覚で使えます。';

  @override
  String get guideAboutDiagramTitle => 'しくみ';

  @override
  String get guideAboutDiagramPhone => 'この端末';

  @override
  String get guideAboutDiagramBridge => 'Bridge Server';

  @override
  String get guideAboutDiagramClaude => 'Codex · Claude\nAntigravity';

  @override
  String get guideAboutDiagramCaption =>
      'コードや設定はあなたの Mac / PC の中にとどまります。Bridge がアプリと各エージェントをつなぎます。';

  @override
  String get guideBridgeTitle => 'Bridge Server を\n起動する';

  @override
  String get guideBridgeDescription =>
      'ターミナルで Bridge Server を起動して、このアプリやスマホから接続します。';

  @override
  String get guideBridgePrerequisites => '必要なもの';

  @override
  String get guideBridgePrereq1 => 'Node.js 22.19 以上がインストールされた Mac / PC';

  @override
  String get guideBridgePrereq2 =>
      'Claudeには ANTHROPIC_API_KEY または BRIDGE_ALLOW_CLAUDE_OAUTH=1 を設定';

  @override
  String get guideBridgePrereq3 => 'Codex / Antigravity を使う場合は各 CLI でログイン済み';

  @override
  String get guideBridgeStep1 => 'npx で実行（おすすめ）';

  @override
  String get guideBridgeStep1Command => 'npx --yes @ccpocket/bridge@latest';

  @override
  String get guideBridgeStep2 => 'またはグローバルインストール';

  @override
  String get guideBridgeStep2Command =>
      'npm install -g @ccpocket/bridge\nccpocket-bridge';

  @override
  String get guideBridgeQrNote => '起動するとターミナルに QR コードと接続 URL が表示されます';

  @override
  String get guideConnectionTitle => '接続する';

  @override
  String get guideConnectionDescription =>
      'Bridge を起動したら、QR コードを読み取るだけですぐに使い始められます。';

  @override
  String get guideConnectionQr => 'QR コードスキャン';

  @override
  String get guideConnectionQrDescription =>
      'macOS アプリまたはターミナルの QR コードを読み取ると、URL と API キーが自動で設定されます。';

  @override
  String get guideConnectionManual => '手動入力 / SSH';

  @override
  String get guideConnectionManualDescription =>
      'ws://<IP アドレス>:8765 と API キーを手動登録できます。SSH 経由での Bridge 起動にも対応しています。';

  @override
  String get guideConnectionRecommended => 'おすすめ';

  @override
  String get guideTailscaleTitle => '外出先からの接続';

  @override
  String get guideTailscaleDescription =>
      '自宅の外からも使いたい場合は、Tailscale（VPN）を使えば安全にリモート接続できます。';

  @override
  String get guideTailscaleStep1 => 'Mac / PC とスマホの両方に Tailscale をインストール';

  @override
  String get guideTailscaleStep2 => '同じアカウントでログイン';

  @override
  String get guideTailscaleStep3 =>
      'Tailscale の IP（ws://100.x.x.x:8765）または Tailscale 用 QR コードで接続';

  @override
  String get guideTailscaleWebsite => 'Tailscale 公式サイト';

  @override
  String get guideTailscaleWebsiteHint => '詳しいセットアップ方法は公式サイトをご覧ください。';

  @override
  String get guideLaunchdTitle => '常時起動の設定';

  @override
  String get guideLaunchdDescription =>
      '毎回手動で Bridge Server を起動するのが面倒な場合、マシンの起動時に自動で立ち上がるよう設定できます。';

  @override
  String get guideLaunchdCommand => 'セットアップコマンド';

  @override
  String get guideLaunchdCommandValue => 'npx --yes @ccpocket/bridge@1 setup';

  @override
  String get guideLaunchdRecommendation =>
      'まずは手動起動で動作確認してから、安定したらサービス登録がおすすめです。';

  @override
  String get guideAutostartMacDescription =>
      'launchd に登録。シェル環境（nvm、Homebrew 等）が自動で引き継がれます。';

  @override
  String get guideAutostartLinuxDescription =>
      'systemd ユーザーサービスを作成。Raspberry Pi 等の Linux ホストに対応。';

  @override
  String get guideReadyTitle => '準備完了！';

  @override
  String get guideReadyDescription =>
      'Mac / PC で Bridge を起動したら、QR コードをスキャンして始めましょう。まだ準備前ならデモモードも試せます。';

  @override
  String get guideReadyStart => 'さっそく始める';

  @override
  String get guideReadyHint => 'このガイドは設定画面からいつでも見返せます';

  @override
  String get creatingSession => 'セッション作成中...';

  @override
  String get resolvingLinkedSession => 'リンク先のセッションを検索しています...';

  @override
  String get resumingLinkedSession => 'セッションを再開しています...';

  @override
  String get sessionUnavailableTitle => 'セッションを利用できません';

  @override
  String get sessionUnavailableDescription =>
      'このセッションは現在の Bridge では利用できません。最近のセッションから開いてください。';

  @override
  String get openRecentSessions => '最近のセッションを開く';

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
  String get promptHistoryFilters => 'フィルター';

  @override
  String get promptHistoryFilterThisDevice => 'この端末で使った履歴';

  @override
  String get promptHistoryFilterThisProject => '開いているプロジェクト';

  @override
  String get promptHistoryFilterThisBridge => '接続中のBridge';

  @override
  String get promptHistoryFilterFavorites => 'お気に入り';

  @override
  String get promptHistoryFilterCommands => 'コマンドとスキル';

  @override
  String get promptHistoryOpenProjectEmptyHint =>
      '開いているプロジェクトのフィルターは、新しいアプリで記録した履歴にのみ有効です。';

  @override
  String get promptHistorySectionTitle => 'プロンプト履歴';

  @override
  String get promptHistorySyncTitle => 'プロンプト履歴を同期';

  @override
  String get promptHistoryReplaceTitle => '旧方式履歴でBridgeを上書き';

  @override
  String get promptHistoryReplaceSubtitle =>
      '旧方式履歴はアプリ側で管理されていました。新方式ではBridge側で履歴を管理します。メイン端末で移行済みの場合は通常不要です。サブ端末でBridgeの履歴を初期化してしまった場合に、接続中のBridge履歴をこの端末の旧方式履歴で上書きします。';

  @override
  String get promptHistoryReplaceConfirmAction => '上書き';

  @override
  String get promptHistoryReplaceDismissAction => '移行済みとして非表示';

  @override
  String get promptHistoryNotSyncedYet => 'まだ同期していません';

  @override
  String promptHistoryLatestSync(String time) {
    return '最終同期: $time';
  }

  @override
  String promptHistorySyncedBridges(int count) {
    return '$count件のBridgeを同期済み';
  }

  @override
  String promptHistorySyncSummaryWithFailures(int synced, int failed) {
    return '$synced件同期、$failed件失敗';
  }

  @override
  String promptHistoryBridgeId(String id) {
    return 'Bridge ID: $id';
  }

  @override
  String promptHistoryOtherBridgeRegistrations(String registrations) {
    return '他の登録: $registrations';
  }

  @override
  String get promptHistoryNoSyncTime => '同期時刻なし';

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
  String get noActiveSessions => '実行中のセッションはありません';

  @override
  String get startSessionToBegin => 'セッションを開始して承認リクエストの受信を始めましょう。';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsCategoryConnection => '接続とBridge';

  @override
  String get settingsCategoryAppearance => '外観';

  @override
  String get settingsCategoryInput => 'チャット';

  @override
  String get settingsCategoryAgents => 'エージェント';

  @override
  String get settingsCategoryGit => 'Gitと差分';

  @override
  String get settingsCategoryNotifications => '通知';

  @override
  String get settingsCategoryUsage => '利用状況';

  @override
  String get settingsCategoryUsageSummary => 'Claude・Codexのプラン利用量';

  @override
  String get settingsCategorySupport => '応援・シェア';

  @override
  String get settingsCategorySupportSummary => 'サポーター・レビュー・シェア';

  @override
  String get settingsCategoryAbout => 'このアプリについて';

  @override
  String get settingsCategoryAboutSummary => 'バージョン・変更履歴・ライセンス';

  @override
  String get settingsGroupDisplay => '表示';

  @override
  String get settingsGroupCode => 'コード表示';

  @override
  String get settingsGroupSending => 'メッセージ送信';

  @override
  String get settingsGroupAttachments => '添付';

  @override
  String get settingsGroupPerformance => 'パフォーマンス';

  @override
  String get settingsGroupSessions => 'セッション';

  @override
  String get settingsGroupFilesAndApps => 'ファイルとアプリ連携';

  @override
  String get settingsGroupDiffView => '差分ビュー';

  @override
  String get settingsEnabledAgents => '使うエージェント';

  @override
  String get settingsBridgeMachine => 'Bridgeマシン';

  @override
  String get settingsNotConnected => '未接続';

  @override
  String get settingsStatusOnline => 'オンライン';

  @override
  String get settingsStatusOffline => 'オフライン';

  @override
  String get settingsStatusChecking => '確認中';

  @override
  String get settingsStatusDisconnectedTitle => 'Bridgeに未接続';

  @override
  String get settingsStatusDisconnectedBody =>
      'マシンに接続すると、Bridgeの状態や利用状況がここに表示されます。';

  @override
  String get settingsSearchHint => '設定を検索';

  @override
  String get settingsSearchNoResults => '一致する設定がありません';

  @override
  String get settingsOn => 'オン';

  @override
  String get settingsOff => 'オフ';

  @override
  String get sectionGeneral => '一般';

  @override
  String get sectionConnectionAccounts => '接続とアカウント';

  @override
  String get sectionNotifications => '通知';

  @override
  String get sectionSupport => '応援';

  @override
  String get sectionEditor => 'エディタ';

  @override
  String get textDensity => '表示密度';

  @override
  String get textDensityDescription =>
      'OSの文字サイズ設定に、このアプリ倍率をさらに掛けます。100%はOS設定のままです。';

  @override
  String get multiPaneBreakpoint => '分割表示の幅';

  @override
  String multiPaneBreakpointDescription(int threePaneWidth) {
    return 'ウィンドウの幅がこの値以上のとき、セッション一覧と会話を並べて表示します。${threePaneWidth}pt未満でツールを開くと、一覧の位置に表示されます。';
  }

  @override
  String multiPaneBreakpointCurrentSplit(int width) {
    return '現在の幅 ${width}pt · 分割表示';
  }

  @override
  String multiPaneBreakpointCurrentSingle(int width) {
    return '現在の幅 ${width}pt · 1画面表示';
  }

  @override
  String multiPaneBreakpointMatchCurrent(int width) {
    return '現在の幅で分割（${width}pt）';
  }

  @override
  String multiPaneBreakpointReset(int width) {
    return 'デフォルト（${width}pt）に戻す';
  }

  @override
  String get codeFontSize => 'コード文字サイズ';

  @override
  String get codeFontFamily => 'コードフォント';

  @override
  String get codeFontPreview => 'プレビュー';

  @override
  String get indentSize => 'インデント幅';

  @override
  String get indentSizeSubtitle => '箇条書きのインデントに使用するスペース数';

  @override
  String get gitDiffInteractionMode => 'Git diff 操作';

  @override
  String get gitDiffQuickActions => 'クイック操作';

  @override
  String get gitDiffQuickActionsDescription =>
      '1本指の横スワイプで hunk の Stage / Unstage / Revert を実行します。長い行は折り返します。';

  @override
  String get gitDiffScrollFirst => '横スクロール優先';

  @override
  String get gitDiffScrollFirstDescription =>
      '長い行を折り返さず、hunk 単位で横スクロールできます。Git 操作はロングタップのメニューまたは下部ボタンから実行します。';

  @override
  String get imagePasteShortcut => '画像ペーストのショートカット';

  @override
  String get imagePasteShortcutCtrlV => 'Ctrl+V';

  @override
  String get imagePasteShortcutCtrlVDescription =>
      'macOS で推奨。Cmd+V を通常のペーストや音声入力ツール用に残します。';

  @override
  String get imagePasteShortcutCommandV => 'Cmd+V';

  @override
  String get imagePasteShortcutCommandVDescription =>
      '音声入力アプリ、クリップボード管理アプリ、テキスト展開ツールと競合する可能性があります。';

  @override
  String get gitDiffFocusAutoLandscape => 'diff集中モードで横画面にする';

  @override
  String get gitDiffFocusAutoLandscapeDescription =>
      'モバイルレイアウトでは、diff集中モードに入ると横画面に固定します。解除すると通常の回転に戻ります。';

  @override
  String get remoteGitStatusBadge => '未同期のGitコミットを薄いバッジで表示';

  @override
  String get remoteGitStatusBadgeDescription =>
      'fetch後に現在ブランチがpushまたはpull可能な場合、セッション画面のGitボタンに薄いバッジを表示します。';

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
  String get appIconTitle => 'アプリアイコン';

  @override
  String get appIconMonthlySupporterPerk => '月額サポーター特典です。';

  @override
  String appIconSettingsSubtitle(String device) {
    return '$deviceのホーム画面に表示されるアイコンを変更できます。';
  }

  @override
  String get appIconSupporterDialogTitle => '月額サポーター特典';

  @override
  String get appIconSupporterSectionLabel => '月額サポーター特典';

  @override
  String get appIconPickerTitle => 'アプリアイコンを選ぶ';

  @override
  String get appIconPickerSubtitle => 'ホーム画面に表示するアイコンを選べます。';

  @override
  String get appIconOptionDefaultTitle => 'ダーク';

  @override
  String get appIconOptionDefaultSubtitle => '通常の CC Pocket アイコンです。';

  @override
  String get appIconOptionLightOutlineTitle => 'ライト';

  @override
  String get appIconOptionLightOutlineSubtitle => '軽やかなラインが映える明るめのバリエーション。';

  @override
  String get appIconOptionCopperEmeraldTitle => 'メタリック';

  @override
  String get appIconOptionCopperEmeraldSubtitle => '光沢感のある特別版。';

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
  String get loadingSessions => 'セッション一覧を読み込み中...';

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
  String get fcmRegistrationFailed => 'Bridge への通知登録に失敗しました';

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
  String get usageConnectToView => 'Bridge に接続すると利用量を表示できます';

  @override
  String get usageFetchFailed => '取得に失敗しました';

  @override
  String get usageFiveHour => '5時間';

  @override
  String get usageSevenDay => '7日間';

  @override
  String get settingsUsageSectionTitle => '利用量';

  @override
  String get settingsUsageNoData => '利用量データが見つかりませんでした。';

  @override
  String get usageDisplayModeRemaining => '残量';

  @override
  String get usageDisplayModeUsed => '使用量';

  @override
  String get usageOpenSettingsHint => '利用量の詳細を開く';

  @override
  String get usagePaceOnTrack => '順調';

  @override
  String get usagePaceSlightlyAhead => 'やや速い';

  @override
  String get usagePaceAhead => '速い';

  @override
  String get usagePaceFarAhead => 'かなり速い';

  @override
  String get usagePaceSlightlyBehind => 'やや余裕';

  @override
  String get usagePaceBehind => '余裕あり';

  @override
  String get usagePaceFarBehind => 'かなり余裕';

  @override
  String usagePaceExpected(int percent) {
    return '目安 $percent% 使用';
  }

  @override
  String get usagePaceWillLast => 'このペースならリセットまで持つ見込み';

  @override
  String usagePaceRunsOutIn(String duration) {
    return 'このペースだと約 $duration で上限の見込み';
  }

  @override
  String get usagePaceAtLimit => '上限に到達しています';

  @override
  String usageCompactResetIn(String duration) {
    return '$duration後にリセット';
  }

  @override
  String usageCompactRunsOutIn(String duration) {
    return '$durationで上限';
  }

  @override
  String get settingsNewSessionTabs => '新規セッションタブ';

  @override
  String get settingsNewSessionTabsDescription =>
      '新規セッションで表示する AI ツールの並び順を変更できます。';

  @override
  String get showHiddenDirectories => '隠しフォルダを表示';

  @override
  String get showHiddenDirectoriesSubtitle =>
      '新規セッションのフォルダ選択に「.」で始まるフォルダを表示します。';

  @override
  String get showBridgeNameInSessionList => 'Bridge名を表示';

  @override
  String get showBridgeNameInSessionListSubtitle =>
      '複数のBridgeが登録されているとき、接続中のBridge名をセッション一覧に表示します。';

  @override
  String get autoRenameCodexSessions => '自動Rename (Codex)';

  @override
  String get autoRenameCodexSessionsSubtitle =>
      '最初のエージェント応答後に Codex セッションへ自動で名前を付ける';

  @override
  String get showExtendedCodexEfforts => 'Effortスライダーに Max / Ultra を表示';

  @override
  String get showExtendedCodexEffortsSubtitle =>
      '選択した Codex モデルが対応している場合、スライダーに Max と Ultra を追加します';

  @override
  String get autoRenameClaudeSessions => '自動Rename (Claude)';

  @override
  String get autoRenameClaudeSessionsSubtitle =>
      '最初のエージェント応答後に Claude セッションへ自動で名前を付ける。API Key 利用時は追加の従量課金が発生します。';

  @override
  String get newSessionTabCodex => 'Codex';

  @override
  String get newSessionTabClaudeCode => 'Claude';

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
  String get codexWriterConflictGuidance =>
      'Codex Desktop または Codex App を閉じてから、もう一度お試しください。';

  @override
  String resumePathNotAllowed(String path) {
    return '「$path」はBridgeの許可フォルダ外です。BRIDGE_ALLOWED_DIRS（カンマ区切り）に追加してBridgeを再起動してください。';
  }

  @override
  String get clipboardNotAvailable => 'クリップボードにアクセスできません';

  @override
  String get failedToLoadImage => '画像の読み込みに失敗しました';

  @override
  String get generatedImagePromptLabel => 'プロンプト';

  @override
  String get generatedImageDetailsLabel => '詳細';

  @override
  String get generatedImageHideDetailsLabel => '詳細を閉じる';

  @override
  String get generatedImageStatusLabel => 'ステータス';

  @override
  String get generatedImageSavedPathLabel => '保存先';

  @override
  String get previousImage => '前の画像';

  @override
  String get nextImage => '次の画像';

  @override
  String generatedImagePositionLabel(int current, int total) {
    return '生成画像 $current / $total';
  }

  @override
  String get noImageInClipboard => 'クリップボードに画像がありません';

  @override
  String get failedToReadClipboard => 'クリップボードの読み取りに失敗しました';

  @override
  String imageLimitReached(int max) {
    return '画像は最大$max枚までです';
  }

  @override
  String imageLimitTruncated(int max, int dropped) {
    return '最初の$max枚のみ添付しました（$dropped枚を除外）';
  }

  @override
  String get selectFromGallery => 'ギャラリーから選択';

  @override
  String get pasteFromClipboard => 'クリップボードから貼付';

  @override
  String get pasteImage => '画像をペースト';

  @override
  String get voiceInputLanguage => '音声入力の言語';

  @override
  String get hideVoiceInput => '音声入力ボタンを非表示';

  @override
  String get hideVoiceInputSubtitle => 'サードパーティの音声入力キーボードを利用する場合に便利';

  @override
  String get openGalleryDirectly => '画像ボタンでギャラリーを直接開く';

  @override
  String get openGalleryDirectlySubtitle => 'すぐに画像選択を開始します。長押しで添付メニューを開けます';

  @override
  String get archive => 'アーカイブ';

  @override
  String get archiveConfirm => 'このセッションをアーカイブしますか？';

  @override
  String get archiveConfirmMessage =>
      'セッションは一覧から非表示になります。Claude Codeからは引き続きアクセスできます。';

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
  String get tooltipIndent => 'インデントを増やす';

  @override
  String get tooltipDedent => 'インデントを減らす';

  @override
  String get tooltipSlashCommand => 'コマンド・スキルを入力';

  @override
  String get tooltipMention => 'ファイル・プラグインをメンション';

  @override
  String get tooltipDollarMention => 'スキル・アプリを入力';

  @override
  String get tooltipPermissionMode => 'パーミッションモード';

  @override
  String get tooltipAttachImage => '画像を添付';

  @override
  String get tooltipPromptHistory => 'プロンプト履歴を開く';

  @override
  String get tooltipVoiceInput => '音声入力を開始';

  @override
  String get tooltipStopRecording => '録音を停止';

  @override
  String get voiceInputUnavailable =>
      '音声入力を利用できません。設定でマイクと音声認識へのアクセスを許可してください。';

  @override
  String get tooltipSendMessage => 'メッセージを送信';

  @override
  String get tooltipRemoveImage => '画像を削除';

  @override
  String get tooltipClearDiff => 'Diff選択を解除';

  @override
  String get showMore => 'もっと見る';

  @override
  String get showLess => '閉じる';

  @override
  String get authErrorTitle => 'Claudeの再ログインが必要です';

  @override
  String get authErrorBody => 'BridgeマシンでClaudeに再ログインしてください。';

  @override
  String get authErrorPrimaryCommandLabel => '手順1';

  @override
  String get authErrorSecondaryCommandLabel => '手順2';

  @override
  String get authErrorAlternativeLabel => 'シェルから実行する場合';

  @override
  String get claudeOAuthOptInTitle => 'サブスクリプション認証には明示的な有効化が必要です';

  @override
  String get claudeOAuthOptInBody =>
      'Anthropicはホストされた未改変のClaude Codeへのユーザー自身のログインを認める一方、Agent SDKガイドでは第三者製品にAPIキーを案内しています。そのためCC Pocketではサブスクリプション認証をデフォルトで無効にしています。';

  @override
  String get claudeOAuthOptInHint =>
      '詳細を確認し、Bridgeマシンで設定して再起動してください。不確実性を避ける場合はAPIキーを利用できます:';

  @override
  String get authHelpTitle => '認証トラブルシューティング';

  @override
  String get authHelpFetchError => 'トラブルシューティングガイドを読み込めませんでした';

  @override
  String get authHelpButton => '手順を見る';

  @override
  String get authHelpLanguageJa => '日本語';

  @override
  String get authHelpLanguageEn => 'English';

  @override
  String get authHelpLanguageZhHans => '简体中文';

  @override
  String get authHelpLanguageKo => '한국어';

  @override
  String get terminalApp => 'ターミナルアプリ';

  @override
  String get terminalAppSubtitle => '外部ターミナルアプリでプロジェクトを開く';

  @override
  String get terminalAppNone => '未設定';

  @override
  String get terminalAppCustom => 'カスタム';

  @override
  String get terminalAppName => 'アプリ名';

  @override
  String get terminalUrlTemplate => 'URL テンプレート';

  @override
  String get terminalUrlTemplateHint => '変数: host, user, port, project_path';

  @override
  String get terminalSshUser => 'SSH ユーザー';

  @override
  String get terminalSshUserHint => '未入力時はマシンの SSH ユーザーを使用';

  @override
  String get openInTerminal => 'ターミナルで開く';

  @override
  String get terminalAppNotInstalled => 'ターミナルアプリを開けませんでした';

  @override
  String get terminalAppExperimental => 'プレビュー';

  @override
  String get terminalAppExperimentalNote =>
      'この機能はプレビュー版です。プリセットはアプリや環境によって動作しない場合があります。新しいプリセットの追加は GitHub で歓迎しています！';

  @override
  String get sectionSpread => 'CC Pocket を広める';

  @override
  String get spreadAppealMessage =>
      'CC Pocket はまだ利用者が少なく、このままだと開発を続けるのが難しい状況です。気に入っていたら、ストア評価（星だけでOK）や知り合いへの紹介で応援してください。';

  @override
  String get shareApp => 'SNSでシェア';

  @override
  String get shareAppSubtitle => '同僚や友人に紹介する';

  @override
  String shareText(String url) {
    return 'CC Pocket: Claude & Codex\nスマホからコーディングエージェントを操作できるアプリ 📱\n#ccpocket\n$url';
  }

  @override
  String get starOnGithub => 'GitHub にスターする';

  @override
  String get rateOnStore => 'App Store で評価する';

  @override
  String get rateOnStoreAndroid => 'Google Play で評価する';

  @override
  String get supporterTitle => 'Supporter';

  @override
  String get supporterMonthlyTitle => '月額サポーター';

  @override
  String get supporterMonthlyPlusTitle => '月額サポーター Plus';

  @override
  String get supporterSnackTitle => 'おやつで応援';

  @override
  String get supporterCoffeeTitle => 'ドリンクで応援';

  @override
  String get supporterLunchTitle => 'ランチで応援';

  @override
  String get supporterStatusActive => 'CC Pocket を応援してくれてありがとうございます。';

  @override
  String get supporterStatusInactive => 'アプリは無料のまま。継続開発を応援できます。';

  @override
  String get supporterStatusLoading => '応援状態を確認しています...';

  @override
  String get supportEntryInactiveTitle => '応援する';

  @override
  String get supportEntryInactiveSubtitle =>
      'CC Pocket が気に入ったら、継続開発を応援してもらえるとうれしいです。';

  @override
  String get supportEntryOneTimeTitle => '応援ありがとう';

  @override
  String get supportEntryOneTimeSubtitle => 'これまでの応援、ありがとうございます。';

  @override
  String get supportEntryActiveTitle => '応援中';

  @override
  String supportEntryActiveSubtitle(String date) {
    return 'いつもありがとうございます。$dateから応援中です。';
  }

  @override
  String get supporterMonthlyDescription => '継続的な開発を後押し';

  @override
  String get supporterMonthlyPerkLabel => 'アプリアイコン変更特典付き';

  @override
  String get supporterSnackDescription => 'おやつを1つおごる';

  @override
  String get supporterCoffeeDescription => 'ドリンクを1杯おごる';

  @override
  String get supporterLunchDescription => 'ランチを1食おごる';

  @override
  String get supporterBuyButton => '応援する';

  @override
  String get supporterActiveButton => '応援中';

  @override
  String get supporterSubscribedButton => '購読中';

  @override
  String get supporterRestoreButton => '購入を復元';

  @override
  String get supporterRetryButton => '再試行';

  @override
  String get supporterProductsUnavailable => '現在利用できる応援プランがありません。';

  @override
  String get supporterRestoreNoticeTitle => '購入の復元について';

  @override
  String get supporterRestoreNoticeBody =>
      '購入の復元は同じ Apple ID または Google アカウントで利用できます。iOS と Android の間で応援状態は共有されません。';

  @override
  String get supporterSummaryTitle => '応援サマリー';

  @override
  String supporterSummarySinceChip(String date) {
    return '$dateから応援中';
  }

  @override
  String supporterSummaryStreakChip(String duration) {
    return '継続 $duration';
  }

  @override
  String supporterSummaryOneTimeCount(int count) {
    return '単発 ×$count';
  }

  @override
  String supporterSummarySnackCount(int count) {
    return 'おやつ ×$count';
  }

  @override
  String supporterSummaryCoffeeCount(int count) {
    return 'ドリンク ×$count';
  }

  @override
  String supporterSummaryLunchCount(int count) {
    return 'ランチ ×$count';
  }

  @override
  String get supporterSummaryLessThanMonth => '1か月未満';

  @override
  String supporterSummaryDurationMonths(int count) {
    return '$countか月';
  }

  @override
  String get supporterSummarySinceLabel => '応援開始';

  @override
  String get supporterSummaryStreakLabel => '継続';

  @override
  String get supporterSummaryOngoingLabel => '継続中';

  @override
  String get supporterSummarySupportPeriodLabel => '応援期間';

  @override
  String get supporterImpactTitle => '応援でできること';

  @override
  String get supporterImpactBody =>
      'CC Pocket が気に入ったら、継続開発を応援してもらえるとうれしいです。アプリはこれからも無料の OSS として続けていきます。';

  @override
  String get supporterImpactAiTitle => '開発と運用のコスト';

  @override
  String get supporterImpactAiBody => 'AI 利用料、実機確認、テスト、配布まわりなどの継続コストを支えます。';

  @override
  String get supporterImpactDevicesTitle => '端末とテスト';

  @override
  String get supporterImpactDevicesBody =>
      '実機確認や OS アップデート追従など、安定運用に必要なコストを支えます。';

  @override
  String get supporterImpactMotivationTitle => '継続するモチベーション';

  @override
  String get supporterImpactMotivationBody =>
      '使ってくれている実感が、新機能や改善を続けるいちばんの後押しになります。';

  @override
  String get supporterPackagesTitle => '応援の方法';

  @override
  String get supporterSubscriptionGroupTitle => '毎月応援';

  @override
  String get supporterSubscriptionGroupBody => '継続的に応援してもらえるとうれしいです。';

  @override
  String get supporterOneTimeGroupTitle => '単発で応援';

  @override
  String get supporterOneTimeGroupBody =>
      'ランチやドリンクをおごる気持ちになったら、応援してもらえるとうれしいです。';

  @override
  String get supporterPurchaseInfoTitle => '購入について';

  @override
  String get supporterPurchaseInfoBody =>
      '購入の復元は同じ Apple ID または Google アカウントで利用できます。iOS と Android の間で応援状態は共有されません。';

  @override
  String get supporterPurchaseInfoLink => '詳しくはこちら';

  @override
  String get supporterPrivacyPolicyLink => 'プライバシーポリシー';

  @override
  String get supporterTermsOfUseLink => '利用規約（Apple標準EULA）';

  @override
  String get supporterLearnMoreTitle => '購入と応援について';

  @override
  String get supporterLearnMoreBody => '無料で提供し続ける考え方や、購入の復元の仕組みを確認できます。';

  @override
  String get supporterOpenLinkFailed => '案内ページを開けませんでした。';

  @override
  String get supporterPurchaseSuccess => 'CC Pocket を応援してくれてありがとうございます。';

  @override
  String get supporterPurchaseCancelled => '購入をキャンセルしました。';

  @override
  String supporterPurchaseFailed(String message) {
    return '購入に失敗しました: $message';
  }

  @override
  String get supporterRestoreSuccess => '購入情報を復元しました。';

  @override
  String supporterRestoreFailed(String message) {
    return '復元に失敗しました: $message';
  }

  @override
  String get gitDiscardAllChangesTitle => 'すべての変更を破棄しますか';

  @override
  String get gitDiscardVisibleUnstagedChangesMessage => '表示中の未ステージ変更をすべて破棄します。';

  @override
  String get gitDiscardChangeTitle => 'この変更を破棄しますか';

  @override
  String get gitDiscardFileUnstagedChangesMessage => 'このファイルの未ステージ変更をすべて破棄します。';

  @override
  String get gitDiscardHunkUnstagedChangesMessage => 'このハンクの未ステージ変更を破棄します。';

  @override
  String get googleSearchSelectionAction => 'Google で検索';

  @override
  String get copyAsMarkdownSelectionAction => 'Markdown でコピー';

  @override
  String get approvalQuestionNotificationTitle => '質問があります - ccpocket';

  @override
  String get approvalRequiredNotificationTitle => '承認待ち - ccpocket';

  @override
  String get exitPlanModeNotificationBody => '作成したプランの確認が必要です';

  @override
  String get renderErrorFallback => 'このコンテンツを表示できませんでした';

  @override
  String get localUrlTitle => 'ローカルURLの開き方';

  @override
  String get localUrlOriginal => 'そのまま開く';

  @override
  String get localUrlReplace => 'ホストを置換して開く';

  @override
  String get localUrlAsk => '開く前に選ぶ';

  @override
  String get localUrlHost => '置換先ホスト';

  @override
  String get localUrlDescription =>
      'エージェントメッセージ内の localhost・127.0.0.1・[::1] のHTTP/HTTPSリンクに適用します。設定はBridge接続先ごとに保存され、本文は変更しません。';

  @override
  String get localUrlHostHelp =>
      '初期値はBridge接続先のIPアドレス／ホスト名です。Wi-FiやTailscaleなど、この端末からWebサーバーに到達できるホストを指定してください。URLのポートとパスは維持します。Webサーバー側も、そのネットワークから接続できるアドレスで待ち受ける必要があります。';

  @override
  String get localUrlInvalidHost =>
      'IPアドレスまたはホスト名のみを入力してください（スキーム・ポート・パスは不要）。IPv6は [ ] で囲みます。';

  @override
  String get annotateImage => '描き込む';

  @override
  String get drawSketch => 'スケッチを描く';

  @override
  String get sketchTitle => 'スケッチ';

  @override
  String get sketchApply => '反映';

  @override
  String get sketchAttach => '添付';

  @override
  String get sketchPen => 'ペン';

  @override
  String get sketchEraser => '消しゴム';

  @override
  String get sketchText => '文字';

  @override
  String get sketchArrow => '矢印';

  @override
  String get sketchRectangle => '四角';

  @override
  String get sketchEllipse => '丸';

  @override
  String get sketchUndo => '元に戻す';

  @override
  String get sketchRedo => 'やり直す';

  @override
  String get sketchStrokeWidth => '線の太さ';

  @override
  String get sketchColor => '色';

  @override
  String get sketchDiscardTitle => '変更を破棄しますか？';

  @override
  String get sketchDiscardMessage => 'スケッチの変更は保存されません。';

  @override
  String get sketchDiscard => '破棄';

  @override
  String get sketchKeepEditing => '編集を続ける';

  @override
  String get sketchExportFailed => 'スケッチを画像にできませんでした。もう一度お試しください。';

  @override
  String get sketchLoadFailed => 'スケッチを開けませんでした。添付画像はそのまま残っています。';

  @override
  String get sketchTextHint => '文字を入力';

  @override
  String get sketchAddText => '文字を追加';

  @override
  String get sketchCancel => 'キャンセル';

  @override
  String get tooltipEditSketch => 'スケッチを編集';

  @override
  String get tooltipAttachmentOptions => '長押しで添付メニューを開く';

  @override
  String get sketchSelect => '選択';

  @override
  String get sketchDelete => '削除';

  @override
  String get filePreviewModelLoadFailed =>
      '3Dモデルを読み込めませんでした。画像や形状を含むGLBファイルを確認してください。';

  @override
  String get filePreviewModelTooLarge => '3Dプレビューは50 MB以下のGLBファイルに対応しています。';

  @override
  String get filePreviewModelGestures => 'ドラッグで回転・ピンチで拡大縮小';

  @override
  String get filePreviewModelReset => '視点をリセット';

  @override
  String get filePreviewModelWarning => '一部の素材や機能を再現できない可能性があります。';

  @override
  String get saveToPhotos => '写真に保存';

  @override
  String get savedToPhotos => '写真に保存しました';

  @override
  String get saveToPhotosFailed => '写真に保存できませんでした。非対応の形式の可能性があります。';

  @override
  String get photosPermissionDenied => '画像・動画を保存するには、設定で写真の追加を許可してください。';

  @override
  String get browserTitle => 'ファイル';

  @override
  String get browserSearch => 'ファイル名・パスで検索';

  @override
  String get browserBack => '戻る';

  @override
  String get browserParent => '親フォルダ';

  @override
  String get browserClose => '閉じる';

  @override
  String get browserAddToChat => 'チャットに追加';

  @override
  String get browserRecent => '最近開いたファイル';

  @override
  String get browserEmpty => 'このフォルダは空です';

  @override
  String get browserNoResults => '一致するファイル・フォルダはありません';

  @override
  String get browserRetry => '再試行';

  @override
  String get browserTimeout => '応答がありません。接続を確認して再試行してください。';

  @override
  String get browserIndexLimited => '検索対象は取得済みの一覧です。すべての項目はフォルダを開いて確認できます。';

  @override
  String get browserLegacy => 'フォルダ内容の取得にはBridgeを更新してください。取得済みの一覧を表示しています。';

  @override
  String get browserToggleList => 'ファイル一覧の表示切替';

  @override
  String get browserRefresh => '更新';

  @override
  String get browserNotAllowed => 'このフォルダは閲覧可能な範囲外です。';

  @override
  String get browserNotFound => 'このパスは存在しません。';

  @override
  String get browserUnreadable => 'このフォルダを読み取れません。';

  @override
  String get browserCopyPath => 'パスをコピー';

  @override
  String get browserNoRecent => '開いたファイルがここに表示されます。';

  @override
  String get finderReveal => 'Finderで表示';

  @override
  String get finderRevealLocalOnly =>
      'このMacのBridgeであることを確認できませんでした。接続先を確認して、もう一度お試しください。';

  @override
  String get finderRevealUpdateBridge => 'Finderで表示するにはBridgeを更新してください。';

  @override
  String get finderRevealFailed => 'Finderで表示できませんでした。ファイルとBridgeの接続を確認してください。';

  @override
  String get performanceModeBridgeUpdate =>
      '通信量を減らすにはBridgeの更新が必要です。現在は画面上の非表示のみ対応しています。';

  @override
  String get liteMode => 'パフォーマンスモード';

  @override
  String get liteModeDescription =>
      'Bridgeから送るツール履歴や途中の画像を削減します。生成画像・添付画像・Explorerの画像は表示します。';

  @override
  String get chatDisplayMode => '表示モード';

  @override
  String get standardMode => '標準';

  @override
  String get followDefaultMode => '設定に従う';

  @override
  String get liteModeRunning => '実行中';

  @override
  String get liteModeWaiting => '承認・回答待ち';

  @override
  String get liteModeIdle => '待機中';

  @override
  String get liteModeCompacting => '会話を整理中';

  @override
  String get liteModeStarting => '開始中';

  @override
  String liteModeLastActivity(String elapsed) {
    return '受信$elapsed前';
  }

  @override
  String liteModeObserved(String elapsed) {
    return '監視$elapsed';
  }

  @override
  String get demoTry => '接続せずに試す';

  @override
  String get demoTitle => 'CC Pocketを体験';

  @override
  String get demoExit => '体験を終了';

  @override
  String get demoRestart => 'もう一度試す';

  @override
  String get demoDisclaimer => 'オフライン体験 · 応答はサンプルです。AIの利用やファイルの変更は行いません。';

  @override
  String get demoWelcome => '依頼を送り、変更を承認・拒否し、差分を確認する流れを試せます。PCやアカウントは不要です。';

  @override
  String get demoSuggestion => '挨拶のメッセージを親しみやすくして';

  @override
  String get demoInputHint => 'メッセージを試す';

  @override
  String get demoInputHelp => 'どんなメッセージでも同じサンプルが始まります。AIには送信されません。';

  @override
  String get demoSend => 'サンプルの依頼を送る';

  @override
  String get demoProposal =>
      'このサンプルでは、lib/welcome.dart の挨拶を「Hello」から「Hello, Pocket!」へ変更します。編集を許可するか選んでください。';

  @override
  String get demoApprovalTitle => 'サンプルの編集を許可しますか？';

  @override
  String get demoApprovalDetail => '編集 · lib/welcome.dart\n変更するのはサンプルデータだけです。';

  @override
  String get demoReject => '拒否';

  @override
  String get demoApprove => '今回だけ許可';

  @override
  String get demoCompleted =>
      'サンプルの編集が完了しました。下の差分で追加・削除された行を確認できます。実際のファイルは変更していません。';

  @override
  String get demoRejected => '編集を拒否しました。変更はありません。ツールの操作は自分で判断できます。';

  @override
  String get demoDiffSummary => 'サンプル差分 · 1行追加、1行削除';

  @override
  String get demoFinish => '自分のBridgeに接続すると、実際のプロジェクトとAIエージェントで作業できます。';

  @override
  String get demoConnect => '自分のBridgeを設定する';

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
    return '$hours時間$minutes分';
  }

  @override
  String liteModeDurationDays(int days, int hours) {
    return '$days日$hours時間';
  }

  @override
  String get mediaFeedbackComments => '素材への指示';

  @override
  String get mediaFeedbackAtTime => 'この時刻にコメント';

  @override
  String get mediaFeedbackWhole => '全体';

  @override
  String get mediaFeedbackVideoHint => '動画への指示…';

  @override
  String get mediaFeedbackImageHint => 'この画像への指示…';

  @override
  String get mediaFeedbackDone => '完了';

  @override
  String get mediaFeedbackSendHint => '自動保存 · チャット送信時に末尾へ追加';

  @override
  String get mediaFeedbackSendError =>
      '素材を添付できませんでした。接続と画像の枚数を確認してください（最大5枚）。指示は下書きに残っています。';

  @override
  String get mediaFeedbackSourceChanged =>
      'この素材はコメント作成後に更新されています。内容と時刻を確認してください。';

  @override
  String get mediaFeedbackConfirmSource => '更新後の素材に適用';

  @override
  String diffCommentHint(String line) {
    return '$line へのコメント…';
  }

  @override
  String get diffCommentOutdated => '変更されたためコメント元の行が見つかりません';

  @override
  String get newProject => '新しいプロジェクトを作る';

  @override
  String get existingProject => '既存のプロジェクトで始める';

  @override
  String get multiProjectStart => 'マルチプロジェクトで始める';

  @override
  String get multiProjectHint =>
      'アプリとAPIなど、複数のプロジェクトをまとめてAIに扱わせます。フォルダやGitリポジトリは別々のまま、同じセッションで作業できます。';

  @override
  String get newProjectName => 'フォルダ名';

  @override
  String get newProjectParent => '保存先フォルダ';

  @override
  String get newProjectDescription => '作りたいもの（任意）';

  @override
  String get newProjectGit => 'Gitで変更を管理する';

  @override
  String get newProjectSettingsSource => 'AI設定の引き継ぎ元';

  @override
  String get newProjectNoSource => '引き継がない';

  @override
  String get newProjectSettingsHint =>
      'CLAUDE.md・AGENTS.md・共有AI設定・スキルなどを下書きとしてコピーします。認証情報・ローカル専用設定・履歴は対象外です。最初のメッセージで新プロジェクト向けの調整を依頼します。';

  @override
  String get newProjectCreate => 'プロジェクトを作成';

  @override
  String get projectSetupWorking => '準備しています…';

  @override
  String get projectSetupCreated => '作成済み';

  @override
  String get projectSetupUpdateHint =>
      '応答を確認できませんでした。Bridgeの接続とバージョンを確認してください。古いBridgeの場合は更新が必要です。作成済みのフォルダは既存プロジェクトから開けます。';

  @override
  String get projectSetupAdaptPrompt =>
      'まず .ccpocket-bootstrap 内のAI設定の下書きを確認し、この新プロジェクト向けに調整してください。元プロジェクト固有のパス・構成・リリース手順を取り除き、使える開発規約とスキルを適切な場所へ配置してください。参照元は変更しないでください。hooks・外部コマンド・MCPなどの実行設定は、内容と参照先を説明し確認を得てから有効にしてください。調整内容を説明した後、依頼したプロジェクトの作成を進めてください。';

  @override
  String get trustProject => 'このプロジェクトをCodexで信頼する';

  @override
  String get trustProjectHint =>
      'このフォルダのCodex設定・hooks・rulesの読み込みを許可します。コマンドの実行権限とは別の設定です。';

  @override
  String get initializeGit => 'Gitを初期化する';

  @override
  String get projectSetupDone => '設定を保存しました';

  @override
  String get gitNoCommits => 'まだコミットがありません';

  @override
  String get sessionProject => 'プロジェクト';

  @override
  String get createProjectShort => '作成';

  @override
  String get multiProjectShort => 'マルチ';

  @override
  String get changeProjectLocation => '変更';

  @override
  String get chooseExistingFolder => '既存フォルダを選択';

  @override
  String get defaultInputDelivery => '実行中に送るメッセージ';

  @override
  String get defaultInputDeliverySubtitle => '送信ボタンの既定動作です。長押しでもう一方を選べます。';

  @override
  String get skillTriggerStyle => 'スキル呼び出し記号';

  @override
  String get skillTriggerStyleSubtitle =>
      '/ と \$ のどちらでもスキル候補を出せます。送信時は Claude なら /、Codex なら \$ に自動で変換します。';

  @override
  String get skillTriggerStyleBoth => '両方';

  @override
  String get skillTriggerStyleSlash => '常に /';

  @override
  String get skillTriggerStyleDollar => '常に \$';

  @override
  String get inputDeliverySteer => '差し込む';

  @override
  String get inputDeliveryQueue => 'キュー';

  @override
  String get inputDeliverySteerDescription => '実行中のターンを止めずに指示を追加します';

  @override
  String get inputDeliveryQueueDescription => '現在のターンが終わってから送信します';

  @override
  String get sendAsSteer => '今のターンに差し込む';

  @override
  String get sendAsQueue => '次のターンにキュー';

  @override
  String get backgroundTasksRunning => 'バックグラウンドで実行中';

  @override
  String backgroundTasksMore(int count) {
    return '他$count件';
  }

  @override
  String sessionCardBackgroundTasks(int count) {
    return 'バックグラウンド $count';
  }

  @override
  String get liteModeBackground => 'バックグラウンド実行中';

  @override
  String sessionCardBackgroundAgents(int count) {
    return 'サブエージェント $count';
  }

  @override
  String get backgroundTasksStop => 'バックグラウンドタスクを停止';

  @override
  String get recentFilterPinnedOnly => 'ピン留め';

  @override
  String recentFilterProjectsSummary(String name, int count) {
    return '$name +$count';
  }

  @override
  String get recentFilterPeriod => '期間';

  @override
  String get recentDateToday => '今日';

  @override
  String get recentDateYesterday => '昨日';

  @override
  String get recentDateDayBeforeYesterday => '一昨日';

  @override
  String get recentDateLast7Days => '過去7日';

  @override
  String get recentDateLast30Days => '過去30日';

  @override
  String get recentDateCustom => '期間を指定…';

  @override
  String get recentDateAnyTime => 'すべての期間';

  @override
  String get recentFilterClear => 'クリア';

  @override
  String get recentAdvancedSearch => '高度な検索';

  @override
  String recentAdvancedConditions(int count) {
    return '詳細条件 $count';
  }

  @override
  String get recentDisplaySettings => '表示設定';

  @override
  String get recentLayout => 'レイアウト';

  @override
  String get recentLayoutList => 'リスト';

  @override
  String get recentLayoutGrouped => 'プロジェクトごと';

  @override
  String get recentCardText => 'カードに表示する発言';

  @override
  String get recentPinnedSection => 'ピン留め';

  @override
  String get recentFavoriteProjects => 'お気に入り';

  @override
  String get recentOtherProjects => 'その他のプロジェクト';

  @override
  String get recentSelectFavorites => 'お気に入りをすべて選択';

  @override
  String get recentNoFavoriteProjects => '☆ をタップするとお気に入りに追加できます';

  @override
  String get recentProjectPickerTitle => 'プロジェクトで絞り込み';

  @override
  String get recentApply => '適用';

  @override
  String get recentReset => 'リセット';

  @override
  String get recentKeywords => 'キーワード';

  @override
  String get recentKeywordsHint => '名前・発言・要約・プロジェクト・ブランチ';

  @override
  String get recentSearchContent => '会話の本文も検索';

  @override
  String get recentSearchContentHint => '時間がかかります。ユーザーとAIのメッセージが対象です';

  @override
  String get recentDateField => '基準にする日時';

  @override
  String get recentDateFieldModified => '最終更新';

  @override
  String get recentDateFieldCreated => '作成';

  @override
  String get recentNamedOnly => '名前付きのみ';

  @override
  String get recentPinnedOnly => 'ピン留めのみ';

  @override
  String get recentAiTool => 'AI ツール';

  @override
  String get recentRequiresBridgeUpdate => 'Bridge を更新すると使えます';

  @override
  String recentMatchedIn(String field) {
    return '一致: $field';
  }

  @override
  String get recentMatchName => '名前';

  @override
  String get recentMatchFirstPrompt => '最初の発言';

  @override
  String get recentMatchLastPrompt => '最後の発言';

  @override
  String get recentMatchSummary => '要約';

  @override
  String get recentMatchProject => 'プロジェクト';

  @override
  String get recentMatchBranch => 'ブランチ';

  @override
  String get recentMatchContent => '本文';

  @override
  String get recentFavoriteTooltip => 'お気に入り';

  @override
  String get contextCompactionTitle => 'コンテキストを圧縮しました';

  @override
  String get contextCompactionManual => '手動';

  @override
  String get contextCompactionAuto => '自動';

  @override
  String contextCompactionTokens(String before, String after) {
    return '$before → $after tokens';
  }

  @override
  String get contextCompactionShowSummary => '要約を表示';

  @override
  String get contextCompactionHideSummary => '要約を隠す';

  @override
  String get contextCompactionOpenTranscript => '以前のやり取りを見る';

  @override
  String get contextCompactionInProgress => 'コンテキストを圧縮中…';

  @override
  String get olderHistoryTitle => '古いメッセージは省略されています';

  @override
  String get transcriptTitle => '以前のやり取り';

  @override
  String get transcriptLoadOlder => 'さらに古いメッセージを読み込む';

  @override
  String get transcriptEmpty => '表示できるメッセージがありません';

  @override
  String get transcriptLoadFailed => 'メッセージを読み込めませんでした';

  @override
  String get transcriptBridgeUpdate => '以前のやり取りを表示するにはBridgeの更新が必要です。';

  @override
  String get githubIssuesAndPrs => 'Issue / PR';

  @override
  String get githubTabIssues => 'Issue';

  @override
  String get githubTabPrs => 'PR';

  @override
  String get githubDraft => 'Draft';

  @override
  String get githubFilterHideDrafts => 'Draftを隠す';

  @override
  String get githubFilterDependabotOnly => 'dependabotのみ';

  @override
  String get githubFilterLabel => 'ラベル';

  @override
  String get githubFilterAllLabels => 'すべてのラベル';

  @override
  String get githubEmptyPrs => 'オープンなPRはありません';

  @override
  String get githubEmptyIssues => 'オープンなIssueはありません';

  @override
  String get githubEmptyFiltered => '条件に合う項目がありません';

  @override
  String get githubOpenOnGitHub => 'GitHubで開く';

  @override
  String get githubRecentComments => '最近のコメント';

  @override
  String get githubNoComments => 'コメントはまだありません';

  @override
  String get githubNoDescription => '説明はありません';

  @override
  String get githubSelectAll => 'すべて選択';

  @override
  String get githubStartFromIssueOrPr => 'Issue / PR から始める';

  @override
  String get githubSelect => '選択';

  @override
  String get githubDeselect => '選択を解除';

  @override
  String get githubClearSelection => '選択をすべて解除';

  @override
  String get githubSelectAllSkipsDrafts => 'Draftは除外されます。含めるには個別にタップしてください。';

  @override
  String githubSelectedCount(int count) {
    return '$count件を選択中';
  }

  @override
  String get githubErrorGhMissingTitle => 'GitHub CLIが見つかりません';

  @override
  String get githubErrorGhMissingBody =>
      'Bridgeを動かしているマシンにGitHub CLI（gh）をインストールしてから、再度お試しください。';

  @override
  String get githubErrorUnauthenticatedTitle => 'GitHub CLIがログインしていません';

  @override
  String get githubErrorUnauthenticatedBody =>
      'Bridgeを動かしているマシンで次のコマンドを実行してから、再度お試しください。';

  @override
  String get githubErrorNotGithubTitle => 'GitHubリポジトリではありません';

  @override
  String get githubErrorNotGithubBody => 'このプロジェクトのoriginリモートはGitHubを指していません。';

  @override
  String get githubErrorFailedTitle => 'GitHubから読み込めませんでした';

  @override
  String get githubErrorTimeoutBody => 'Bridgeから応答がありません。接続を確認して再度お試しください。';

  @override
  String get githubErrorUnsupportedTitle => 'Bridgeの更新が必要です';

  @override
  String get githubErrorUnsupportedBody =>
      'このBridgeはIssue / PRの表示に対応していません。Bridgeを最新版に更新してから、再度お試しください。';

  @override
  String get githubChecksSuccess => 'CI成功';

  @override
  String get githubChecksFailure => 'CI失敗';

  @override
  String get githubChecksPending => 'CI実行中';

  @override
  String get settingsEnabledModels => '利用するモデル';

  @override
  String get settingsEnabledModelsDescription =>
      'モデル選択に表示するモデルを絞り込みます。すべて選択すると制限なしで表示されます。';

  @override
  String get settingsEnabledModelsAll => 'すべて表示';

  @override
  String get settingsEnabledModelsSelectAll => 'すべて選択';

  @override
  String get settingsEnabledModelsClearAll => 'すべて解除';

  @override
  String get settingsEnabledModelsAtLeastOne => '1つ以上のモデルを選択してください';

  @override
  String get settingsEnabledModelsLoading => 'モデル一覧を読み込み中…';

  @override
  String get settingsEnabledModelsUnavailable =>
      'Bridgeに接続すると利用可能なモデル一覧を取得できます';

  @override
  String get settingsModelPickerStyle => 'モデルの選択方法';

  @override
  String get settingsModelPickerStyleSubtitle =>
      'モデル名をタップしたときの表示方法。メニューにするとシートを重ねずその場で選べます。';

  @override
  String get modelPickerStyleBottomSheet => 'シート';

  @override
  String get modelPickerStylePopupMenu => 'メニュー';

  @override
  String handoffTo(String agent) {
    return '$agentに引き継ぐ';
  }

  @override
  String handoffConfirmBody(String source, String agent) {
    return '$sourceが引き継ぎメモを書いたあと、このセッションを停止し、$agentが同じディレクトリで続きを行います。実行中のターンは中断されます。';
  }

  @override
  String handoffInstructionLabel(String agent) {
    return '$agentへの指示（任意）';
  }

  @override
  String get handoffInstructionHint => '空欄なら作業の続きを任せます';

  @override
  String get handoffConfirmAction => '引き継ぐ';

  @override
  String handoffStarted(String agent) {
    return '$agentへの引き継ぎを開始しました';
  }

  @override
  String handoffCardFrom(String source) {
    return '$sourceから引き継ぎ';
  }

  @override
  String handoffCardNoteRequest(String agent) {
    return '$agentへの引き継ぎメモを依頼';
  }

  @override
  String get localBridgeTitle => 'このMacのBridge';

  @override
  String get localBridgeSettingsSubtitle => '状態・ペアリング・設定';

  @override
  String get localBridgeStatusRunning => '稼働中';

  @override
  String localBridgeStatusDetail(String version, int port) {
    return 'v$version・ポート $port';
  }

  @override
  String localBridgeStatusCounts(int sessions, int clients) {
    return 'セッション $sessions・接続中の端末 $clients';
  }

  @override
  String get localBridgeNotRunningTitle => 'Bridgeが起動していません';

  @override
  String localBridgeNotRunningBody(int port) {
    return 'ポート $port で応答がありません。ターミナルで次のコマンドを実行して起動してください。';
  }

  @override
  String get localBridgeSecretUnavailableTitle => 'このBridgeは管理できません';

  @override
  String get localBridgeSecretUnavailableBody =>
      'Bridgeは動いていますが、ペアリング情報を読み取れません。別のユーザーが起動しているか、Bridgeが古い可能性があります。';

  @override
  String get localBridgeUpdateRequiredTitle => 'Bridgeの更新が必要です';

  @override
  String get localBridgeUpdateRequiredBody =>
      'このBridgeはアプリからの管理に対応していません。最新版に更新して再起動してください。';

  @override
  String get localBridgeErrorTitle => 'Bridgeの情報を取得できませんでした';

  @override
  String get localBridgeRestartRequired => '変更は再起動後に反映されます';

  @override
  String get localBridgeRestartNow => '再起動して反映';

  @override
  String get localBridgeRestarting => '再起動中…';

  @override
  String get localBridgeRestartConfirmTitle => 'Bridgeを再起動しますか？';

  @override
  String get localBridgeRestartConfirmBody => '接続中の端末は自動で再接続します。';

  @override
  String localBridgeRestartConfirmSessions(int count) {
    return '実行中のセッション $count 件が中断されます。';
  }

  @override
  String get localBridgeNotSupervised =>
      'このBridgeは手動で起動されているため、アプリから再起動できません。起動したターミナルで再起動してください。';

  @override
  String get localBridgeRestartFailed => 'Bridgeが再起動しませんでした';

  @override
  String get localBridgeActionFailed => '操作に失敗しました';

  @override
  String get localBridgeInvalidSettings => '保存できない設定があります';

  @override
  String get localBridgeChangePort => '別のポートのBridgeを管理';

  @override
  String get localBridgePairingTitle => 'スマホをつなぐ';

  @override
  String get localBridgePairingBody => 'スマホのCC PocketでQRコードを読み取ると接続できます。';

  @override
  String get localBridgePairingSensitive => 'QRコードにはAPIキーが含まれます。画面共有に注意してください。';

  @override
  String get localBridgePairingNoAddress =>
      '他の端末から届くアドレスが見つかりません。Wi-FiかTailscaleに接続してください。';

  @override
  String get localBridgeCopyLink => '接続リンクをコピー';

  @override
  String get localBridgeShowQr => 'QRコードを表示';

  @override
  String get localBridgeHideQr => 'QRコードを隠す';

  @override
  String get localBridgeRotateKey => 'APIキーを再生成';

  @override
  String get localBridgeRotateKeyConfirmBody =>
      '再起動後、ペアリング済みの端末はQRコードを読み直す必要があります。';

  @override
  String get localBridgeRotateKeyDone => 'APIキーを再生成しました。再起動後に有効になります。';

  @override
  String get localBridgeAuthDisabled => '認証が無効です。このポートに届く人は誰でもエージェントを操作できます。';

  @override
  String get localBridgeToolsTitle => '必要なツール';

  @override
  String get localBridgeToolsReady => '準備ができています';

  @override
  String get localBridgeToolsNotReady => 'Node.js・Gitと、エージェントが1つ以上必要です';

  @override
  String get localBridgeToolsUnsupported => 'ツールの確認にはBridgeの更新が必要です';

  @override
  String get localBridgeToolReady => '利用可能';

  @override
  String get localBridgeToolNotInstalled => '未インストール';

  @override
  String get localBridgeToolNeedsSetup => 'セットアップが必要';

  @override
  String get localBridgeToolInstall => 'インストール';

  @override
  String get localBridgeToolSetup => 'セットアップ';

  @override
  String get localBridgeToolDocs => '公式ガイドを開く';

  @override
  String get localBridgeToolRecheck => '再チェック';

  @override
  String get localBridgeToolRunInTerminal => 'ターミナルで実行してから再チェックしてください。';

  @override
  String get localBridgeToolRequired => '必須';

  @override
  String get localBridgeToolAgent => 'エージェント';

  @override
  String get localBridgeToolOptional => '任意';

  @override
  String get localBridgeToolDescNode => 'Bridgeの実行に必要です';

  @override
  String get localBridgeToolDescGit => '差分の表示やブランチ操作に使います';

  @override
  String get localBridgeToolDescClaude => 'Claude Codeのセッションに使います';

  @override
  String get localBridgeToolDescCodex => 'Codexのセッションに使います';

  @override
  String get localBridgeToolDescAntigravity => 'Antigravityのセッションに使います';

  @override
  String get localBridgeToolDescGh => 'GitHubのIssue・PRの表示に使います';

  @override
  String get localBridgeToolDescTailscale => '外出先から安全に接続できます';

  @override
  String get localBridgeGroupNetwork => 'ネットワーク';

  @override
  String get localBridgeGroupAccess => 'アクセス範囲';

  @override
  String get localBridgeGroupAgents => 'エージェント';

  @override
  String get localBridgeGroupSecurity => 'セキュリティ';

  @override
  String get localBridgeSettingPort => 'ポート';

  @override
  String get localBridgeSettingHost => '待ち受けアドレス';

  @override
  String get localBridgeSettingPublicWsUrl => '公開URL';

  @override
  String get localBridgeSettingPublicWsUrlDesc =>
      'QRコードに使う ws:// または wss:// のURL';

  @override
  String get localBridgeSettingAllowedDirs => 'プロジェクトを開けるフォルダ';

  @override
  String get localBridgeSettingReadOnlyDirs => '閲覧のみ許可するフォルダ';

  @override
  String get localBridgeSettingFileDownloadAllowAllPaths => 'すべてのファイルの共有を許可';

  @override
  String get localBridgeSettingFileDownloadAllowAllPathsDesc =>
      'プロジェクト外のファイルもダウンロードできるようになります';

  @override
  String get localBridgeSettingInsecureNoAuth => '認証を無効にする';

  @override
  String get localBridgeSettingInsecureNoAuthDesc => '非推奨。ポートに届く人は誰でも操作できます';

  @override
  String get localBridgeSettingAllowClaudeOAuth => 'Claudeのサブスクリプションログインを使う';

  @override
  String get localBridgeSettingCodexAppServerMode => 'Codex app-serverの共有';

  @override
  String get localBridgeSettingCodexSharedAppServerUrl => '共有app-serverのURL';

  @override
  String get localBridgeSettingCodexAssistModel => 'Codexアシストのモデル';

  @override
  String get localBridgeSettingCodexAssistReasoningEffort => 'Codexアシストの推論強度';

  @override
  String get localBridgeSettingNotifyGoalTurnCompleted => 'Goalの途中のターンも通知';

  @override
  String get localBridgeSettingAntigravityApiKey => 'AntigravityのAPIキー';

  @override
  String get localBridgeCodexModePrivate => '共有しない';

  @override
  String get localBridgeCodexModeManaged => 'Bridgeが起動する';

  @override
  String get localBridgeCodexModeExternal => '外部のapp-serverを使う';

  @override
  String localBridgeSettingLockedByEnv(String env) {
    return '環境変数 $env で指定されています';
  }

  @override
  String get localBridgeSettingNotSet => '未設定';

  @override
  String get localBridgeSettingConfigured => '設定済み';

  @override
  String get localBridgeSettingResetToDefault => '既定に戻す';

  @override
  String get localBridgeAllowedDirsAll => 'すべてのフォルダ（制限なし）';

  @override
  String get localBridgeAddFolder => 'フォルダを追加';

  @override
  String get localBridgePermissionsTitle => 'macOSの権限';

  @override
  String get localBridgePermissionsFooter =>
      'フルディスクアクセスと画面収録の一覧では「CC Pocket」として表示されます。変更はBridgeを再起動すると反映されます。';

  @override
  String get localBridgePermissionsDialogTitle => 'macOSの権限を確認';

  @override
  String get localBridgePermissionsDialogBody =>
      'Bridgeを起動しました。エージェントが途中で止まらないよう、足りない権限をシステム設定で有効にしてください。あとからこの画面でも変更できます。';

  @override
  String get localBridgePermissionLoginItem => 'バックグラウンドでの実行';

  @override
  String get localBridgePermissionLoginItemDesc =>
      'ログイン時にBridgeを起動し、アプリを閉じても動かし続けます';

  @override
  String get localBridgePermissionFullDisk => 'フルディスクアクセス';

  @override
  String get localBridgePermissionFullDiskDesc =>
      '書類・デスクトップ・ダウンロードや外付けディスクにあるプロジェクトを、Macでの確認ダイアログなしで扱えます';

  @override
  String get localBridgePermissionScreenCapture => '画面収録';

  @override
  String get localBridgePermissionScreenCaptureDesc =>
      'スマホからこのMacのスクリーンショットを撮る機能に使います';

  @override
  String get localBridgePermissionLocalNetwork => 'ローカルネットワーク';

  @override
  String get localBridgePermissionLocalNetworkDesc =>
      'エージェントが同じネットワークの機器（開発サーバーや実機など）に接続するときに使います';

  @override
  String get localBridgePermissionRequired => '必須';

  @override
  String get localBridgePermissionRecommended => '推奨';

  @override
  String get localBridgePermissionOptional => '任意';

  @override
  String get localBridgePermissionGranted => '許可済み';

  @override
  String get localBridgePermissionMissing => '許可されていません';

  @override
  String get localBridgePermissionUnknown => '状態はシステム設定で確認してください';

  @override
  String get localBridgePermissionOpenSettings => '設定を開く';

  @override
  String get guideLocalBridgeStepPermissions => 'macOSの権限を許可する';

  @override
  String get guideLocalBridgeStepPermissionsDetail =>
      '起動後に出る案内から、フルディスクアクセスなどをシステム設定で有効にします。Bridgeの管理画面でいつでも確認できます。';

  @override
  String get localBridgeSettingPortDesc => 'スマホなどが接続するポート番号（既定: 8765）';

  @override
  String get localBridgeSettingHostDesc =>
      '接続を受け付けるアドレス。0.0.0.0 はすべてのネットワーク、127.0.0.1 はこのMacだけ（既定: 0.0.0.0）';

  @override
  String get localBridgeSettingAllowedDirsDesc =>
      'この中にあるフォルダだけをプロジェクトとして開けます（既定: ホームフォルダ）';

  @override
  String get localBridgeSettingReadOnlyDirsDesc =>
      'プロジェクトの外でも、ファイルのプレビュー・ダウンロード・Finder表示だけを許可します';

  @override
  String get localBridgeSettingAllowClaudeOAuthDesc =>
      'APIキーではなくClaudeのサブスクリプションでClaude Codeを動かします。利用規約上のリスクを確認のうえ有効にしてください';

  @override
  String get localBridgeSettingAntigravityApiKeyDesc =>
      'Antigravityで使うGemini APIキー。未設定ならagyのGoogleログインを使います';

  @override
  String get localBridgeSettingCodexAppServerModeDesc =>
      'Codexのapp-serverをターミナルのCodexと共有するか（実験的）';

  @override
  String get localBridgeSettingCodexSharedAppServerUrlDesc =>
      '共有するapp-serverの ws:// URL。外部のapp-serverを使うときは必須です';

  @override
  String get localBridgeSettingCodexAssistModelDesc =>
      'セッション名の自動生成やコミットメッセージ作成に使うモデル';

  @override
  String get localBridgeSettingCodexAssistReasoningEffortDesc =>
      '上記の補助機能の推論強度（既定: none）';

  @override
  String get localBridgeSettingNotifyGoalTurnCompletedDesc =>
      'CodexのGoalが進行中でも、ターンが終わるたびに通知します';

  @override
  String get localBridgeChooseFolder => 'フォルダを選ぶ…';

  @override
  String get localBridgeFolderPathLabel => 'パスを入力して追加';

  @override
  String get localBridgeFoldersEmpty => 'フォルダはまだ登録されていません';

  @override
  String get localBridgeFolderSuggestionsTitle => 'よく使われるフォルダ';

  @override
  String get localBridgeFolderSuggestionAdded => '追加済み';

  @override
  String get localBridgeFolderSuggestionTmpTitle => '一時フォルダ';

  @override
  String get localBridgeFolderSuggestionTmpDesc =>
      'エージェントがスクリーンショットや生成したファイルの置き場によく使います';

  @override
  String get localBridgeFolderSuggestionAntigravityTitle => 'Antigravityの成果物';

  @override
  String get localBridgeFolderSuggestionAntigravityDesc =>
      'Antigravityが計画書や生成した画像を保存します';

  @override
  String get localBridgeUnsavedChanges => '未保存の変更があります';

  @override
  String get localBridgeDiscard => '破棄';

  @override
  String get localBridgeSaved => '保存しました';

  @override
  String get localBridgeLogsTitle => 'ログ';

  @override
  String get localBridgeLogsSubtitle => 'Bridgeの最近の出力';

  @override
  String get localBridgeLogsEmpty => 'ログはありません';

  @override
  String get localBridgeConnectHere => 'このアプリから接続';

  @override
  String get localBridgeStart => 'Bridgeを起動';

  @override
  String get localBridgeStop => '停止';

  @override
  String get localBridgeStarting => '起動中…（初回は1分ほどかかることがあります）';

  @override
  String get localBridgeStopping => '停止中…';

  @override
  String get localBridgeStartBody => 'ボタンを押すと、このMacでBridgeが起動します。';

  @override
  String get localBridgeManagedNote => 'アプリを閉じてもBridgeは動き続け、ログイン時に自動で起動します。';

  @override
  String get localBridgeManualStartHint => 'ターミナルから起動することもできます。';

  @override
  String get localBridgeStopConfirmTitle => 'Bridgeを停止しますか？';

  @override
  String get localBridgeStopConfirmBody => '接続中の端末は切断され、ログイン時の自動起動も解除されます。';

  @override
  String get localBridgeRequiresApproval =>
      'システム設定の「一般 > ログイン項目と機能拡張」で「CC Pocket Bridge」を許可してください。';

  @override
  String get localBridgeNodeMissing => 'Node.js が見つかりません。インストールすると自動で起動します。';

  @override
  String localBridgeNodeTooOld(String version) {
    return 'Node.js $version は古すぎます。22.19 以上に更新すると自動で起動します。';
  }

  @override
  String localBridgePortInUse(int port) {
    return 'ポート $port は別のプログラムが使用中です。';
  }

  @override
  String get localBridgeStartFailed => 'Bridgeの起動を確認できませんでした';

  @override
  String get localBridgeSafeMode =>
      '保存された設定では起動できなかったため、既定の設定で動いています。設定を見直して再起動してください。';

  @override
  String get guideLocalBridgeTitle => 'このMacで\nBridgeを動かす';

  @override
  String get guideLocalBridgeDescription =>
      'Bridgeは、スマホとこのMacのエージェントをつなぐ小さなサーバーです。macOS版ではアプリから起動・管理できます。';

  @override
  String get guideLocalBridgeStep1 => '「Bridgeを起動」を押す';

  @override
  String get guideLocalBridgeStep1Detail => 'アプリを閉じても動き続け、ログイン時に自動で起動します。';

  @override
  String get guideLocalBridgeStep2 => '必要なツールを確認する';

  @override
  String get guideLocalBridgeStep2Detail =>
      'Node.js、Git、Codex・Claude Code・Antigravity などの導入状況と、インストール用コマンドを確認できます。';

  @override
  String get guideLocalBridgeStep3 => 'この Mac で接続・スマホで QR スキャン';

  @override
  String get guideLocalBridgeStep3Detail =>
      '「このアプリから接続」ですぐ使い始められます。スマホからも使う場合は、同じ画面の QR コードを読み取ります。';

  @override
  String get guideLocalBridgeOpen => 'Bridgeの管理を開く';

  @override
  String get guideBridgeMacAppNote =>
      'Macをお使いなら、macOS版CC Pocketを入れるとアプリからBridgeを起動でき、下のコマンドは不要です。';

  @override
  String bridgeAuthRequiredLocalBody(String host) {
    return '$host の Bridge が API キーを必要としています。このMacのBridgeの管理画面から、このアプリを接続できます。';
  }

  @override
  String get localBridgeUnregister => '自動起動を解除';

  @override
  String guideStepProgress(int current, int total) {
    return 'STEP $current / $total';
  }

  @override
  String get guideCopyLink => 'リンクをコピー';

  @override
  String get guideSendToMac => 'Mac に送る';

  @override
  String get guideSendToPc => 'PC に送る';

  @override
  String get guideOpenWebsite => 'ページを開く';

  @override
  String guideShareMacDownloadMessage(String url) {
    return 'CC Pocket for macOS: $url';
  }

  @override
  String guideShareBridgeCommandMessage(String command) {
    return 'CC Pocket Bridge:\n$command';
  }

  @override
  String get guideAboutDesktopTitle => 'CC Pocket へようこそ';

  @override
  String get guideAboutMacDescription =>
      'この Mac の Codex・Claude・Antigravity を快適に操作でき、同じセッションをスマホからもそのまま続けられます。';

  @override
  String get guideAboutDesktopDescription =>
      '自分のマシンで動く Codex・Claude・Antigravity を、このアプリやスマホから操作できます。';

  @override
  String get guideAboutDiagramDesktop => 'Mac / スマホ';

  @override
  String get guideAboutHighlightLocal => 'コードも認証情報も自分のマシン内で完結';

  @override
  String get guideAboutHighlightMac => 'Mac なら専用アプリを入れるだけ（コマンド不要）';

  @override
  String get guideAboutHighlightMacLocal => 'この Mac アプリから Bridge の起動・管理まで完結';

  @override
  String get guideAboutHighlightHandoff => 'CLI・Mac・スマホ間でセッションをそのまま継続';

  @override
  String get guideHostSetupTitle => 'Mac / PC を準備する';

  @override
  String get guideHostSetupDescription =>
      'お使いの環境を選んでください。Mac をお使いなら macOS 版アプリが一番かんたんです。';

  @override
  String get guideHostTabMac => 'Mac（おすすめ）';

  @override
  String get guideHostTabCli => 'Linux / Windows / CLI';

  @override
  String get guideMacRecommendTitle => 'macOS 版 CC Pocket';

  @override
  String get guideMacRecommendSubtitle =>
      'ターミナル操作や常時起動の設定は不要。Mac にアプリを入れるだけで Bridge が動きます。';

  @override
  String get guideMacBenefit1 => 'ボタン 1 つで Bridge 起動・ログイン時自動起動';

  @override
  String get guideMacBenefit2 => 'Node.js や各エージェントの導入状況を自動チェック';

  @override
  String get guideMacBenefit3 => 'アプリ内の QR コードをスマホで読むだけで接続';

  @override
  String get guideMacInstallMethodDownload => 'ダウンロードページ（.dmg）';

  @override
  String get guideMacInstallMethodHomebrew => 'Homebrew でインストール';

  @override
  String get guideMacAppleSiliconNote =>
      'Apple Silicon Mac（macOS 13 以降）対応。Intel Mac やコマンド派の方は「Linux / Windows / CLI」タブをご利用ください。';

  @override
  String get guideMacAfterInstallTitle => 'Mac に入れたら 3 ステップ';

  @override
  String get guideMacAfterInstallStep1 =>
      'Mac で CC Pocket を開き「この Mac の Bridge」を押す';

  @override
  String get guideMacAfterInstallStep2 => '「Bridge を起動」を押し、不足ツールがあれば案内どおりに入れる';

  @override
  String get guideMacAfterInstallStep3 => '表示された QR コードをこのスマホでスキャン';

  @override
  String get guideCliPrerequisitesNote =>
      'Node.js 22.19 以上と、使いたいエージェント CLI（Codex / Claude / Antigravity のいずれか 1 つ以上）が必要です。';

  @override
  String get guideCliRunTitle => 'ターミナルで Bridge を起動';

  @override
  String get guideCliAutostartToggle => '常時起動（自動起動）を設定したい場合';

  @override
  String get guideCliAuthToggle => '各エージェントの認証について';

  @override
  String get guideCliAuthCodex => 'Codex: 事前に codex でログイン（または OPENAI_API_KEY）';

  @override
  String get guideCliAuthClaude =>
      'Claude: ANTHROPIC_API_KEY を設定（サブスク利用は BRIDGE_ALLOW_CLAUDE_OAUTH=1）';

  @override
  String get guideCliAuthAntigravity =>
      'Antigravity: 事前に agy でログイン（または Gemini API キー）';

  @override
  String get guideTailscaleSectionTitle => '外出先から使いたい場合（Tailscale）';

  @override
  String get guideReadyScanQr => 'QR コードをスキャンして接続';

  @override
  String get guideReadyLater => 'あとで接続してホームへ';

  @override
  String get guideReadyDesktopTitle => 'スマホでも続けよう';

  @override
  String get guideReadyDesktopDescription =>
      '準備完了です！モバイル版 CC Pocket を入れてペアリングすれば、外出先からも同じセッションを操作できます。';

  @override
  String get guideMobileAppCardTitle => 'モバイル版 CC Pocket（iOS / Android）';

  @override
  String get guideMobileAppCardBody =>
      'インストールページを開くと App Store / Google Play へ移動します。';

  @override
  String get guideDesktopLocalConnectTip =>
      'この PC の Bridge に接続するときは ws://127.0.0.1:8765 と起動時に表示される API キーを使います。';

  @override
  String get settingsCategoryLocalBridge => 'このMacのBridge';

  @override
  String get settingsCategoryShortcuts => 'キーボードショートカット';

  @override
  String get settingsCategoryShortcutsSummary => 'ナビゲーション・セッション・表示のショートカット';

  @override
  String get settingsConnectedBridgeSectionTitle => '接続中のBridge';

  @override
  String get settingsConnectedToThisMacBadge => 'このMacのローカルBridgeに接続中';

  @override
  String get settingsOpenLocalBridgeAction => 'このMacのBridge設定を開く';

  @override
  String get settingsEditBridgeMachine => '接続設定を編集';

  @override
  String get settingsReconnectBridge => '再接続';

  @override
  String get settingsCopyBridgeUrl => 'URLをコピー';

  @override
  String get settingsSwitchBridge => 'Bridgeを切り替え';

  @override
  String get settingsBridgeDiagnosticsTitle => '接続中のBridge情報';

  @override
  String get settingsBridgeEndpointLabel => 'エンドポイント';

  @override
  String get settingsBridgeTransportLabel => '通信方式';

  @override
  String get settingsBridgeTransportSecure => 'WSS（暗号化）';

  @override
  String get settingsBridgeTransportStandard => 'WS（標準）';

  @override
  String get settingsBridgeTransportSshTunnel => 'SSHトンネル';

  @override
  String get settingsBridgeProtocolLabel => 'プロトコル';

  @override
  String get settingsBridgeAllowedDirsLabel => '許可されたディレクトリ';

  @override
  String get settingsBridgeAllowedDirsAll => '制限なし (*)';

  @override
  String get settingsConnectedBridgeToolsTitle => '接続先ホストのツール';

  @override
  String get settingsConnectedBridgeToolsError => '接続先ホストのツール状態を取得できませんでした';

  @override
  String get settingsCheckForUpdates => 'アップデートを確認…';

  @override
  String get settingsCheckingForUpdates => 'アップデートを確認中…';

  @override
  String get settingsUpToDate => '最新バージョンです';

  @override
  String get settingsUpdateCheckFailed => 'アップデートの確認に失敗しました';

  @override
  String get shortcutsDialogTitle => 'キーボードショートカット';

  @override
  String get shortcutsGroupApplication => 'アプリケーション';

  @override
  String get shortcutsGroupNavigation => 'ナビゲーション';

  @override
  String get shortcutsGroupSession => 'セッション';

  @override
  String get shortcutsGroupViewPanes => '表示とペイン';

  @override
  String get shortcutsGroupComposer => '入力欄と編集';

  @override
  String get shortcutOpenSettings => '設定を開く';

  @override
  String get shortcutOpenLocalBridge => 'このMacのBridge設定';

  @override
  String get shortcutShowShortcuts => 'キーボードショートカット一覧';

  @override
  String get shortcutNewSession => '新しいセッション';

  @override
  String get shortcutQuickSearch => 'クイック検索 / セッション切り替え';

  @override
  String get shortcutSwitchSessionNumber => '1〜9番目のセッションに切り替え';

  @override
  String get shortcutCloseActive => '現在の画面・セッション・ウィンドウを閉じる';

  @override
  String get shortcutRefresh => 'セッション一覧・履歴を更新';

  @override
  String get shortcutApproveTool => '保留中のツール実行を承認';

  @override
  String get shortcutPermissionMode => '権限モードメニューを開く';

  @override
  String get shortcutStopGeneration => '生成を中断 / 停止';

  @override
  String get shortcutToggleSidebar => 'サイドバーの表示切替';

  @override
  String get shortcutToggleGitPane => 'Git差分ペインの開閉';

  @override
  String get shortcutToggleExplorerPane => 'ファイルエクスプローラーの開閉';

  @override
  String get shortcutToggleGalleryPane => 'ギャラリーペインの開閉';

  @override
  String get shortcutZoomIn => '文字サイズを拡大';

  @override
  String get shortcutZoomOut => '文字サイズを縮小';

  @override
  String get shortcutZoomReset => '文字サイズをリセット';

  @override
  String get shortcutSendMessage => 'メッセージを送信';

  @override
  String get shortcutInsertNewline => '改行を挿入';

  @override
  String get shortcutFindInBrowser => 'ファイル内で検索';

  @override
  String get shortcutDismissOverlay => 'ポップアップやシートを閉じる';

  @override
  String get menuFile => 'ファイル';

  @override
  String get menuView => '表示';

  @override
  String get menuSession => 'セッション';

  @override
  String get menuNewSession => '新しいセッション';

  @override
  String get menuCloseWindow => 'ウィンドウを閉じる';

  @override
  String get menuCloseSession => 'セッションを閉じる';

  @override
  String get menuCloseSettings => '設定を閉じる';

  @override
  String get menuReconnect => '再接続 / 更新';

  @override
  String get menuDisconnect => '切断';

  @override
  String get menuToggleSidebar => 'サイドバーを切り替え';

  @override
  String get menuQuickSearch => 'クイック検索';

  @override
  String get menuGitDiff => 'Git差分';

  @override
  String get menuFileExplorer => 'ファイルエクスプローラー';

  @override
  String get menuGallery => 'ギャラリー';

  @override
  String get menuActualSize => '実際のサイズ';

  @override
  String get menuZoomIn => '拡大';

  @override
  String get menuZoomOut => '縮小';

  @override
  String get menuStopGeneration => '生成を停止';

  @override
  String get menuPermissionMode => '権限モード…';

  @override
  String get menuLocalBridgeSettings => 'このMacのBridge…';

  @override
  String get menuCheckForUpdates => 'アップデートを確認…';

  @override
  String get menuKeyboardShortcuts => 'キーボードショートカット';

  @override
  String get menuSetupGuide => 'セットアップガイド';

  @override
  String get menuChangelog => '変更履歴';

  @override
  String get menuGitHubRepo => 'GitHubリポジトリ';

  @override
  String get plainText => 'プレーンテキスト';

  @override
  String get resizeSidebar => 'サイドバーの幅を変更';

  @override
  String get resizeRightPane => '右ペインの幅を変更';

  @override
  String get displayPresetAll => 'すべて';

  @override
  String get displayPresetRecommended => 'おすすめ';

  @override
  String get displayPresetCustom => 'カスタム';

  @override
  String displayPresetCustomSummary(int enabled, int total) {
    return 'カスタム ($enabled/$total)';
  }

  @override
  String get displayPresetAllDescription => 'すべてのツール操作・差分・実行結果を表示します。';

  @override
  String get displayPresetRecommendedDescription =>
      'Tasks・Thinking・サブエージェントは残しつつ、Bridgeから送るツールログや途中の画像を削減します。';

  @override
  String get displayPresetCustomDescription => '表示・受信する項目を個別に設定しています。';

  @override
  String get displayItemsSectionTitle => '表示する項目';

  @override
  String get displayItemsAlwaysVisibleNote =>
      'メッセージ本文・プラン・承認・質問・生成画像・エラーは常に表示されます。';

  @override
  String get displayItemTasks => 'Tasks / TODO';

  @override
  String get displayItemTasksSubtitle => 'タスク一覧・進捗チェックリスト';

  @override
  String get displayItemThinking => 'Thinking（思考）';

  @override
  String get displayItemThinkingSubtitle => '思考プロセスとストリーミング表示';

  @override
  String get displayItemSubagents => 'サブエージェント / Swarm';

  @override
  String get displayItemSubagentsSubtitle => 'サブエージェント起動・要約・Swarm会話';

  @override
  String get displayItemCodeEdits => 'コード編集・差分';

  @override
  String get displayItemCodeEditsSubtitle => 'ファイルの作成・編集と差分カード';

  @override
  String get displayItemOtherTools => 'その他のツール操作';

  @override
  String get displayItemOtherToolsSubtitle => 'コマンド実行・ファイル閲覧・検索・MCPなど';

  @override
  String get displayItemToolResults => 'ツール結果・付随画像';

  @override
  String get displayItemToolResultsSubtitle => 'ツールの出力本文やスクショ等の画像';

  @override
  String get stopSessionConfirmActive => 'このセッションは現在稼働中です。停止してもよろしいですか？';

  @override
  String get stopSessionConfirmBackground =>
      'このセッションには実行中のバックグラウンドタスクが残っています。停止してもよろしいですか？';

  @override
  String get stopSessionConfirmActiveAndBackground =>
      'このセッションは稼働中で、実行中のバックグラウンドタスクも残っています。停止してもよろしいですか？';

  @override
  String get settingsCategoryGallerySummary => '保存された画像とスクリーンショット';
}
