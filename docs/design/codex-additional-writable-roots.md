# Codex Additional Writable Roots

## Context

CC Pocket の New Session で、Codex セッション開始時に追加の writable directory を指定したい。

目的は Codex CLI の `--add-dir` に近い UX を、Bridge 経由の `codex app-server` 利用時にも提供すること。

## Confirmed Behavior

Codex 側をローカル確認した結果、Bridge 実装に効く事実は次の通り。

- `thread/start` / `thread/resume` は `config` override を受け取れる
- `config` override では `sandbox_workspace_write.writable_roots` を渡せる
- `config` override はキー単位の上書きであり、config 全体の置き換えではない
- ただし `writable_roots` は配列 merge ではなく replace
- `sandbox_workspace_write.network_access` など sibling key は保持される
- `codex --add-dir ... app-server` は、少なくとも現行確認版では app-server セッションの writable roots に反映されなかった

このため、Bridge から spawn 引数で本物の `--add-dir` を使う案は採用しない。

## Goal

- Codex New Session / Resume Session で追加 writable roots を指定できる
- 既存 config の effective `writable_roots` を保ったまま、指定分を追加できる
- active session の resume と recent sessions 経由の resume の両方で再現できる

## Non-Goals

- Claude セッション対応
- Codex upstream の app-server protocol 変更
- Codex CLI の `--add-dir` と完全に同じ内部実装にすること

## Design Summary

Bridge は `codex app-server` 起動後、`thread/start` の直前に `config/read { cwd }` を呼び、
effective config から `sandbox_workspace_write.writable_roots` を取得する。

その配列に New Session で指定された追加 roots を append + dedupe し、
`thread/start.config.sandbox_workspace_write.writable_roots` に merged list として渡す。

これにより app-server の replace 挙動を Bridge 側で吸収し、ユーザー体験としては add-dir に近づける。

## Desired Behavior

### 追加指定なし

- 現行挙動のまま
- `~/.codex/config.toml` と project config の effective 設定をそのまま使う
- `config/read` は不要

### 追加指定あり

- Bridge が effective `writable_roots` を取得
- 指定された roots を末尾に追加
- 重複を除去
- merged list を `thread/start.config` に入れて start / resume する

## WebSocket Protocol Changes

`packages/bridge/src/parser.ts` の `start` / `resume_session` に次を追加する。

```json
{
  "type": "start",
  "provider": "codex",
  "projectPath": "/Users/me/project",
  "additionalWritableRoots": [
    "/Users/me/Workspace/codex",
    "/Users/me/Workspace/openclaw"
  ]
}
```

新規フィールド:

- `additionalWritableRoots?: string[]`

## Bridge Changes

### 1. `parser.ts`

- `start`
- `resume_session`

両方に `additionalWritableRoots?: string[]` を追加し、配列バリデーションを行う。

### 2. `websocket.ts`

- Codex `start` / `resume_session` で `additionalWritableRoots` を `CodexStartOptions` に渡す
- 追加 root ごとに Bridge 側の path allowlist を適用する
- 相対パスを許容する場合は `projectPath` 基準で解決してから検証する

初期実装では、次の簡潔なルールにする。

- 文字列配列のみ許可
- Bridge 受信時に絶対パスへ正規化
- `BRIDGE_ALLOWED_DIRS` 外は reject

### 3. `codex-process.ts`

`CodexStartOptions` に次を追加する。

- `additionalWritableRoots?: string[]`

start / resume の流れを次のように変更する。

1. app-server 起動
2. `initialize`
3. `additionalWritableRoots` が空でなければ `config/read { cwd: projectPath }`
4. `config.sandbox_workspace_write?.writable_roots ?? []` を取得
5. requested roots を append + dedupe
6. `thread/start.config.sandbox_workspace_write.writable_roots` に merged list を設定
7. `thread/start` or `thread/resume`

config override の例:

```json
{
  "config": {
    "profile": "research",
    "model_reasoning_effort": "high",
    "sandbox_workspace_write": {
      "writable_roots": [
        "/existing/root",
        "/new/root"
      ]
    }
  }
}
```

ポイント:

- `profile` や `model_reasoning_effort` は既存通り `config` に載せる
- `sandbox_workspace_write` も同じ `config` オブジェクトにまとめる
- `network_access` など sibling key は `config/read` 側の effective 値をそのまま再送しない
  - `writable_roots` だけ override しても sibling は保持されるため不要

### 4. `session.ts`

`SessionInfo.codexSettings` に次を追加する。

- `additionalWritableRoots?: string[]`

active session の再開時に同じ設定を再送できるようにする。

### 5. `websocket.ts` resume recipe

`buildResumeSessionMessage()` が `additionalWritableRoots` を含めるようにする。

これにより active session を元にした repro / resume recipe でも設定を失わない。

### 6. `sessions-index.ts`

Codex の session JSONL には `additionalWritableRoots` は残らないため、Bridge 側で sidecar 保存する。

保存ファイル案:

- `~/.codex/ccpocket-session-additional-writable-roots.json`

構造案:

```json
{
  "thr_123": [
    "/Users/me/Workspace/codex",
    "/Users/me/Workspace/openclaw"
  ]
}
```

用途:

- recent sessions 一覧に roots を再付与する
- `resume_session` 時に同じ追加 roots を再送する

既存の `ccpocket-session-profiles.json` と同じ扱いで十分。

## Merge Rules

Bridge での merge ルールは次の通り。

1. base = `config/read(cwd).config.sandbox_workspace_write?.writable_roots ?? []`
2. requested = `additionalWritableRoots`
3. `base + requested` の順で連結
4. 正規化した絶対パスで重複除去
5. 順序は最初の出現順を維持

意図:

- config 由来の roots を先に残す
- New Session で追加したものは末尾に足す
- 同じ path の二重登録を避ける

## Error Handling

### invalid path

- `additionalWritableRoots` に不正な path が含まれる場合は session start を reject
- silent ignore はしない

### path not allowed

- `BRIDGE_ALLOWED_DIRS` 外は reject
- エラーメッセージに対象 path を含める

### `config/read` failure

- `additionalWritableRoots` が未指定なら影響なし
- 指定ありで `config/read` に失敗した場合は session start を fail

理由:

- fallback して requested roots だけを送ると、既存 roots を消してしまうため危険

## Read-Only Sandbox

`sandboxMode = read-only` の場合、追加 writable roots を指定しても sandbox 上は意味を持たない。

ただし初期実装では特別扱いせず、そのまま保存・再送してよい。

理由:

- resume 時に sandboxMode が変わる可能性がある
- Bridge 実装を単純に保てる
- app-server 側が read-only 時に writable roots を使わなくても問題はない

必要なら後で UI に warning を出す。

## Security Notes

- Bridge は request 由来の追加 roots のみを検証する
- config 側に既にある writable roots は現行どおり Bridge ではブロックしない

これは既存仕様の延長であり、今回の改修で新たに広げるのは request 由来の追加分だけ。

## Test Plan

### `parser.test.ts`

- `start` で `additionalWritableRoots` を parse できる
- `resume_session` で `additionalWritableRoots` を parse できる
- 配列以外は reject

### `codex-process.test.ts`

- 追加 roots なしでは `config/read` を呼ばない
- 追加 roots ありでは `config/read` 後に `thread/start` を送る
- `config/read` の base roots と requested roots が merge される
- 重複除去される
- `config/read` 失敗時は start が失敗する

### `websocket.test.ts`

- `start` で `additionalWritableRoots` が `sessionManager.create(... codexOptions)` に渡る
- `resume_session` でも渡る
- path allowlist 違反で reject される

### `session.test.ts`

- `codexSettings.additionalWritableRoots` が保持される

### `sessions-index` tests

- sidecar の load/save
- recent session 復元時に `codexSettings.additionalWritableRoots` が付与される

## Files To Change

- `packages/bridge/src/parser.ts`
- `packages/bridge/src/parser.test.ts`
- `packages/bridge/src/websocket.ts`
- `packages/bridge/src/websocket.test.ts`
- `packages/bridge/src/codex-process.ts`
- `packages/bridge/src/codex-process.test.ts`
- `packages/bridge/src/session.ts`
- `packages/bridge/src/session.test.ts`
- `packages/bridge/src/sessions-index.ts`

## Open Questions

1. `additionalWritableRoots` は absolute path 限定にするか
2. UI で read-only sandbox 時の warning を出すか
3. sidecar ファイルを profile 保存と統合するか、別ファイルに分けるか

## Recommendation

初期実装では次を採用する。

- Bridge protocol に `additionalWritableRoots: string[]` を追加
- Bridge で absolute path 正規化 + allowlist 検証
- `config/read` による effective roots 取得 + merge
- `thread/start.config.sandbox_workspace_write.writable_roots` に merged list を渡す
- recent sessions / active session resume のため sidecar 保存を入れる

この方式なら Codex upstream 変更なしで実現でき、現在の app-server の replace 挙動も安全に吸収できる。
