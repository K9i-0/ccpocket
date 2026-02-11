# Agent Teams 拡張設計

## 調査結果 (2025-02-11)

### SDK バージョン: @anthropic-ai/claude-agent-sdk v0.2.39

### Agent Teams の現状

- **Agent Teams は Claude Code CLI の機能**であり、SDK の `query()` から直接チームを作成する API はない
- 環境変数 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で有効化（実験的機能）
- SDK は `agents` オプションで**サブエージェント**（単一セッション内のヘルパー）を定義可能

### 利用可能な SDK API

#### サブエージェント定義 (`agents` オプション)

```typescript
query({
  prompt,
  options: {
    agents: {
      "code-reviewer": {
        description: "Expert code reviewer",
        prompt: "Analyze code quality",
        tools: ["Read", "Glob", "Grep"],
        model: "sonnet",  // optional: "sonnet" | "opus" | "haiku" | "inherit"
      },
    },
  },
});
```

- Claude が `Task` ツールでサブエージェントを生成
- 各エージェントは独立したコンテキストウィンドウを持つ
- `tools` で利用可能なツールを制限可能

#### フックイベント

| イベント | トリガー | 制御方法 |
|---------|---------|---------|
| `TeammateIdle` | チームメイトがアイドル状態になるとき | exit 0: 許可, exit 2: stderr をフィードバックとして送信 |
| `TaskCompleted` | タスク完了マーク時 | exit 0: 許可, exit 2: 完了をブロック + フィードバック |

```typescript
// フック入力型
type TeammateIdleHookInput = {
  hook_event_name: 'TeammateIdle';
  session_id: string;
  cwd: string;
  permission_mode: string;
  teammate_name: string;
  team_name: string;
};

type TaskCompletedHookInput = {
  hook_event_name: 'TaskCompleted';
  session_id: string;
  cwd: string;
  permission_mode: string;
  task_id: string;
  task_subject: string;
  task_description?: string;
  teammate_name?: string;
  team_name?: string;
};
```

#### sessionId オプション

- TypeScript SDK では未実装 ([Issue #145](https://github.com/anthropics/claude-agent-sdk-typescript/issues/145))
- 回避策: `extraArgs: { 'session-id': uuid }` で渡せる
- `resume` とは異なり、新規セッション作成時にカスタム UUID を指定する用途

### Agent Teams の制約

1. CLI 専用機能であり SDK から直接制御不可
2. セッション再開時にチームメイトは復元されない
3. ネストされたチームは不可（チームメイトが自チームを作成できない）
4. 各チームメイトが独立した Claude インスタンス（コスト増大）
5. 1セッション = 1チームのみ

---

## 拡張設計

### Bridge Server の変更

#### SessionInfo 拡張

```typescript
interface SessionInfo {
  // 既存フィールド
  id: string;
  process: SdkProcess;
  history: ServerMessage[];
  projectPath: string;
  claudeSessionId?: string;
  status: ProcessStatus;
  // ...

  // 新規フィールド
  agentId?: string;          // エージェント識別子 (チーム内)
  teamId?: string;           // チーム識別子
  parentSessionId?: string;  // 親セッション (サブエージェント用)
}
```

#### SessionManager 拡張

```typescript
class SessionManager {
  // 既存メソッド
  create(projectPath, options, pastMessages, worktreeOpts): string;
  get(id): SessionInfo | undefined;
  list(): SessionSummary[];
  destroy(id): boolean;

  // 新規メソッド
  getByAgentTeam(agentId: string, teamId: string): SessionInfo | undefined;
  listByTeam(teamId: string): SessionInfo[];
  assignTask(taskId: string, agentId: string, context: string): void;
}
```

#### resolveSession 拡張

```typescript
private resolveSession(
  sessionId: string | undefined,
  agentId?: string,
  teamId?: string,
): SessionInfo | undefined {
  if (sessionId) return this.sessionManager.get(sessionId);
  if (agentId && teamId) {
    return this.sessionManager.getByAgentTeam(agentId, teamId);
  }
  return this.getFirstSession();
}
```

#### 新規 WebSocket メッセージタイプ

```typescript
// Client → Server
| { type: "team:create"; projectPath: string; agents: Record<string, AgentDef> }
| { type: "team:assign_task"; teamId: string; agentId: string; task: string }
| { type: "team:status"; teamId: string }

// Server → Client
| { type: "team:created"; teamId: string; agents: string[] }
| { type: "team:agent_status"; teamId: string; agentId: string; status: ProcessStatus }
| { type: "team:task_completed"; teamId: string; agentId: string; taskId: string }
```

### Flutter の変更

#### TeamOrchestratorCubit (新規)

```dart
class TeamOrchestratorCubit extends Cubit<TeamOrchestratorState> {
  final Map<String, ChatSessionCubit> agentSessions;
  final String teamId;
  final BridgeService _bridge;

  void assignSessionToAgent(String agentId, String sessionId) {
    agentSessions[agentId] = ChatSessionCubit(
      sessionId: sessionId,
      bridge: _bridge,
    );
  }
}
```

#### BridgeService 拡張

```dart
// メッセージタグを (msg, sessionId, agentId) の3要素に拡張
Stream<ServerMessage> messagesForAgent(String sessionId, String agentId) {
  return _taggedMessageController.stream
      .where((triple) =>
        (triple.$2 == null || triple.$2 == sessionId) &&
        (triple.$3 == null || triple.$3 == agentId))
      .map((triple) => triple.$1);
}
```

#### UI 設計

セッション一覧でチーム階層を表示:

```
Team: "Feature X Development"
  ├─ researcher (idle)
  ├─ coder (running)
  └─ tester (waiting)

Team: "Bug Fixes"
  └─ debugger (running)
```

### データフロー

```
Flutter UI
    ↓ team:create { agents: {...} }
Bridge Server
    ↓ SessionManager.create() × N (エージェント数分)
    ↓ SdkProcess.start() with agents option
Claude CLI (独立インスタンス × N)
    ↓ SDKMessage (async iterator)
SdkProcess.on('message')
    ↓ broadcastSessionMessage(sessionId, msg) with agentId tag
WebSocket → Flutter
    ↓ ChatSessionCubit per agent
TeamOrchestratorCubit (統括)
```

### 実装優先順位

1. **Phase 1**: `agents` オプション対応 (Bridge → SDK のパススルー)
2. **Phase 2**: Flutter UI でチーム表示・制御
3. **Phase 3**: `TeammateIdle` / `TaskCompleted` フック統合
4. **Phase 4**: `sessionId` オプション対応 (SDK 実装待ち)
