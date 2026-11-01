# 差分への複数コメント（Diff Review Comments）設計

Issue: [#147 Diff Commenting](https://github.com/K9i-0/ccpocket/issues/147)

ステータス: 設計のみ（未実装）

## 背景と目的

現在のGit画面でAIに修正を依頼する経路は、hunk / ファイルの「Request Change」だけである。
これは選んだ1つの差分を ```` ```diff ```` としてチャット入力欄に添付する方式で、
次の制約がある。

- 添付できる差分は1件のみ（`attachedDiffSelection` は単一値）。
- 差分とコメントが対応しない。複数箇所への指摘は1つのプロンプトにまとめて書く必要がある。
- 行単位の指定ができない。

GitHubのレビューやCodexアプリと同じく、差分を見ながら複数箇所にコメントを付け、
まとめてAIへ送れるようにする。

既存の動画タイムスタンプコメント（[media-feedback.md](../media-feedback.md)）は
「セッション単位の下書き」「自動保存」「チャット入力欄から送信」
「送信したスナップショットだけ削除」という仕組みを持つ。差分コメントはこの仕組みを
拡張し、アンカーを「動画の再生位置」から「ファイルの行範囲」に置き換えたものとして扱う。

## スコープ

### v1

- hunkの行単位（1行または連続した範囲）と、hunk全体へのコメント。
- 1つのセッションに複数ファイル・複数箇所のコメントを下書きとして保存する。
- 差分画面内に、アンカー位置の直下へコメントをインライン表示し、編集・削除できる。
- チャット入力欄にコメントのカードを表示し、プロンプトが空でもコメントだけで送れる。
- Claude / Codex共通。Bridgeとプロトコルの変更はない。

### 対象外（後続候補）

- ファイル全体ビュー（FilePeek）の任意行へのコメント。アンカー形式は共通化できるよう設計する。
- コメントへの返信・スレッド・解決状態。
- 過去のターン差分やコミット済み差分へのコメント（作業ツリー・staged差分のみ）。

## 既存機能との関係

| 機能 | 扱い |
| --- | --- |
| Request Change（hunk / ファイル） | 残す。単発で差分を丸ごと渡す用途として共存させる。 |
| 動画・画像コメント | 同じCubit・同じカード列・同じ送信経路を使う。 |

送信テキストの順序は「Request Changeの差分（先頭）→ 本文 → 画像/動画コメント → 差分コメント」。
既存2種の位置は変えない。

## データモデル

`MediaFeedbackCubit` と `MediaFeedback` を拡張する。新しいCubitは作らない。
pending → 実セッションIDへの移行（`DraftService` の `mediaFeedback.migrate`）、
送信スナップショットの削除（`removeSent`）、入力欄のカードをそのまま共有できる。

```dart
enum FeedbackMediaKind { image, video, code }

FeedbackMedia(
  key: 'code:<projectPath>:<filePath>',
  label: '<ファイル名>',
  kind: FeedbackMediaKind.code,   // 追加。省略時は isVideo から導出
  isVideo: false,                 // 既存JSONとの互換のため残す
  path: '<filePath>',
  projectPath: '<projectPath>',
)

MediaFeedback(
  id: 'code:<micros>:<seq>',
  media: ...,
  text: 'コメント本文',
  positionMs: null,
  code: CodeAnchor(...),          // 追加。code以外では null
)

CodeAnchor(
  diffSource: DiffSource.working | DiffSource.staged,
  side: DiffSide.newSide | DiffSide.oldSide,
  startLine: 12,                  // side側の行番号
  endLine: 14,
  hunkHeader: '@@ -10,6 +10,9 @@ ...',
  excerpt: '+foo\n+bar\n-baz',     // コメント時点の対象行（diff形式、最大40行）
)
```

- 追加フィールドはすべて省略可能にする。既存の `media_feedback_v1_` のJSONはそのまま読める。
  保存キーは変えない。
- 永続化された `hunkIdx` / `fileIdx` は使わない。再取得・stage・編集でずれるため。
- 行番号は `side` 側で数える。追加行・コンテキスト行は新側、削除行だけの範囲は旧側。
  追加と削除をまたぐ範囲は新側の行番号を優先し、`excerpt` で削除行も渡す。
- working と staged では同じファイルでも行番号が異なるため、`diffSource` をアンカーに含める。
- hunk全体へのコメントは、そのhunkの新側の範囲を `startLine`〜`endLine` に入れる。

### 互換性

- 旧アプリが新形式のJSONを読むと、未知のフィールドは無視され、code項目は画像コメントとして
  扱われる。ダウングレードは想定外とし、対処しない。
- Bridgeのバージョンに依存しない（送信は既存の `sendMessage` のテキスト）。

## 再アンカーと古いコメント

AIがファイルを書き換えるとアンカーがずれるのが前提になる。そのため、画像・動画と違って
**送信を止めない**（media-feedbackの更新時刻チェックとは意図的に異なる）。

差分の取得ごとに、各コメントを次の順で現在の差分へ対応付ける。結果は表示用で、保存しない。

1. 同じ `diffSource` / ファイル / `side` で、`excerpt` の変更行が同じ並びで現れる位置。
   行番号が最も近いものを選ぶ。
2. 見つからなければ「古いコメント（outdated）」とし、ファイル見出しの直下に
   `excerpt` と一緒にまとめて表示する。
3. ファイル自体が差分から消えた場合は、差分画面の先頭にまとめて表示する。

送信には常に保存済みの `excerpt` を使う。古いコメントにも送信時に `(outdated)` を付ける。

## UI

### 差分画面

- 行の長押し、または行番号ガターのタップでコメントを開始する。
  開始後、別の行をタップすると範囲を伸ばす。範囲は同じhunk内に限る。
- hunkのアクションメニューに「Comment」を追加する（hunk全体へのコメント）。
- コメント入力はアンカー直下のインラインエディタにする。動画用の `MediaFeedbackEditor` は
  一時停止・シーク前提なので流用せず、保存処理（入力中に `put`、空なら削除）だけ揃える。
- 保存済みのコメントはアンカー行の直下にカードで表示し、タップで編集、×で削除する。
  ファイル見出しにコメント数のバッジを出す。
- セッションに紐付かないGit画面（`MediaFeedbackBinding.maybeOf` が null）ではコメント操作を出さない。
- ルートの差分画面でも埋め込みペインでも、コメントはCubitに直接保存する。
  Request Changeのような `pop` / `onRequestChange` の受け渡しは不要。

### チャット入力欄

- `MediaFeedbackCards` に code 種別を追加する。ファイル単位で1枚、件数と先頭コメントを表示する。
- タップでGit画面を開き、そのファイルへスクロールする。×でそのファイルのコメントを全削除する。
- 画像・動画コメントと同じく、プロンプトが空でも送信できる。

## 送信フォーマット

`appendMediaFeedback` に code 種別の分岐を追加する。ファイル順はコメント追加順、
ファイル内は `startLine` 順。

````text
Code review comments
Project: /path/to/project

File: lib/foo.dart (working tree diff)
- L12-14 (new):
  ```diff
  +final a = 1;
  +final b = 2;
  -final c = 3;
  ```
  Use const here.
- L40 (old) (outdated):
  ```diff
  -return null;
  ```
  Why was this removed?
````

- 画像の添付処理（`feedbackImages`）の対象外。
- `excerpt` はコメント時点のものを使う。送信時に差分を取り直さない。

## 状態遷移と送信後

- 下書きは自動保存。差分画面を閉じても残る。
- 送信経路が受け付けた時点で、送信したスナップショットと一致するコメントだけを削除する
  （既存の `removeSent`）。

## 主な変更ファイル（予定）

- `features/media_feedback/state/media_feedback_state.dart`: `FeedbackMediaKind`、`CodeAnchor`、送信フォーマット
- `features/media_feedback/widgets/media_feedback_cards.dart`: code カードと遷移
- `utils/diff_parser.dart`: excerpt 生成、再アンカーの純粋関数
- `features/git/widgets/diff_hunk_widget.dart` / `diff_content_list.dart`: 行選択、インライン表示・エディタ
- `features/git/git_screen.dart`: hunkメニューの「Comment」、binding取得、指定ファイルへのスクロール
- `features/chat_session/widgets/chat_input_with_overlays.dart`: 送信条件（必要に応じて）
- `l10n/app_*.arb`（en / ja / ko / zh）

## 検証方法

- 単体テスト
  - `appendMediaFeedback`: code種別の出力、ファイル内の行順、outdated表記、画像・動画との混在順。
  - 既存の `media_feedback_v1_` JSON（code フィールドなし）が読めること。
  - 再アンカー: 行がずれた場合の追従、同一内容が複数あるときの最近傍選択、見つからない場合のoutdated、
    working / staged の取り違えがないこと。
  - excerpt 生成: 追加・削除・コンテキスト混在、40行上限。
- Cubitテスト: 複数ファイルへの `put`、`removeSent` で送信中の追加分を残すこと、`migrate`。
- Widgetテスト: 行の長押しでエディタが出る、範囲選択、インライン表示、セッションなしで操作が出ないこと。
- `dart analyze` / `dart format` / 関連テスト。
- シミュレーターでのUI検証（mobile-automation、テスト用Bridge `8766`）
  - 2ファイル・3箇所にコメント → 入力欄のカード → 送信 → 送信テキストの確認。
  - AIの編集後に差分を再取得し、追従・outdated表示を確認。
  - 埋め込みペイン（デスクトップ幅）でも同様に確認。
