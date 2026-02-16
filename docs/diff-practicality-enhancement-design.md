# Diff実用性強化 設計

## 目的

Diff画面を「閲覧専用」から「変更確定まで完結できる画面」に拡張する。

対象は以下3点。

1. 簡単なgit操作の提供
2. hide whitespace
3. メッセージ含めAIでコミット

## スコープ

### In Scope

- `get_diff` の whitespace 無視オプション
- 安全な限定git操作 (`status` / `add` / `restore --staged` / `commit`)
- コミットメッセージ提案（AI生成）とコミット実行フロー

### Out of Scope（初期）

- 破壊的操作 (`reset --hard`, `checkout --`, `rebase`, `push`, `pull`)
- ブランチ作成/削除
- 複雑なhunk単位ステージング (`git add -p`)

## 現状整理

- Bridge: `get_diff` は `git diff --no-color` 固定 (`packages/bridge/src/websocket.ts`)
- Mobile: `ClientMessage.getDiff(projectPath)` は引数なし (`apps/mobile/lib/models/messages.dart`)
- Diff画面: 折りたたみ・ファイルフィルタ・hunk選択は実装済み (`apps/mobile/lib/features/diff/diff_screen.dart`)

## 提案アーキテクチャ

### 1. get_diff 拡張（hide whitespace）

#### Client -> Server

`get_diff` にオプション追加。

```ts
{
  type: "get_diff",
  projectPath: string,
  ignoreWhitespace?: boolean, // default false
  staged?: boolean            // default false (working tree diff)
}
```

#### Bridge実行

- 既存 `collectGitDiff()` を以下に拡張。
- `ignoreWhitespace=true` のとき `git diff --no-color -w`
- `staged=true` のとき `git diff --no-color --cached`（`-w` 併用可）

#### Mobile

- Diff画面に `Hide whitespace` トグル追加
- トグル変更時に同条件で再取得
- URL/画面復帰時は状態復元（`DiffViewState`に `ignoreWhitespace` / `staged` を保持）

### 2. git操作 API（限定）

#### Client -> Server

新規 `git_op` メッセージを追加。

```ts
// status
{ type: "git_op", projectPath: string, op: "status" }

// stage (files省略で all)
{ type: "git_op", projectPath: string, op: "add", files?: string[] }

// unstage
{ type: "git_op", projectPath: string, op: "restore_staged", files?: string[] }

// commit
{
  type: "git_op",
  projectPath: string,
  op: "commit",
  message: string,
  amend?: false
}
```

#### Server -> Client

```ts
{
  type: "git_op_result",
  op: "status" | "add" | "restore_staged" | "commit",
  success: boolean,
  stdout?: string,
  error?: string,
  status?: {
    staged: Array<{ path: string; code: string }>;
    unstaged: Array<{ path: string; code: string }>;
    untracked: string[];
    branch?: string;
    ahead?: number;
    behind?: number;
  },
  commit?: {
    hash: string,
    summary: string,
  }
}
```

#### 実装方針

- `git status --porcelain=v1 -b` をBridgeで構造化して返す
- 実行コマンドは allowlist 固定（入力文字列をそのまま実行しない）
- `projectPath` は既存 `get_diff` と同様に cwd として扱う

### 3. AIコミットメッセージ

## 方針（既存機能の延長）

新しいAI実行基盤は作らず、既存セッション送信 (`input`) を使って提案文を作る。

1. Diff画面で `staged diff` を取得
2. 既存の「選択差分をチャットに添付」導線を再利用
3. 固定プロンプトを自動挿入して「Conventional Commits候補を3件」生成
4. 候補を `CommitSheet` で編集・確定
5. `git_op(commit)` 実行

### AIプロンプト（固定）

- 出力形式をJSON固定（パース容易化）
- 候補3件 + 理由短文
- 72文字目安、命令形、`feat|fix|refactor|chore|docs|test` を優先

例:

```text
以下のstaged diffからConventional Commits形式のコミットメッセージ候補を3件作成。
JSONのみで返答:
{"candidates":[{"type":"feat","scope":"diff","subject":"...","body":"..."}]}
```

### 失敗時フォールバック

- AI提案取得失敗: 手入力コミットを継続可能
- JSONパース失敗: テキスト全文を候補1件として表示

## UIフロー

1. Diff画面 AppBar
- `Hide whitespace` トグル
- `Git` ボタン（BottomSheet）

2. Git BottomSheet
- `Status`（staged/unstaged/untracked）
- `Stage all` / `Unstage all`
- `AIでコミットメッセージ作成`
- `Commit`（編集必須）

3. CommitSheet
- 候補タブ（AI提案3件）
- 編集欄（最終文面）
- 実行前確認（対象: staged files数）
- 実行後トースト（hash表示）

## セキュリティ/安全性

- allowlist外のgit操作は拒否
- `commit` 実行前に staged 0件ならエラー返却
- 空メッセージ/改行のみは拒否
- コミットメッセージ最大長を制限（例 4KB）
- すべての失敗は `git_op_result.error` に返してUIに表示

## 実装フェーズ

### Phase 1（最小価値）

- `get_diff(ignoreWhitespace)`
- Diff UIトグル
- 既存テスト更新

### Phase 2（安全なGit操作）

- `git_op(status/add/restore_staged)`
- Diff画面のGit BottomSheet

### Phase 3（AIコミット）

- AI候補生成導線（既存input活用）
- `git_op(commit)`
- CommitSheet編集 + 実行

## 変更対象ファイル（予定）

### Bridge

- `packages/bridge/src/parser.ts`
- `packages/bridge/src/websocket.ts`
- `packages/bridge/src/websocket.test.ts`

### Mobile

- `apps/mobile/lib/models/messages.dart`
- `apps/mobile/lib/features/diff/state/diff_view_state.dart`
- `apps/mobile/lib/features/diff/state/diff_view_cubit.dart`
- `apps/mobile/lib/features/diff/diff_screen.dart`
- `apps/mobile/test/diff_view_cubit_test.dart`
- `apps/mobile/test/diff_screen_test.dart`

## テスト戦略

### Bridge

- `get_diff(ignoreWhitespace=true)` で `-w` が付与されること
- `git_op` の許可/拒否分岐
- `status` パースの妥当性
- `commit` 成功/失敗（stagedなし、メッセージ空）

### Mobile

- トグル操作で再取得パラメータが変わること
- `git_op_result` 反映
- AI候補選択 -> 編集 -> commit送信
- エラー時UI（リトライ/手入力継続）

## 未決事項

1. AI提案を「現在開いているセッション」に流すか、「専用の短命セッション」に分離するか
2. `status` を都度`git_op(status)`で取得するか、`get_diff`応答に同梱するか
3. Commit body（2行目以降）を初期実装で許可するか（subject onlyに絞るか）

