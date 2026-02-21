# Claude CLI Stream-JSON Protocol Specification

> Reverse-engineered from Claude CLI v2.1.29+ (Mach-O ARM64, Node.js SEA)
> SDK version: `@anthropic-ai/claude-agent-sdk@0.2.50`
> Last updated: 2026-02-21

---

## 1. Overview

Claude CLI supports a programmatic `stream-json` protocol for integration with external tools.
Communication happens via **stdin** (JSON messages, newline-delimited) and **stdout** (JSON events, newline-delimited).

This document captures the protocol details discovered through binary analysis and integration testing.

---

## 2. CLI Startup Options

### Format Flags

| Flag | Values | Description |
|------|--------|-------------|
| `--output-format` | `text` (default), `json`, `stream-json` | Output event format |
| `--input-format` | `text` (default), `stream-json` | Input message format |
| `--include-partial-messages` | (flag) | Include `stream_event` messages for real-time streaming |
| `--verbose` | (flag) | Enable verbose output |

### Session Management

| Flag | Description |
|------|-------------|
| `-c`, `--continue` | Continue the most recent conversation in the current directory |
| `-r`, `--resume [sessionId]` | Resume by session ID, or open interactive picker |
| `--fork-session` | Create a new session ID when resuming (use with `--resume` or `--continue`) |
| `--from-pr [value]` | Resume session linked to a PR |
| `--session-id <uuid>` | Use a specific session ID |
| `--no-session-persistence` | Disable session persistence (only with `--print`) |

### Permission Flags

| Flag | Description |
|------|-------------|
| `--permission-mode <mode>` | Set permission mode (see Section 5) |
| `--allowed-tools <tools...>` | Comma/space-separated tool rules to allow (e.g. `"Bash(git:*) Edit"`) |
| `--disallowed-tools <tools...>` | Tool rules to deny |
| `--dangerously-skip-permissions` | Bypass all permission checks |
| `--permission-prompt-tool <tool>` | MCP tool for custom permission prompts (only with `--print`) |

### Model & Agent

| Flag | Description |
|------|-------------|
| `--model <model>` | Model alias (`sonnet`, `opus`) or full name |
| `--agent <agent>` | Agent for the session |
| `--fallback-model <model>` | Fallback when default model is overloaded |
| `--max-thinking-tokens <n>` | Maximum thinking tokens (only with `--print`) |
| `--max-turns <n>` | Maximum agentic turns (only with `--print`) |
| `--max-budget-usd <n>` | Maximum API spend |

### Other

| Flag | Description |
|------|-------------|
| `-p`, `--print` | Non-interactive mode: print and exit |
| `--system-prompt <prompt>` | Custom system prompt |
| `--append-system-prompt <prompt>` | Append to default system prompt |
| `--mcp-config <configs...>` | Load MCP server configs |
| `--add-dir <dirs...>` | Additional directories to allow tool access |
| `--tools <tools...>` | Specify available tools from built-in set |

---

## 3. CLI Output Events (stdout)

All events are newline-delimited JSON objects with a `type` field.

### 3.1 System Init Event

Emitted once at startup after initialization.

```typescript
{
  type: "system";
  subtype: "init";
  session_id: string;          // Unique session identifier
  tools: string[];             // Available tool names
  model: string;               // Active model name
  slash_commands?: string[];   // Available slash command names (without "/")
  skills?: string[];           // User-invocable skill names
  agents?: string[];           // Available agent types
  mcp_servers?: Array<{ name: string; status: string }>;
  permissionMode?: string;     // Current permission mode
  claude_code_version?: string;
}
```

**Example:**
```json
{
  "type": "system",
  "subtype": "init",
  "session_id": "abc-123",
  "tools": ["Bash", "Read", "Edit", "Write", "Glob", "Grep"],
  "model": "claude-opus-4-5-20251101",
  "slash_commands": ["compact", "context", "cost", "init", "review", "pr-comments", "release-notes", "security-review", "keybindings-help"],
  "skills": ["keybindings-help"],
  "agents": ["Bash", "general-purpose", "Plan", "Explore"]
}
```

**Notes:**
- `slash_commands` includes both built-in commands and custom commands from `.claude/commands/` directories
- `skills` contains only user-invocable skills (those with `user-invocable: true` or not set to false)
- Fields added in CLI v2.1.x; older versions may omit them

### 3.2 Assistant Message Event

Emitted when Claude produces a response (complete message, not streaming).

```typescript
{
  type: "assistant";
  message: {
    id: string;
    role: "assistant";
    content: AssistantContent[];
    model: string;
  };
}
```

**Content block types:**

```typescript
// Text response
{ type: "text"; text: string }

// Tool invocation
{ type: "tool_use"; id: string; name: string; input: Record<string, unknown> }

// Extended thinking
{ type: "thinking"; thinking: string }
```

### 3.3 User Tool Result Event

Emitted when tool results are provided back to Claude (either auto-executed or user-approved).

```typescript
{
  type: "user";
  message: {
    role: "user";
    content: [
      {
        type: "tool_result";
        tool_use_id: string;      // References tool_use.id from assistant message
        content: string | ContentBlock[];  // Result text or content block array
      }
    ];
  };
}
```

**Note:** A single `user` event may contain multiple `tool_result` blocks when tools run in parallel.

### 3.4 Result Event

Emitted at the end of a conversation turn.

```typescript
// Success
{
  type: "result";
  subtype: "success";
  result: string;           // Final assistant text
  total_cost_usd: number;
  duration_ms: number;
  duration_api_ms: number;
  num_turns: number;
  is_error: false;
  session_id: string;
}

// Error
{
  type: "result";
  subtype: "error" | "error_during_execution";
  error: string;
  is_error: true;
  session_id: string;
}
```

### 3.5 Stream Event (Partial Messages)

Requires `--include-partial-messages`. Wraps Anthropic API streaming events.

```typescript
{
  type: "stream_event";
  event: StreamEvent;
  parent_tool_use_id: string | null;
  uuid: string;
  session_id: string;
}
```

**Stream event types:**

| Event Type | Description |
|-----------|-------------|
| `message_start` | Start of a new message |
| `content_block_start` | New content block (text, tool_use, thinking) |
| `content_block_delta` | Incremental update to current block |
| `content_block_stop` | Content block finished |
| `message_delta` | Message-level update (usage info) |
| `message_stop` | Message complete |

**Delta types within `content_block_delta`:**

| Delta Type | Field | Description |
|-----------|-------|-------------|
| `text_delta` | `text` | Incremental text content |
| `thinking_delta` | `thinking` | Incremental thinking content |
| `input_json_delta` | `partial_json` | Incremental tool input JSON |

---

## 4. CLI Input Messages (stdin)

### 4.1 User Text Message

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [{ "type": "text", "text": "User message here" }]
  }
}
```

### 4.2 Tool Result Message

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [
      {
        "type": "tool_result",
        "tool_use_id": "<id-from-tool_use-block>",
        "content": "Tool output string"
      }
    ]
  }
}
```

**Note:** `content` can be a string or an array of content blocks (`[{ type: "text", text: "..." }]`).

---

## 5. Permission System

### 5.1 Permission Modes

Set via `--permission-mode <mode>` CLI flag.

| Mode | Behavior |
|------|----------|
| `default` | Ask for every tool execution |
| `acceptEdits` | Auto-approve safe tools (Read, Edit, Write, etc.), ask for Bash/MCP |
| `bypassPermissions` | Auto-approve all tools |
| `plan` | Analysis only, requires approval |
| `delegate` | Requires approval (like default) |
| `dontAsk` | Auto-deny all permission prompts (non-interactive) |

**Safe tools in `acceptEdits` mode:**
`Read`, `Glob`, `Grep`, `Edit`, `Write`, `NotebookEdit`, `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`, `EnterPlanMode`, `AskUserQuestion`, `WebSearch`, `WebFetch`, `Task`, `Skill`

Exception: `ExitPlanMode` always requires approval even in `acceptEdits` mode.

### 5.2 Rule Format

Rules follow the pattern: `ToolName(ruleContent)`

| Rule | Meaning |
|------|---------|
| `Read` | Any use of the Read tool |
| `Bash(npm:*)` | Any Bash command starting with `npm` |
| `Bash(git status)` | Exact Bash command `git status` |
| `Edit(.claude)` | Edit tool for `.claude` paths |
| `Write(/etc/*)` | Write tool for `/etc/` paths |

**Parsing regex** (internal function `pzT`):
```javascript
/^([^(]+)\(([^)]+)\)$/
// → { toolName: match[1], ruleContent: match[2] }
// If no match → { toolName: fullString, ruleContent: undefined }
```

**Bash ruleContent matching:**
- `ruleContent.endsWith(":*")` → prefix match (e.g., `npm:*` matches any command starting with `npm`)
- Otherwise → exact match

### 5.3 Rule Behaviors

| Behavior | Description |
|----------|-------------|
| `allow` | Auto-approve tool execution |
| `deny` | Auto-reject tool execution |
| `ask` | Always prompt user for approval |
| `passthrough` | Internal: no rule matched, continue checking |

### 5.4 Rule Destinations (Scopes)

Rules are organized by where they are stored:

| Destination | Persistence | Source |
|------------|-------------|--------|
| `session` | In-memory, volatile | Session-scoped approvals |
| `cliArg` | In-memory | `--allowed-tools` / `--disallowed-tools` CLI args |
| `command` | In-memory | Slash commands |
| `localSettings` | File | `.claude/settings.local.json` |
| `projectSettings` | File | `.claude/settings.json` (checked in) |
| `userSettings` | File | `~/.claude/settings.json` |
| `policySettings` | File | Organization policies (read-only) |
| `flagSettings` | Runtime | Feature flags (read-only) |

### 5.5 toolPermissionContext Structure

Internal state object managing all permission rules:

```typescript
{
  mode: PermissionMode;
  additionalWorkingDirectories: Map<string, { path: string; source: string }>;
  alwaysAllowRules: {
    session: string[];          // e.g., ["Read(/path)", "Bash(npm:*)"]
    cliArg: string[];
    command: string[];
    localSettings: string[];
    projectSettings: string[];
    userSettings: string[];
    policySettings: string[];
    flagSettings: string[];
  };
  alwaysDenyRules: { /* same structure */ };
  alwaysAskRules: { /* same structure */ };
  isBypassPermissionsModeAvailable: boolean;
  shouldAvoidPermissionPrompts: boolean;
}
```

### 5.6 Rule Operations

| Operation | Description |
|-----------|-------------|
| `addRules` | Add rules: `{ type: "addRules", rules: RuleValue[], behavior: string, destination: string }` |
| `removeRules` | Remove rules: `{ type: "removeRules", rules: RuleValue[], behavior: string, destination: string }` |
| `replaceRules` | Replace all rules: `{ type: "replaceRules", rules: RuleValue[], behavior: string, destination: string }` |

### 5.7 Permission Check Flow

Internal function `SQ8` / `D5` (deobfuscated as `checkPermission`):

1. **Check deny rules** → if match, return `{ behavior: "deny" }`
2. **Check ask rules** → if match, return `{ behavior: "ask" }`
3. **Call `tool.checkPermissions()`** → returns passthrough/allow/deny/ask
4. If deny, return deny
5. If `requiresUserInteraction` and ask, return ask
6. **Check mode** → if `bypassPermissions` or `plan` with bypass available, return allow
7. **Check allow rules** → if match, return allow
8. **Default**: return ask with message

### 5.8 Settings File Format

```json
{
  "permissions": {
    "allow": ["Bash(npm:*)", "Edit(.claude)", "Read"],
    "deny": ["Bash(rm -rf:*)"],
    "ask": ["Write(/etc/*)"],
    "defaultMode": "acceptEdits",
    "additionalDirectories": ["/path/to/extra"]
  }
}
```

### 5.9 CLI UI Labels

| Label | Action |
|-------|--------|
| `"Yes, for this session"` | Add allow rule to `session` destination |
| `"Yes, and allow Claude to edit its own settings for this session"` | Special case for settings editing |

---

## 6. AskUserQuestion

### 6.1 Input Schema

```typescript
interface AskUserQuestionInput {
  questions: Array<{           // 1-4 questions
    question: string;          // The question text
    header: string;            // Short label (max 12 chars)
    options: Array<{           // 2-4 options per question
      label: string;           // Display text (1-5 words)
      description: string;     // Explanation
    }>;
    multiSelect: boolean;      // Allow multiple selections
  }>;
  answers?: {                  // Optional: pre-populated or collected answers
    [k: string]: string;       // Key = question text, Value = selected label(s)
  };
  metadata?: {                 // Optional: tracking/analytics metadata
    source?: string;           // e.g. "remember" for /remember command
  };
}
```

### 6.2 Answer Format

The `answers` field maps question text to selected answer:

```json
{
  "questions": [
    { "question": "Which library?", "header": "Library", "options": [...] }
  ],
  "answers": {
    "Which library?": "React"
  }
}
```

For `multiSelect`, the answer contains comma-separated labels.

### 6.3 CLI-only Features (SDK未公開)

Claude Code CLIのターミナルUIでは、選択肢に `markdown` プレビューフィールドがサポートされている。
選択肢にフォーカスすると右側にASCIIモックアップやコード例がサイドバイサイドで表示される。

**しかし、このフィールドはSDK (`@anthropic-ai/claude-agent-sdk@0.2.50`) の公開スキーマには含まれていない。**
CLIの内部レンダリング専用で、stream-json出力には現れない。

| Feature | CLI Terminal UI | SDK stream-json |
|---------|----------------|-----------------|
| `label` | Yes | Yes |
| `description` | Yes | Yes |
| `markdown` preview | Yes (side-by-side) | **Not exposed** |
| `annotations` | Yes (internal) | **Not exposed** |

ccpocketで対応する場合、SDKへの追加を待つ必要がある。

---

## 7. SDK Control Requests

When using `--input-format stream-json`, the CLI also accepts control requests:

| Subtype | Description |
|---------|-------------|
| `initialize` | Initialize session (system prompt, agents, hooks, MCP servers) |
| `set_permission_mode` | Change permission mode at runtime |
| `set_model` | Change model at runtime |
| `set_max_thinking_tokens` | Change thinking token limit |
| `interrupt` | Abort current operation |
| `mcp_status` | Get MCP server connection status |
| `mcp_set_servers` | Configure MCP servers |
| `mcp_reconnect` | Reconnect a specific MCP server |
| `mcp_toggle` | Enable/disable MCP server |
| `mcp_message` | Send message to MCP server |
| `rewind_files` | Revert files to a checkpoint |

**Format:**

```json
{
  "type": "control_request",
  "request_id": "unique-id",
  "request": {
    "subtype": "set_permission_mode",
    "mode": "acceptEdits"
  }
}
```

**Response:**

```json
{
  "type": "control_response",
  "response": {
    "subtype": "success",
    "request_id": "unique-id",
    "response": { ... }
  }
}
```

---

## 8. Bridge Server WebSocket Protocol

The ccpocket Bridge Server translates between Flutter mobile app (WebSocket) and Claude CLI (stdio).

### 8.1 Client -> Server Messages

| Type | Fields | Description |
|------|--------|-------------|
| `start` | `projectPath`, `sessionId?`, `continue?`, `permissionMode?` | Start new session |
| `input` | `text`, `sessionId?` | Send user message |
| `approve` | `id`, `sessionId?` | Approve tool execution |
| `approve_always` | `id`, `sessionId?` | Approve and allow for session |
| `reject` | `id`, `message?`, `sessionId?` | Reject tool execution |
| `answer` | `toolUseId`, `result`, `sessionId?` | Respond to AskUserQuestion |
| `list_sessions` | | List active sessions |
| `stop_session` | `sessionId` | Stop a session |
| `get_history` | `sessionId` | Get session message history |
| `list_recent_sessions` | `limit?` | List recent sessions |
| `resume_session` | `sessionId`, `projectPath`, `permissionMode?` | Resume a previous session |

### 8.2 Server -> Client Messages

| Type | Key Fields | Description |
|------|-----------|-------------|
| `system` | `subtype`, `sessionId?`, `model?` | System events (init, session_created) |
| `assistant` | `message` (with content array) | Claude's response |
| `tool_result` | `toolUseId`, `content`, `toolName?`, `images?` | Tool execution result |
| `result` | `subtype`, `result?`, `error?`, `cost?`, `duration?`, `sessionId?` | Final result or error |
| `error` | `message` | Error notification |
| `status` | `status` | Process status change |
| `history` | `messages` | Message history array |
| `permission_request` | `toolUseId`, `toolName`, `input` | Tool needs approval |
| `stream_delta` | `text` | Streaming text delta |
| `thinking_delta` | `text` | Streaming thinking delta |

### 8.3 Process Status

| Status | Meaning |
|--------|---------|
| `idle` | Waiting for user input |
| `running` | Processing / executing tools |
| `waiting_approval` | Tool execution needs user approval |

---

## Appendix: Reverse Engineering Notes

- **Binary format**: Node.js SEA (Single Executable Application) built with Bun runtime
- **Obfuscation**: Variable names minified but string literals preserved
- **Key internal functions**:
  - `pzT()` — Parse rule format `ToolName(ruleContent)`
  - `SQ8()` / `D5` — Permission check (deny → ask → checkPermissions → mode → allow → ask)
  - `HhT()` — Get all allow rules
  - `kc()` — Get all deny rules
  - `qhT()` — Get all ask rules
  - `j1()` — Apply rule operation to context
  - `bU8()` — Create permission prompt tool handler
  - `D5` — Default `canUseTool` function
- **Telemetry prefix**: `tengu_` (e.g., `tengu_bash_tool_command_executed`)
- **Settings files**: `~/.claude/settings.json`, `.claude/settings.json`, `.claude/settings.local.json`

---

## 9. Slash Commands & Skills

### 9.1 Command Discovery

Available commands are reported in the `system.init` event's `slash_commands` array.
This includes both built-in commands and custom commands from `.claude/commands/` directories.
Commands are sent to the CLI as plain text user input (e.g., `"/review"`). The CLI handles interpretation.

### 9.2 Built-in Commands

| Command | Description |
|---------|-------------|
| `/compact [instructions]` | Summarize conversation to free context |
| `/context` | Show context usage and excluded skills |
| `/cost` | Show token usage and cost |
| `/clear` | Clear conversation history |
| `/help` | Show all available commands |
| `/plan` | Switch to Plan mode |
| `/model` | Switch model (Sonnet, Opus, Haiku) |
| `/status` | Show version and connectivity |
| `/config` | Open settings panel |
| `/permissions` | View and update tool permissions |
| `/init` | Initialize project with CLAUDE.md |
| `/memory` | Open CLAUDE.md for editing |
| `/review` | Code review of current changes |
| `/pr-comments` | PR comments |
| `/release-notes` | Generate release notes |
| `/security-review` | Security review |
| `/resume` | Resume a previous session |
| `/rename` | Rename current session |
| `/rewind` | Rewind to a previous point |
| `/export [filename]` | Export conversation |
| `/doctor` | Run health checks |
| `/add-dir` | Add working directories |
| `/mcp` | Manage MCP servers |
| `/vim` | Enable vim mode |
| `/login` | Switch Anthropic accounts |

### 9.3 Custom Commands (`.claude/commands/`)

Markdown files placed in these directories become slash commands:

| Directory | Scope |
|-----------|-------|
| `<project>/.claude/commands/` | Project-level (committable) |
| `~/.claude/commands/` | User-level (global) |

**File format:**
```markdown
---
description: Brief description for /help listing
allowed-tools: Read, Grep, Glob, Bash(git:*)
---
Prompt content sent to Claude when command is invoked.
Use $ARGUMENTS for all arguments, or $1, $2 for positional.
```

- Filename (minus `.md`) becomes the command name: `review-pr.md` → `/review-pr`
- Subdirectories create namespaced commands: `db/migrate.md` → `/db:migrate`
- Frontmatter is optional; body is the prompt text

### 9.4 Skills (`.claude/skills/`)

Skills are the evolution of custom commands with richer capabilities:

```
.claude/skills/
  my-skill/
    SKILL.md           # Required: skill definition
    scripts/           # Optional: executable scripts
    references/        # Optional: documentation
    templates/         # Optional: templates
```

**SKILL.md frontmatter:**

| Field | Description |
|-------|-------------|
| `name` | Skill identifier (max 64 chars, lowercase/numbers/hyphens) |
| `description` | How Claude decides when to auto-invoke (max 1024 chars) |
| `disable-model-invocation` | If true, only user can invoke |
| `user-invocable` | If false, only Claude can invoke |
| `allowed-tools` | Restrict available tools |
| `context: fork` | Run as isolated subagent |
| `agent` | Specify agent type (e.g., Explore) |

**Skill locations scanned:**
- `<project>/.claude/skills/` — project skills
- `~/.claude/skills/` — user skills
- `~/.config/claude/skills/` — user skills (alternative)
- Plugin-provided skills

**Progressive loading:** At startup, only `name` and `description` are loaded. Full content is loaded on demand.

### 9.5 Execution

All commands (built-in, custom, skills) are executed by sending the command text as a regular user text message via stdin:

```json
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"/review main"}]}}
```

The CLI internally detects the `/` prefix, matches the command, loads the markdown content, substitutes `$ARGUMENTS`, and processes it as a prompt.
