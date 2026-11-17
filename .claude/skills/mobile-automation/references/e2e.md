## E2E テスト (Bridge必要)

Bridge Server を経由して実際のClaude Code / Codexセッションでの動作を検証する。テスト用Bridgeとシミュレーターは [`scripts/e2e-env.sh`](../../../../scripts/e2e-env.sh) で用意する。チェックアウト（メイン・worktree）ごとに別ポート・別シミュレーターになるので、並列でもそのまま使える。

### ワークフロー

```bash
# Step 1: テスト用 Bridge 起動（チェックアウトのルートで）
bash scripts/e2e-env.sh bridge
# 8766, 8769-8799 から空きポートを選び、前景実行する（exec）。
# 長時間実行を管理できるツールで起動し、その実行セッションIDと、出力1行目のポートを控える。
# 同時に別エージェントが同じポートを取ると EADDRINUSE で終了するので、再実行して次のポートを使う。

# Step 2: シミュレーター準備
bash scripts/e2e-env.sh sim
# このチェックアウト専用の "ccpocket-e2e-<ディレクトリ名>" を新規作成（既存なら再利用）し、
# simslim があれば slim 化して起動する。最終行が UDID。clone は元端末の接続先などを引き継ぐので使わない。

# Step 3: アプリ起動（references/startup.md に従い、device に Step 2 の UDID を指定）

# Step 4: Bridge 接続（ディープリンクで URL と APIキーを渡す）
bash scripts/e2e-env.sh connect <UDID> <Step 1のポート>
# 新規シミュレーターでは初回だけ iOS の「“CC Pocket”で開きますか?」が出る（下記）。
# 続けて通知の権限ダイアログが出たら alert accept で許可する。

# Step 5: セッション作成
#   tap key: "new_session_fab"
#   dialog_project_path でパスを選択
#   tap key: "dialog_start_button"

# Step 6: メッセージ送信 & 検証
#   enter_text key: "message_input" text: "<テスト用プロンプト>"
#   tap key: "send_button"
#   get_interactive_elements で応答UIを確認
#   承認バーが表示されたら approve/reject の動作を検証

# Step 7: クリーンアップ
#   mcp__dart-mcp__stop_app (pid指定)
#   保存した実行セッションを停止し、そのBridgeと子プロセスの終了を確認する
#   worktree を片付けるときは bash scripts/e2e-env.sh sim-delete でシミュレーターも削除する
```

### 初回の「開く」確認

`simctl openurl` で送ったディープリンクには、シミュレーターごとに初回だけ iOS の確認が出る。日本語ロケールの「開く」は `alert accept` が認識しないので、アプリを指定したセッションで ref を押す。`--udid` を付けるので、複数台が起動していても対象を取り違えない。`flutter run` の接続は切れない（2026-11 確認）。

```bash
mise exec -- agent-device open com.k9i.ccpocket --platform ios --udid <UDID>
mise exec -- agent-device snapshot        # [button] "開く" の @ref を確認
mise exec -- agent-device press @e3
mise exec -- agent-device close
mise exec -- agent-device alert accept --platform ios --udid <UDID>   # 続く通知ダイアログ
```

一度許可したシミュレーターでは確認が出ず、`connect` だけで接続先が切り替わる。

### 並列実行

worktree ごとに Step 1〜2 を行えば、Bridge のポートとシミュレーターが分かれる。

- Bridge はそのチェックアウトのコードで起動する。worktree の変更を検証するときは worktree のルートで `bridge` を実行する。
- APIキー（`~/.ccpocket/bridge-api-key`）は全 Bridge で共通なので、`connect` はポートだけ変えればよい。ポートごとに分かれているのは pairing secret と prompt history。`project-history.json`・ギャラリー・アーカイブは本番 Bridge も含めて共有される。
- slim 化したシミュレーターは iOS 27.2 で1台あたり約3〜3.5GB（stock は約10GB）。台数はメモリの空きで決める。
- slim では Push通知（`apsd`）・iCloud・Spotlight などが止まる。それらを検証するときは `simslim on <udid> --except store` などで残すか、stock のシミュレーターを使う。権限ダイアログと agent-device の操作は slim でも動く。
- iOS ビルド（xcodebuild）が同時に走ると CPU が詰まりやすい。急がない場合はビルドをずらし、起動後の操作を並列にする。

### Bridge接続時の注意

- 本番Bridge（8765）とは別ポートなので、本番に接続している iPhone アプリには影響しない。本番を停止・再起動しない。
- Bridgeが起動していない状態で接続しようとすると「Connection refused」になる。Bridgeの起動を先に確認すること。

ポート番号だけを条件に一括killしない（並列時は他のエージェントの Bridge を止めてしまう）。npmラッパーのPIDだけをkillすると子プロセスが残る場合があるため、実行ツールのセッション停止・割り込みで終了させ、残存があれば自分が起動したプロセスと確認できたものだけ停止する。
