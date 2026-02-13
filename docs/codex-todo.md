# Codex 対応: やり残し・今後の改善

## 機能面

### 履歴復元 (`get_history`)
- Codexセッションの `get_history` は未実装
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
