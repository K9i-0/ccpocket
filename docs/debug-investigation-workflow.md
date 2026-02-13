# Debug Investigation Workflow

チャット画面の不具合（ダイアログ未表示、承認状態の不整合、ストリーミング途切れ等）を
エージェントに調査させやすくするためのワークフロー。

## 目的

1. ログが不足して原因追跡できない状態を減らす
2. 1セッション分の再現材料を短時間で収集できるようにする
3. エージェントに渡す情報をワンタップで共有できるようにする

## 実装済みスコープ

### 1) ログ充実（Debug Trace）

Bridge Server がセッション単位で以下を時系列記録する。

- Client -> Bridge の操作イベント（`input`, `approve`, `reject`, `answer` など）
- Bridge -> Client の送信イベント（`assistant`, `permission_request`, `result`, `status` など）
- セッション制御イベント（`session_created`, `stop_session`, `get_history` など）

記録形式は metadata 中心（本文全文ではなく要約）:

- `ts` (ISO8601)
- `sessionId`
- `direction` (`incoming` / `outgoing` / `internal`)
- `channel` (`ws` / `session` / `bridge`)
- `type`
- `detail` (短い要約)

Debug Trace はディスクにも永続化される。

- 保存先: `~/.ccpocket/debug/traces/<sessionId>.jsonl`
- 1行1イベント(JSONL)

### 2) セッション再現材料（Debug Bundle）

Bridge の `get_debug_bundle` で以下をまとめて返す。

- セッション基本情報（provider, status, projectPath, worktree情報）
- `pastMessageCount`
- in-memory history の要約 (`historySummary`)
- Debug Trace (`debugTrace`)
- 永続トレースファイルパス (`traceFilePath`)
- 再現レシピ (`reproRecipe`)
  - `startBridgeCommand`
  - `wsUrlHint`
  - `resumeSessionMessage`
  - `getHistoryMessage`
  - `getDebugBundleMessage`
  - `notes`
- エージェント向け調査プロンプト (`agentPrompt`)
- 現在の git diff (`diff`, `diffError`)
- 保存済みbundle JSONファイルパス (`savedBundlePath`)

bundle は取得時にディスク保存される。

- 保存先: `~/.ccpocket/debug/bundles/<sessionId>-<timestamp>.json`

### 3) エージェント共有

Flutter の Chat / Codex Chat から Debug Bundle を取得し、
AIエージェント向けの調査プロンプトをクリップボードへコピーできるようにする。

- AppBar に「Copy for Agent」アクションを追加
- コピー内容は軽量な調査依頼テンプレート（sessionId, path, repro情報, 変更ファイル）を優先
- `savedBundlePath` / `traceFilePath` が取得できる場合は、AIに「そのファイルを読む」前提で案内
- パスが取れない場合のみ fallback として bundle JSON を同梱
- 成功/失敗は SnackBar で通知

## 次フェーズ候補

- 完全な replay ランナー（step実行、速度変更、ブレークポイント）
- PII マスキングルールの強化（現状は要約中心でリスク低減）
- 共有前プレビューでの赤入れ/伏せ字編集

## 運用

不具合発生時は次の手順:

1. 該当チャット画面で `Copy for Agent` を実行
2. コピーされた調査プロンプトをエージェントに貼り付け
3. 追加で必要なら同一時点のスクリーンショットを添付
4. エージェントは `agentPrompt` と `reproRecipe` を使って再現し、`historySummary` + `debugTrace` + `diff` から再現仮説を立てる
