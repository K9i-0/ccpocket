## トラブルシューティング

### "Connection refused" (Marionette接続失敗)
- **原因:** アプリが完全に起動していない、またはwsUriが不正
- **対策:** launch_app 後に5秒以上待ってから get_app_logs でwsUriを再取得。wsUriが取得できない場合はビルド中なのでさらに待つ

### "Widget not found" (タップ失敗)
- **原因:** ウィジェットが未描画、キー名の誤り、または画面外にある
- **対策:**
  1. `get_interactive_elements` で現在表示中の要素を確認
  2. [Widget Keys一覧](mock-and-keys.md)でキー文字列のスペルを確認
  3. `scroll_to` で画面外のウィジェットを表示させる

### アプリクラッシュ
- **対策:**
  1. `get_logs` でスタックトレースを確認
  2. `stop_app` → `launch_app` で再起動
  3. 再起動後は [startup.md](startup.md) のVM Service URI取得からやり直す

### Marionette Tips
- `tap`: `key` > `text` > `coordinates` の優先順位で指定する。keyが最も安定
- `enter_text`: key パラメータでテキストフィールドを指定する
- `get_logs`: Marionette接続後のログのみ取得。起動時のログは `get_app_logs` (dart-mcp) で取得
- `hot_reload`: UIの微調整に便利。ただしconst定義の変更やdependency更新には `hot_restart` が必要
- `long_press`: `InkWell.onLongPress` や `GestureDetector.onLongPress` に繋がる。CC Pocket の recent/running session card では長押しでアクションシートを開ける
- `long_press` の検証対象は実画面を優先する。ストアスクリーンショット用のモック `Session List` は `onLongPressRecentSession` / `onLongPressRunningSession` が no-op のため、長押し挙動の確認には使えない
- `swipe`: `Slidable` と `Dismissible` の両方で有効。CC Pocket では recent session card のアーカイブ action pane 表示や、Git画面の stage / unstage / revert に使える
- `swipe` 実行後は必ず `get_interactive_elements` を再取得して、action pane が開いたか、対象セルが横移動したかを確認する
- クリップボード系アクションは Marionette から直接読み出せない。`copy_resume_command` のような機能は、長押しでシートが出ること、対象項目をタップできること、シートが閉じることをもってUIフロー確認とする
- recent session card は `Slidable` の key が要素一覧に出るので、`swipe(key: "recent_session_<id>", direction: "left")` のように key 指定で狙うのが安定
- 長押し対象に key が無い場合は、まず `get_interactive_elements` で bounds を確認し、`long_press(coordinates: {x, y})` を使うと成功率が高い

### Dart MCP Tips
- `launch_app`: root は絶対パスで指定。返り値のPIDは必ず保存する
- `list_devices`: 起動中のデバイスのみ表示される
- `stop_app`: launch_app で取得したPIDを渡す
