# 差分への複数コメント（Diff Review Comments）

Issue: [#147 Diff Commenting](https://github.com/K9i-0/ccpocket/issues/147)

## 背景と目的

Git画面でAIに修正を依頼する既存の経路は、hunk / ファイルの「Request Change」だけである。
選んだ1つの差分を ```` ```diff ```` としてチャット入力欄に添付する方式で、次の制約がある。

- 添付できる差分は1件のみ（`attachedDiffSelection` は単一値）。
- 差分とコメントが対応しない。複数箇所への指摘は1つのプロンプトにまとめて書く必要がある。
- 行単位の指定ができない。

GitHubのレビューやCodexアプリと同じく、差分を見ながら複数箇所にコメントを付け、
まとめてAIへ送れるようにする。

動画のタイムスタンプコメント（[media-feedback.md](../media-feedback.md)）が持つ
「セッション単位の下書き」「自動保存」「チャット入力欄から送信」
「送信したスナップショットだけ削除」という仕組みを拡張し、アンカーを
「動画の再生位置」から「差分の行範囲」に置き換えたものとして扱う。

## スコープ

- 差分の1行・連続した行範囲（同じhunk内）、またはhunk全体へのコメント。
- 1つのセッションに複数ファイル・複数箇所のコメントを下書きとして保存する。
- 差分画面内で、対象行の直下にコメントを表示し、編集・削除できる。
- チャット入力欄にファイル単位のカードを表示し、プロンプトが空でもコメントだけで送れる。
- Claude / Codex共通。Bridgeとプロトコルの変更はない。

対象外: ファイル全体ビュー（FilePeek）へのコメント、返信・解決状態、
ツール結果の個別差分（`initialDiff`）やコミット済み差分へのコメント。

## 既存機能との関係

- Request Change（hunk / ファイル）は残す。単発で差分を丸ごと渡す用途として共存させる。
- 画像・動画コメントと同じ `MediaFeedbackCubit`、同じカード列、同じ送信経路を使う。
- 送信テキストの順序は「Request Changeの差分 → 本文 → 画像/動画コメント → 差分コメント」。
  既存2種の位置は変えない。

## データモデル

`MediaFeedbackCubit` / `MediaFeedback` を拡張し、新しいCubitは作らない。
pending → 実セッションIDへの移行（`DraftService` の `mediaFeedback.migrate`）、
送信スナップショットの削除（`removeSent`）、入力欄のカードをそのまま共有する。

```dart
FeedbackMedia(
  key: 'code:<working|staged>:<projectPath>:<filePath>',
  label: '<ファイル名>',
  isCode: true,                 // 追加
  path: '<filePath>',
  projectPath: '<projectPath>',
)

MediaFeedback(id: 'code:<micros>:<seq>', media: ..., text: '...', code: CodeAnchor(...))

CodeAnchor(
  source: DiffSource.working | DiffSource.staged,
  side: DiffSide.newSide | DiffSide.oldSide,
  startLine: 12, endLine: 14,   // side側の行番号（表示・送信用）
  lineCount: 3,                 // 選択した差分行数
  hunkHeader: '@@ -10,6 +10,9 @@',
  excerpt: '+foo\n+bar\n-baz',   // コメント時点の差分行（最大40行）
)
```

- 追加フィールドはすべて省略可能。既存の `media_feedback_v1_` のJSONはそのまま読める。保存キーは変えない。
- 差分内のインデックス（fileIdx / hunkIdx）は保存しない。再取得・stage・編集でずれるため。
- 範囲に新側の行番号があれば新側、削除行だけなら旧側で数える。削除行は `excerpt` で渡す。
- working と staged では行番号が異なるため、`source` をアンカーとカードのキーに含める。
- 旧アプリが新形式を読むと未知フィールドは無視され、画像コメントとして扱われる。ダウングレードは考慮しない。

## 再アンカーと古いコメント

AIがファイルを書き換えるとアンカーがずれることが前提になる。そのため画像・動画と違って
**送信を止めない**。code項目は `modifiedAt` を設定せず、既存の送信前チェックの対象外になる。

表示のたびに、各コメントを現在の差分へ対応付ける（`locateCodeAnchor`、結果は保存しない）。

1. 同じ `source` / ファイルの差分で、`excerpt` の行が同じ並びで現れる位置を探す。
   複数あれば元の行番号に最も近いものを選ぶ。
2. 見つからなければ「古いコメント」としてファイル見出しの直下に `excerpt` 付きで表示する。
3. ファイル自体が差分から消えたコメントは差分画面には出ない。チャット入力欄のカードには残り、
   そのまま送信・削除できる。

送信には常に保存済みの `excerpt` を使い、送信時に差分を取り直さない。送信する行番号もコメント時点の値。
差分画面のカードは、再アンカーできた場合に現在の行番号を表示する。

## UI

### 差分画面

- 行のタップでコメントを開始する。長押しは既存どおりhunkのアクションメニューを開く。
- 開いているコメントと同じhunk内の別の行をタップすると範囲を伸縮する。別のhunkやファイルの
  行をタップすると新しいコメントを始める。空のコメントの単一行をもう一度タップすると閉じる。
- hunkのアクションメニューに「Comment」（hunk全体）を追加する。メニューの既存項目と同じく英語固定。
- 入力はアンカー直下のインラインエディタ。入力ごとに `put` し、空なら削除する（画像・動画と同じ）。
  動画用の `MediaFeedbackEditor` は一時停止・シーク前提なので流用しない。
- 保存済みのコメントはアンカー行の直下にカードで表示し、タップで編集、×で削除する。
- 入力中は、編集中のコメント本文の変化だけでは差分全体を再構築しない（`needsRebuild`）。
- bindingは `GitScreen.sessionId` と `DraftService` から作る（ルート・埋め込みペインとも
  sessionIdが渡される）。sessionIdがない場合だけ `MediaFeedbackBinding.maybeOf` に戻し、
  それも null ならコメント操作を出さない。
- コメントはCubitへ直接保存するため、Request Changeのような `pop` / `onRequestChange` の受け渡しは不要。

### チャット入力欄

- `MediaFeedbackCards` に code 種別を追加する。ファイル単位で1枚、件数と先頭コメントを表示する。
- タップでGit画面を開く（ファイルへの自動スクロールはしない）。×でそのファイルのコメントを全削除する。

## 送信フォーマット

`appendMediaFeedback` が code 種別を最後にまとめる。ファイル順は最初のコメント追加順、
ファイル内は `startLine` 順。複数行の本文は字下げする。

````text
Code review comments:

File: lib/foo.dart (working tree diff)
Project: /path/to/project
- L12-14:
  ```diff
  +final a = 1;
  +final b = 2;
  -final c = 3;
  ```
  Use const here.
- L40 (old):
  ```diff
  -return null;
  ```
  Why was this removed?
````

`path` があるため、画像添付の準備（`feedbackImages`）では既存条件でスキップされる。

## 主な実装

- `features/media_feedback/state/media_feedback_state.dart`: `isCode`、`CodeAnchor`、送信フォーマット
- `features/git/diff_comments.dart`: アンカー作成・再アンカー・配置の純粋関数
- `features/git/widgets/diff_comment_presenter.dart`: 下書きから差分の装飾を作る
- `features/git/widgets/diff_comment_widgets.dart`: カード、インラインエディタ、古いコメント
- `features/git/widgets/diff_hunk_widget.dart` / `diff_content_list.dart`: 行タップ、選択表示、行間への挿入
- `features/git/git_screen.dart`: binding取得、hunkメニューの「Comment」
- `features/media_feedback/widgets/media_feedback_cards.dart`: code カード

## 検証

- `test/diff_comments_test.dart`: アンカー作成（新側/旧側、40行上限）、移動への追従、最近傍選択、
  outdated、送信フォーマットと画像・動画との順序、画像添付の対象外、旧JSONの読み込みと永続化。
- `test/git_diff_comments_widget_test.dart`: 行タップ→範囲拡張→保存→カード表示、複数コメント、削除、
  hunkメニューからのコメント、outdated表示、セッションなしで操作が出ないこと。
- 既存の `git_screen_test.dart` / `media_feedback_test.dart` が通ること。
- シミュレーターでの確認: 差分画面で複数箇所にコメント → 入力欄のカード → 送信テキスト。
