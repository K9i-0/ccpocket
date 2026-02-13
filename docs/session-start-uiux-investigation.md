# Session Start UI/UX 調査メモ

> 作成日: 2026-02-14 (JST)
> 対象: セッション開始UI/UX改善 + Codex worktree resume可否

## 1. 調査対象

- Claude Code 側でセッション開始時に追加すべき項目はあるか
- Recent Sessions カード長押しで「前回と違う設定で開始」は可能か
- Codex で worktree 機能は導入できるか
- 前回セッション作成時の設定をアプリ側でキャッシュ可能か
- 追加調査: Codex の worktree resume は実際に可能か（履歴作成ベース）

## 2. 結論サマリ

### 2.1 Claude Code 側の追加候補

現状の `start` では Claude 側に `permissionMode` しか実質渡しておらず、
SDKが持つ以下の設定はUIにもBridgeにも未露出。

- `model`
- `thinking` / `effort`
- `maxTurns`
- `maxBudgetUsd`
- `systemPrompt`（必要なら）

根拠:

- `packages/bridge/src/sdk-process.ts` では `query()` に `permissionMode` など最小限のみ渡している
- `node_modules/@anthropic-ai/claude-agent-sdk/sdk.d.ts` には `model`, `maxTurns`, `maxBudgetUsd`, `systemPrompt`, `thinking` が定義されている

### 2.2 Recent Sessions 長押し仕様

仕様上は可能。実装上は未対応（現状は `onTap` のみ）。

- `RecentSessionCard` に `onLongPress` を追加
- 長押しで `showNewSessionSheet` をプリセット付きで開く
- `Start` は `ClientMessage.start(...)` の既存パラメータで送信可能

根拠:

- `apps/mobile/lib/widgets/session_card.dart` は `ListTile(onTap: ...)` のみ
- `apps/mobile/lib/features/session_list/widgets/home_content.dart` も `onTap` 経由のみ
- `apps/mobile/lib/models/messages.dart` の `ClientMessage.start` は provider/codex/worktree をすでに受け取れる

### 2.3 Codex の worktree 導入

導入自体は可能。

- Bridge は provider 共通で worktree を解決し、`effectiveCwd` をプロセス起動に使う
- Codex プロセスは `workingDirectory` を受け取って起動する

根拠:

- `packages/bridge/src/session.ts` の `effectiveCwd = wtPath ?? projectPath`
- `packages/bridge/src/codex-process.ts` の `workingDirectory: projectPath`

ただし UI は現在 Codex 選択時に worktree トグルを消している。

- `apps/mobile/lib/widgets/new_session_sheet.dart`

### 2.4 前回設定キャッシュ

可能。現状は未実装。

- 既存の `SharedPreferences` 利用箇所に `session_start_defaults` を追加すれば対応可能
- 現在保存しているのは接続URL/APIキー、設定画面の一部のみ

根拠:

- `apps/mobile/lib/features/session_list/session_list_screen.dart`
- `apps/mobile/lib/features/settings/state/settings_cubit.dart`

## 3. 追加調査: Codex worktree resume（履歴作成ベース）

### 3.1 実施内容

以下2つのテストで検証した。

1. `packages/bridge/src/sessions-index.test.ts`
- 追加テスト: `keeps codex worktree cwd as projectPath for resume targets`
- `~/.codex/sessions/.../*.jsonl` をテスト内で生成（`session_meta.payload.cwd = /tmp/project-a-worktrees/feature-x`）
- `getAllRecentSessions()` の復元結果を確認

2. `packages/bridge/src/session.test.ts`
- 追加テスト: `uses existing worktree path as cwd for codex resume sessions`
- `SessionManager.create(..., worktreeOpts.existingWorktreePath, provider='codex', threadId=...)` の起動cwdを確認

実行コマンド:

```bash
npm run test --workspace=packages/bridge -- src/session.test.ts src/sessions-index.test.ts
```

結果: 2ファイル 34 tests passed

### 3.2 判明したこと

### 可能なケース

- Codex履歴の `session_meta.payload.cwd` が worktree path であれば、
  recent session の `projectPath` も worktree path になる
- その `projectPath` を使って `resume_session` すれば、Codex はその worktree cwd で再開できる

つまり「履歴がworktree cwdを持っている」前提なら resume 可能。

### 不足しているケース

- Codex resume では Claude のような `WorktreeStore` 復元ロジックを使っていない
- そのため、main project path だけ渡された場合に
  「前回の worktree を逆引きして復元」はできない

### 3.3 補足リスク

- Codex recent sessions の project filter は厳密一致なので、
  main project で絞ると worktree cwd セッションは表示されない
- UXとしては「セッションが消えたように見える」可能性がある

## 4. 実装提案（優先順）

1. セッション開始デフォルトの保存/復元（`SharedPreferences`）
2. RecentSession 長押しメニュー（「この設定で新規」「編集して新規」）
3. Codex UI でも worktree オプションを解放
4. Codex resume でも worktree 復元戦略を追加

- 案A: Codex 専用の threadId -> worktreePath マッピングを持つ
- 案B: projectPath が main の場合に recent history から最終cwdを推定する
