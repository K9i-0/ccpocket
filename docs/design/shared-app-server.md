# Shared App Server (Codex TUI Session Joining)

## Status: Shelved (revalidated 2026-05-06)

Codex側の基盤が未成熟のため、実用レベルに達しないと判断し一旦見送り。
ブランチ `feat/shared-app-server` に実装を残す。

2026-05-06 に `openai/codex` 最新 `origin/main` (`332b8b2c74 fix build (#21261)`) を確認したが、
再開条件はまだ満たしていない。

- WebSocket transport は引き続き `experimental / unsupported`
- `codex --remote` は CLI オプションとして残っており、`--remote-auth-token-env` も追加済み
- WebSocket 認証 (`--ws-auth ...`) と大きめの outbound buffer は追加されたが、本番利用可能という扱いではない
- `thread/resume` は running thread でも最終的に persisted rollout/history を読むため、`thread/start` 直後の合流にはまだ弱い
- app-server protocol に per-turn の client/owner/originator は見当たらず、CC Pocket と TUI の二重参加時に「誰の入力か」を区別する根拠がない

結論: いま再開するなら、ユーザー向け機能ではなく `dev-only` の検証ブランチで実験を継続するのが妥当。

## 概要

CC PocketのBridgeが `codex app-server --listen ws://127.0.0.1:<port>` でWebSocketトランスポートを使用し、Codex TUI (`codex --remote ws://...`) が同じセッションに合流できるようにする機能。

## アーキテクチャ

```
Flutter App <--WebSocket--> Bridge <--WebSocket--> codex app-server (ws://PORT)
                                                        ^
                                                        |
                                              Codex TUI (codex --remote ws://PORT)
```

- Bridge: stdio の代わりに WebSocket で app-server と通信
- app-server: 複数クライアントの接続を受け付け、イベントをブロードキャスト
- TUI: `codex --remote ws://host:port` で外部 app-server に接続

## 実装済みの内容

### Bridge (TypeScript)

- `codex-process.ts`: WebSocket トランスポート追加 (ポート 19800-19899 自動検出)
- `parser.ts`: `sharedAppServer` / `remoteUrl` プロトコル拡張
- `websocket.ts`: セッション作成時に `remoteUrl` を伝播

### Flutter App

- `NewSessionSheet`: "Shared App Server" トグル (Experimental 表記)
- `CodexSessionScreen`: "Copy Remote Command" メニュー (`codex --remote ws://...` をコピー)
- `ChatSessionState`: `remoteUrl` フィールド追加
- l10n: en/ja/zh 対応

### 検証スクリプト

- `scripts/verify-shared-app-server.mjs`: 基本的な thread discovery / resume / broadcast の検証
- `scripts/verify-bidirectional.mjs`: 双方向通信の検証 (問題発見用)

## 確認済みの問題点

### 1. thread/resume が thread/start 直後に失敗する

`thread/start` した直後は rollout ファイルがディスクにフラッシュされていないため、別クライアントから `thread/resume` すると `"no rollout found"` エラーになる。最初の `turn/start` が完了してrolloutが書き込まれるまで待つ必要がある。

- TUI からの合流タイミングが制限される
- CC Pocket側でワークアラウンドは可能だが、UXが悪い

2026-05-06 再確認:

- `thread/resume` は running thread の fast path を持つ
- ただしその fast path でも `read_stored_thread_for_resume(... include_history=true)` を呼び、persisted history を要求する
- そのため「app-server メモリ上には thread があるが rollout がまだない」状態は、依然として合流失敗リスクが残る

### 2. 双方向のメッセージ表示が正しく動作しない

実機テストで確認:

- **CLI (TUI) のメッセージが CC Pocket に表示されない** — TUI が `turn/start` したイベントが Bridge に届かない、または届いても正しく処理されていない可能性
- **CC Pocket で送ったメッセージが CLI にエージェントのメッセージとして表示される** — ユーザー入力とエージェント出力の区別が付かない

app-server のブロードキャスト自体は全 subscriber に送信される仕組みだが、各クライアントが「誰が開始した turn か」を区別する仕組みが不十分。

2026-05-06 再確認:

- `TurnStartParams` / `TurnStartedNotification` / `ThreadItem.UserMessage` に per-turn の client id / originator / owner はない
- `Thread.source` は thread 単位の由来 (`cli`, `vscode`, `exec`, `appServer` 等) で、同一 thread に参加する複数クライアントの区別には使えない
- `responsesapiClientMetadata` は `turn/start` に追加されているが experimental で、app-server 通知に戻ってくる ownership 情報ではない
- Bridge 側だけで解決する場合、入力を楽観的に local echo し、同じ `userMessage` item を dedupe する程度のワークアラウンドになる

### 3. `codex --remote` が未ドキュメント・Experimental

- developers.openai.com に `--remote` オプションの記載なし
- WebSocket トランスポート自体が "experimental and unsupported" 扱い
- 将来のリリースで削除される可能性がある

2026-05-06 再確認:

- CLI root/TUI 用オプションとして `--remote ws://...|wss://...` は存在する
- `--remote-auth-token-env` が追加され、Bearer token を WebSocket handshake に付与できる
- app-server README は `--listen ws://IP:PORT` を引き続き experimental / unsupported と明記している
- `codex --remote` は interactive TUI 専用で、非 interactive subcommand では拒否される

### 4. WebSocket transport の安定性

2026-04 以降、`#18203` の remote TUI 切断問題に対して `#19246` で WebSocket outbound buffer が `32 * 1024` に拡大された。
これは通常の出力バーストには効くが、transport router の基本動作は「disconnectable connection の writer queue が full なら切断」のまま。

- 短い turn / 通常の tool output では以前より安定している可能性が高い
- 長時間・大量出力・遅いモバイル回線では依然として切断リスクがある
- CC Pocket で使うなら、再接続・再 subscribe・missed event recovery を前提に設計する必要がある

## 2026-05-06 検証メモ

参照した upstream:

- `openai/codex` local clone: `origin/main` = `332b8b2c74 fix build (#21261)`
- 関連差分: `HEAD..origin/main` は `codex-rs/tui/src/resume_picker.rs` の fixture 修正のみで、app-server / protocol / CLI には影響なし
- app-server README: WebSocket transport は `experimental / unsupported`
- app-server protocol:
  - `ThreadStartParams`: `permissions`, `environments`, `dynamicTools`, `experimentalRawEvents` などが追加
  - `ThreadResumeParams`: `history`, `path`, `permissions`, `excludeTurns` などが追加
  - `TurnStartParams`: `responsesapiClientMetadata`, `environments`, `permissions`, `collaborationMode` などが追加
  - `ThreadItem.UserMessage`: `id` と `content` のみで client owner 情報なし
- TUI remote:
  - `codex --remote` は `ws://host:port` / `wss://host:port` を受け付ける
  - remote auth token は `wss://` または loopback `ws://` のみ許可

## 再開する場合の実験プラン

ユーザー向け UI 復活前に、まず Bridge 側だけで dev-only 検証を行う。

1. `feat/shared-app-server` を最新 `main` に rebase
2. app-server 起動時に loopback + token file を使う
   - `codex app-server --listen ws://127.0.0.1:<port> --ws-auth capability-token --ws-token-file <file>`
   - TUI 側は `CODEX_REMOTE_AUTH_TOKEN=<token> codex --remote ws://127.0.0.1:<port> --remote-auth-token-env CODEX_REMOTE_AUTH_TOKEN`
3. `thread/start` 直後、`turn/start` 前、`turn/completed` 後の各タイミングで `thread/resume` を検証
4. TUI 起点 `turn/start` が Bridge subscriber に届くか、Bridge 起点 `turn/start` が TUI に user message として描画されるかを再確認
5. Bridge 側で `userMessage.id` dedupe と local echo 抑制が可能か検証
6. 大量出力 prompt で WebSocket 切断が再現するか確認
7. 失敗時に `thread/read` / `thread/turns/list` / `thread/resume excludeTurns` で復旧できるか確認

## 再開の条件

以下が満たされた場合に再検討:

1. Codex app-server の WebSocket トランスポートが安定版になる
2. `thread/resume` が `thread/start` 直後でも rollout 依存なしで動作する
3. 複数クライアント間の turn ownership が明確に区別できる仕組みが導入される
4. `codex --remote` が公式ドキュメントに掲載される
5. WebSocket 切断後の missed event recovery が app-server protocol として実装される、または Bridge 側で安全に復旧できることを確認する
