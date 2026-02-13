# Codex 対応: やり残し・今後の改善

## 進捗メモ (2026-02-13)

### 実行計画
1. 履歴復元/再接続の完成（最優先）
2. セッション一覧の provider 可視化
3. モデル選択 UI をドロップダウン化
4. Bridge の Codex 系ユニットテスト追加
5. デバッグボタン削除と SDK バージョン戦略整理

### 現在の着手
- **1. 履歴復元/再接続** を開始
- 方針:
  - `resume_session` に provider 分岐を追加（Claude/Codex）
  - Codex セッションログ (`~/.codex/sessions/...jsonl`) から past history を復元
  - `get_history` で復元済みメッセージを返せる状態を保証

### 実装ログ
- 2026-02-13:
  - `resume_session` に `provider` を追加し、Codex 分岐を実装
  - Codex ログ (`~/.codex/sessions/**/*.jsonl`) から履歴復元する処理を bridge に追加
  - recent sessions へ Codex セッションを統合（`provider: "codex"` を付与）
  - mobile 側の `resume_session` 送信に `provider` を追加
  - `~/.claude/projects` が存在しない環境でも Codex recent が取得できるよう `getAllRecentSessions` の早期 return を修正
  - Codex recent / history 復元のユニットテストを追加
  - Codex セッション開始設定 UI 追加: `SandboxMode` / `ApprovalPolicy` enum + ドロップダウン
  - モデル選択を自由テキスト → ドロップダウン化 (gpt-5.3-codex 等)
  - デバッグ用 `_testCodexSession()` ボタン削除
- 2026-02-13 (追加):
  - `resume_session` 時の即時 `past_history` 送信を廃止し、履歴配信を `get_history(sessionId)` 経路に統一
  - mobile の `pendingPastHistory` バッファ経路を削除（重複表示リスクのある二重経路を解消）
  - Codex 履歴ファイル探索を厳密化（`threadId` の曖昧サフィックス一致を除去）
  - Bridge テスト追加: `codex-process.test.ts` / `session.test.ts` / `websocket.test.ts`
  - Mobile/Bridge のテストを実行し回帰なしを確認

## 機能面

### 履歴復元 (`get_history`)
- 進捗: `resume_session` の Codex 分岐とログ復元実装を追加（2026-02-13）
- Codexセッションの `get_history` は一部未完（復元経路の実機検証・不足ケース確認が必要）
- Codex SDK に過去のスレッドメッセージを取得する API があるか要調査
- 現状: アプリ再起動やセッション再表示で過去メッセージが消える

### セッション一覧での Codex 表示
- 進捗: `session_card.dart` で provider バッジ表示を実装済み（Codex / Claude Code）
- 残: 一覧全体での視認性・並び替え優先度など UX 調整は必要に応じて実施

### ~~モデル選択 UI の改善~~ ✅ 完了 (2026-02-13)
- ドロップダウン化済み（`gpt-5.3-codex`, `gpt-5.3-codex-spark`, `gpt-5.2-codex`, `gpt-5.1-codex-max` + Default）
- `SandboxMode` / `ApprovalPolicy` ドロップダウンも同時追加

### セッション再接続 (resume)
- `codex.resumeThread(threadId)` で再接続可能だが、未テスト
- Running セッションをタップした場合のフローで検証が必要

## テスト

### Bridge ユニットテスト
- ✅ `codex-process.ts` のユニットテスト追加済み
- ✅ `session.ts` の Codex パスのテスト追加済み
- ✅ `websocket.ts` の resume/get_history 経路テスト追加済み
- Codex SDK のモックはテスト内で実装済み

## 技術的負債

### ~~デバッグ用テストボタン~~ ✅ 削除済み (2026-02-13)
- `_testCodexSession()` と AppBar のデバッグボタンを削除

### Codex SDK のバージョン固定
- `@openai/codex-sdk: ^0.101.0` — SDK がまだ初期段階で破壊的変更の可能性あり
- 安定版リリース後にバージョン戦略を見直す

## 引き継ぎメモ（次の開発）

### ~~次テーマ: Codex セッション開始時の設定~~ ✅ 完了 (2026-02-13)
- New Session ダイアログで `sandboxMode` / `approvalPolicy` / `model` を選択可能に
- `ClientMessage.start` → Bridge `CodexStartOptions` への反映済み
- Bridge ログ (`[codex-process] Starting ...`) で選択値を確認可能
- 受け入れ条件: UI選択 ✅ / プロトコル反映 ✅ / ログ確認 ✅ / テスト（既存の Bridge テストでカバー、追加テストは次回）

### 次テーマ候補
1. 履歴復元の実機検証（最優先）
2. セッション一覧の provider UX 微調整（必要時）
3. Codex SDK バージョン戦略の見直し

### 次実装の計画（2026-02-13）
目的: アプリ再起動・再接続後でも Codex 会話履歴を確実に再表示できる状態にする。

1. 受信経路の整合性を固定する（Bridge ↔ Mobile）
- 対象: `packages/bridge/src/websocket.ts`, `apps/mobile/lib/services/bridge_service.dart`
- 作業:
  - `resume_session` 時の `past_history` / `history` / `status` の送信順と `sessionId` 付与ルールを明文化し、実装を揃える
  - `pendingPastHistory` バッファ依存の経路と `messagesForSession` 経路の二重処理・取りこぼしを確認し、どちらかに寄せる
  - Codex/Claude で挙動が分かれる箇所をコメントで明示
- 完了条件:
  - 再接続直後に履歴が 0 件になるケースが再現しない
  - 同じ履歴が二重表示されない

2. Codex 履歴復元の不足ケースを埋める
- 対象: `packages/bridge/src/sessions-index.ts`
- 作業:
  - `getCodexSessionHistory` のパース対象を再点検（空行・壊れた行・assistant 複数チャンクなど）
  - `findCodexSessionJsonlPath` の一致ロジック（threadId / file名）で誤一致・未一致ケースをテストで固定
  - 必要なら履歴復元時の最大件数や順序保証を追加
- 完了条件:
  - 手元サンプル JSONL で user/assistant の順序が安定して復元される
  - threadId 指定で誤ファイルを拾わない

3. Codex 再接続フローを実機で検証する
- 対象: `apps/mobile/lib/features/session_list/session_list_screen.dart`, `apps/mobile/lib/features/chat_codex/*`
- 作業:
  - Recent から Codex セッション再開 → 過去履歴表示 → 追加入力送信までを通し検証
  - Running セッション再オープン時の `get_history` が期待どおりか確認
  - 失敗時はログ（Bridge / Mobile）を採取して再現手順をドキュメント化
- 完了条件:
  - 3 ケース（Recent 再開 / Running 再表示 / アプリ再起動後再開）で履歴欠損なし

4. 自動テストを追加して回帰防止する
- 対象: `packages/bridge/src/session.test.ts`（新規）, `packages/bridge/src/codex-process.test.ts`（新規）, `packages/bridge/src/sessions-index.test.ts`
- 作業:
  - `session.ts` の Codex セッション作成・履歴件数計上・status 遷移のテスト追加
  - `codex-process.ts` の `start` / `resumeThread(threadId)` 呼び分けをモックで固定
  - `sessions-index.ts` の Codex 履歴復元エッジケースを追加
- 完了条件:
  - 追加テストが CI で安定通過し、履歴回りの回帰を検知できる
