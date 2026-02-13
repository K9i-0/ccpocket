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

## 機能面

### 履歴復元 (`get_history`)
- 進捗: `resume_session` の Codex 分岐とログ復元実装を追加（2026-02-13）
- Codexセッションの `get_history` は一部未完（復元経路の実機検証・不足ケース確認が必要）
- Codex SDK に過去のスレッドメッセージを取得する API があるか要調査
- 現状: アプリ再起動やセッション再表示で過去メッセージが消える

### セッション一覧での Codex 表示
- `SessionInfo.provider` フィールドは存在するが、UIに未反映
- セッション一覧でアイコンやラベルで Claude / Codex を区別すべき

### ~~モデル選択 UI の改善~~ ✅ 完了 (2026-02-13)
- ドロップダウン化済み（`gpt-5.3-codex`, `gpt-5.3-codex-spark`, `gpt-5.2-codex`, `gpt-5.1-codex-max` + Default）
- `SandboxMode` / `ApprovalPolicy` ドロップダウンも同時追加

### セッション再接続 (resume)
- `codex.resumeThread(threadId)` で再接続可能だが、未テスト
- Running セッションをタップした場合のフローで検証が必要

## テスト

### Bridge ユニットテスト
- `codex-process.ts` のユニットテスト未追加
- `session.ts` の Codex パスのテスト未追加
- Codex SDK のモックが必要

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
1. セッション一覧での provider 可視化（アイコン/ラベル）
2. Bridge の Codex 系ユニットテスト追加
3. 履歴復元の実機検証・不足ケース修正
