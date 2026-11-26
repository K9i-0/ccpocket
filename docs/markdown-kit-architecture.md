# `packages/markdown_kit` アーキテクチャと互換性方針

ccpocket の Markdown 描画およびテキスト選択基盤である独自パッケージ `packages/markdown_kit/` の設計判断、構成、アプリ統合、および保守・互換性方針をまとめる。

---

## 1. 背景: なぜ `flutter_markdown` を置き換えたか

従来 ccpocket は `flutter_markdown` + Flutter 標準 `SelectionArea` を使っていたが、長文チャット・ストリーミング・モバイル選択 UX・Flutter 3.50 移行において構造的な制約が重なっていた。

1. **SDK 選択ハンドルの貫通と選択解除 (`_SelectionHandleOverlay` / `SelectableRegion`)**
   - Flutter 標準の `_SelectionHandleOverlay` はハンドルを `HitTestBehavior.translucent` で描画し、ドラッグ開始の閾値に `2 * kTouchSlop`（36 lp）を使う。タッチ後にわずかに間を置いて縦ドラッグすると、イベントが背面の `ListView`・横スクロール・iOS 戻るスワイプへ貫通してジェスチャーアリーナを奪われやすい。
   - さらに `SelectableRegion` はジェスチャーキャンセル時に `onCancel = clearSelection` を呼ぶため、スクロールに競り負けた瞬間にユーザーの選択状態そのものが破棄される。
2. **`_kBlockTags` リークとブロック構造の制約**
   - `flutter_markdown` 内部の `_kBlockTags` 判定により、カスタム要素や HTML / 拡張ブロックの扱いが崩れやすく、コピー出力でも段落・リスト・テーブルの区切り改行欠落や、箇条書き記号・コードブロックヘッダーの混入を防ぎにくかった。
3. **`UniqueKey()` によるサブツリー再マウント**
   - 再ビルド時に `UniqueKey()` でウィジェットが作り直される箇所があり、RenderObject に紐づく `SelectionArea` の選択状態がストリーミング更新や無関係なリビルドで頻繁に失われていた。
4. **`Wrap` によるインライン分断**
   - インライン要素（ファイルパス、カラーコードスウォッチ、インラインコード等）にカスタムウィジェットを混ぜると `Wrap` ベースの分割レイアウトへフォールバックし、自然な行折り返しと連続テキスト選択が分断されていた。
5. **非推奨 `package:flutter/material.dart` への依存**
   - Flutter 3.50 で `package:flutter/material.dart` が非推奨となり ccpocket 本体は `package:material_ui` へ移行したが、`flutter_markdown` は旧 `material.dart` の `Theme` / `SelectableText` に依存し続けたため互換ブリッジやレガシー型インポートを残す必要があった（[flutter-3.50-upgrade.md](flutter-3.50-upgrade.md)）。

---

## 2. `packages/markdown_kit/` のアーキテクチャ

### 2.1 `package:flutter/widgets.dart` のみの境界

- パッケージ依存は `flutter`（`package:flutter/widgets.dart` のみ）、`markdown: ^7.3.0`、`meta` に限定する。
- `package:flutter/material.dart`、`package:flutter/cupertino.dart`、`package:material_ui`、および ccpocket 固有ドメインには一切依存しない。
- テーマ（値等価性 `==`/`hashCode` を備えた `MarkdownThemeData`）、選択ハンドル外観（`MarkdownSelectionHandleBuilder`）、拡大鏡（`MarkdownMagnifierBuilder`）、コンテキストメニュー（`MarkdownContextMenuBuilder`）、各種ノードビルダー（`MarkdownBuilders`）はすべて外から注入可能とし、将来的な独立切り出しにも耐える設計とした。

### 2.2 モジュール構成

```text
packages/markdown_kit/lib/
├── markdown_kit.dart                      # パブリック API バレルエクスポート
└── src/
    ├── ast/
    │   ├── markdown_ast.dart              # 不変 MarkdownDocument / sealed MarkdownBlock / sealed MarkdownInline
    │   └── rendered_text.dart             # ブロック単位の正規プレーンテキスト抽出（選択オフセットの単一ソース）
    ├── parser/
    │   ├── markdown_parser.dart           # MarkdownParser 抽象 + MarkdownParserOptions + BoundedLruCache
    │   ├── block_splitter.dart            # splitMarkdownBlocks / sanitizeStreamingTail（ストリーミング安全分割）
    │   ├── gfm_parser.dart                # GfmMarkdownParser（package:markdown ベース + 拡張構文 + 2段キャッシュ）
    │   └── inline_scanner.dart            # MarkdownInlineRule / MarkdownInlineScanner（高速後処理フック）
    ├── selection/
    │   ├── selection_model.dart           # MarkdownPosition / MarkdownSelection / MarkdownSelectionSurface / ReconciliationPolicy
    │   ├── selection_controller.dart      # MarkdownSelectionController（モデルアンカー管理）
    │   ├── selection_handles.dart         # MarkdownSelectionHandleOverlay（不透明 44pt・低 slop ハンドル＆ルーペ）
    │   ├── selection_autoscroll.dart      # MarkdownSelectionAutoscrollConfig / AxisDirection.up 対応エッジ自動スクロール
    │   ├── selection_formatter.dart       # MarkdownPlainTextFormatter / MarkdownMarkupFormatter
    │   ├── selection_scope.dart           # MarkdownSelectionScope（タッチ・デスクトップ入力統合）
    │   └── default_context_menu.dart      # MarkdownDefaultContextMenu（ビルダー未指定時の既定メニュー）
    ├── rendering/
    │   ├── markdown_theme.dart            # MarkdownThemeData / MarkdownTheme / MarkdownInlineCodeStyle
    │   ├── markdown_builders.dart         # MarkdownBuilders（code/inlineCode/link/image/table/alert/latex/customInline）
    │   ├── selectable_paragraph.dart      # SelectableParagraph / RenderSelectableParagraph / CodeTextSpan / TappableTextSpan
    │   ├── list_item_widget.dart          # Canvas 描画ハンギングインデント付きリスト項目
    │   ├── table_widget.dart              # 横スクロール対応テーブル
    │   ├── details_widget.dart            # <details>/<summary> 折りたたみブロック
    │   └── block_renderer.dart            # MarkdownBlockRenderer（AST → Widget ツリー変換）
    └── widgets/
        ├── markdown_view.dart             # MarkdownView（ブロック単位キャッシュ・ストリーミング対応）
        ├── sliver_markdown_view.dart      # SliverMarkdownView（Viewport Lazy Sliver）
        └── selectable_plain_text.dart     # SelectablePlainText（1 ブロックプレーンテキスト）
```

### 2.3 ハイブリッド描画 × モデルアンカー選択エンジン

Flutter の `SelectionArea` を使用せず、**カスタム `RenderSelectableParagraph` 描画 × モデルアンカー `MarkdownSelectionController` / `MarkdownSelectionScope`** のハイブリッド構成を採用している。

- **`RenderSelectableParagraph` (`selectable_paragraph.dart`)**
  - `RenderParagraph` を拡張し、`MarkdownSelectionSurface` としてコントローラへ登録される。
  - 選択ハイライトの描画、`CodeTextSpan` に対する行単位の角丸背景ピル描画、`TappableTextSpan` に対するグリフボックス単位のタップ判定およびネイティブ `hoverStyle`（ポインターホバー時の下線等）を単一パラグラフ内で完結させる。これにより `WidgetSpan` / `Wrap` によるテキスト分断と旧 `LinkHoverUnderline` ワークアラウンドを不要にした。
  - リスト記号は `MarkdownListItemWidget` で Canvas 描画（ハンギングインデント）とし、コピー対象テキストから構造的に分離する。
- **モデルアンカー選択 (`MarkdownSelectionController` / `MarkdownSelectionScope`)**
  - 選択範囲は RenderObject 参照ではなく、AST 座標 `MarkdownPosition(documentId, blockIndex, offset)`（`extractBlockRenderedText` 上の UTF-16 オフセット）で保持する。
  - `ListView.builder` や `SliverList.builder` の仮想化で画面外のウィジェットが破棄されても選択は失われず、再マウント時にハイライトとハンドルが復元される。
  - ストリーミング中の追記やストリーミング→確定バブルへの切り替えも、`MarkdownReconciliationPolicy.contentAnchored` により選択を維持しやすい。
- **不透明 44pt・低 slop ハンドル (`MarkdownSelectionHandleOverlay`)**
  - 各ハンドルは `LayerLink` で選択端点へ追従する独立 `OverlayEntry` に配置し、`Listener(behavior: HitTestBehavior.opaque)` + `RawGestureDetector(behavior: HitTestBehavior.opaque)` で最小 `44×44` lp（`kMarkdownHandleMinHitSize = 44.0`）のヒット領域を確保する。
  - ドラッグ閾値を `2.0` lp（`kMarkdownHandleTouchSlop = 2.0`）まで下げることで、100〜150ms の待機を挟む縦ドラッグでも背面 `ListView`・横スクロール・iOS 戻るスワイプへイベントが貫通しない。
- **タッチ / デスクトップのジェスチャー分離**
  - タッチ端末ではロングタップ（`LongPressGestureRecognizer`）のみで選択を開始し、通常スクロールとの競合をゼロにする。
  - ドラッグの `onCancel` はエッジ自動スクロールの停止のみを行い、**絶対に選択を解除しない**。選択中にハンドル以外の領域を縦横スワイプしてもそのままスクロールでき、選択は維持される。
  - デスクトップではドラッグ選択、ダブル／トリプルクリック（単語／ブロック選択）、Shift 拡張、右クリックメニュー、キーボードショートカット（Copy / Select All / Esc 解除）に対応する。
- **`AxisDirection.up` 対応エッジ自動スクロール (`selection_autoscroll.dart`)**
  - 自動スクロールの移動量は画面空間の視覚座標（`visualDy`）で計算し、対象 `ScrollPosition` の `AxisDirection`（通常 `down` / チャット `ListView(reverse: true)` の `up`）に合わせて符号を自動反転する。
  - `MarkdownSelectionAutoscrollConfig` で `topPad`・`bottomPad`（コンポーザーバーや SafeArea を考慮）・`useHostUnionGate` を調整でき、チャットリストのようにメッセージ単体がリスト全体より小さい場面でも画面端で安定して自動スクロールする。
- **チャットでの `allowCrossDocumentSelection: false`**
  - コントローラ自体は複数ドキュメント跨ぎ選択に対応（デフォルト `true`）するが、ccpocket のチャット画面ではリスト上位の単一コントローラを `allowCrossDocumentSelection: false` で構成する。
  - これにより、ハンドルドラッグや Select All は開始メッセージ（`documentId`）の先頭〜末尾でクランプされて隣接バブルへ誤って跨ぐことがなく、別バブルをロングタップした際も単一コントローラ上で競合なく選択が切り替わる。

### 2.4 コピーフォーマッタ (`selection_formatter.dart`)

- **`MarkdownPlainTextFormatter` (`controller.getText()`)**
  - ブロック間 `\n\n`、リスト項目・テーブル行間 `\n`、テーブルセル間 `\t` を保持したクリーンなプレーンテキストを生成する。
  - Canvas 描画の箇条書き記号、水平線（`ThematicBreakBlock`）、および `codeBlockBuilder` 外側の言語ヘッダー・コピーボタンは選択サーフェスへ登録しないためコピー結果へ混入しない。
- **`MarkdownMarkupFormatter` (`controller.getMarkdown()`)**
  - 選択された AST ブロックから標準 GFM Markdown（`#` 見出し、`>` 引用、`> [!NOTE]` アラート、本文中のバッククォート長に応じて安全に長さを選ぶフェンスコードブロック、入れ子・タスクリスト、パイプテーブル、`---`、`<details>`、`$$` 数式、脚注定義）を再構成する。
  - 先頭・末尾で部分選択されたブロックは未選択文字列を漏らさないよう、安全にプレーンテキストのスライスへフォールバックする。

### 2.5 `MarkdownParser` 抽象とストリーミング最適化

- **`MarkdownParser` インターフェース**
  - `parse(String markdown, {bool isStreaming = false}) -> MarkdownDocument` のみを契約とし、将来のパーサー差し替えを可能にする。
- **`GfmMarkdownParser`（デフォルト実装）**
  - Dart 公式 `package:markdown` をラップし、GFM 標準構文に加えて以下をサポートする（いずれも `MarkdownParserOptions` で制御可能）：
    - **GFM アラート** (`> [!NOTE]` / `TIP` / `IMPORTANT` / `WARNING` / `CAUTION`)
    - **頻出 HTML タグ** (`<br>`, `<details>/<summary>`, `<b>`/`<strong>`, `<i>`/`<em>`, `<u>`, `<s>`/`<del>`, `<sub>`, `<sup>`, `<kbd>`, `<a>`, `<img>`)
    - **脚注** (`[^1]` / `[^1]: ...`)
    - **LaTeX フック** (`\(...\)`・`\[...\]` を標準有効、通貨記号 `$5` 等の誤爆を避けるため `$...$`・`$$...$$` は `enableDollarLatex: false` のオプトイン)
    - **高速インライン後処理 (`MarkdownInlineRule` / `MarkdownInlineScanner`)**: `triggerCodeUnits` または `mayMatch` による事前フィルタを必須とし、通常テキストへの全文字 Regex 走査を回避しつつ、コードスパンや既存リンク内部には触れない。
- **ストリーミング分割とキャッシュ分離 (`block_splitter.dart`)**
  - `splitMarkdownBlocks` は `chunks.join() == text` を常に満たす形でトップレベルブロックを分割し、リンク参照定義・脚注定義・複数段落 HTML ブロックがある場合は単一チャンクへフォールバックする。
  - `package:markdown` は行頭の字下げや改行前の空白をテキストノードに残し、HTML 出力時に落とす。markdown_kit は AST へ直接変換するので、ブロックごとのインライン変換の最後に行頭・行末の空白を除去する（`-   項目` の余分な空白や継続行の字下げが表示に出ないように）。
  - ストリーミング中に保留するもの: 書きかけのコードフェンスと数式、末尾のバックスラッシュ、区切り行が揃う前の表の見出し行、閉じ括弧が来る前のアラート記法、最終行で閉じ側が未着のインライン記法（`**太字`・`~~取り消し`・コードスパン・`[ラベル](リンク先`）。インラインの保留は末尾から 300 文字以内の開始記号に限る（はぐれた `**` が長い段落の残りを隠さないため）。コードブロック内では何も保留しない。保留されるのは `isStreaming: true` の間だけで、確定後は全文を表示する。
  - `isStreaming: true` 時は `sanitizeStreamingTail` で未閉じ構文のチラつきを抑えつつ、確定済みチャンクを `BoundedLruCache`（文書キャッシュ＋ブロックキャッシュ）から再利用する。変化し続ける末尾チャンクは専用スロットに保持し、ストリーミングの中間フレームが共有 LRU キャッシュをスラッシングしないようにしている。
  - `CodeBlock.closed` フラグにより、未閉じフェンスのコードブロックをアプリ側ハイライターへ明示的に伝えられる。
- **パース失敗時のフォールバック**
  - `package:markdown` は一部の入力で例外を投げる（例: `> [!NOTE]` の直後に表の区切り行 `| --- | :-: |` が続くと "BlockParser.parseLines is not advancing"）。チャット本文はモデル出力であり内容を制御できないため、`GfmMarkdownParser` は例外を外へ出さない。
  - 失敗したチャンクを `splitMarkdownBlocks(..., ignoreCrossBlockConstructs: true)` で分け直し、失敗した部分だけを生テキストの段落として表示する。この縮退時は、分けた部分をまたぐ脚注番号・参照リンクは解決されない。
- **生 HTML ブロック**
  - 対応タグ以外の HTML ブロックはタグを含む生テキストとして表示する。HTML コメントだけのブロックは表示しない。

### 2.6 3 つの公開ウィジェットの使い分け

| ウィジェット | 用途 | 特徴 |
| --- | --- | --- |
| `MarkdownView` | チャットバブル・カード・ダイアログ・ストリーミング表示 | 確定済みトップレベルブロックのウィジェットを再利用（`onBlockBuilt` / `onBlockReused` 計測可）。上位に `MarkdownSelectionScope` があれば参加し、無ければ自動でスタンドアロンスコープを生成。 |
| `SliverMarkdownView` | 長文単一ドキュメント画面（`CustomScrollView` 内） | `SliverList.builder`（`addAutomaticKeepAlives: false`）で可視領域＋`cacheExtent` のみ遅延ビルドしつつ、文書全体は上位 `MarkdownSelectionScope` へ登録するため画面外ブロックを含めた選択・コピーが可能。 |
| `SelectablePlainText` | ユーザー発言バブルやプレーンテキスト表示切替 | 1 ブロックの軽量プレーンテキストとして同一の `MarkdownSelectionController`・不透明ハンドル・自動スクロール体験に参加。 |

---

## 3. ccpocket への統合 (`apps/mobile/`)

ccpocket 本体は `apps/mobile/pubspec.yaml` から `path: ../../packages/markdown_kit` でパッケージを参照し、`material_ui` およびアプリ機能との接続を薄いアダプタ層に集約している。

### 3.1 アダプタコンポーネント

- **`CcpocketSelectionScope`**: `MarkdownSelectionScope` をラップし、`material_ui` の `AdaptiveTextSelectionToolbar` によるアクションメニュー（**Copy** / **Copy as Markdown** / **Select All** / macOS ネイティブのみ **Search with Google**）、プラットフォーム準拠の選択ハンドル外観、およびエッジ自動スクロール設定を提供する。
- **`CcpocketMarkdown`**: `MarkdownView` のアプリ標準ラッパー。`Theme.of(context)` + `AppColors`（値等価性実装済み）+ `CodeTextSettings` から生成・キャッシュした `MarkdownThemeData` を渡し、以下を接続する：
  - `inlineCodeBuilder`: バッククォート内ファイルパス（`TappableTextSpan` で File Peek を開く）、Hex カラーコード（ベースライン揃えの丸スウォッチ `WidgetSpan` + 等幅 `TextSpan`）、通常インラインコード（`CodeTextSpan`）。
  - `MarkdownInlineRule`: 既知パス接尾辞に一致する裸のファイルパス検出、および `http://localhost:...` 等の単一ラベルホストオートリンク。
  - `codeHighlighter`: シンタックスハイライト（フォント種別・サイズ・色を含むキャッシュキー、および `CodeBlock.closed == false` 時の単一スロット分離キャッシュ）。
  - `codeBlockBuilder`: 選択対象外の言語ヘッダー＋コピーボタン＋横スクロールの枠。
  - `imageBuilder`: ホスト側ローカルパスはタップ可能な画像チップ、リモート URL は `Image.network`（エラー時はチップへフォールバック）。
- **`CcpocketSliverMarkdown`**: `SliverMarkdownView` のアプリ標準ラッパー。`FilePeekMarkdown`、`PlanDetailSheet`、`AuthHelpScreen`、`ChangelogScreen` の長文ドキュメント画面で使用する。
- **`CcpocketSelectableText`**: `SelectablePlainText` のアプリ標準ラッパー。`UserBubble` やアシスタントメッセージのプレーンテキスト表示モードで使用し、チャット内の全メッセージ選択体験を統一する。

### 3.2 チャット画面の構成と非 Markdown 領域との境界

- `ChatMessageList` は `ListView.builder`（`reverse: true`）の上位に 1 つの `CcpocketSelectionScope` + `MarkdownSelectionController(allowCrossDocumentSelection: false)` を配置し、`AssistantBubble`・`StreamingBubble`・`UserBubble` へ安定した `documentId` と `documentOrder` を渡す。
- `StreamingBubble` から確定済み `AssistantBubble` への遷移および仮想化スクロールアウト時は `keepDocumentOnDispose: true` により選択状態が維持される。
- Diff ビューア・ログビューア・コード専用プレビュー・ツール入出力カード（`DiffHunkWidget`、`FilePeekCode`、`LocalBridgeLogsScreen`、`ToolUseTile`、`ToolResultBubble`、`ThinkingBubble` 等）の非 Markdown 領域は引き続き `GoogleSearchSelectionArea`（`apps/mobile/lib/widgets/google_search_text_selection.dart`）を使用する。

---

## 4. 互換性・保守方針

1. **依存境界の維持**: `packages/markdown_kit/lib/` 配下に `material.dart` / `cupertino.dart` / `material_ui` / アプリ固有パッケージのインポートを持ち込まない。見た目・アクション・業務ルールは必ずビルダーまたはコールバック経由で `apps/mobile/` から注入する。
2. **SDK 互換性**: `pubspec.yaml` の下限は Flutter 3.50.0 / Dart 3.14。新しいパッケージなので最新に近い Flutter を要求することは許容する、という方針（2026-11-27 決定）。3.50.0 と 3.50.1 で全テストが通ることを確認済み。3.47.2 では 21 件が失敗する（表セル内のベースライン揃えウィジェットの Intrinsic 計測、RTL でのインライン画像の並びなど、フレームワーク側の挙動差）。下限を下げるときは、その版で実際にテストを通してから変更する。
3. **CI・リリースゲート**:
   - `.github/workflows/test.yml` の `markdown-kit` ジョブで `flutter pub get`・`dart format --output=none --set-exit-if-changed .`・`dart analyze .`・`flutter test --no-pub` を実行し、集約ジョブ `mobile` およびリリースゲート（`.github/workflows/app-release-test-gate.yml`）の必須条件とする。
   - ローカルリリース前チェック（`scripts/release/run-checks.sh`）でも `packages/markdown_kit` の `dart analyze` と `flutter test` を `apps/mobile` と併せて実行する。
   - git worktree 作成時は `scripts/worktree-bootstrap.sh` が `packages/markdown_kit/.dart_tool` を複製し `flutter pub get --offline` を実行する。
4. **回帰テストの基準**: ハンドルの不透明ヒットテスト・150ms 待機後の縦ドラッグ貫通防止・`ListView(reverse: true)` での自動スクロール・仮想化スクロールアウト後の選択復元・プレーンテキスト／Markdown 復元コピー・ストリーミング分割不変条件は `packages/markdown_kit/test/` の自動テストで担保し、変更時は必ず全件通す。
   - `parser_robustness_test.dart` は固定シードのランダム文書で、分割の連結不変条件・チャンク単位と全文のパース一致・全プレフィックスのストリーミング収束・病的入力の処理時間を検査する。正規表現を追加・変更したら必ず通す（コメント判定の正規表現が指数的バックトラックを起こした前例がある）。
   - `rendering_regression_test.dart` / `selection_regression_test.dart` は独立レビューで見つかった欠陥の再現テスト。
   - `test/commonmark_spec/` は CommonMark 0.31.2 の 652 例を通し、仕様と一致しない例を「`package:markdown` 起因」と「markdown_kit 起因（理由つき）」に分けて `baseline.json` に記録する。どちらの方向でも分類が変わると失敗するので、基準表は意図した変更でしか動かない。再生成は `UPDATE_COMMONMARK_BASELINE=1 flutter test test/commonmark_spec`。
   - `corpus_invariants_test.dart` は同じ例を入力に、分割・ストリーミング収束・コピー・描画オフセットの不変条件を検査する。`GfmMarkdownParser.rawTextFallbackCount` で「例外は出ないが生テキストに縮退した」入力を検出できる。
   - `selection_*_test.dart` / `rendering_*_test.dart` / `parser_*_test.dart` は `flutter_md` と `gpt_markdown` のテストスイートを棚卸しし、未カバーだった振る舞いを markdown_kit の API と仕様に合わせて書き起こしたもの。
5. **パーサー差し替え互換性**: AST（`MarkdownDocument` / `MarkdownBlock` / `MarkdownInline`）と `MarkdownParser` インターフェースを安定境界として維持し、将来 `package:markdown` 以外のパーサーへ移行する場合も選択エンジンとレンダラーへの影響を最小化する。

---

## 5. 公開 API と 1.0.0 公開手順

### 5.1 公開 API の範囲

- 公開 API は `lib/markdown_kit.dart` が `show` で列挙したものだけ。`lib/src/` にあっても列挙されていないもの（ブロックごとのウィジェット、ハンドルのオーバーレイ、自動スクロールのセッション、文書登録のヘルパー、LRU キャッシュなど）は内部実装で、互換性を保証しない。
- パッケージ自身のテストは内部を検証するために `src/` を import してよい。利用側（ccpocket を含む）は barrel だけを import する。例外は `apps/mobile/test/streaming_bubble_test.dart` の 1 箇所で、理由をその場に書いてある。
- コードブロックの見た目を変える拡張点は 2 つに分かれている。中身（ハイライト）は `codeHighlighter`、枠（ヘッダーやコピーボタン）は `codeBlockBuilder`。`codeBlockBuilder` に渡る `codeContent` は不透明なウィジェットとして配置だけ行い、型を調べたり作り直したりしない。以前 ccpocket がこれを行っていて、パッケージ側が段落を `Directionality` で包んだ際にハイライトが無効になった。
- `contextMenuBuilder` を渡さない場合は `MarkdownDefaultContextMenu` が出る（widgets のみで描画、ラベル差し替え可）。ccpocket は常に自前のビルダーを渡すので影響しない。
- `example/` は barrel だけを import する最小アプリで、widget test を CI で実行している。公開 API に不足が出ると、まずここで気づける。
- `analysis_options.yaml` で `public_member_api_docs` を有効にしている。公開メンバーに doc コメントが無いと解析が失敗する。

### 5.2 公開当日の手順

`packages/markdown_kit` は `publish_to: none`・version `0.1.0` のまま運用している。一時コピーで `publish_to` を外し version を `1.0.0` にした状態の `flutter pub publish --dry-run` は、警告が「`repository` 欄が無い」の 1 件だけであることを確認済み。公開時に行うこと:

1. 新しいリポジトリへ `packages/markdown_kit/` を移す（履歴を残すなら `git filter-repo --subdirectory-filter packages/markdown_kit`）。この文書のうち 1〜2 章と 5〜7 章はパッケージ側へ移し、3 章（ccpocket への統合）は ccpocket に残す。
2. `pubspec.yaml`: `publish_to: none` を削除、`version: 1.0.0`、`repository:`（と必要なら `issue_tracker:`）を追加。
3. `CHANGELOG.md` の `1.0.0` の内容を最終確認する。
4. 新リポジトリに CI を用意する（`flutter pub get` → `dart format --output=none --set-exit-if-changed .` → `dart analyze .` → `flutter test`、`example/` でも `flutter test`）。
5. `flutter pub publish --dry-run` で警告ゼロを確認してから `flutter pub publish`。公開は取り消せない。
6. ccpocket の `apps/mobile/pubspec.yaml` を path 依存から `markdown_kit: ^1.0.0` に切り替え、`packages/markdown_kit/`、CI の `markdown-kit` ジョブ、`scripts/release/run-checks.sh` と `scripts/worktree-bootstrap.sh` の該当行を削除する。
7. 上流の dart-lang/tools #2932・#2933 が修正されたら、生テキストへのフォールバックとストリーミング末尾の保留が不要になっていないかを見直す。

---

## 6. ライセンス

- パッケージは MIT（`packages/markdown_kit/LICENSE`）。
- 例外は `test/commonmark_spec/spec.json` のみ。CommonMark 仕様の例集で CC BY-SA 4.0、無改変でテスト入力として同梱している。このファイルは MIT の対象外で、`packages/markdown_kit/NOTICE.md` とルートの README に明記している。
- `flutter_md`（MIT）と `gpt_markdown`（BSD 系）は設計とテスト観点の参考元で、コードは写していない（`lib/` と `test/` を両パッケージと行単位で照合し、一致は import・定型句・`copyWith` の行のみであることを確認済み）。NOTICE に謝辞を記載している。

---

## 7. 既知の制限

- **「Markdown としてコピー」**: リテラルの記号はエスケープしない（`\*文字\*` は `*文字*` として出力される）。数式は元の区切りに関わらず `$...$` / `$$...$$` で出力する。マーカーが異なる隣接リスト（`*` と `-`）は 1 つのリストとして再解釈されうる。
- **内容アンカー再照合 (`contentAnchored`)**: 追記以外の書き換えで選択文字列が元の位置から消え、同じ文字列が別の場所にある場合、選択はそちらへ移る。追記のみのストリーミングと確定バブルへの切り替えは高速経路を通るため影響しない。
- **`keepDocumentOnDispose: true`**: コントローラは破棄されるまで、登録された文書（AST 参照）を保持し続ける。チャットではリスト単位のコントローラなので、画面を閉じれば解放される。
- **処理時間**: 閉じない `\(` が 1 行に数千個並ぶ入力、数千段に入れ子の `<details>` は入力長の 2 乗で遅くなる。
- **`<sub>` / `<sup>`**: フォントが対応する OpenType 機能を持たない場合、文字は小さくなるが上下にはずれない。
- **参照定義**: ラベルが 2 行にまたがる参照定義（`[Foo\n  bar]: /url`）は分割器が認識できず、リンクが解決されない。フェンスの情報文字列では一般的でない名前付き実体参照（`&ouml;` など）を復号しない。
- **閉じた `<details>` をまたぐ選択**: 終端が閉じた本文の中にある場合、ハンドルは summary の末尾に出る。コピーには見えていない本文も含まれる。
- **`<details>` の開閉状態**: ルートの `PageStorage` に保持する。`PageStorage` が祖先に無い場合（ルートの外）は State の寿命のみで、仮想化で画面外へ出ると初期状態に戻る。
- **幅 24lp 未満**: 脚注のラベルが行からはみ出す（テストフォントで 24lp、実フォントでは 20lp 程度から）。
- **入れ子の深さ**: 引用・リスト・`<details>` の入れ子は 500 段まで。それより深い部分はテキストとして表示する（AST とウィジェットツリーを辿る処理が段数ぶん再帰するため）。
- **上流 `package:markdown` 7.3.1 起因**: `~~~x~~~` が二重の取り消し線になる。コードスパン内の U+2028 / U+2029 でバッククォートが解釈されない。数千文字の空白を挟んだ行、`www` に続く大量のドット、閉じない `[a](<…` などは入力長の 2 乗で遅くなる。該当テストは理由つきでスキップしている。
