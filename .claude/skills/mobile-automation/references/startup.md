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

起動ログでビルドとデプロイの完了を確認する。進行中なら短い間隔で再確認し、エラーがあれば先に調べる。

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
| ダブルタップ | Marionette | `double_tap` |
| 長押し | Marionette | `long_press` |
| テキスト入力 | Marionette | `enter_text` |
| スワイプ/ドラッグ | Marionette | `swipe` |
| ピンチズーム | Marionette | `pinch_zoom` |
| 戻る操作 | Marionette | `press_back_button` |
| スクロール | Marionette | `scroll_to` |
| アプリログ | Marionette | `get_logs` |
| スクリーンショット | Marionette | `take_screenshots` |
| カスタム拡張一覧 | Marionette | `list_custom_extensions` |
| カスタム拡張呼び出し | Marionette | `call_custom_extension` |

### CLI 操作一覧

| 操作 | コマンド |
|------|---------|
| デバイス一覧 | `flutter devices` |
| テスト実行 | `cd apps/mobile && flutter test` |
| 静的解析 | `dart analyze apps/mobile` |
| フォーマット | `dart format apps/mobile` |
| 依存関係 | `cd apps/mobile && flutter pub get` |
