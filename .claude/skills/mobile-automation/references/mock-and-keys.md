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
1. アプリ起動（[startup.md](startup.md)）
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
