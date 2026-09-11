## E2E テスト (Bridge必要)

Bridge Server を経由して実際のClaude Code / Codexセッションでの動作を検証する。

### ワークフロー

```bash
# Step 1: テスト用 Bridge 起動（ポート8766、本番8765に影響なし）
cd <プロジェクトルート>
BRIDGE_PORT=8766 npm run bridge
# 長時間実行を管理できるツールで起動し、その実行セッションIDを保存する。

# Step 2: アプリ起動（references/startup.mdに従う）

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
#   保存した実行セッションを停止し、そのBridgeと子プロセスの終了を確認する
```

### Bridge接続時の注意

- テスト用Bridge（8766）を使うことで本番Bridge（8765）に接続しているiPhoneアプリに影響を与えない
- Bridgeが起動していない状態で接続しようとすると「Connection refused」になる。Bridgeの起動を先に確認すること

ポート番号だけを条件に一括killしない。既存プロセスが8766を使用していたら別ポートを選ぶ。npmラッパーのPIDだけをkillすると子プロセスが残る場合があるため、実行ツールのセッション停止・割り込みで終了させ、残存があれば自分が起動したプロセスと確認できたものだけ停止する。
