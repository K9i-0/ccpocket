---
name: mobile-automation
description: MCP (dart-mcp + Marionette) を使ったFlutterアプリのE2E自動化・UI検証ガイド
---

# Mobile Automation

dart-mcp と Marionette MCP を使ったFlutterアプリのUI検証・E2E自動化の包括ガイド。

## サブエージェント活用

**`e2e-verifier` サブエージェント**を使ってE2E検証を委譲できる。

```
Task tool で e2e-verifier サブエージェントを起動:

subagent_type: e2e-verifier
model: opus

プロンプト:
---
アプリが起動済みです。以下の検証を実施してください。

## 検証内容
[検証したい項目を記述]

## 接続情報（必要に応じて）
- VM Service URI: [wsUri]
- PID: [pid]

日本語で回答してください。
---
```

**使い分け:**
- 単純なUI確認（要素存在チェック等）→ 直接MCP操作
- 包括的なE2E検証 → `e2e-verifier` サブエージェントに委譲

## CLI vs MCP 判断基準

**原則: DTD/VM Service接続が必要な操作はMCP、それ以外はCLI**

### MCP必須（CLIで代替不可）

| 操作 | ツール | MCP名 |
|------|--------|-------|
| アプリ起動 | Dart MCP | `launch_app` |
| アプリ停止 | Dart MCP | `stop_app` |
| アプリログ取得 | Dart MCP | `get_app_logs` |
| DTD接続 | Dart MCP | `connect_dart_tooling_daemon` |
| ホットリロード | Dart MCP | `hot_reload` |
| ホットリスタート | Dart MCP | `hot_restart` |
| ウィジェットツリー | Dart MCP | `get_widget_tree` |
| ランタイムエラー | Dart MCP | `get_runtime_errors` |
| VM Service接続 | Marionette | `connect` |
| UI要素一覧 | Marionette | `get_interactive_elements` |
| タップ | Marionette | `tap` |
| テキスト入力 | Marionette | `enter_text` |
| スクロール | Marionette | `scroll_to` |
| アプリログ (Marionette) | Marionette | `get_logs` |
| スクリーンショット | Marionette | `take_screenshots` |

### CLI推奨（MCPより効率的）

| 操作 | CLI コマンド |
|------|-------------|
| デバイス一覧 | `flutter devices` |
| テスト実行 | `cd apps/mobile && flutter test` |
| 静的解析 | `dart analyze apps/mobile` |
| フォーマット | `dart format apps/mobile` |
| 依存関係 | `cd apps/mobile && flutter pub get` |

## アプリ起動ワークフロー

### 1. デバイス確認

```bash
flutter devices
```

### 2. アプリ起動 (Dart MCP)

```
mcp__dart-mcp__launch_app
  root: /Users/kotahayashi/Workspace/ccpocket/apps/mobile
  target: lib/main.dart
  device: <デバイスID>
```

返り値の **pid** を控える（クリーンアップ用）。

### 3. 待機

5秒待機（Xcode build + シミュレーターデプロイの完了待ち）。

### 4. VM Service URI 取得

```
mcp__dart-mcp__get_app_logs
  pid: <起動時のpid>
```

ログから `app.debugPort` イベントの **wsUri** を探す:
```
"wsUri":"ws://127.0.0.1:XXXXX/YYYY=/ws"
```

### 5. Marionette接続

```
mcp__marionette__connect
  uri: <wsUri>
```

**重要:** Marionette MCPは自動接続しない。必ず手動で `connect` が必要。

### 6. 接続確認

```
mcp__marionette__get_interactive_elements
```

要素一覧が返ればOK。

## ツール優先順位

UI検証時は以下の優先順位で使う:

1. **`get_interactive_elements`** — 最優先。タップ可能なボタン・入力欄等の一覧。常にこれを最初に呼ぶ
2. **`get_logs`** — エラー確認。"ERROR", "Exception" でフィルタ
3. **`tap`** / **`enter_text`** / **`scroll_to`** — UI操作
4. **`take_screenshots`** — **最後の手段**。APIトークンを大量消費する

### スクリーンショット制限

- 1セッションで **最大3-5枚** まで
- `get_interactive_elements` + `get_logs` で大半の検証は可能
- レイアウト・ビジュアル確認が本当に必要な場面のみ使う

## Widget Keys 一覧

### Session List Screen (ホーム画面)
- `session_list` — セッション一覧ListView
- `search_field` — セッション検索入力
- `search_button` — 検索トグルボタン
- `mock_preview_button` — モックシナリオギャラリーを開く (AppBar)
- `gallery_button` — ギャラリー画面へ遷移
- `refresh_button` — セッション一覧リフレッシュ
- `disconnect_button` — サーバー切断
- `new_session_fab` — 新規セッション作成FAB
- `load_more_button` — セッション追加読み込み

### 接続フォーム (Connect Form)
- `server_url_field` — サーバーURL入力
- `api_key_field` — APIキー入力
- `connect_button` — 接続ボタン
- `scan_qr_button` — QRスキャンボタン

### Chat Input Bar
- `message_input` — メッセージテキスト入力
- `send_button` — メッセージ送信
- `voice_button` — 音声入力
- `stop_button` — ストリーミング停止
- `slash_command_button` — スラッシュコマンドメニュー

### Approval Bar (承認バー)
- `approve_button` — ツール実行承認
- `reject_button` — ツール実行拒否
- `approve_always_button` — Always承認モード
- `view_plan_header_button` — プランヘッダー表示
- `plan_feedback_input` — プランフィードバック入力
- `clear_context_chip` — コンテキストクリアチップ

### Message Action Bar
- `copy_button` — メッセージコピー
- `plain_text_toggle` — プレーンテキスト表示切替
- `share_button` — メッセージ共有

### Plan Card & Detail Sheet
- `plan_edited_badge` — プラン編集済みバッジ
- `view_full_plan_button` — プラン詳細シート表示
- `plan_edit_toggle` — プラン編集モード切替
- `plan_edit_field` — プラン編集テキスト入力
- `plan_edit_cancel` — プラン編集キャンセル
- `plan_edit_apply` — プラン編集適用

### New Session Sheet
- `dialog_project_path` — プロジェクトパス選択
- `dialog_permission_mode` — パーミッションモード選択
- `dialog_worktree` — Worktreeトグル
- `dialog_worktree_branch` — Worktreeブランチ入力
- `dialog_start_button` — セッション開始ボタン

### Chat Screen
- `status_indicator` — ステータスインジケーター
- `session_switcher` — セッション切替

## Mock UI テスト (Bridge不要)

AppBarの「Mock Preview」ボタンから10種のモックシナリオを利用可能。

### ワークフロー

```
1. get_interactive_elements (ホーム画面確認)
2. tap key: "mock_preview_button"
3. tap text: "<シナリオ名>"
4. get_interactive_elements (チャットUI確認)
5. get_logs (エラー確認)
```

### モックシナリオ一覧

| # | 名前 | 検証ポイント |
|---|------|-------------|
| 1 | Approval Flow | approve/reject/always_approve ボタン表示 |
| 2 | AskUserQuestion | 質問テキスト + 選択肢オプション表示 |
| 3 | Multi-Question | 複数質問の同時表示 + multiSelect |
| 4 | Image Result | 画像参照のツール結果表示 |
| 5 | Streaming | 文字単位のストリーミング表示 |
| 6 | Thinking Block | 折りたたみ可能な思考コンテンツ |
| 7 | Plan Mode | EnterPlanMode → ExitPlanMode フロー |
| 8 | Subagent Summary | Taskツール + 圧縮結果表示 |
| 9 | Error | エラーメッセージ表示 |
| 10 | Full Conversation | System → Assistant → Tool → Result 全体 |

**おすすめクイックテスト:** Approval Flow, Streaming, Plan Mode（主要UIパターンをカバー）

## E2E テスト (Bridge必要)

```
1. Bridge起動: cd /Users/kotahayashi/Workspace/ccpocket && npm run bridge &
2. アプリ起動 (上記ワークフロー)
3. サーバー接続 → セッション作成 → メッセージ送信 → 承認フロー検証
4. 終了時: stop_app + Bridge停止 (lsof -ti :8765 | xargs kill)
```

## トラブルシューティング

### "Connection refused" (Marionette接続失敗)
- **原因:** アプリが完全に起動していない
- **対策:** launch_app 後に5秒待ってからMarionette操作を開始

### "Widget not found" (タップ失敗)
- **原因:** ウィジェット未描画 or キー名の誤り
- **対策:**
  1. get_interactive_elements で存在確認
  2. キー文字列のスペル確認（上記Widget Keys一覧参照）
  3. scroll_to で画面外のウィジェットをスクロール

### アプリクラッシュ
- **対策:**
  1. get_logs でスタックトレース確認
  2. stop_app → launch_app で再起動

### Marionette MCP Tips
- `tap`: `key` > `text` > `coordinates` の優先順位で指定
- `enter_text`: key でテキストフィールドを指定する
- `get_logs`: Marionette接続後のログのみ取得。起動時ログは `get_app_logs` (dart-mcp) で取得
- `hot_reload`: const定義の変更やdependency更新には非対応 (hot_restart が必要)

### Dart MCP Tips
- `launch_app`: root は絶対パス。返り値のPIDを保存
- `list_devices`: 起動中のデバイスのみ表示される
- `stop_app`: launch_app で取得したPIDを渡す

## クリーンアップ

```
1. mcp__dart-mcp__stop_app (pid指定)
2. Bridge実行中なら: lsof -ti :8765 | xargs kill
```
