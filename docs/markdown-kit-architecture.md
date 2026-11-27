# ccpocket での `markdown_kit` の使い方

ccpocket の Markdown 描画とテキスト選択は [`markdown_kit`](https://pub.dev/packages/markdown_kit) が担う。もとは `packages/markdown_kit/` としてこのリポジトリで作り、1.0.0（2026-11-27）で [K9i-0/markdown_kit](https://github.com/K9i-0/markdown_kit) へ分離して pub.dev に公開した。分離前の履歴は新リポジトリに引き継いである。

パッケージ自体の設計判断・互換性方針・既知の制限・リリース手順は、新リポジトリの [doc/architecture.md](https://github.com/K9i-0/markdown_kit/blob/main/doc/architecture.md) にある。この文書は ccpocket 側の接続部分だけを扱う。

## 方針

- 見た目・アクション・業務ルールはビルダーとコールバックで `apps/mobile/` から渡す。パッケージ側に ccpocket の都合を持ち込まない。
- `apps/mobile/` は barrel（`package:markdown_kit/markdown_kit.dart`）だけを import する。例外は `apps/mobile/test/streaming_bubble_test.dart` の 1 箇所で、理由をその場に書いてある。
- `codeBlockBuilder` に渡る `codeContent` は不透明なウィジェットとして配置だけ行い、型を調べたり作り直したりしない。
- パッケージを直すときは新リポジトリで直して版を上げ、ここでは `apps/mobile/pubspec.yaml` の制約を更新する。両方を同時に試すときは、`apps/mobile/pubspec_overrides.yaml` で手元の clone を `path` 参照する（コミットしない）。

## アダプタ層

ccpocket 本体は `apps/mobile/pubspec.yaml` から `markdown_kit: ^1.0.0` で参照し、`material_ui` およびアプリ機能との接続を薄いアダプタ層に集約している。

### アダプタコンポーネント

- **`CcpocketSelectionScope`**: `MarkdownSelectionScope` をラップし、`material_ui` の `AdaptiveTextSelectionToolbar` によるアクションメニュー（**Copy** / **Copy as Markdown** / **Select All** / macOS ネイティブのみ **Search with Google**）、プラットフォーム準拠の選択ハンドル外観、およびエッジ自動スクロール設定を提供する。
- **`CcpocketMarkdown`**: `MarkdownView` のアプリ標準ラッパー。`Theme.of(context)` + `AppColors`（値等価性実装済み）+ `CodeTextSettings` から生成・キャッシュした `MarkdownThemeData` を渡し、以下を接続する：
  - `inlineCodeBuilder`: バッククォート内ファイルパス（`TappableTextSpan` で File Peek を開く）、Hex カラーコード（ベースライン揃えの丸スウォッチ `WidgetSpan` + 等幅 `TextSpan`）、通常インラインコード（`CodeTextSpan`）。
  - `MarkdownInlineRule`: 既知パス接尾辞に一致する裸のファイルパス検出、および `http://localhost:...` 等の単一ラベルホストオートリンク。
  - `codeHighlighter`: シンタックスハイライト（フォント種別・サイズ・色を含むキャッシュキー、および `CodeBlock.closed == false` 時の単一スロット分離キャッシュ）。
  - `codeBlockBuilder`: 選択対象外の言語ヘッダー＋コピーボタン＋横スクロールの枠。
  - `imageBuilder`: ホスト側ローカルパスはタップ可能な画像チップ、リモート URL は `Image.network`（エラー時はチップへフォールバック）。
- **`CcpocketSliverMarkdown`**: `SliverMarkdownView` のアプリ標準ラッパー。`FilePeekMarkdown`、`PlanDetailSheet`、`AuthHelpScreen`、`ChangelogScreen` の長文ドキュメント画面で使用する。
- **`CcpocketSelectableText`**: `SelectablePlainText` のアプリ標準ラッパー。`UserBubble` やアシスタントメッセージのプレーンテキスト表示モードで使用し、チャット内の全メッセージ選択体験を統一する。

### チャット画面の構成と非 Markdown 領域との境界

- `ChatMessageList` は `ListView.builder`（`reverse: true`）の上位に 1 つの `CcpocketSelectionScope` + `MarkdownSelectionController(allowCrossDocumentSelection: false)` を配置し、`AssistantBubble`・`StreamingBubble`・`UserBubble` へ安定した `documentId` と `documentOrder` を渡す。
- `StreamingBubble` から確定済み `AssistantBubble` への遷移および仮想化スクロールアウト時は `keepDocumentOnDispose: true` により選択状態が維持される。
- Diff ビューア・ログビューア・コード専用プレビュー・ツール入出力カード（`DiffHunkWidget`、`FilePeekCode`、`LocalBridgeLogsScreen`、`ToolUseTile`、`ToolResultBubble`、`ThinkingBubble` 等）の非 Markdown 領域は引き続き `GoogleSearchSelectionArea`（`apps/mobile/lib/widgets/google_search_text_selection.dart`）を使用する。
