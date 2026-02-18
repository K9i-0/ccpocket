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

## 課題③: インタラクティブメッセージ（ユーザー反応が必要なメッセージ）

### 調査対象メッセージ種別

| 種別 | 説明 | ccpocketでの現状 |
|------|------|-----------------|
| Tool Approval | ツール実行前の承認要求 | ✅ 実装済み（ApprovalBar） |
| AskUserQuestion | Claudeからの質問 + 選択肢 | ✅ 実装済み（QuestionCard） |
| Plan Mode | ExitPlanMode承認 | ✅ 実装済み（PlanCard） |
| Error | エラー表示 | ⚠️ テキストのみ |
| Status | セッション状態表示 | ⚠️ 基本的なインジケーターのみ |

---

### 3-1. Tool Approval（ツール承認）

#### 比較表

| OSS | 方式 | ボタン | 特殊機能 |
|-----|------|--------|---------|
| **Happy Coder** | インラインフッター | Allow / Allow All Edits / Allow for Session / Deny | Codex用別UIあり |
| **CodePilot** | インラインAlert | Deny / Allow Once / Allow for Session | ツール別ステータスバッジ |
| **Crystal** | **モーダルダイアログ** | Allow / Deny | **パラメータ編集可能**、高リスク警告 |
| **Opcode** | なし（自動承認） | - | - |

#### Happy Coder の実装

**ファイル**: `sources/components/tools/PermissionFooter.tsx`

- PermissionFooterコンポーネントがツールメッセージの下部に表示
- 状態: `pending` → `approved`/`denied`/`canceled`
- 承認後は選択されたボタンに左ボーダー表示、非選択ボタンはopacity 0.3
- ローディング中はActivityIndicator表示
- Edit系ツール（Edit/MultiEdit/Write）は「Allow All Edits」ボタンを追加表示

```
[Allow]  [Allow All Edits]  [Allow for Session]  [Deny]
↓ 承認後
[✓ Allowed]  (他ボタンは薄くなる)
```

#### CodePilot の実装

**ファイル**: `src/components/chat/confirmation.tsx`

- Alertコンポーネントベースのインライン承認UI
- 7つの状態を管理: `approval-requested`, `approval-responded`, `input-streaming`, `input-available`, `output-available`, `output-denied`, `output-error`
- 承認後1秒間フィードバック表示（"Allowed"/"Denied"）してからUIクリア

**ステータスバッジ（tool.tsx）**:

| 状態 | アイコン | 色 | ラベル |
|------|---------|---|--------|
| approval-requested | Clock | 黄 | Awaiting Approval |
| approval-responded | CheckCircle | 青 | Responded |
| input-available | Clock (pulse) | - | Running |
| output-available | CheckCircle | 緑 | Completed |
| output-denied | XCircle | オレンジ | Denied |
| output-error | XCircle | 赤 | Error |

#### Crystal の実装

**ファイル**: `frontend/src/components/PermissionDialog.tsx`

- **モーダルダイアログ形式**（画面全体をオーバーレイ）
- ツール別のスマートプレビュー:
  - Bash: コマンド + description
  - Write/Edit: ファイルパス + 内容プレビュー（500文字まで）
  - その他: JSON表示
- **高リスクツール警告**: Bash/Delete/Write/Edit → 赤い盾アイコン + 警告バッジ
- **パラメータ編集機能**: 承認前にJSON形式でパラメータ修正可能（Edit/Preview トグル）

#### 💡 ccpocketへの示唆

1. **承認後のフィードバック表示**: CodePilotのように承認/拒否後に短時間フィードバックを表示
2. **高リスクツール警告**: Crystal方式で Bash/Write/Edit に視覚的警告
3. **ツール別プレビュー**: 承認バーにツール種別に応じたスマートプレビューを追加

---

### 3-2. AskUserQuestion

#### 比較表

| OSS | 実装 | 備考 |
|-----|------|------|
| **Happy Coder** | ❌ なし | 通常のテキスト入力で応答する設計 |
| **CodePilot** | ❌ なし | permission_requestフローに注力 |
| **Crystal** | ❌ なし | Codexのexec/patch承認は別機構 |
| **Opcode** | ❌ なし | 自動承認モード |

**結論**: 調査した4つのOSSはいずれもAskUserQuestion専用UIを実装していない。ccpocketの現行実装（QuestionCard + 選択肢ボタン）は独自の優位性。

---

### 3-3. Plan Mode（ExitPlanMode承認）

#### 比較表

| OSS | 実装 | 備考 |
|-----|------|------|
| **Happy Coder** | Markdown表示 + PermissionFooter | プラン内容をMarkdownレンダリング |
| **CodePilot** | ❌ なし | モード選択UIのみ（code/plan/ask） |
| **Crystal** | テキストサマリーのみ | 「exit planning mode」として表示 |
| **Opcode** | ❌ なし | - |

#### Happy Coderの実装

**ファイル**: `sources/components/tools/views/ExitPlanToolView.tsx`

```typescript
// ExitPlanModeのinputからplanテキストを抽出
const plan = knownTools.ExitPlanMode.input.safeParse(tool.input);
// → MarkdownViewでレンダリング + PermissionFooter（承認ボタン）
```

- プラン内容をMarkdown形式で表示
- 承認ボタンは通常のPermissionFooter（Allow/Deny）
- ccpocketのPlanCardと同等の機能

#### 💡 ccpocketへの示唆

ccpocketのPlanCard（Markdown表示 + 承認/編集機能）は他OSSより充実している。現行のまま問題なし。

---

### 3-4. エラー表示

#### 比較表

| OSS | 方式 | カラーリング | 特殊機能 |
|-----|------|------------|---------|
| **Happy Coder** | インラインボックス | error=赤背景, warning=オレンジ背景 | Warning/Errorアイコン使い分け |
| **CodePilot** | Markdownテキスト + ツール背景色 | error=`bg-destructive/10` | タイムアウト警告（60s黄/90s赤） |
| **Crystal** | グローバルErrorDialog + インラインボックス | error=赤, warning=黄 | 詳細折りたたみ、コマンド出力表示 |
| **Opcode** | Result Card | error=赤背景 + AlertCircleアイコン | コスト・所要時間表示 |

#### Happy Coderの実装

**ファイル**: `sources/components/tools/ToolError.tsx`

```
// エラーボックスのスタイル
error:   { background: '#FFF0F0', border: '#FF3B30', text: '#FF3B30' }
warning: { background: '#FFF8F0', border: '#FF9500', text: '#FF9500' }
```

- `tool.state === 'error'`時に自動表示
- パーミッション拒否時はエラー表示をスキップ

#### CodePilotの実装（タイムアウト警告が特徴的）

**ファイル**: `src/components/chat/StreamingMessage.tsx`

**StreamingStatusBar**: ストリーミング中のステータスバー
- シマーテキスト + 経過タイマー
- **60秒**: 黄色警告「Running longer than usual」
- **90秒**: 赤色警告「Tool may be stuck」 + **Force stopボタン**表示

```typescript
const isWarning = toolElapsed >= 60;
const isCritical = toolElapsed >= 90;
// isCritical → Force stopボタンを表示
```

#### Crystalの実装（2層構造）

1. **ErrorDialog**: グローバルエラー（モーダル）— タイトル + エラー詳細 + コマンド出力
2. **インラインエラー**: 会話内 — `bg-status-error/10` 背景 + XCircleアイコン

エラーカテゴリ別の表示:
| カテゴリ | 背景色 | アイコン |
|---------|--------|---------|
| system.error | 赤/10 | XCircle |
| git_error | 赤/10 | XCircle |
| tool_error | 赤/10 | XCircle |

#### 💡 ccpocketへの示唆

1. **タイムアウト警告**: CodePilot方式で長時間実行ツールに警告 + Force stop
2. **エラーカテゴリ別スタイル**: 背景色 + アイコンで視覚的区別
3. **詳細折りたたみ**: Crystal方式でエラー詳細を折りたたみ表示

---

### 3-5. ステータスインジケーター

#### 比較表

| OSS | 状態数 | アニメーション | 表示位置 |
|-----|--------|-------------|---------|
| **Happy Coder** | 4 | パルス (Reanimated) | 入力バー横のStatusDot |
| **CodePilot** | 3 | パルス + シマー | セッションリスト + メッセージ内 |
| **Crystal** | 6 | 回転 + パルス | ヘッダー + 会話内 |
| **Opcode** | 3 | パルス | メッセージリスト下部 |

#### Happy Coderの実装

**ファイル**: `sources/components/StatusDot.tsx`

React Native Reanimatedを使用したパルスアニメーション:

```typescript
// opacity 1.0 ↔ 0.3 を1秒周期で繰り返す
opacity.value = withRepeat(
  withTiming(0.3, { duration: 1000 }),
  -1,   // 無限ループ
  true   // リバース
);
```

| 状態 | 色 | パルス | テキスト |
|------|---|--------|---------|
| disconnected | #999 (グレー) | なし | "last seen {time}" |
| thinking | #007AFF (青) | **あり** | ランダムな"vibing"メッセージ |
| waiting | #34C759 (緑) | なし | "online" |
| permission_required | #FF9500 (オレンジ) | **あり** | "permission required" |

#### CodePilotの実装

**ファイル**: `src/components/chat/ChatListPanel.tsx`

セッションリストでのステータス表示:
- **ストリーミング中**: 緑のパルスドット（`animate-ping`）
- **承認待ち**: アンバーの通知アイコン（`bg-amber-500/10`）

```html
<!-- ストリーミング中 -->
<span class="relative flex h-2 w-2">
  <span class="absolute animate-ping rounded-full bg-green-400 opacity-75" />
  <span class="relative rounded-full bg-green-500" />
</span>

<!-- 承認待ち -->
<span class="flex h-3.5 w-3.5 items-center justify-center rounded-full bg-amber-500/10">
  <NotificationIcon class="h-2.5 w-2.5 text-amber-500" />
</span>
```

#### Crystalの実装（最も詳細）

**ファイル**: `frontend/src/components/StatusIndicator.tsx`

6状態をサポート + パフォーマンス最適化:

| 状態 | アイコン | 色 | アニメーション |
|------|---------|---|-------------|
| initializing | Loader2 | 緑 | 回転 (spin) |
| running | Loader2 | 緑 | 回転 (spin) |
| waiting | PauseCircle | 黄 | パルス (pulse) |
| stopped | CheckCircle | グレー | なし |
| completed_unviewed | Bell | 青 | パルス (pulse) |
| error | AlertCircle | 赤 | なし |

**パフォーマンス最適化**: ドキュメントが非表示（タブ切替等）のとき、アニメーションを自動停止。

**会話ログ内のステータスメッセージ** (`RichOutputView.tsx`):
| ステータス | 背景色 | タイトル |
|-----------|--------|---------|
| completed | 緑/10 | Session Completed |
| running | 青/10 | Session Running |
| waiting | 黄/10 | Waiting for Input |
| error | 赤/10 | Session Error |

#### 💡 ccpocketへの示唆

1. **StatusDotの強化**: Happy Coder方式でパルスアニメーション追加（thinking/permission_required）
2. **セッションリストのステータス**: CodePilot方式で承認待ちセッションに通知アイコン
3. **会話内ステータスメッセージ**: Crystal方式でステータス変更を会話ログに表示

---

### 3-6. ツール実行中の表示

#### 比較表

| OSS | 実行中表示 | 経過時間 | タイムアウト |
|-----|----------|---------|------------|
| **Happy Coder** | ActivityIndicator | なし | なし |
| **CodePilot** | シマーテキスト + ElapsedTimer | ✅ `Xs` / `Xm Xs` | ✅ 60s警告/90s強制停止 |
| **Crystal** | Loader2 (spin) | なし | なし |
| **Opcode** | パルスドット + "Running..." | なし | なし |

#### CodePilotのElapsedTimer（参考実装）

```typescript
function ElapsedTimer() {
  const [elapsed, setElapsed] = useState(0);
  useEffect(() => {
    const interval = setInterval(() => {
      setElapsed(Math.floor((Date.now() - startRef.current) / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, []);
  const mins = Math.floor(elapsed / 60);
  const secs = elapsed % 60;
  return <span>{mins > 0 ? `${mins}m ${secs}s` : `${secs}s`}</span>;
}
```

#### 💡 ccpocketへの示唆

1. **経過タイマー**: CodePilot方式でツール実行時間を表示
2. **タイムアウト警告**: 長時間実行ツールに警告 + 停止ボタン

---

### 3-7. ツールグループ表示

#### CodePilotの折りたたみグループ（`tool-actions-group.tsx`）

連続するツール実行を1グループにまとめて表示:

```
[▶] [6] 3 running · 2 completed           git commit...
```

**特徴**:
- 展開/折りたたみトグル
- 自動展開: 実行中のツールがある場合
- 自動折りたたみ: 全ツール完了時
- ユーザー操作を優先: 手動で操作した場合は自動制御を停止

**個別ツール行**:
```
[FileIcon] Edit  main.dart           [✓ green dot]
[Terminal] Bash  git commit -m "..."  [↻ spinning]
```

#### 💡 ccpocketへの示唆

現在のccpocketでは各ToolUseTileが独立表示。連続ツールをグループ化して折りたたみ表示にすると視認性が向上する。

---

## 総合改善提案（インタラクティブメッセージ）

### 優先度A: 即座に取り込めるUX改善

| 改善項目 | 参考OSS | 工数 |
|---------|--------|------|
| 承認後のフィードバック表示（Allowed/Denied + 短時間表示） | CodePilot | 小 |
| StatusDotのパルスアニメーション | Happy Coder | 小 |
| エラー表示の色分け強化（背景色 + アイコン） | Crystal | 小 |
| ツール実行中の経過タイマー表示 | CodePilot | 小 |

### 優先度B: 中期的に取り組む改善

| 改善項目 | 参考OSS | 工数 |
|---------|--------|------|
| 高リスクツール警告バッジ（Bash/Write/Edit） | Crystal | 中 |
| セッションリストに承認待ちアイコン表示 | CodePilot | 中 |
| ツールグループ折りたたみ表示 | CodePilot | 中 |
| ストリーミングタイムアウト警告 + Force stop | CodePilot | 中 |

### 優先度C: 将来的に検討

| 改善項目 | 参考OSS | 工数 |
|---------|--------|------|
| 承認時のパラメータ編集機能 | Crystal | 大 |
| 会話ログ内ステータスメッセージ表示 | Crystal | 中 |
| Favicon/プッシュ通知でのパーミッション通知 | Happy Coder | 大 |

---

## 参照ファイル一覧

### CodePilot
- `src/components/ai-elements/tool-actions-group.tsx` — ツールグループ折りたたみ表示
- `src/components/chat/ToolCallBlock.tsx` — ツール個別表示
- `src/components/chat/confirmation.tsx` — パーミッション承認UI (7状態管理)
- `src/components/chat/StreamingMessage.tsx` — ストリーミングステータスバー + タイムアウト警告
- `src/components/chat/ChatListPanel.tsx` — セッションリスト承認待ちアイコン
- `src/components/ai-elements/tool.tsx` — ツールステータスバッジ

### Happy Coder
- `sources/sync/typesRaw.ts` — Raw message型定義
- `sources/sync/typesMessage.ts` — UI message型定義
- `sources/sync/reducer/reducer.ts` — 5フェーズreducer
- `sources/components/tools/PermissionFooter.tsx` — 承認UIフッター
- `sources/components/tools/ToolError.tsx` — エラー表示
- `sources/components/tools/views/ExitPlanToolView.tsx` — Plan Mode表示
- `sources/components/StatusDot.tsx` — パルスアニメーション付きステータスドット
- `sources/components/AgentInput.tsx` — 入力バー + ステータス表示

### Opcode
- `src/components/StreamMessage.tsx` — メッセージレンダリング
- `src/components/ToolWidgets.tsx` — 全ツールWidget定義
- `src/components/widgets/BashWidget.tsx` — Bash専用Widget
- `src/components/widgets/TodoWidget.tsx` — Todo専用Widget

### Crystal
- `frontend/src/components/panels/ai/transformers/ClaudeMessageTransformer.ts` — メッセージ変換
- `frontend/src/components/PermissionDialog.tsx` — モーダル承認ダイアログ
- `frontend/src/components/StatusIndicator.tsx` — 6状態ステータスインジケーター
- `frontend/src/components/ErrorDialog.tsx` — グローバルエラーダイアログ
- `frontend/src/components/panels/ai/RichOutputView.tsx` — インラインステータス/エラー表示
