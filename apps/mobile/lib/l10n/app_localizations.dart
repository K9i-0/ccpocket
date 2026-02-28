import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ja'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'CC Pocket'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In ja, this message translates to:
  /// **'名前を変更'**
  String get rename;

  /// No description provided for @renameSession.
  ///
  /// In ja, this message translates to:
  /// **'セッション名を変更'**
  String get renameSession;

  /// No description provided for @sessionNameHint.
  ///
  /// In ja, this message translates to:
  /// **'セッション名'**
  String get sessionNameHint;

  /// No description provided for @clearName.
  ///
  /// In ja, this message translates to:
  /// **'名前をクリア'**
  String get clearName;

  /// No description provided for @connect.
  ///
  /// In ja, this message translates to:
  /// **'接続'**
  String get connect;

  /// No description provided for @copy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In ja, this message translates to:
  /// **'コピーしました'**
  String get copied;

  /// No description provided for @copiedToClipboard.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードにコピーしました'**
  String get copiedToClipboard;

  /// No description provided for @lineCopied.
  ///
  /// In ja, this message translates to:
  /// **'行をコピーしました'**
  String get lineCopied;

  /// No description provided for @start.
  ///
  /// In ja, this message translates to:
  /// **'開始'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get stop;

  /// No description provided for @send.
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get send;

  /// No description provided for @settings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settings;

  /// No description provided for @gallery.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリー'**
  String get gallery;

  /// No description provided for @galleryWithCount.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリー ({count})'**
  String galleryWithCount(int count);

  /// No description provided for @disconnect.
  ///
  /// In ja, this message translates to:
  /// **'切断'**
  String get disconnect;

  /// No description provided for @back.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get back;

  /// No description provided for @next.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get next;

  /// No description provided for @done.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get skip;

  /// No description provided for @edit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get share;

  /// No description provided for @all.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get all;

  /// No description provided for @none.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get none;

  /// No description provided for @serverUnreachable.
  ///
  /// In ja, this message translates to:
  /// **'サーバーに接続できません'**
  String get serverUnreachable;

  /// No description provided for @serverUnreachableBody.
  ///
  /// In ja, this message translates to:
  /// **'Bridge サーバーに到達できません:'**
  String get serverUnreachableBody;

  /// No description provided for @setupSteps.
  ///
  /// In ja, this message translates to:
  /// **'セットアップ手順:'**
  String get setupSteps;

  /// No description provided for @setupStep1Title.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server を起動'**
  String get setupStep1Title;

  /// No description provided for @setupStep1Command.
  ///
  /// In ja, this message translates to:
  /// **'npx @ccpocket/bridge@latest'**
  String get setupStep1Command;

  /// No description provided for @setupStep2Title.
  ///
  /// In ja, this message translates to:
  /// **'常時起動したい場合はサービス登録'**
  String get setupStep2Title;

  /// No description provided for @setupStep2Command.
  ///
  /// In ja, this message translates to:
  /// **'npx @ccpocket/bridge@latest setup'**
  String get setupStep2Command;

  /// No description provided for @setupNetworkHint.
  ///
  /// In ja, this message translates to:
  /// **'両方のデバイスが同じネットワーク上にあることを確認してください（または Tailscale を使用）。'**
  String get setupNetworkHint;

  /// No description provided for @connectAnyway.
  ///
  /// In ja, this message translates to:
  /// **'接続を続行'**
  String get connectAnyway;

  /// No description provided for @stopSession.
  ///
  /// In ja, this message translates to:
  /// **'セッションを停止'**
  String get stopSession;

  /// No description provided for @stopSessionConfirm.
  ///
  /// In ja, this message translates to:
  /// **'このセッションを停止しますか？ Claude プロセスが終了します。'**
  String get stopSessionConfirm;

  /// No description provided for @startNewWithSameSettings.
  ///
  /// In ja, this message translates to:
  /// **'同じ設定で新規開始'**
  String get startNewWithSameSettings;

  /// No description provided for @editSettingsThenStart.
  ///
  /// In ja, this message translates to:
  /// **'設定を変更して開始'**
  String get editSettingsThenStart;

  /// No description provided for @serverRequiresApiKey.
  ///
  /// In ja, this message translates to:
  /// **'このサーバーには API キーが必要です'**
  String get serverRequiresApiKey;

  /// No description provided for @bridgeServerUpdated.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server を更新しました'**
  String get bridgeServerUpdated;

  /// No description provided for @failedToUpdateServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバーの更新に失敗しました'**
  String get failedToUpdateServer;

  /// No description provided for @bridgeServerStarted.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server を起動しました'**
  String get bridgeServerStarted;

  /// No description provided for @failedToStartServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバーの起動に失敗しました'**
  String get failedToStartServer;

  /// No description provided for @bridgeServerStopped.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server を停止しました'**
  String get bridgeServerStopped;

  /// No description provided for @failedToStopServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバーの停止に失敗しました'**
  String get failedToStopServer;

  /// No description provided for @sshPassword.
  ///
  /// In ja, this message translates to:
  /// **'SSH パスワード'**
  String get sshPassword;

  /// No description provided for @sshPasswordPrompt.
  ///
  /// In ja, this message translates to:
  /// **'{machineName} の SSH パスワードを入力'**
  String sshPasswordPrompt(String machineName);

  /// No description provided for @password.
  ///
  /// In ja, this message translates to:
  /// **'パスワード'**
  String get password;

  /// No description provided for @deleteMachine.
  ///
  /// In ja, this message translates to:
  /// **'マシンを削除'**
  String get deleteMachine;

  /// No description provided for @deleteMachineConfirm.
  ///
  /// In ja, this message translates to:
  /// **'\"{displayName}\" を削除しますか？保存された認証情報もすべて削除されます。'**
  String deleteMachineConfirm(String displayName);

  /// No description provided for @connectToBridgeServer.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server に接続'**
  String get connectToBridgeServer;

  /// No description provided for @orConnectManually.
  ///
  /// In ja, this message translates to:
  /// **'または手動で接続'**
  String get orConnectManually;

  /// No description provided for @serverUrl.
  ///
  /// In ja, this message translates to:
  /// **'サーバー URL'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In ja, this message translates to:
  /// **'ws://<host-ip>:8765'**
  String get serverUrlHint;

  /// No description provided for @apiKeyOptional.
  ///
  /// In ja, this message translates to:
  /// **'API キー（任意）'**
  String get apiKeyOptional;

  /// No description provided for @apiKeyHint.
  ///
  /// In ja, this message translates to:
  /// **'認証なしの場合は空欄'**
  String get apiKeyHint;

  /// No description provided for @scanQrCode.
  ///
  /// In ja, this message translates to:
  /// **'QR コードをスキャン'**
  String get scanQrCode;

  /// No description provided for @setupGuide.
  ///
  /// In ja, this message translates to:
  /// **'セットアップガイド'**
  String get setupGuide;

  /// No description provided for @readyToStart.
  ///
  /// In ja, this message translates to:
  /// **'準備完了'**
  String get readyToStart;

  /// No description provided for @readyToStartDescription.
  ///
  /// In ja, this message translates to:
  /// **'+ ボタンを押してセッションを作成し、Claude でコーディングを始めましょう。'**
  String get readyToStartDescription;

  /// No description provided for @newSession.
  ///
  /// In ja, this message translates to:
  /// **'新規セッション'**
  String get newSession;

  /// No description provided for @neverConnected.
  ///
  /// In ja, this message translates to:
  /// **'未接続'**
  String get neverConnected;

  /// No description provided for @justNow.
  ///
  /// In ja, this message translates to:
  /// **'たった今'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In ja, this message translates to:
  /// **'{minutes}分前'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In ja, this message translates to:
  /// **'{hours}時間前'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In ja, this message translates to:
  /// **'{days}日前'**
  String daysAgo(int days);

  /// No description provided for @unfavorite.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り解除'**
  String get unfavorite;

  /// No description provided for @favorite.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get favorite;

  /// No description provided for @updateBridge.
  ///
  /// In ja, this message translates to:
  /// **'Bridge を更新'**
  String get updateBridge;

  /// No description provided for @stopServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバーを停止'**
  String get stopServer;

  /// No description provided for @update.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get update;

  /// No description provided for @offline.
  ///
  /// In ja, this message translates to:
  /// **'オフライン'**
  String get offline;

  /// No description provided for @unreachable.
  ///
  /// In ja, this message translates to:
  /// **'接続不可'**
  String get unreachable;

  /// No description provided for @checking.
  ///
  /// In ja, this message translates to:
  /// **'確認中...'**
  String get checking;

  /// No description provided for @recentProjects.
  ///
  /// In ja, this message translates to:
  /// **'最近のプロジェクト'**
  String get recentProjects;

  /// No description provided for @orEnterPath.
  ///
  /// In ja, this message translates to:
  /// **'またはパスを入力'**
  String get orEnterPath;

  /// No description provided for @projectPath.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトパス'**
  String get projectPath;

  /// No description provided for @projectPathHint.
  ///
  /// In ja, this message translates to:
  /// **'/path/to/your/project'**
  String get projectPathHint;

  /// No description provided for @permission.
  ///
  /// In ja, this message translates to:
  /// **'パーミッション'**
  String get permission;

  /// No description provided for @approval.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get approval;

  /// No description provided for @worktree.
  ///
  /// In ja, this message translates to:
  /// **'Worktree'**
  String get worktree;

  /// No description provided for @advanced.
  ///
  /// In ja, this message translates to:
  /// **'詳細設定'**
  String get advanced;

  /// No description provided for @modelOptional.
  ///
  /// In ja, this message translates to:
  /// **'モデル（任意）'**
  String get modelOptional;

  /// No description provided for @effort.
  ///
  /// In ja, this message translates to:
  /// **'Effort'**
  String get effort;

  /// No description provided for @defaultLabel.
  ///
  /// In ja, this message translates to:
  /// **'デフォルト'**
  String get defaultLabel;

  /// No description provided for @maxTurns.
  ///
  /// In ja, this message translates to:
  /// **'Max Turns'**
  String get maxTurns;

  /// No description provided for @maxTurnsHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 8'**
  String get maxTurnsHint;

  /// No description provided for @maxTurnsError.
  ///
  /// In ja, this message translates to:
  /// **'1以上の整数を入力してください'**
  String get maxTurnsError;

  /// No description provided for @maxBudgetUsd.
  ///
  /// In ja, this message translates to:
  /// **'最大予算 (USD)'**
  String get maxBudgetUsd;

  /// No description provided for @maxBudgetHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 1.00'**
  String get maxBudgetHint;

  /// No description provided for @maxBudgetError.
  ///
  /// In ja, this message translates to:
  /// **'0以上の数値を入力してください'**
  String get maxBudgetError;

  /// No description provided for @fallbackModel.
  ///
  /// In ja, this message translates to:
  /// **'フォールバックモデル'**
  String get fallbackModel;

  /// No description provided for @forkSessionOnResume.
  ///
  /// In ja, this message translates to:
  /// **'再開時にセッションを分岐'**
  String get forkSessionOnResume;

  /// No description provided for @persistSessionHistory.
  ///
  /// In ja, this message translates to:
  /// **'セッション履歴を保持'**
  String get persistSessionHistory;

  /// No description provided for @model.
  ///
  /// In ja, this message translates to:
  /// **'モデル'**
  String get model;

  /// No description provided for @sandbox.
  ///
  /// In ja, this message translates to:
  /// **'Sandbox'**
  String get sandbox;

  /// No description provided for @reasoning.
  ///
  /// In ja, this message translates to:
  /// **'Reasoning'**
  String get reasoning;

  /// No description provided for @webSearch.
  ///
  /// In ja, this message translates to:
  /// **'Web Search'**
  String get webSearch;

  /// No description provided for @networkAccess.
  ///
  /// In ja, this message translates to:
  /// **'ネットワークアクセス'**
  String get networkAccess;

  /// No description provided for @worktreeNew.
  ///
  /// In ja, this message translates to:
  /// **'新規'**
  String get worktreeNew;

  /// No description provided for @worktreeExisting.
  ///
  /// In ja, this message translates to:
  /// **'既存 ({count})'**
  String worktreeExisting(int count);

  /// No description provided for @branchOptional.
  ///
  /// In ja, this message translates to:
  /// **'ブランチ（任意）'**
  String get branchOptional;

  /// No description provided for @branchHint.
  ///
  /// In ja, this message translates to:
  /// **'ccpocket/<auto>'**
  String get branchHint;

  /// No description provided for @noExistingWorktrees.
  ///
  /// In ja, this message translates to:
  /// **'既存の worktree はありません'**
  String get noExistingWorktrees;

  /// No description provided for @planApprovalSummary.
  ///
  /// In ja, this message translates to:
  /// **'上のプランを確認して、承認するか計画を続けてください'**
  String get planApprovalSummary;

  /// No description provided for @planApprovalSummaryCard.
  ///
  /// In ja, this message translates to:
  /// **'プランを確認して、承認するか計画を続けてください'**
  String get planApprovalSummaryCard;

  /// No description provided for @toolApprovalSummary.
  ///
  /// In ja, this message translates to:
  /// **'ツール実行には承認が必要です'**
  String get toolApprovalSummary;

  /// No description provided for @planApproval.
  ///
  /// In ja, this message translates to:
  /// **'プラン承認'**
  String get planApproval;

  /// No description provided for @approvalRequired.
  ///
  /// In ja, this message translates to:
  /// **'承認が必要'**
  String get approvalRequired;

  /// No description provided for @viewEditPlan.
  ///
  /// In ja, this message translates to:
  /// **'プランを表示 / 編集'**
  String get viewEditPlan;

  /// No description provided for @keepPlanning.
  ///
  /// In ja, this message translates to:
  /// **'計画を続ける'**
  String get keepPlanning;

  /// No description provided for @keepPlanningHint.
  ///
  /// In ja, this message translates to:
  /// **'変更点を入力...'**
  String get keepPlanningHint;

  /// No description provided for @sendFeedbackKeepPlanning.
  ///
  /// In ja, this message translates to:
  /// **'フィードバックを送信して計画を続ける'**
  String get sendFeedbackKeepPlanning;

  /// No description provided for @acceptAndClear.
  ///
  /// In ja, this message translates to:
  /// **'承認 & クリア'**
  String get acceptAndClear;

  /// No description provided for @acceptPlan.
  ///
  /// In ja, this message translates to:
  /// **'プラン承認'**
  String get acceptPlan;

  /// No description provided for @reject.
  ///
  /// In ja, this message translates to:
  /// **'拒否'**
  String get reject;

  /// No description provided for @approve.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get approve;

  /// No description provided for @always.
  ///
  /// In ja, this message translates to:
  /// **'常に許可'**
  String get always;

  /// No description provided for @messagePlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'Claude にメッセージ...'**
  String get messagePlaceholder;

  /// No description provided for @filesMentioned.
  ///
  /// In ja, this message translates to:
  /// **'{count} ファイルを @メンション中'**
  String filesMentioned(int count);

  /// No description provided for @diffLines.
  ///
  /// In ja, this message translates to:
  /// **'{count} 行の diff'**
  String diffLines(int count);

  /// No description provided for @tapInterruptHoldStop.
  ///
  /// In ja, this message translates to:
  /// **'タップ: 中断, 長押し: 停止'**
  String get tapInterruptHoldStop;

  /// No description provided for @rewindToHere.
  ///
  /// In ja, this message translates to:
  /// **'ここまで巻き戻す'**
  String get rewindToHere;

  /// No description provided for @tapToRetry.
  ///
  /// In ja, this message translates to:
  /// **'タップしてリトライ'**
  String get tapToRetry;

  /// No description provided for @diffSummaryAddedRemoved.
  ///
  /// In ja, this message translates to:
  /// **'+{added}/-{removed} 行'**
  String diffSummaryAddedRemoved(int added, int removed);

  /// No description provided for @lineCountSummary.
  ///
  /// In ja, this message translates to:
  /// **'{count} 行'**
  String lineCountSummary(int count);

  /// No description provided for @toolResult.
  ///
  /// In ja, this message translates to:
  /// **'ツール結果'**
  String get toolResult;

  /// No description provided for @answered.
  ///
  /// In ja, this message translates to:
  /// **'回答済み'**
  String get answered;

  /// No description provided for @claudeIsAsking.
  ///
  /// In ja, this message translates to:
  /// **'Claude が質問しています'**
  String get claudeIsAsking;

  /// No description provided for @submitAllAnswers.
  ///
  /// In ja, this message translates to:
  /// **'すべての回答を送信'**
  String get submitAllAnswers;

  /// No description provided for @submitWithCount.
  ///
  /// In ja, this message translates to:
  /// **'送信 ({count} 件選択)'**
  String submitWithCount(int count);

  /// No description provided for @selectOptionsToSubmit.
  ///
  /// In ja, this message translates to:
  /// **'オプションを選択してください'**
  String get selectOptionsToSubmit;

  /// No description provided for @typeYourAnswer.
  ///
  /// In ja, this message translates to:
  /// **'回答を入力...'**
  String get typeYourAnswer;

  /// No description provided for @orTypeCustomAnswer.
  ///
  /// In ja, this message translates to:
  /// **'またはカスタム回答を入力...'**
  String get orTypeCustomAnswer;

  /// No description provided for @otherAnswer.
  ///
  /// In ja, this message translates to:
  /// **'その他の回答...'**
  String get otherAnswer;

  /// No description provided for @selectAllThatApply.
  ///
  /// In ja, this message translates to:
  /// **'該当するものをすべて選択'**
  String get selectAllThatApply;

  /// No description provided for @noScreenshotsYet.
  ///
  /// In ja, this message translates to:
  /// **'スクリーンショットはまだありません'**
  String get noScreenshotsYet;

  /// No description provided for @screenshotButtonHint.
  ///
  /// In ja, this message translates to:
  /// **'チャットツールバーのスクリーンショットボタンで画面をキャプチャできます。'**
  String get screenshotButtonHint;

  /// No description provided for @screenshotsWillAppearHere.
  ///
  /// In ja, this message translates to:
  /// **'Claude セッションのスクリーンショットがここに表示されます。'**
  String get screenshotsWillAppearHere;

  /// No description provided for @allWithCount.
  ///
  /// In ja, this message translates to:
  /// **'すべて ({count})'**
  String allWithCount(int count);

  /// No description provided for @noImages.
  ///
  /// In ja, this message translates to:
  /// **'画像がありません'**
  String get noImages;

  /// No description provided for @failedToDeleteImage.
  ///
  /// In ja, this message translates to:
  /// **'画像の削除に失敗しました'**
  String get failedToDeleteImage;

  /// No description provided for @failedToDownloadImage.
  ///
  /// In ja, this message translates to:
  /// **'画像のダウンロードに失敗しました'**
  String get failedToDownloadImage;

  /// No description provided for @failedToShareImage.
  ///
  /// In ja, this message translates to:
  /// **'画像の共有に失敗しました'**
  String get failedToShareImage;

  /// No description provided for @deleteScreenshot.
  ///
  /// In ja, this message translates to:
  /// **'スクリーンショットを削除しますか？'**
  String get deleteScreenshot;

  /// No description provided for @cannotBeUndone.
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get cannotBeUndone;

  /// No description provided for @changes.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get changes;

  /// No description provided for @cancelSelection.
  ///
  /// In ja, this message translates to:
  /// **'選択をキャンセル'**
  String get cancelSelection;

  /// No description provided for @selectAndAttach.
  ///
  /// In ja, this message translates to:
  /// **'選択して添付'**
  String get selectAndAttach;

  /// No description provided for @refresh.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get refresh;

  /// No description provided for @filterFiles.
  ///
  /// In ja, this message translates to:
  /// **'ファイルをフィルター'**
  String get filterFiles;

  /// No description provided for @attachFilesAndHunks.
  ///
  /// In ja, this message translates to:
  /// **'添付 {files} ファイル, {hunks} ハンク'**
  String attachFilesAndHunks(int files, int hunks);

  /// No description provided for @filterFilesTitle.
  ///
  /// In ja, this message translates to:
  /// **'ファイルをフィルター'**
  String get filterFilesTitle;

  /// No description provided for @noChanges.
  ///
  /// In ja, this message translates to:
  /// **'変更なし'**
  String get noChanges;

  /// No description provided for @allFilesFilteredOut.
  ///
  /// In ja, this message translates to:
  /// **'すべてのファイルがフィルターされています'**
  String get allFilesFilteredOut;

  /// No description provided for @showAll.
  ///
  /// In ja, this message translates to:
  /// **'すべて表示'**
  String get showAll;

  /// No description provided for @setupGuideTitle.
  ///
  /// In ja, this message translates to:
  /// **'セットアップガイド'**
  String get setupGuideTitle;

  /// No description provided for @guideAboutTitle.
  ///
  /// In ja, this message translates to:
  /// **'CC Pocket とは'**
  String get guideAboutTitle;

  /// No description provided for @guideAboutDescription.
  ///
  /// In ja, this message translates to:
  /// **'スマートフォンから Claude Code や Codex を操作できるモバイルクライアントです。'**
  String get guideAboutDescription;

  /// No description provided for @guideAboutDiagramTitle.
  ///
  /// In ja, this message translates to:
  /// **'しくみ'**
  String get guideAboutDiagramTitle;

  /// No description provided for @guideAboutDiagramPhone.
  ///
  /// In ja, this message translates to:
  /// **'iPhone'**
  String get guideAboutDiagramPhone;

  /// No description provided for @guideAboutDiagramBridge.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server'**
  String get guideAboutDiagramBridge;

  /// No description provided for @guideAboutDiagramClaude.
  ///
  /// In ja, this message translates to:
  /// **'Claude CLI\n/ Codex'**
  String get guideAboutDiagramClaude;

  /// No description provided for @guideAboutDiagramCaption.
  ///
  /// In ja, this message translates to:
  /// **'PC で Bridge Server を起動し、\nスマホから接続して使います。'**
  String get guideAboutDiagramCaption;

  /// No description provided for @guideBridgeTitle.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server の\nセットアップ'**
  String get guideBridgeTitle;

  /// No description provided for @guideBridgeDescription.
  ///
  /// In ja, this message translates to:
  /// **'PC で Bridge Server を起動しましょう。'**
  String get guideBridgeDescription;

  /// No description provided for @guideBridgePrerequisites.
  ///
  /// In ja, this message translates to:
  /// **'必要なもの'**
  String get guideBridgePrerequisites;

  /// No description provided for @guideBridgePrereq1.
  ///
  /// In ja, this message translates to:
  /// **'Node.js がインストールされた Mac / PC'**
  String get guideBridgePrereq1;

  /// No description provided for @guideBridgePrereq2.
  ///
  /// In ja, this message translates to:
  /// **'Claude Code CLI または Codex CLI\n（使いたい方だけでOK）'**
  String get guideBridgePrereq2;

  /// No description provided for @guideBridgeStep1.
  ///
  /// In ja, this message translates to:
  /// **'npx で実行（推奨）'**
  String get guideBridgeStep1;

  /// No description provided for @guideBridgeStep1Command.
  ///
  /// In ja, this message translates to:
  /// **'npx @ccpocket/bridge@latest'**
  String get guideBridgeStep1Command;

  /// No description provided for @guideBridgeStep2.
  ///
  /// In ja, this message translates to:
  /// **'またはグローバルインストール'**
  String get guideBridgeStep2;

  /// No description provided for @guideBridgeStep2Command.
  ///
  /// In ja, this message translates to:
  /// **'npm install -g @ccpocket/bridge\nccpocket-bridge'**
  String get guideBridgeStep2Command;

  /// No description provided for @guideBridgeQrNote.
  ///
  /// In ja, this message translates to:
  /// **'起動するとターミナルに QR コードが表示されます'**
  String get guideBridgeQrNote;

  /// No description provided for @guideConnectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'接続方法'**
  String get guideConnectionTitle;

  /// No description provided for @guideConnectionDescription.
  ///
  /// In ja, this message translates to:
  /// **'同じ Wi-Fi ネットワーク内なら、すぐに接続できます。'**
  String get guideConnectionDescription;

  /// No description provided for @guideConnectionQr.
  ///
  /// In ja, this message translates to:
  /// **'QR コードスキャン'**
  String get guideConnectionQr;

  /// No description provided for @guideConnectionQrDescription.
  ///
  /// In ja, this message translates to:
  /// **'ターミナルに表示された QR コードを読み取るだけ。一番簡単です。'**
  String get guideConnectionQrDescription;

  /// No description provided for @guideConnectionMdns.
  ///
  /// In ja, this message translates to:
  /// **'自動検出 (mDNS)'**
  String get guideConnectionMdns;

  /// No description provided for @guideConnectionMdnsDescription.
  ///
  /// In ja, this message translates to:
  /// **'同一 LAN 内の Bridge Server を自動で見つけて表示します。'**
  String get guideConnectionMdnsDescription;

  /// No description provided for @guideConnectionManual.
  ///
  /// In ja, this message translates to:
  /// **'手動入力'**
  String get guideConnectionManual;

  /// No description provided for @guideConnectionManualDescription.
  ///
  /// In ja, this message translates to:
  /// **'ws://<IP アドレス>:8765 の形式で直接入力します。'**
  String get guideConnectionManualDescription;

  /// No description provided for @guideConnectionRecommended.
  ///
  /// In ja, this message translates to:
  /// **'おすすめ'**
  String get guideConnectionRecommended;

  /// No description provided for @guideTailscaleTitle.
  ///
  /// In ja, this message translates to:
  /// **'外出先からの接続'**
  String get guideTailscaleTitle;

  /// No description provided for @guideTailscaleDescription.
  ///
  /// In ja, this message translates to:
  /// **'自宅の外からも使いたい場合は、Tailscale（VPN の一種）を使えば安全にリモート接続できます。'**
  String get guideTailscaleDescription;

  /// No description provided for @guideTailscaleStep1.
  ///
  /// In ja, this message translates to:
  /// **'Mac と iPhone の両方に Tailscale をインストール'**
  String get guideTailscaleStep1;

  /// No description provided for @guideTailscaleStep2.
  ///
  /// In ja, this message translates to:
  /// **'同じアカウントでログイン'**
  String get guideTailscaleStep2;

  /// No description provided for @guideTailscaleStep3.
  ///
  /// In ja, this message translates to:
  /// **'Bridge URL に Tailscale IP を使用\n(例: ws://100.x.x.x:8765)'**
  String get guideTailscaleStep3;

  /// No description provided for @guideTailscaleWebsite.
  ///
  /// In ja, this message translates to:
  /// **'Tailscale 公式サイト'**
  String get guideTailscaleWebsite;

  /// No description provided for @guideTailscaleWebsiteHint.
  ///
  /// In ja, this message translates to:
  /// **'詳しいセットアップ方法は公式サイトをご覧ください。'**
  String get guideTailscaleWebsiteHint;

  /// No description provided for @guideLaunchdTitle.
  ///
  /// In ja, this message translates to:
  /// **'常時起動の設定'**
  String get guideLaunchdTitle;

  /// No description provided for @guideLaunchdDescription.
  ///
  /// In ja, this message translates to:
  /// **'毎回手動で Bridge Server を起動するのが面倒な場合、Mac の起動時に自動で立ち上がるよう設定できます。'**
  String get guideLaunchdDescription;

  /// No description provided for @guideLaunchdCommand.
  ///
  /// In ja, this message translates to:
  /// **'セットアップコマンド'**
  String get guideLaunchdCommand;

  /// No description provided for @guideLaunchdCommandValue.
  ///
  /// In ja, this message translates to:
  /// **'npx @ccpocket/bridge@latest setup'**
  String get guideLaunchdCommandValue;

  /// No description provided for @guideLaunchdRecommendation.
  ///
  /// In ja, this message translates to:
  /// **'まずは手動起動で動作確認してから、安定したら launchd 登録がおすすめです。'**
  String get guideLaunchdRecommendation;

  /// No description provided for @guideReadyTitle.
  ///
  /// In ja, this message translates to:
  /// **'準備完了!'**
  String get guideReadyTitle;

  /// No description provided for @guideReadyDescription.
  ///
  /// In ja, this message translates to:
  /// **'Bridge Server を起動して、\nQR コードをスキャンするところから\n始めましょう。'**
  String get guideReadyDescription;

  /// No description provided for @guideReadyStart.
  ///
  /// In ja, this message translates to:
  /// **'さっそく始める'**
  String get guideReadyStart;

  /// No description provided for @guideReadyHint.
  ///
  /// In ja, this message translates to:
  /// **'このガイドは設定画面からいつでも確認できます'**
  String get guideReadyHint;

  /// No description provided for @creatingSession.
  ///
  /// In ja, this message translates to:
  /// **'セッション作成中...'**
  String get creatingSession;

  /// No description provided for @copyForAgent.
  ///
  /// In ja, this message translates to:
  /// **'エージェント用にコピー'**
  String get copyForAgent;

  /// No description provided for @messageHistory.
  ///
  /// In ja, this message translates to:
  /// **'メッセージ履歴'**
  String get messageHistory;

  /// No description provided for @viewChanges.
  ///
  /// In ja, this message translates to:
  /// **'変更を確認'**
  String get viewChanges;

  /// No description provided for @screenshot.
  ///
  /// In ja, this message translates to:
  /// **'スクリーンショット'**
  String get screenshot;

  /// No description provided for @debug.
  ///
  /// In ja, this message translates to:
  /// **'デバッグ'**
  String get debug;

  /// No description provided for @logs.
  ///
  /// In ja, this message translates to:
  /// **'ログ'**
  String get logs;

  /// No description provided for @viewApplicationLogs.
  ///
  /// In ja, this message translates to:
  /// **'アプリケーションログを表示'**
  String get viewApplicationLogs;

  /// No description provided for @mockPreview.
  ///
  /// In ja, this message translates to:
  /// **'モックプレビュー'**
  String get mockPreview;

  /// No description provided for @viewMockChatScenarios.
  ///
  /// In ja, this message translates to:
  /// **'モックチャットシナリオを表示'**
  String get viewMockChatScenarios;

  /// No description provided for @updateTrack.
  ///
  /// In ja, this message translates to:
  /// **'アップデートトラック'**
  String get updateTrack;

  /// No description provided for @updateTrackDescription.
  ///
  /// In ja, this message translates to:
  /// **'変更後にアプリを再起動すると反映されます'**
  String get updateTrackDescription;

  /// No description provided for @updateTrackStable.
  ///
  /// In ja, this message translates to:
  /// **'Stable（安定版）'**
  String get updateTrackStable;

  /// No description provided for @updateTrackStaging.
  ///
  /// In ja, this message translates to:
  /// **'Staging（テスト）'**
  String get updateTrackStaging;

  /// No description provided for @updateDownloaded.
  ///
  /// In ja, this message translates to:
  /// **'アップデートをダウンロードしました。アプリを再起動すると反映されます。'**
  String get updateDownloaded;

  /// No description provided for @promptHistory.
  ///
  /// In ja, this message translates to:
  /// **'プロンプト履歴'**
  String get promptHistory;

  /// No description provided for @frequent.
  ///
  /// In ja, this message translates to:
  /// **'頻度順'**
  String get frequent;

  /// No description provided for @recent.
  ///
  /// In ja, this message translates to:
  /// **'新しい順'**
  String get recent;

  /// No description provided for @searchHint.
  ///
  /// In ja, this message translates to:
  /// **'検索...'**
  String get searchHint;

  /// No description provided for @noMatchingPrompts.
  ///
  /// In ja, this message translates to:
  /// **'一致するプロンプトがありません'**
  String get noMatchingPrompts;

  /// No description provided for @noPromptHistoryYet.
  ///
  /// In ja, this message translates to:
  /// **'プロンプト履歴はまだありません'**
  String get noPromptHistoryYet;

  /// No description provided for @approvalQueue.
  ///
  /// In ja, this message translates to:
  /// **'承認キュー'**
  String get approvalQueue;

  /// No description provided for @resetQueue.
  ///
  /// In ja, this message translates to:
  /// **'キューをリセット'**
  String get resetQueue;

  /// No description provided for @swipeSkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get swipeSkip;

  /// No description provided for @swipeSend.
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get swipeSend;

  /// No description provided for @swipeDismiss.
  ///
  /// In ja, this message translates to:
  /// **'却下'**
  String get swipeDismiss;

  /// No description provided for @swipeApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認'**
  String get swipeApprove;

  /// No description provided for @swipeReject.
  ///
  /// In ja, this message translates to:
  /// **'拒否'**
  String get swipeReject;

  /// No description provided for @allClear.
  ///
  /// In ja, this message translates to:
  /// **'すべて完了!'**
  String get allClear;

  /// No description provided for @itemsProcessed.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件処理しました'**
  String itemsProcessed(int count);

  /// No description provided for @bestStreak.
  ///
  /// In ja, this message translates to:
  /// **'最高連続: {count}'**
  String bestStreak(int count);

  /// No description provided for @tryAgain.
  ///
  /// In ja, this message translates to:
  /// **'もう一度'**
  String get tryAgain;

  /// No description provided for @waitingForTasks.
  ///
  /// In ja, this message translates to:
  /// **'タスク待ち'**
  String get waitingForTasks;

  /// No description provided for @agentReadyForPrompt.
  ///
  /// In ja, this message translates to:
  /// **'エージェントは次のプロンプトを待っています。'**
  String get agentReadyForPrompt;

  /// No description provided for @backToSessions.
  ///
  /// In ja, this message translates to:
  /// **'セッション一覧に戻る'**
  String get backToSessions;

  /// No description provided for @working.
  ///
  /// In ja, this message translates to:
  /// **'処理中...'**
  String get working;

  /// No description provided for @waitingForApprovalRequests.
  ///
  /// In ja, this message translates to:
  /// **'エージェントからの承認リクエストを待っています。'**
  String get waitingForApprovalRequests;

  /// No description provided for @noActiveSessions.
  ///
  /// In ja, this message translates to:
  /// **'アクティブなセッションがありません'**
  String get noActiveSessions;

  /// No description provided for @startSessionToBegin.
  ///
  /// In ja, this message translates to:
  /// **'セッションを開始して承認リクエストの受信を始めましょう。'**
  String get startSessionToBegin;

  /// No description provided for @settingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @sectionGeneral.
  ///
  /// In ja, this message translates to:
  /// **'一般'**
  String get sectionGeneral;

  /// No description provided for @sectionEditor.
  ///
  /// In ja, this message translates to:
  /// **'エディタ'**
  String get sectionEditor;

  /// No description provided for @indentSize.
  ///
  /// In ja, this message translates to:
  /// **'インデント幅'**
  String get indentSize;

  /// No description provided for @indentSizeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'箇条書きのインデントに使用するスペース数'**
  String get indentSizeSubtitle;

  /// No description provided for @sectionAbout.
  ///
  /// In ja, this message translates to:
  /// **'概要'**
  String get sectionAbout;

  /// No description provided for @theme.
  ///
  /// In ja, this message translates to:
  /// **'テーマ'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In ja, this message translates to:
  /// **'システム'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ja, this message translates to:
  /// **'ライト'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ja, this message translates to:
  /// **'ダーク'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In ja, this message translates to:
  /// **'端末の設定に従う'**
  String get languageSystem;

  /// No description provided for @voiceInput.
  ///
  /// In ja, this message translates to:
  /// **'音声入力'**
  String get voiceInput;

  /// No description provided for @pushNotifications.
  ///
  /// In ja, this message translates to:
  /// **'プッシュ通知'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'Bridge 経由でセッション通知を受け取ります'**
  String get pushNotificationsSubtitle;

  /// No description provided for @pushNotificationsUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'Firebase 設定後に利用できます'**
  String get pushNotificationsUnavailable;

  /// No description provided for @version.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get version;

  /// No description provided for @loading.
  ///
  /// In ja, this message translates to:
  /// **'読み込み中...'**
  String get loading;

  /// No description provided for @setupGuideSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'初めての方はこちら'**
  String get setupGuideSubtitle;

  /// No description provided for @openSourceLicenses.
  ///
  /// In ja, this message translates to:
  /// **'オープンソースライセンス'**
  String get openSourceLicenses;

  /// No description provided for @githubRepository.
  ///
  /// In ja, this message translates to:
  /// **'GitHub リポジトリ'**
  String get githubRepository;

  /// No description provided for @changelog.
  ///
  /// In ja, this message translates to:
  /// **'変更履歴'**
  String get changelog;

  /// No description provided for @changelogTitle.
  ///
  /// In ja, this message translates to:
  /// **'変更履歴'**
  String get changelogTitle;

  /// No description provided for @showAllMain.
  ///
  /// In ja, this message translates to:
  /// **'すべて表示 (main)'**
  String get showAllMain;

  /// No description provided for @changelogFetchError.
  ///
  /// In ja, this message translates to:
  /// **'変更履歴の取得に失敗しました'**
  String get changelogFetchError;

  /// No description provided for @fcmBridgeNotInitialized.
  ///
  /// In ja, this message translates to:
  /// **'Bridge が未初期化です'**
  String get fcmBridgeNotInitialized;

  /// No description provided for @fcmTokenFailed.
  ///
  /// In ja, this message translates to:
  /// **'FCM token を取得できませんでした'**
  String get fcmTokenFailed;

  /// No description provided for @fcmEnabled.
  ///
  /// In ja, this message translates to:
  /// **'通知を有効化しました'**
  String get fcmEnabled;

  /// No description provided for @fcmEnabledPending.
  ///
  /// In ja, this message translates to:
  /// **'Bridge 再接続後に通知登録します'**
  String get fcmEnabledPending;

  /// No description provided for @fcmDisabled.
  ///
  /// In ja, this message translates to:
  /// **'通知を無効化しました'**
  String get fcmDisabled;

  /// No description provided for @fcmDisabledPending.
  ///
  /// In ja, this message translates to:
  /// **'Bridge 再接続後に通知解除します'**
  String get fcmDisabledPending;

  /// No description provided for @pushPrivacyMode.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーモード'**
  String get pushPrivacyMode;

  /// No description provided for @pushPrivacyModeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'通知にプロジェクト名や内容を含めない'**
  String get pushPrivacyModeSubtitle;

  /// No description provided for @updateNotificationLanguage.
  ///
  /// In ja, this message translates to:
  /// **'通知言語を更新'**
  String get updateNotificationLanguage;

  /// No description provided for @notificationLanguageUpdated.
  ///
  /// In ja, this message translates to:
  /// **'通知言語を更新しました'**
  String get notificationLanguageUpdated;

  /// No description provided for @defaultNotRecommended.
  ///
  /// In ja, this message translates to:
  /// **'Default（非推奨）'**
  String get defaultNotRecommended;

  /// No description provided for @imageAttached.
  ///
  /// In ja, this message translates to:
  /// **'画像添付'**
  String get imageAttached;

  /// No description provided for @sectionBackup.
  ///
  /// In ja, this message translates to:
  /// **'バックアップ'**
  String get sectionBackup;

  /// No description provided for @backupPromptHistory.
  ///
  /// In ja, this message translates to:
  /// **'プロンプト履歴をバックアップ'**
  String get backupPromptHistory;

  /// No description provided for @restorePromptHistory.
  ///
  /// In ja, this message translates to:
  /// **'プロンプト履歴をリストア'**
  String get restorePromptHistory;

  /// No description provided for @backupSuccess.
  ///
  /// In ja, this message translates to:
  /// **'バックアップが完了しました'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In ja, this message translates to:
  /// **'バックアップに失敗しました: {error}'**
  String backupFailed(String error);

  /// No description provided for @restoreSuccess.
  ///
  /// In ja, this message translates to:
  /// **'リストアが完了しました'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In ja, this message translates to:
  /// **'リストアに失敗しました: {error}'**
  String restoreFailed(String error);

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロンプト履歴のリストア'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'ローカルのプロンプト履歴がバックアップの内容で上書きされます。この操作は元に戻せません。'**
  String get restoreConfirmMessage;

  /// No description provided for @restoreConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'リストア'**
  String get restoreConfirmButton;

  /// No description provided for @noBackupFound.
  ///
  /// In ja, this message translates to:
  /// **'バックアップがありません'**
  String get noBackupFound;

  /// No description provided for @backupInfo.
  ///
  /// In ja, this message translates to:
  /// **'最終バックアップ: {date}'**
  String backupInfo(String date);

  /// No description provided for @backupVersionInfo.
  ///
  /// In ja, this message translates to:
  /// **'v{version} · {size}'**
  String backupVersionInfo(String version, String size);

  /// No description provided for @connectToBackup.
  ///
  /// In ja, this message translates to:
  /// **'Bridge に接続するとバックアップが利用できます'**
  String get connectToBackup;

  /// No description provided for @usageConnectToView.
  ///
  /// In ja, this message translates to:
  /// **'Bridge に接続すると利用量を表示できます'**
  String get usageConnectToView;

  /// No description provided for @usageFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しました'**
  String get usageFetchFailed;

  /// No description provided for @usageFiveHour.
  ///
  /// In ja, this message translates to:
  /// **'5時間'**
  String get usageFiveHour;

  /// No description provided for @usageSevenDay.
  ///
  /// In ja, this message translates to:
  /// **'7日間'**
  String get usageSevenDay;

  /// No description provided for @usageResetAt.
  ///
  /// In ja, this message translates to:
  /// **'リセット: {time}'**
  String usageResetAt(String time);

  /// No description provided for @usageAlreadyReset.
  ///
  /// In ja, this message translates to:
  /// **'リセット済み'**
  String get usageAlreadyReset;

  /// No description provided for @attachedImages.
  ///
  /// In ja, this message translates to:
  /// **'添付画像 ({count})'**
  String attachedImages(int count);

  /// No description provided for @attachedImagesNoCount.
  ///
  /// In ja, this message translates to:
  /// **'添付画像'**
  String get attachedImagesNoCount;

  /// No description provided for @failedToFetchImages.
  ///
  /// In ja, this message translates to:
  /// **'画像を取得できませんでした'**
  String get failedToFetchImages;

  /// No description provided for @responseTimedOut.
  ///
  /// In ja, this message translates to:
  /// **'応答がタイムアウトしました'**
  String get responseTimedOut;

  /// No description provided for @failedToFetchImagesWithError.
  ///
  /// In ja, this message translates to:
  /// **'画像の取得に失敗しました: {error}'**
  String failedToFetchImagesWithError(String error);

  /// No description provided for @retry.
  ///
  /// In ja, this message translates to:
  /// **'リトライ'**
  String get retry;

  /// No description provided for @clipboardNotAvailable.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードにアクセスできません'**
  String get clipboardNotAvailable;

  /// No description provided for @failedToLoadImage.
  ///
  /// In ja, this message translates to:
  /// **'画像の読み込みに失敗しました'**
  String get failedToLoadImage;

  /// No description provided for @noImageInClipboard.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードに画像がありません'**
  String get noImageInClipboard;

  /// No description provided for @failedToReadClipboard.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードの読み取りに失敗しました'**
  String get failedToReadClipboard;

  /// No description provided for @selectFromGallery.
  ///
  /// In ja, this message translates to:
  /// **'ギャラリーから選択'**
  String get selectFromGallery;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In ja, this message translates to:
  /// **'クリップボードから貼付'**
  String get pasteFromClipboard;

  /// No description provided for @voiceInputLanguage.
  ///
  /// In ja, this message translates to:
  /// **'音声入力の言語'**
  String get voiceInputLanguage;

  /// No description provided for @archive.
  ///
  /// In ja, this message translates to:
  /// **'アーカイブ'**
  String get archive;

  /// No description provided for @sessionArchived.
  ///
  /// In ja, this message translates to:
  /// **'セッションをアーカイブしました'**
  String get sessionArchived;

  /// No description provided for @archiveFailed.
  ///
  /// In ja, this message translates to:
  /// **'セッションのアーカイブに失敗しました'**
  String get archiveFailed;

  /// No description provided for @archiveFailedWithError.
  ///
  /// In ja, this message translates to:
  /// **'セッションのアーカイブに失敗しました: {error}'**
  String archiveFailedWithError(String error);

  /// No description provided for @noRecentSessions.
  ///
  /// In ja, this message translates to:
  /// **'最近のセッションはありません'**
  String get noRecentSessions;

  /// No description provided for @noSessionsMatchFilters.
  ///
  /// In ja, this message translates to:
  /// **'現在のフィルター条件に一致するセッションがありません'**
  String get noSessionsMatchFilters;

  /// No description provided for @adjustFiltersAndSearch.
  ///
  /// In ja, this message translates to:
  /// **'フィルター条件や検索語を変更してください'**
  String get adjustFiltersAndSearch;

  /// No description provided for @tooltipDisplayMode.
  ///
  /// In ja, this message translates to:
  /// **'カードに表示するメッセージを切替'**
  String get tooltipDisplayMode;

  /// No description provided for @tooltipProviderFilter.
  ///
  /// In ja, this message translates to:
  /// **'AIツールで絞り込み'**
  String get tooltipProviderFilter;

  /// No description provided for @tooltipProjectFilter.
  ///
  /// In ja, this message translates to:
  /// **'プロジェクトで絞り込み'**
  String get tooltipProjectFilter;

  /// No description provided for @tooltipNamedOnly.
  ///
  /// In ja, this message translates to:
  /// **'名前を付けたセッションのみ'**
  String get tooltipNamedOnly;

  /// No description provided for @tooltipIndent.
  ///
  /// In ja, this message translates to:
  /// **'インデント'**
  String get tooltipIndent;

  /// No description provided for @tooltipDedent.
  ///
  /// In ja, this message translates to:
  /// **'インデント解除'**
  String get tooltipDedent;

  /// No description provided for @tooltipSlashCommand.
  ///
  /// In ja, this message translates to:
  /// **'スラッシュコマンド'**
  String get tooltipSlashCommand;

  /// No description provided for @tooltipPermissionMode.
  ///
  /// In ja, this message translates to:
  /// **'パーミッションモード'**
  String get tooltipPermissionMode;

  /// No description provided for @tooltipAttachImage.
  ///
  /// In ja, this message translates to:
  /// **'画像を添付'**
  String get tooltipAttachImage;

  /// No description provided for @tooltipPromptHistory.
  ///
  /// In ja, this message translates to:
  /// **'プロンプト履歴'**
  String get tooltipPromptHistory;

  /// No description provided for @tooltipVoiceInput.
  ///
  /// In ja, this message translates to:
  /// **'音声入力'**
  String get tooltipVoiceInput;

  /// No description provided for @tooltipStopRecording.
  ///
  /// In ja, this message translates to:
  /// **'録音を停止'**
  String get tooltipStopRecording;

  /// No description provided for @tooltipSendMessage.
  ///
  /// In ja, this message translates to:
  /// **'メッセージを送信'**
  String get tooltipSendMessage;

  /// No description provided for @tooltipRemoveImage.
  ///
  /// In ja, this message translates to:
  /// **'画像を削除'**
  String get tooltipRemoveImage;

  /// No description provided for @tooltipClearDiff.
  ///
  /// In ja, this message translates to:
  /// **'Diff選択を解除'**
  String get tooltipClearDiff;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
