# Rewind / Fork / Rename 機能調査

## 概要

Claude CLI の rewind, fork, rename 機能を ccpocket に輸入するための調査結果。
Claude Agent SDK v0.2.39 を対象に調査。

---

## 1. Rewind（会話巻き戻し）

### SDK対応状況: ✅ サポートあり

2つの独立したRewind機構がある。

### 1a. 会話のRewind（`resumeSessionAt`）

セッション再開時に、指定UUIDまでの会話のみ読み込み、以降を破棄する。

```typescript
// query() オプション
{
  resume: "<sessionId>",
  resumeSessionAt: "<targetMessageUuid>",  // ここまで読み込む
}
```

- プロセスの停止→再起動が必要
- 指定UUID以降のメッセージは破棄される

### 1b. ファイルのRewind（`rewindFiles()`）

ファイルを指定時点の状態に復元する。`enableFileCheckpointing: true` が前提。

```typescript
// query() オプションで有効化
{ enableFileCheckpointing: true }

// Query インスタンスのメソッド
const result = await query.rewindFiles(userMessageId, { dryRun: false });
```

**戻り値:**
```typescript
type RewindFilesResult = {
  canRewind: boolean;
  error?: string;
  filesChanged?: string[];  // 変更されたファイル一覧
  insertions?: number;
  deletions?: number;
};
```

- `dryRun: true` でプレビュー可能（実際のファイル変更なし）

### SDKの内部プロトコル

```typescript
// CLI プロセスへの制御リクエスト
type SDKControlRewindFilesRequest = {
  subtype: 'rewind_files';
  user_message_id: string;
  dry_run?: boolean;
};
```

### 実装方針

1. `sdk-process.ts`: `enableFileCheckpointing: true` を query オプションに追加
2. Rewind時: プロセス停止 → `resume` + `resumeSessionAt` で再起動
3. ファイルRewind: `rewindFiles()` を呼び出し、結果をクライアントに返す
4. **前提条件**: メッセージUUIDのクライアント転送が必要

---

## 2. Fork（会話分岐）

### SDK対応状況: ✅ サポートあり

### 仕組み

既存会話を読み込みつつ、新しいセッションIDで分岐する。

```typescript
// query() オプション
{
  resume: "<sourceSessionId>",
  forkSession: true,                       // フォーク有効化
  resumeSessionAt: "<targetMessageUuid>",  // 省略時は末尾から分岐
  sessionId: "<customNewSessionId>",       // 省略時は自動生成
}
```

### JSONL内部構造

フォークされたメッセージはツリー構造で管理される:

```json
{
  "uuid": "msg-uuid",
  "parentUuid": "parent-msg-uuid",
  "isSidechain": true
}
```

`sessions-index.json` にも `isSidechain` フラグが付与される。

### 実装方針

1. `session.ts`: fork メソッド追加（`forkSession: true` + `resume` で新セッション作成）
2. フォーク元セッションの停止は不要（新しいプロセスとして起動）
3. `resumeSessionAt` との組み合わせで、任意時点からのフォークが可能
4. **前提条件**: メッセージUUIDのクライアント転送が必要（フォーク開始地点の指定用）

---

## 3. Rename（セッション名変更）

### SDK対応状況: ❌ SDK APIなし（ファイルシステム直接操作）

### 仕組み

CLIの `/custom-title` スラッシュコマンドがJSONLファイルに直接書き込む。
SDK の `Query` インターフェースには対応メソッドがない。

### JONLエントリ

セッションの JSONL ファイルに以下を追記する:

```json
{"type": "custom-title", "customTitle": "新しい名前", "sessionId": "session-uuid"}
```

### sessions-index.json

`customTitle` フィールドとして反映される:

```json
{
  "sessionId": "session-uuid",
  "customTitle": "新しい名前",
  "firstPrompt": "...",
  ...
}
```

### 実装方針

**Approach A — ファイル直接操作（推奨）:**
1. Bridge Server で `rename_session` メッセージを受信
2. 対象セッションの JSONL ファイルに `custom-title` エントリを追記
3. JSONL ファイルパスは `sessions-index.json` の `fullPath` から取得可能

**Approach B — スラッシュコマンド経由（非推奨）:**
- `/custom-title <name>` を CLI プロセスに送信
- LLMを経由するため不安定

---

## 共通の前提条件: メッセージUUID追跡

### 現状の問題

現在の Bridge Server は `SDKAssistantMessage.uuid` / `SDKUserMessage.uuid` をクライアントに転送していない。
Rewind と Fork には各メッセージのUUIDが必要。

### 必要な変更

1. `parser.ts`: メッセージ変換時に `uuid` フィールドを保持
2. サーバーメッセージに `messageUuid` を追加してクライアントに送信
3. Flutter側: メッセージモデルに `uuid` フィールドを追加

---

## プロトコル変更案

### Client → Server（新規メッセージ）

```typescript
// 会話巻き戻し
{ type: "rewind_session", sessionId: string, targetMessageUuid: string, rewindFiles?: boolean }

// 会話分岐
{ type: "fork_session", claudeSessionId: string, projectPath: string, atMessageUuid?: string, permissionMode?: string }

// セッション名変更
{ type: "rename_session", claudeSessionId: string, customTitle: string }
```

### Server → Client（新規メッセージ）

```typescript
// Rewind結果
{ type: "rewind_result", success: boolean, filesChanged?: string[], insertions?: number, deletions?: number, error?: string }

// リネーム確認
{ type: "session_renamed", sessionId: string, customTitle: string }
```

---

## 実装優先度

| 優先度 | 機能 | 複雑度 | 理由 |
|--------|------|--------|------|
| 1 | Rename | 低 | SDK不要、ファイル操作のみ |
| 2 | Fork | 低〜中 | SDKオプション1つで実現、UUID追跡が前提 |
| 3 | Rewind | 中 | UUID追跡 + ファイル復元 + プロセス再起動 |

> **注意**: Fork と Rewind は「メッセージUUID追跡」が共通の前提条件。
> Rename は独立して実装可能。
