# Claude Desktop SSH機能 & SDK進化の調査レポート

> 調査日: 2025-02-14
> ソース: https://code.claude.com/docs/en/desktop, /en/cli-reference, /en/headless, /en/sub-agents, /en/agent-teams
> Agent SDK ドキュメント: https://platform.claude.com/docs/en/agent-sdk/overview

---

## 1. Claude Desktop の SSH / Remote 機能

### 概要

Claude Desktop に3つの実行環境が追加された:

| 環境 | 説明 |
|------|------|
| **Local** | ローカルマシンで実行（従来通り） |
| **Remote** | Anthropicクラウド上で実行。アプリ閉じても継続 |
| **SSH** | リモートマシンにSSH接続し、Desktop UIから操作 |

### SSH セッション

- Desktop UIからSSH接続設定（host, port, identity file）
- リモートマシン上でClaude Codeが実行され、DesktopがUIフロントエンド
- Permission modes、Connectors、Plugins、MCP Servers が利用可能
- **制約**: リモートマシンにClaude Codeがインストール済みであること

### Remote セッション

- `claude --remote "Fix the login bug"` でクラウドセッション作成
- **claude.ai/code** や **Claude iOSアプリ** からリモートセッション監視可能
- 複数リポジトリを同時に操作可能
- サブスクリプション枠を消費（別途コンピュート料金なし）
- Ask modeは利用不可（自動でファイル編集を承認）
- Act modeは利用不可（既にサンドボックス環境）

### ccpocket への影響

**短期的にはccpocketの優位性は維持される:**
- Bridge経由のCLI直接操作（API経由でなくローカル実行）
- リアルタイムの承認/拒否フロー
- カスタムMCP統合

**中長期的リスク:**
- iOSアプリにSSHセッション機能が来た場合、主要ユースケースがカバーされる可能性
- Remote セッションの監視は既にiOSから可能（ただしインタラクティブ操作の範囲は不明）

---

## 2. CLI の新機能・新フラグ

### ccpocket に活用可能な新フラグ

#### `--permission-prompt-tool` (パーミッション外部ハンドリング)

```bash
claude -p --permission-prompt-tool mcp_auth_tool "query"
```

- パーミッションプロンプトをMCPツール経由で外部ハンドリング
- 現在のBridgeは SDK の `canUseTool` コールバックで実装済みだが、CLI直接利用時の代替手段として有用
- 将来的にCLIモードに切り替える場合の選択肢

#### `--input-format stream-json` (双方向ストリーミング)

```bash
claude -p --input-format stream-json --output-format stream-json
```

- 入力もJSONストリームで送信可能
- WebSocket経由の双方向通信と親和性が高い

#### `--include-partial-messages` (部分メッセージ)

```bash
claude -p --output-format stream-json --verbose --include-partial-messages "query"
```

- トークン単位のストリーミング差分を公式サポート
- **現在のBridgeは SDK の `includePartialMessages: true` で既に利用中**

#### セッション管理の強化

| フラグ | 説明 | Bridgeでの利用状況 |
|--------|------|-------------------|
| `--resume <session-id>` | セッション復帰 | **利用中** (`resume` オプション) |
| `--continue` | 最新セッション継続 | **利用中** (`continueMode` オプション) |
| `--fork-session` | セッション分岐 | **利用中** (resume時オプションとしてUI対応済み) |
| `--from-pr 123` | PR紐付きセッション再開 | **未利用** — GitHub連携で有用 |
| `--session-id <uuid>` | 明示的セッションID指定 | **未利用** |
| `--no-session-persistence` | 永続化無効 | **未利用** |

#### コスト・安全性

| フラグ | 説明 | 活用案 |
|--------|------|--------|
| `--max-budget-usd` | コスト上限設定 | **利用中** (モバイルUI + Bridge連携済み) |
| `--max-turns` | ターン数制限 | **利用中** (モバイルUI + Bridge連携済み) |
| `--fallback-model` | 過負荷時フォールバック | **利用中** (モバイルUI + Bridge連携済み) |
| `--tools` | 使用ツール制限 | 特定ワークフローでの制限 |

#### その他

| フラグ | 説明 |
|--------|------|
| `--agent` | セッションで使うエージェント指定 |
| `--agents` | カスタムサブエージェントをJSON定義 |
| `--chrome` | ブラウザ自動化統合 |
| `--remote` | クラウドセッション作成 |
| `--teleport` | Webセッションをローカルに引き込む |

---

## 3. Agent SDK の進化

### 現在のccpocket Bridge の状況

- **既に `@anthropic-ai/claude-agent-sdk` ベース** (v0.2.29)
- CLI spawn + stdio パースではなく、SDK の `query()` を直接利用
- `canUseTool` コールバックで承認フローを実装
- `includePartialMessages` でストリーミング対応済み
- `enableFileCheckpointing` でリワインド対応済み

### SDK の新機能・改善点

#### Python / TypeScript SDK パッケージ

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "Fix the bug in auth.py",
  options: { allowedTools: ["Read", "Edit", "Bash"] }
})) {
  console.log(message);
}
```

- CLIラッパーではなくネイティブライブラリとして利用可能
- **ccpocketは既にこのパターンで実装済み**

#### Hooks (ライフサイクルフック)

SDK レベルでフックを定義可能:

```typescript
query({
  prompt: "Refactor utils.py",
  options: {
    permissionMode: "acceptEdits",
    hooks: {
      PostToolUse: [
        { matcher: "Edit|Write", hooks: [logFileChange] }
      ]
    },
  },
});
```

| フック | タイミング | ccpocketでの活用案 |
|--------|-----------|-------------------|
| `PreToolUse` | ツール実行前 | カスタムバリデーション（危険コマンドブロック等） |
| `PostToolUse` | ツール実行後 | ファイル変更通知、自動lint、コスト追跡 |
| `Stop` | セッション終了時 | 自動サマリー生成、通知送信 |
| `SessionStart` | セッション開始時 | 初期化処理、環境検証 |
| `SessionEnd` | セッション終了時 | クリーンアップ、統計記録 |
| `SubagentStart/Stop` | サブエージェント開始/終了 | サブエージェント進捗のUI表示 |

**現状**: Bridgeは独自のイベントエミッターで類似機能を実装しているが、
SDK Hooksに移行することでよりクリーンかつ公式サポートされた形になる。

#### Subagents (サブエージェント)

```typescript
query({
  prompt: "Use the code-reviewer agent to review this codebase",
  options: {
    allowedTools: ["Read", "Glob", "Grep", "Task"],
    agents: {
      "code-reviewer": {
        description: "Expert code reviewer",
        prompt: "Analyze code quality",
        tools: ["Read", "Glob", "Grep"],
        model: "sonnet",
      }
    },
  },
});
```

- **`agents` オプション**: セッション単位でカスタムサブエージェント定義
- **ビルトイン**: Explore (Haiku, read-only), Plan, General-purpose
- **メモリ**: `memory` フィールドで永続知識の蓄積が可能
- サブエージェントからのメッセージには `parent_tool_use_id` が付与

**ccpocketでの活用案:**
- Flutter UIからサブエージェントを定義・起動するUI
- 「レビュー」「デバッグ」「テスト」等のプリセットエージェント
- サブエージェントの進捗をリアルタイム表示

#### Sessions (セッション管理)

```typescript
// セッションIDを取得
for await (const message of query({ prompt: "Read the auth module" })) {
  if (message.type === "system" && message.subtype === "init") {
    sessionId = message.session_id;
  }
}

// セッション復帰
for await (const message of query({
  prompt: "Now find all callers",
  options: { resume: sessionId }
})) { ... }
```

**ccpocketは既にこのパターンで実装済み** (`resume`, `continue` オプション)

#### MCP サーバー統合

```typescript
query({
  prompt: "Open example.com",
  options: {
    mcpServers: {
      playwright: { command: "npx", args: ["@playwright/mcp@latest"] }
    }
  },
});
```

- セッション単位でMCPサーバーを動的に追加可能
- **活用案**: Flutter UIからMCPサーバーの有効/無効を切り替え

#### Structured Output (構造化出力)

```bash
claude -p --output-format json --json-schema '{"type":"object",...}' "query"
```

- JSON Schema に準拠した構造化出力
- Flutter側のパースを型安全に

---

## 4. Agent Teams (実験的)

> 環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で有効化

### 概要

- 複数のClaude Codeインスタンスをチームとして協調動作
- チームリード + 複数のテームメイト構成
- 共有タスクリスト + エージェント間メッセージング
- 各テームメイトは独立したコンテキストウィンドウ

### Subagents vs Agent Teams

| | サブエージェント | Agent Teams |
|--|----------------|-------------|
| コンテキスト | 親に結果を返す | 完全に独立 |
| 通信 | 親への一方通行 | エージェント間直接通信 |
| 調整 | 親が管理 | 共有タスクリスト |
| 適用場面 | 結果だけ必要な集中タスク | 議論・協調が必要な複雑作業 |
| トークンコスト | 低い | 高い（各エージェントが独立インスタンス） |

### SDK からの利用状況

- **Agent Teams は CLI 機能**であり、SDK `query()` からチームを直接作成する API はまだない
- SDK は `agents` オプションでサブエージェントのみ定義可能
- **既存調査**: `docs/agent-teams-design.md` 参照

### 公式ドキュメントで確認された新情報

1. **delegate mode**: リードをコーディネーション専用に制限
2. **Plan approval**: テームメイトに実装前のプラン承認を要求可能
3. **TeammateIdle / TaskCompleted フック**: 品質ゲート
4. **ファイルロックによるタスク競合防止**
5. **tmux / iTerm2 スプリットペインモード**

---

## 5. ccpocket UX向上ロードマップ

### Phase 1: SDK新機能の活用 (短期)

| 項目 | 内容 | 優先度 |
|------|------|--------|
| SDK Hooks 活用 | `PostToolUse` でファイル変更/ツール使用統計、コスト追跡強化 | 完了 |
| `--fork-session` 対応 | セッション分岐UI | 完了 |
| `--max-budget-usd` 対応 | コスト上限設定UI | 完了 |
| `--max-turns` 対応 | ターン数制限UI | 完了 |
| `--fallback-model` 対応 | フォールバックモデル設定 | 完了 |

### Phase 2: サブエージェント活用 (中期)

| 項目 | 内容 | 優先度 |
|------|------|--------|
| プリセットエージェント | レビュー/デバッグ/テスト等のワンタップ起動 | 高 |
| カスタムエージェント定義 | Flutter UIからエージェント設定 | 中 |
| サブエージェント進捗表示 | `parent_tool_use_id` で進捗追跡 | 中 |
| エージェントメモリ表示 | 永続メモリの閲覧・管理 | 低 |

### Phase 3: 差別化機能 (長期)

| 項目 | 内容 | 優先度 |
|------|------|--------|
| Agent Teams UI | マルチエージェント管理画面 | 高 |
| Remote Sessions | クラウドセッション監視 (API公開待ち) | 中 |
| MCP動的管理 | セッション単位のMCPサーバー切り替え | 中 |
| Chrome統合 | ブラウザ自動化の結果表示 | 低 |

### Phase 4: 公式機能との差別化 (長期)

公式iOSアプリとの差別化ポイント:

1. **ローカルCLI直接操作** — Bridgeを介したリアルタイム承認フロー
2. **カスタムサブエージェント** — プロジェクト固有のエージェント定義
3. **コスト管理** — 詳細なトークン使用量追跡・上限設定
4. **開発者向けカスタマイズ** — MCP統合、Hooks、独自ワークフロー

---

## 6. SDK バージョンアップ検討

### 現在: `@anthropic-ai/claude-agent-sdk` ^0.2.29

公式ドキュメントは最新SDKの機能を反映している。
バージョンアップ時の確認ポイント:

1. **Hooks API** が利用可能か（`hooks` オプション）
2. **Subagent memory** 設定が利用可能か
3. **`SubagentStart/Stop` イベント** のサポート
4. **`--fork-session` 相当の SDK オプション** の有無
5. **Structured output** (`jsonSchema` オプション) のサポート

### CHANGELOG 参照先
- TypeScript: https://github.com/anthropics/claude-agent-sdk-typescript/blob/main/CHANGELOG.md
- Python: https://github.com/anthropics/claude-agent-sdk-python/blob/main/CHANGELOG.md

---

## 7. 参考リンク

- [Claude Desktop ドキュメント](https://code.claude.com/docs/en/desktop)
- [CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Headless / Programmatic Usage](https://code.claude.com/docs/en/headless)
