---
name: mobile-automation
description: MCP (dart-mcp + Marionette) を使ったFlutterアプリのE2E自動化・UI検証ガイド。シミュレーターでのUI動作確認、モックプレビュー検証、Bridge経由のE2Eテスト、スクリーンショット撮影など、アプリの動作検証が必要なときに使う。「動作確認して」「UIを検証して」「E2Eテスト」「シミュレーターで確認」「モックで確認」と言われたときや、UI変更後の検証フェーズで使用すること。
---

# Mobile Automation

dart-mcp と Marionette MCP を使ったFlutterアプリのUI検証・E2E自動化ガイド。

## デフォルト設定

特別な指示がない限り、以下をデフォルトとして使う:

- **デバイス**: iOSシミュレーター（`flutter devices` で確認し、iPhone Simulator を選択）
- **Bridge ポート**: `8766`（テスト用。本番の8765と分離してテストできる）
- **プロジェクトルート**: リポジトリルート（`git rev-parse --show-toplevel` で取得）
- **アプリルート**: `<プロジェクトルート>/apps/mobile`

ユーザーが実機やポート8765を指定した場合はそちらに従う。

## サブエージェント活用

E2E検証は **`e2e-verifier` サブエージェント** に委譲すると効率的。独立したコンテキストで検証するため、実装バイアスなく客観的に動作を確認できる。

```
Agent tool で e2e-verifier サブエージェントを起動:

subagent_type: e2e-verifier

プロンプト:
---
アプリが起動済みです。以下の検証を実施してください。

## 検証内容
[検証したい項目を記述]

## 接続情報
- VM Service URI: [wsUri]
- PID: [pid]

日本語で回答してください。
---
```

**使い分け:**
- 単純なUI確認（要素の存在チェック、1-2画面の確認）→ 直接MCP操作
- 包括的なE2E検証（複数画面のフロー、回帰テスト）→ `e2e-verifier` サブエージェントに委譲

## アプリ起動ワークフロー

### Step 1: デバイス確認

```bash
flutter devices
```

出力からシミュレーターのデバイスIDを確認する（例: `1A2B3C4D-5E6F-...`）。

### Step 2: アプリ起動

```
mcp__dart-mcp__launch_app
  root: <アプリルートの絶対パス>
  target: lib/main.dart
  device: <シミュレーターのデバイスID>
```

返り値の **pid** を控える（以降の全ステップで必要）。

### Step 3: 待機

**5秒待機する。** Xcodeビルド + シミュレーターへのデプロイが完了するまで待つ必要がある。初回ビルド時は10秒程度かかることもある。

### Step 4: VM Service URI 取得

```
mcp__dart-mcp__get_app_logs
  pid: <Step 2のpid>
```

ログ出力から `app.debugPort` イベントを探し、**wsUri** を抽出する:
```json
"params": { "wsUri": "ws://127.0.0.1:XXXXX/YYYY=/ws" }
```

wsUri が見つからない場合はビルドがまだ完了していない。5秒待って再度 `get_app_logs` を呼ぶ。

### Step 5: Marionette 接続

```
mcp__marionette__connect
  uri: <wsUri>
```

Marionette MCP は自動接続しないため、この手動 `connect` が必須。省略するとその後のUI操作が全て失敗する。

### Step 6: 接続確認

```
mcp__marionette__get_interactive_elements
```

UI要素の一覧が返れば接続成功。

## CLI vs MCP の使い分け

**原則: DTD/VM Service接続が必要な操作はMCP、それ以外はCLI**

MCP が必要な操作はアプリのランタイムに接続して情報を取得・操作するもの（起動、停止、ホットリロード、UI操作、ログ取得など）。一方、ビルドツールや静的解析のようにアプリのランタイムに依存しない操作はCLIの方が速くて確実。

### MCP 操作一覧

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
| アプリログ | Marionette | `get_logs` |
| スクリーンショット | Marionette | `take_screenshots` |

### CLI 操作一覧

| 操作 | コマンド |
|------|---------|
| デバイス一覧 | `flutter devices` |
| テスト実行 | `cd apps/mobile && flutter test` |
| 静的解析 | `dart analyze apps/mobile` |
| フォーマット | `dart format apps/mobile` |
| 依存関係 | `cd apps/mobile && flutter pub get` |

## ツール優先順位

UI検証時は以下の順序で使う。スクリーンショットはトークンを大量に消費するため、テキストベースの検証を優先する:

1. **`get_interactive_elements`** — 最優先。画面上のタップ可能なボタン・入力欄の一覧を取得。画面遷移後は必ずこれを呼んで現在の状態を確認する
2. **`get_logs`** — エラー確認。"ERROR", "Exception" でフィルタして問題がないか確認
3. **`tap`** / **`enter_text`** / **`scroll_to`** — UI操作。key指定を優先し、textやcoordinatesは代替手段
4. **`take_screenshots`** — 最後の手段。レイアウトやビジュアルの確認が本当に必要な場合のみ。1セッションで3-5枚を目安に

## Widget Keys 一覧

各画面のインタラクティブ要素に付与されたValueKey。`tap` や `enter_text` では key 指定が最も確実。

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

Bridge Server なしでUIの見た目と挙動を確認できる。AppBarの「Mock Preview」ボタンから10種のモックシナリオにアクセスできる。

### ワークフロー

```
1. アプリ起動 (上記ワークフロー)
2. get_interactive_elements → ホーム画面の要素確認
3. tap key: "mock_preview_button" → モックギャラリーを開く
4. tap text: "<シナリオ名>" → 目的のシナリオを選択
5. get_interactive_elements → チャットUIの要素確認
6. get_logs → エラーがないか確認
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

**クイックテスト推奨:** Approval Flow, Streaming, Plan Mode（主要UIパターンをカバー）

## E2E テスト (Bridge必要)

Bridge Server を経由して実際のClaude Code / Codexセッションでの動作を検証する。

### ワークフロー

```bash
# Step 1: テスト用 Bridge 起動（ポート8766、本番8765に影響なし）
cd <プロジェクトルート> && BRIDGE_PORT=8766 npm run bridge &

# Step 2: アプリ起動（上記「アプリ起動ワークフロー」に従う）

# Step 3: サーバー接続
#   get_interactive_elements で接続フォームを確認
#   enter_text key: "server_url_field" text: "ws://localhost:8766"
#   tap key: "connect_button"

# Step 4: セッション作成
#   tap key: "new_session_fab"
#   dialog_project_path でパスを選択
#   tap key: "dialog_start_button"

# Step 5: メッセージ送信 & 検証
#   enter_text key: "message_input" text: "<テスト用プロンプト>"
#   tap key: "send_button"
#   get_interactive_elements で応答UIを確認
#   承認バーが表示されたら approve/reject の動作を検証

# Step 6: クリーンアップ
#   mcp__dart-mcp__stop_app (pid指定)
#   lsof -ti :8766 | xargs kill
```

### Bridge接続時の注意

- テスト用Bridge（8766）を使うことで本番Bridge（8765）に接続しているiPhoneアプリに影響を与えない
- Bridgeが起動していない状態で接続しようとすると「Connection refused」になる。Bridgeの起動を先に確認すること

## トラブルシューティング

### "Connection refused" (Marionette接続失敗)
- **原因:** アプリが完全に起動していない、またはwsUriが不正
- **対策:** launch_app 後に5秒以上待ってから get_app_logs でwsUriを再取得。wsUriが取得できない場合はビルド中なのでさらに待つ

### "Widget not found" (タップ失敗)
- **原因:** ウィジェットが未描画、キー名の誤り、または画面外にある
- **対策:**
  1. `get_interactive_elements` で現在表示中の要素を確認
  2. 上記Widget Keys一覧でキー文字列のスペルを確認
  3. `scroll_to` で画面外のウィジェットを表示させる

### アプリクラッシュ
- **対策:**
  1. `get_logs` でスタックトレースを確認
  2. `stop_app` → `launch_app` で再起動
  3. 再起動後は Step 3 (wsUri取得) からやり直す

### Marionette Tips
- `tap`: `key` > `text` > `coordinates` の優先順位で指定する。keyが最も安定
- `enter_text`: key パラメータでテキストフィールドを指定する
- `get_logs`: Marionette接続後のログのみ取得。起動時のログは `get_app_logs` (dart-mcp) で取得
- `hot_reload`: UIの微調整に便利。ただしconst定義の変更やdependency更新には `hot_restart` が必要

### Dart MCP Tips
- `launch_app`: root は絶対パスで指定。返り値のPIDは必ず保存する
- `list_devices`: 起動中のデバイスのみ表示される
- `stop_app`: launch_app で取得したPIDを渡す

## クリーンアップ

検証完了後は必ずリソースを解放する:

```
1. mcp__dart-mcp__stop_app (pid指定) → アプリ停止
2. Bridge実行中なら: lsof -ti :8766 | xargs kill → テスト用Bridge停止
```
