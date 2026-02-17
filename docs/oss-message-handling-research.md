# OSS調査: Claude Codeメッセージ表示のベストプラクティス

## 調査目的

ccpocketの2つの課題を解決するため、Claude Code SDKを利用するOSSの実装を調査した。

1. **ユーザーメッセージの区別** — 表示すべきユーザー発言とシステム的メッセージの区別が不安定
2. **ツール省略表示** — CLIのようなコンパクトなツール表示ができていない

## 調査対象

| OSS | Stars | Tech | SDK連携方式 |
|-----|-------|------|------------|
| [CodePilot](https://github.com/op7418/CodePilot) | 2.0k | Electron + Next.js | Agent SDK直接利用 |
| [Happy Coder](https://github.com/KennyPlus/happy-coder) | - | React Native + Expo | CLI wrapper + WebSocket |
| [Opcode](https://github.com/winfunc/opcode) | 20.6k | Tauri (Rust) + React | CLI subprocess |
| [Crystal](https://github.com/stravu/crystal) | 2.9k | Electron + TypeScript | CLI subprocess (PTY) |

---

## 課題①: ユーザーメッセージの区別

### 各OSSのアプローチ比較

#### Happy Coder（最も体系的）

**ファイル**: `sources/sync/typesRaw.ts`, `sources/sync/reducer/reducer.ts`

SDK raw messageの`type`フィールドで大別した後、5フェーズのreducerで分類:

```
Phase 0:   AgentState permissions（ツール承認状態の管理）
Phase 0.5: Message-to-Event conversion（特殊メッセージをイベントに変換）
Phase 1:   User + Text messages（ユーザー発言とエージェントテキスト）
Phase 2:   Tool calls（ツール呼び出し）
Phase 3:   Tool results（ツール実行結果）
Phase 4:   Sidechains（サブエージェントの会話）
Phase 5:   Mode switch events（モード切替イベント）
```

**ユーザーメッセージの判別基準**:

| 条件 | 分類 | 表示 |
|------|------|------|
| `role: 'user'` + `content.type: 'text'` | `UserTextMessage` | ✅ 表示 |
| `role: 'agent'` + `data.type: 'user'` + `content: string`（非sidechain） | `user` role | ✅ 表示 |
| `role: 'agent'` + `data.type: 'user'` + `content: array[tool_result]` | `agent` role | ❌ 非表示（tool-resultとして処理） |
| `role: 'agent'` + `data.isMeta: true` | - | ❌ スキップ |
| `role: 'agent'` + `data.isCompactSummary: true` | - | ❌ スキップ |
| `role: 'agent'` + `data.type: 'user'` + `isSidechain: true` | `sidechain` | 🔀 サブエージェント表示 |

**キーポイント**: `isMeta` と `isCompactSummary` フラグでシステム的メッセージを早期にフィルタ。

#### Crystal

**ファイル**: `frontend/src/components/panels/ai/transformers/ClaudeMessageTransformer.ts`

```typescript
// ユーザーメッセージの判別（parseUserMessage）
if (!hasToolResult && hasOnlyText) {
  // → 表示: 純粋なテキストのみのユーザーメッセージ
}
// tool_resultを含むuser messageはnull（非表示）
```

**判別基準**: `content`配列に`tool_result`が含まれるかで分岐。`hasOnlyText && !hasToolResult`のみ表示。

#### Opcode

**ファイル**: `src/components/StreamMessage.tsx`

```typescript
// ユーザーメッセージ
if (message.type === "user") {
  if (message.isMeta) return null;  // メタメッセージは非表示
  // 残りを表示
}
```

**判別基準**: `isMeta`フラグのみでフィルタ。シンプルだがカバレッジは低い。

### 💡 ccpocketへの示唆

現在のccpocketでは `UserInputMessage` を受け取って表示判定しているが、以下の改善が考えられる:

1. **`isMeta` / `isSynthetic` の早期フィルタ** — normalizeの段階で除外
2. **user type + tool_result content の非表示** — Happy Coder/Crystalと同様、tool_resultを含むuser messageはユーザー発言として表示しない
3. **isCompactSummary の除外** — SDK由来のcompact summaryは別系統で扱う

---

## 課題②: ツール省略表示

### 各OSSのアプローチ比較

#### CodePilot（最も洗練）

**ファイル**: `src/components/ai-elements/tool-actions-group.tsx`, `src/components/chat/ToolCallBlock.tsx`

**2層構造**:
- **グループヘッダー**: `[▶] [6] 3 running · 2 completed   git commit...`
- **展開時の個別行**: アイコン + ツール名 + サマリー + ステータスドット

**ツールカテゴリ分類**:

| カテゴリ | ツール名マッチ | アイコン |
|---------|--------------|---------|
| `read` | Read, ReadFile | 📄 File |
| `write` | Write, Edit, CreateFile, NotebookEdit | ✏️ FileEdit |
| `bash` | Bash, Execute, Shell | 💻 CommandLine |
| `search` | Search, Glob, Grep, WebSearch | 🔍 Search |
| `other` | その他すべて | 🔧 Wrench |

**サマリー抽出ルール**:

```typescript
// tool-actions-group.tsx の getToolSummary()
switch (category) {
  case 'read':
  case 'write':
    // file_path → ファイル名のみ抽出
    return extractFilename(inp.file_path || inp.path);
    // 例: "/Users/k9i/src/main.dart" → "main.dart"

  case 'bash':
    // command → 60文字で切り捨て
    return cmd.length > 60 ? cmd.slice(0, 57) + '...' : cmd;
    // 例: "git commit -m 'Add feature...'"

  case 'search':
    // pattern → クォート付き50文字
    return `"${pattern.slice(0, 47) + '...'}"`;
    // 例: '"class ChatScreen"'

  default:
    return name;  // ツール名そのまま
}
```

**ToolCallBlock展開時の表示（カテゴリ別）**:

| カテゴリ | 展開時の表示内容 |
|---------|----------------|
| read | ファイルパス + シンタックスハイライト付きコード |
| write | ファイルパス + diff (old_string/new_string) + コード |
| bash | `$ command` (黒背景) + 実行結果 (暗灰背景) |
| search | パターン + 結果（50行まで） |
| other | JSON input + output |

#### Opcode（最も網羅的）

**ファイル**: `src/components/StreamMessage.tsx`, `src/components/ToolWidgets.tsx`

**25種の専用Widget**:

| Widget | ツール | 表示内容 |
|--------|-------|---------|
| `TodoWidget` | TodoWrite | チェックリスト (✅/⏳/○ + priority badge) |
| `EditWidget` | Edit | ファイルパス + diff表示 |
| `MultiEditWidget` | MultiEdit | 複数編集のdiff |
| `BashWidget` | Bash | `$ command` + 実行結果 |
| `ReadWidget` | Read | ファイルパス + 行番号付きコード |
| `WriteWidget` | Write | ファイルパス + 新規内容 |
| `GlobWidget` | Glob | パターン + マッチ結果 |
| `GrepWidget` | Grep | パターン + 検索結果 |
| `LSWidget` | LS | ディレクトリツリー |
| `MCPWidget` | mcp__* | MCP server名 + パラメータ |
| `TaskWidget` | Task | サブエージェント description + prompt |
| `WebSearchWidget` | WebSearch | 検索クエリ + 結果 |
| `WebFetchWidget` | WebFetch | URL + レスポンス |
| `ThinkingWidget` | thinking | 折りたたみ式思考プロセス |
| `CommandWidget` | slash command | コマンド名 + 引数 |
| `SystemInitializedWidget` | system.init | モデル名 + セッション情報 |

#### Happy Coder

**ファイル**: `sources/components/tools/ToolView.tsx`, `sources/utils/messageUtils.ts`

**knownToolsレジストリ**: 各ツールにメタデータ (title, icon, subtitle抽出関数) を定義

```typescript
function getToolSummary(tools: ToolCall[]): string {
  // 単一: "Edited /path/to/file.ts"
  // 複数: "Used Edit, Read, Bash"
}
```

### 💡 ccpocketへの示唆（ツール省略表示ルール表）

現在のccpocketの `ToolUseTile` は汎用JSON表示だが、以下のようにカテゴリ別に最適化できる:

| ツール名 | 省略表示（1行） | 展開時 |
|---------|---------------|--------|
| **Read** | `📄 Read` + ファイル名 | ファイルパス全体 |
| **Edit** | `✏️ Edit` + ファイル名 | old/new diff |
| **Write** | `✏️ Write` + ファイル名 | ファイルパス + 内容プレビュー |
| **Bash** | `💻` + コマンド(60文字) | フルコマンド + 出力 |
| **Grep** | `🔍 Grep` + `"パターン"` | パターン + マッチ結果 |
| **Glob** | `🔍 Glob` + `"パターン"` | パターン + ファイル一覧 |
| **WebSearch** | `🌐 WebSearch` + クエリ | クエリ + 結果 |
| **Task** | `🤖 Task` + description | prompt全体 |
| **TodoWrite** | `📋 Todo` + 件数 | チェックリスト |
| **mcp__*** | `🔌` + server名 | パラメータJSON |
| **その他** | ツール名 | JSON input |

---

## アーキテクチャ比較

### メッセージフロー

```
[ccpocket 現在]
Claude CLI → sdk-process.ts (型変換) → WebSocket → Flutter (ChatMessageHandler → ChatEntry)

[CodePilot]
Claude Agent SDK → claude-client.ts (SSEストリーム) → Frontend (MessageList → ToolActionsGroup)

[Happy Coder]
Claude CLI → Backend → Socket.io (暗号化) → typesRaw (Zod検証) → reducer (5フェーズ) → Message型

[Crystal]
Claude CLI (PTY) → ClaudeCodeManager → DB → IPC → ClaudeMessageTransformer → UnifiedMessage

[Opcode]
Claude CLI → Rust Backend → Tauri events → useClaudeMessages hook → StreamMessage → ToolWidgets
```

### メッセージ型の抽象化レベル

| OSS | Raw → UI変換 | 中間型 | UI型 |
|-----|-------------|--------|------|
| ccpocket | `ServerMessage` → `ChatEntry` | なし（直接変換） | `sealed ChatEntry` |
| Happy Coder | `RawRecord` → `NormalizedMessage` → `Message` | **あり（Normalized）** | `UserText/AgentText/ToolCall/ModeSwitch` |
| CodePilot | SDK message → `SSEEvent` → Component | SSEイベント型 | `ToolAction[]` |
| Crystal | `ClaudeRawMessage` → `UnifiedMessage` | なし | `UnifiedMessage` (segments) |

**注目**: Happy Coderの3層型変換（Raw → Normalized → Message）が最も堅牢。

---

## ccpocketへの改善提案まとめ

### 優先度1: ユーザーメッセージ判別の改善

**現在の問題**: `UserInputMessage` の `isSynthetic`, `isMeta` の判定が不十分

**改善案**:
- Bridge側の `sdkMessageToServerMessage()` で `isMeta`, `isCompactSummary` を早期フィルタ
- Flutter側で `user type + content配列にtool_resultのみ` のメッセージを非表示
- Happy Coderの `normalizeRawMessage()` のフィルタロジックを参考に

### 優先度2: ツール省略表示の導入

**現在の問題**: `ToolUseTile` が全ツール同じJSON表示

**改善案**:
- CodePilotの `getToolCategory()` + `getToolSummary()` パターンを導入
- 5カテゴリ (read/write/bash/search/other) に分類
- 省略表示: ファイル名 / コマンド60文字 / パターン50文字
- `ToolResultBubble` のauto-summaryもカテゴリ別に最適化

### 優先度3: ツール別展開表示の強化

**現在の問題**: 展開時もJSON表示

**改善案**:
- Opcodeの25種Widgetを参考に、主要ツール (Edit/Bash/Read/Grep) の専用表示を追加
- diff表示、シンタックスハイライト、ターミナル風表示

---

## 参照ファイル一覧

### CodePilot
- `/Users/k9i-mini/Workspace/CodePilot/src/components/ai-elements/tool-actions-group.tsx`
- `/Users/k9i-mini/Workspace/CodePilot/src/components/chat/ToolCallBlock.tsx`

### Happy Coder
- `/Users/k9i-mini/Workspace/happy-coder/sources/sync/typesRaw.ts`
- `/Users/k9i-mini/Workspace/happy-coder/sources/sync/typesMessage.ts`
- `/Users/k9i-mini/Workspace/happy-coder/sources/sync/reducer/reducer.ts`
- `/Users/k9i-mini/Workspace/happy-coder/sources/sync/reducer/messageToEvent.ts`
- `/Users/k9i-mini/Workspace/happy-coder/sources/sync/reducer/reducerTracer.ts`

### Opcode
- `/Users/k9i-mini/Workspace/opcode/src/components/StreamMessage.tsx`
- `/Users/k9i-mini/Workspace/opcode/src/components/ToolWidgets.tsx`

### Crystal
- `/Users/k9i-mini/Workspace/crystal/frontend/src/components/panels/ai/transformers/ClaudeMessageTransformer.ts`
