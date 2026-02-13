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

## 機能面

### 履歴復元 (`get_history`)
- 進捗: `resume_session` の Codex 分岐とログ復元実装を追加（2026-02-13）
- Codexセッションの `get_history` は一部未完（復元経路の実機検証・不足ケース確認が必要）
- Codex SDK に過去のスレッドメッセージを取得する API があるか要調査
- 現状: アプリ再起動やセッション再表示で過去メッセージが消える

### セッション一覧での Codex 表示
- `SessionInfo.provider` フィールドは存在するが、UIに未反映
- セッション一覧でアイコンやラベルで Claude / Codex を区別すべき

### モデル選択 UI の改善
- 現在は自由テキスト入力
- Codex の利用可能モデル一覧をドロップダウンで表示する方が良い
- 利用可能モデル (2025時点): `gpt-5.3-codex`, `gpt-5.3-codex-spark`, `gpt-5.2-codex`, `gpt-5.1-codex-max` 等
- 参考: https://developers.openai.com/codex/models/

### セッション再接続 (resume)
- `codex.resumeThread(threadId)` で再接続可能だが、未テスト
- Running セッションをタップした場合のフローで検証が必要

## テスト

### Bridge ユニットテスト
- `codex-process.ts` のユニットテスト未追加
- `session.ts` の Codex パスのテスト未追加
- Codex SDK のモックが必要

## 技術的負債

### デバッグ用テストボタン
- `session_list_screen.dart` に `_testCodexSession()` が残っている（`kDebugMode` ガード付き）
- プロジェクトパスがハードコード (`/Users/k9i-mini/Workspace/ccpocket`)
- 不要になったら削除する

### Codex SDK のバージョン固定
- `@openai/codex-sdk: ^0.101.0` — SDK がまだ初期段階で破壊的変更の可能性あり
- 安定版リリース後にバージョン戦略を見直す

## 引き継ぎメモ（次の開発）

### 次テーマ: Codex セッション開始時の設定
- 次の実装は「Codex セッション開始時に必要な設定を UI/プロトコルで明示的に渡す」ことを優先する
- 想定設定:
  - `sandboxMode` (`read-only` / `workspace-write` / `danger-full-access`)
  - `approvalPolicy` (`never` / `on-request` / `on-failure` / `untrusted`)
  - `model`（選択 UI 改善と合わせて）

### 目的
- セッション開始時の挙動をユーザーが予測可能にする
- 実行環境差異（特に `.git` 書き込み可否）による混乱を減らす

### 受け入れ条件
- New Session ダイアログで Codex 向け開始設定を選択できる
- `ClientMessage.start` に設定が載り、bridge 側で `CodexStartOptions` に反映される
- 選択値が実行ログ（または system message）で確認できる
- 最低限のテスト（parser / start 経路）が追加される
