# Shared App Server (Codex TUI Session Joining)

## Status: Shelved (2026-04-06)

Codex側の基盤が未成熟のため、実用レベルに達しないと判断し一旦見送り。
ブランチ `feat/shared-app-server` に実装を残す。

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

### 2. 双方向のメッセージ表示が正しく動作しない

実機テストで確認:
- **CLI (TUI) のメッセージが CC Pocket に表示されない** — TUI が `turn/start` したイベントが Bridge に届かない、または届いても正しく処理されていない可能性
- **CC Pocket で送ったメッセージが CLI にエージェントのメッセージとして表示される** — ユーザー入力とエージェント出力の区別が付かない

app-server のブロードキャスト自体は全 subscriber に送信される仕組みだが、各クライアントが「誰が開始した turn か」を区別する仕組みが不十分。

### 3. `codex --remote` が未ドキュメント・Experimental

- developers.openai.com に `--remote` オプションの記載なし
- WebSocket トランスポート自体が "experimental and unsupported" 扱い
- 将来のリリースで削除される可能性がある

## 再開の条件

以下が満たされた場合に再検討:
1. Codex app-server の WebSocket トランスポートが安定版になる
2. `thread/resume` が thread/start 直後でも動作する (rollout の遅延フラッシュ問題が解消)
3. 複数クライアント間の turn ownership が明確に区別できる仕組みが導入される
4. `codex --remote` が公式ドキュメントに掲載される
