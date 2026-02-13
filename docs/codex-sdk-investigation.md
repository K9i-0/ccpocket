# Codex CLI SDK 調査ドキュメント

> 調査日: 2025-02-13
> SDK バージョン: `@openai/codex-sdk@0.101.0`
> CLI バージョン: `codex-cli 0.101.0`

## 1. アーキテクチャ概要

### 通信方式

Codex SDKはCLIバイナリを `child_process.spawn()` で起動し、**stdin/stdout で JSON Lines (JSONL)** 通信する。

```
Codex class
  └── startThread() / resumeThread(id)
        └── Thread class
              └── runStreamed(input) / run(input)
                    └── CodexExec.run()
                          └── spawn("codex", ["exec", "--experimental-json", ...args])
                                ├── stdin: ユーザー入力テキスト
                                └── stdout: JSONL イベントストリーム (readline)
```

**Claude Agent SDK との違い**: Claude SDKはAPI呼び出しを内蔵しているが、Codex SDKは外部バイナリに依存する。

### クラス構成

| クラス | 役割 |
|--------|------|
| `Codex` | エントリポイント。`startThread()` / `resumeThread(id)` |
| `Thread` | 会話スレッド管理。`run()` (同期) / `runStreamed()` (AsyncGenerator) |
| `CodexExec` | バイナリ spawn、引数構築、JSONL解析 |

## 2. 型定義

### CodexOptions (コンストラクタ)

```typescript
type CodexOptions = {
  codexPathOverride?: string;           // バイナリパス
  baseUrl?: string;                     // API Base URL
  apiKey?: string;                      // OpenAI APIキー
  config?: CodexConfigObject;           // TOML形式config overrides
  env?: Record<string, string>;         // 環境変数 (指定時はprocess.env非継承)
};
```

### ThreadOptions (スレッド設定)

```typescript
type ThreadOptions = {
  model?: string;
  sandboxMode?: SandboxMode;
  workingDirectory?: string;
  skipGitRepoCheck?: boolean;
  modelReasoningEffort?: ModelReasoningEffort;
  networkAccessEnabled?: boolean;
  webSearchMode?: WebSearchMode;
  webSearchEnabled?: boolean;
  approvalPolicy?: ApprovalMode;
  additionalDirectories?: string[];
};

type ApprovalMode = "never" | "on-request" | "on-failure" | "untrusted";
type SandboxMode = "read-only" | "workspace-write" | "danger-full-access";
type ModelReasoningEffort = "minimal" | "low" | "medium" | "high" | "xhigh";
type WebSearchMode = "disabled" | "cached" | "live";
```

### TurnOptions (ターン設定)

```typescript
type TurnOptions = {
  outputSchema?: unknown;   // 構造化出力のJSONスキーマ
  signal?: AbortSignal;     // キャンセル用
};
```

### Input

```typescript
type Input = string | UserInput[];
type UserInput =
  | { type: "text"; text: string }
  | { type: "local_image"; path: string };
```

## 3. イベントシステム (ThreadEvent)

### 型定義

```typescript
type ThreadEvent =
  | ThreadStartedEvent    // { type: "thread.started", thread_id: string }
  | TurnStartedEvent      // { type: "turn.started" }
  | TurnCompletedEvent    // { type: "turn.completed", usage: Usage }
  | TurnFailedEvent       // { type: "turn.failed", error: { message: string } }
  | ItemStartedEvent      // { type: "item.started", item: ThreadItem }
  | ItemUpdatedEvent      // { type: "item.updated", item: ThreadItem }
  | ItemCompletedEvent    // { type: "item.completed", item: ThreadItem }
  | ThreadErrorEvent;     // { type: "error", message: string }

type Usage = {
  input_tokens: number;
  cached_input_tokens: number;
  output_tokens: number;
};
```

### 実測イベント順序

**テキストのみの応答:**
```
thread.started → turn.started → item.completed(reasoning) → item.completed(agent_message) → turn.completed
```

**コマンド実行を含む応答:**
```
thread.started → turn.started → item.completed(reasoning) → item.completed(agent_message)
  → item.started(command_execution) → item.completed(command_execution)
  → item.completed(agent_message) → turn.completed
```

**エラー時:**
```
thread.started → turn.started → error → turn.failed → (例外throw)
```

### 実測で判明した事項

- **`item.updated` は現バージョンでは未発生** — started→completed のみ
- **`item.started` は `command_execution` でのみ発生** — `reasoning`/`agent_message` は `item.completed` のみ
- **`reasoning` のテキストはサマリー形式** (例: `"**Planning file read execution**"`)

## 4. アイテム型 (ThreadItem)

```typescript
type ThreadItem =
  | AgentMessageItem       // テキスト応答
  | ReasoningItem          // 推論サマリー
  | CommandExecutionItem   // コマンド実行
  | FileChangeItem         // ファイル変更 (パッチ)
  | McpToolCallItem        // MCPツール呼び出し
  | WebSearchItem          // Web検索
  | TodoListItem           // TODOリスト
  | ErrorItem;             // エラー
```

### 実測データサンプル

#### AgentMessageItem
```json
{
  "id": "item_1",
  "type": "agent_message",
  "text": "`hello.txt` says: `Hello from codex test`"
}
```

#### ReasoningItem
```json
{
  "id": "item_0",
  "type": "reasoning",
  "text": "**Planning file read execution**"
}
```

#### CommandExecutionItem (started)
```json
{
  "id": "item_2",
  "type": "command_execution",
  "command": "/bin/zsh -lc 'cat hello.txt'",
  "aggregated_output": "",
  "exit_code": null,
  "status": "in_progress"
}
```

#### CommandExecutionItem (completed)
```json
{
  "id": "item_2",
  "type": "command_execution",
  "command": "/bin/zsh -lc 'cat hello.txt'",
  "aggregated_output": "Hello from codex test",
  "exit_code": 0,
  "status": "completed"
}
```

#### TurnCompletedEvent
```json
{
  "type": "turn.completed",
  "usage": {
    "input_tokens": 15601,
    "cached_input_tokens": 14464,
    "output_tokens": 121
  }
}
```

#### エラー (ThreadErrorEvent + TurnFailedEvent)
```json
// 1. error イベント
{ "type": "error", "message": "{\"detail\":\"The 'invalid-model-name' model is not supported...\"}" }
// 2. turn.failed イベント
{ "type": "turn.failed", "error": { "message": "{\"detail\":\"...\"}" } }
// 3. 例外 throw: "Codex Exec exited with code 1: ..."
```

### 実測で未出現のアイテム

| アイテム | 理由 |
|---------|------|
| `FileChangeItem` | Codexはシェルコマンド (`printf > file`) でファイル操作するため、`command_execution` として表れる。パッチ形式の変更時のみ `file_change` が発生する可能性あり |
| `McpToolCallItem` | MCPサーバー未設定のため未テスト |
| `WebSearchItem` | Web検索未有効のため未テスト |
| `TodoListItem` | 複雑なタスクで計画作成時に発生する可能性あり |

## 5. Claude Agent SDK との比較

| 機能 | Claude Agent SDK | Codex SDK |
|------|-----------------|-----------|
| **通信方式** | SDK内蔵 (直接API呼び出し) | CLIバイナリ spawn + JSONL |
| **セッション作成** | `query({ prompt, options })` | `codex.startThread(options)` |
| **セッション再開** | `query({ options: { resume: id } })` | `codex.resumeThread(id, options)` |
| **ユーザー入力** | AsyncGenerator で逐次 yield | `thread.run(input)` / `thread.runStreamed(input)` |
| **ストリーミング** | AsyncGenerator (messages) | AsyncGenerator (ThreadEvent) |
| **パーミッション** | `canUseTool` コールバック (Promise) | `approvalPolicy` で事前設定 |
| **ツール承認** | リアルタイム approve/reject | **なし (SDK経由では不可)** |
| **メッセージ型** | system/assistant/user/result/stream_event | thread.started/turn.started/item.*/turn.completed |
| **画像入力** | Content block (base64) | `{ type: "local_image", path: string }` |
| **セッション永続化** | `~/.claude/projects/` JSONL | `~/.codex/sessions/` |
| **コスト情報** | `result.cost` (金額) / `result.duration` | `turn.completed.usage` (トークン数のみ) |
| **Sandbox** | なし (OS権限に依存) | read-only / workspace-write / danger-full-access |
| **キャンセル** | プロセス kill | `AbortSignal` via `TurnOptions.signal` |

## 6. ブリッジ統合における設計指針

### A. パーミッションモデルの違い (最大の差異)

**Claude**: セッション中にリアルタイムでツール承認/拒否が可能
```
canUseTool コールバック → Promise で待機 → approve/reject をユーザーが選択
```

**Codex**: **SDK経由では実行時承認なし**。事前ポリシー設定のみ。
```
approvalPolicy: "never"       → 全自動 (ユーザー介入なし)
approvalPolicy: "on-request"  → SDK経由では "never" と同じ動作 ★実測結果
approvalPolicy: "on-failure"  → 失敗時のみ?
approvalPolicy: "untrusted"   → 最も制限的
```

**Bridge Server側の対応**:
- Codexセッションでは `permission_request` を送信しない
- セッション開始時に `approvalPolicy` と `sandboxMode` を設定
- `sandboxMode` がCodexの安全性を担保する主要な仕組み

### B. イベント → ServerMessage 変換マッピング

| Codex イベント/アイテム | → Bridge ServerMessage | 備考 |
|------------------------|----------------------|------|
| `thread.started` | `{ type: "system", subtype: "init" }` | thread_id → sessionId |
| `turn.started` | `{ type: "status", status: "running" }` | |
| `item.completed` (reasoning) | `{ type: "thinking_delta", text }` | |
| `item.completed` (agent_message) | `{ type: "assistant", message: { content: [{ type: "text", text }] } }` | |
| `item.started` (command_execution) | `{ type: "assistant", message: { content: [{ type: "tool_use", name: "Bash", input: { command } }] } }` | |
| `item.completed` (command_execution) | `{ type: "tool_result", content: aggregated_output, toolName: "Bash" }` | |
| `item.completed` (file_change) | `{ type: "tool_result", content: JSON.stringify(changes), toolName: "FileChange" }` | 未実測 |
| `item.completed` (mcp_tool_call) | `{ type: "tool_result", content: ..., toolName: tool }` | 未実測 |
| `item.completed` (todo_list) | 独自メッセージ or assistant として表示 | 要設計 |
| `turn.completed` | `{ type: "result", subtype: "success" }` | usage → cost換算なし |
| `turn.failed` | `{ type: "result", subtype: "error" }` | |
| `error` | `{ type: "error", message }` | |

### C. ユーザー入力の違い

**Claude**: AsyncGeneratorでメッセージを逐次yield (ターン間で待機可能、1つのquery()内で複数ターン)
```typescript
// Claude
const query = query({ prompt: asyncGeneratorYieldingMessages() });
```

**Codex**: `thread.run(input)` で1ターン実行 → 完了 → 次の `run()` 呼び出し
```typescript
// Codex
const result1 = await thread.runStreamed("first message");
// ... events consumed ...
const result2 = await thread.runStreamed("second message");
```

**Bridge側**: Codex用のプロセスクラスでは、ユーザー入力をキューに入れて `runStreamed()` をループ呼び出しする。

### D. セッション履歴

**Claude**: `~/.claude/projects/{hash}/sessions-index.json` + JSONL
**Codex**: `~/.codex/sessions/` (thread_id ベース)

→ Codexの `list_recent_sessions` 対応は Phase 4 (後回し)。

## 7. アーキテクチャ方針

### 採用: 案A→案C 段階的移行

**Phase 1 (案A)**: `codex-process.ts` を追加し、SessionManager に `provider: "claude" | "codex"` 分岐を追加。

**Phase 2 (案C)**: 2つのプロバイダーが安定したら、共通インターフェース `ProcessProvider` を抽出してリファクタリング。

#### 選定理由
- Codex SDKのパーミッションモデルが大きく異なるため、共通インターフェースの設計には実動作データが必要
- 個人プロジェクトなので動くものを早く作って体験しながら設計を固める方が効率的
- 1サーバー管理で運用コストを抑える

#### 比較表 (参考)

| 観点 | 案A: 単一Bridge | 案B: BFF | 案C: プラグイン |
|------|----------------|---------|---------------|
| 開発コスト | ◎ 低い | ✕ 高い | ○ 中程度 |
| 運用コスト | ◎ 1プロセス | ✕ 3プロセス | ◎ 1プロセス |
| 拡張性 | △ | ◎ | ○ |
| 障害分離 | ✕ | ◎ | △ |

## 8. 実装ロードマップ

### Phase 1: Bridge Server (codex-process.ts)
- `@openai/codex-sdk` を dependencies に追加
- `CodexProcess` クラス (EventEmitter、SdkProcessと同パターン)
- ThreadEvent → ServerMessage 変換レイヤー
- SessionManager に provider 分岐追加
- WebSocket プロトコルに `provider` フィールド追加 (`start` メッセージ)

### Phase 2: Flutter App 最低限
- セッション開始時のプロバイダー選択UI (Claude Code / Codex)
- チャット画面はUI共有 (ServerMessage形式が同一なので既存Widget再利用)
- Codex固有設定UI (sandboxMode, approvalPolicy)

### Phase 3: Flutter App オプション機能
- コマンド実行結果の展開表示
- TodoListItem の表示
- Diff表示 (将来的に FileChangeItem 対応)
- セッション履歴 (Codex sessions)
