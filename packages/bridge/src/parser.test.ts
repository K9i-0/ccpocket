import { describe, it, expect } from "vitest";
import {
  isAgentBackgroundTask,
  normalizeToolResultContent,
  parseClientMessage,
} from "./parser.js";

// ---- normalizeToolResultContent ----

describe("normalizeToolResultContent", () => {
  it("returns string as-is", () => {
    expect(normalizeToolResultContent("hello")).toBe("hello");
  });

  it("returns empty string for empty string input", () => {
    expect(normalizeToolResultContent("")).toBe("");
  });

  it("extracts text blocks from array", () => {
    const content = [
      { type: "text", text: "line1" },
      { type: "text", text: "line2" },
    ];
    expect(normalizeToolResultContent(content)).toBe("line1\nline2");
  });

  it("filters out non-text blocks", () => {
    const content = [
      { type: "text", text: "keep" },
      { type: "image", data: "abc" },
      { type: "text", text: "also keep" },
    ];
    expect(normalizeToolResultContent(content)).toBe("keep\nalso keep");
  });

  it("returns empty string for empty array", () => {
    expect(normalizeToolResultContent([])).toBe("");
  });

  it("handles non-string non-array via String()", () => {
    expect(normalizeToolResultContent(42 as unknown as string)).toBe("42");
  });

  it("handles null/undefined via fallback", () => {
    expect(normalizeToolResultContent(null as unknown as string)).toBe("");
    expect(normalizeToolResultContent(undefined as unknown as string)).toBe("");
  });
});

// ---- parseClientMessage ----

describe("parseClientMessage", () => {
  it("validates loopback Finder proofs without accepting a remote host or file path", () => {
    const request = { type: "reveal_file_local", projectPath: "/p", filePath: "movie.mp4",
      requestId: "reveal-2", proofPort: 54321, proofToken: "a".repeat(64) };
    expect(parseClientMessage(JSON.stringify(request))).toEqual(request);
    for (const patch of [{ proofPort: 0 }, { proofPort: 80 }, { proofPort: 65536 },
      { proofPort: "12345" }, { proofPort: 1234.5 }, { proofHost: "example.com" },
      { proofPath: "/some/file" }, { proofToken: "bad" }]) {
      expect(parseClientMessage(JSON.stringify({ ...request, ...patch }))).toBeNull();
    }
  });
  it("validates Finder reveal requests and their locality proof", () => {
    const request = { type: "reveal_file", projectPath: "/p", filePath: "video.mp4",
      requestId: "reveal-1", proofPath: "/tmp/ccpocket-finder-abc/proof", proofToken: "a".repeat(64) };
    expect(parseClientMessage(JSON.stringify(request))).toEqual(request);
    for (const patch of [{ proofToken: "bad" }, { requestId: "" }, { filePath: "x\0y" },
      { proofPath: 5 }, { command: "open" }]) {
      expect(parseClientMessage(JSON.stringify({ ...request, ...patch }))).toBeNull();
    }
  });
  it("parses start request correlation", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","requestId":"start-1"}',
      ),
    ).toMatchObject({
      type: "start",
      projectPath: "/p",
      requestId: "start-1",
    });
  });
  it("parses file upload lifecycle messages and rejects invalid policies", () => {
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "prepare_file_upload",
          projectPath: "/repo",
          directoryPath: "docs",
          fileName: "report.pdf",
          sizeBytes: 10,
          conflictPolicy: "rename",
          requestId: "upload-1",
        }),
      ),
    ).toMatchObject({ type: "prepare_file_upload", sizeBytes: 10 });
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "prepare_file_upload",
          projectPath: "/repo",
          directoryPath: "",
          fileName: "report.pdf",
          sizeBytes: 10,
          conflictPolicy: "delete",
          requestId: "upload-1",
        }),
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "finalize_file_upload",
          uploadToken: "a".repeat(48),
          sha256: "b".repeat(64),
          requestId: "upload-1",
        }),
      ),
    ).toMatchObject({ type: "finalize_file_upload" });
  });

  it("parses client capabilities", () => {
    const msg = parseClientMessage(
      '{"type":"client_capabilities","protocolVersion":1,"minimumProtocolVersion":1,"appVersion":"1.72.1","supportedServerMessages":["conversation_queue"]}',
    );
    expect(msg).toEqual({
      type: "client_capabilities",
      protocolVersion: 1,
      minimumProtocolVersion: 1,
      appVersion: "1.72.1",
      supportedServerMessages: ["conversation_queue"],
    });
  });

  it("rejects an invalid client protocol range", () => {
    expect(
      parseClientMessage(
        '{"type":"client_capabilities","protocolVersion":1,"minimumProtocolVersion":2}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"client_capabilities","minimumProtocolVersion":1}',
      ),
    ).toBeNull();
  });

  it("rejects client capabilities with invalid supported messages", () => {
    expect(
      parseClientMessage(
        '{"type":"client_capabilities","supportedServerMessages":[123]}',
      ),
    ).toBeNull();
  });

  it("parses prompt history sync messages", () => {
    const msg = parseClientMessage(
      JSON.stringify({
        type: "sync_prompt_history",
        clientId: "phone",
        clientName: "iPhone",
        sinceRevision: 3,
        includeDeleted: true,
        entries: [{ text: "/test", projectPath: "/repo", totalUseCount: 2 }],
      }),
    );
    expect(msg).toEqual({
      type: "sync_prompt_history",
      clientId: "phone",
      clientName: "iPhone",
      sinceRevision: 3,
      includeDeleted: true,
      entries: [{ text: "/test", projectPath: "/repo", totalUseCount: 2 }],
    });
  });

  it("parses prompt history custom Project identity", () => {
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "record_prompt_history",
          text: "same prompt",
          projectPath: "/shared/primary",
          projectId: "project-a",
          projectName: "Flutter apps",
          clientId: "phone",
          sessionId: "session-a",
        }),
      ),
    ).toMatchObject({
      projectId: "project-a",
      projectName: "Flutter apps",
    });
  });

  it("rejects prompt history entries without text", () => {
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "import_prompt_history_v1",
          clientId: "phone",
          entries: [{ projectPath: "/repo" }],
        }),
      ),
    ).toBeNull();
  });

  it("rejects migration import modes because v1 import is replace-only", () => {
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "import_prompt_history_v1",
          clientId: "phone",
          mode: "merge",
          entries: [{ text: "/test", projectPath: "/repo" }],
        }),
      ),
    ).toBeNull();
  });

  it("parses start message", () => {
    const msg = parseClientMessage('{"type":"start","projectPath":"/tmp/foo"}');
    expect(msg).toEqual({ type: "start", projectPath: "/tmp/foo" });
  });

  it("parses start with optional fields", () => {
    const msg = parseClientMessage(
      '{"type":"start","projectPath":"/p","sessionId":"s1","continue":true,"permissionMode":"acceptEdits","profile":"ccpocket","approvalPolicy":"on-request","approvalsReviewer":"auto_review","codexPermissionsMode":"autoReview","additionalWritableRoots":["/tmp/extra"],"autoRename":true}',
    );
    expect(msg).toEqual({
      type: "start",
      projectPath: "/p",
      sessionId: "s1",
      continue: true,
      permissionMode: "acceptEdits",
      profile: "ccpocket",
      approvalPolicy: "on-request",
      approvalsReviewer: "auto_review",
      codexPermissionsMode: "autoReview",
      additionalWritableRoots: ["/tmp/extra"],
      autoRename: true,
    });
  });

  it("parses Project session identity", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","projectId":"project-1","workspaceKind":"project"}',
      ),
    ).toMatchObject({ projectId: "project-1", workspaceKind: "project" });
  });

  it("parses auto permission mode", () => {
    const msg = parseClientMessage(
      '{"type":"set_permission_mode","mode":"auto","sessionId":"s1"}',
    );
    expect(msg).toEqual({
      type: "set_permission_mode",
      mode: "auto",
      sessionId: "s1",
    });
  });

  it("parses start with advanced Claude options", () => {
    const msg = parseClientMessage(
      '{"type":"start","projectPath":"/p","model":"claude-sonnet","effort":"xhigh","maxTurns":5,"maxBudgetUsd":1.5,"fallbackModel":"claude-haiku","forkSession":true,"persistSession":false}',
    );
    expect(msg).toEqual({
      type: "start",
      projectPath: "/p",
      model: "claude-sonnet",
      effort: "xhigh",
      maxTurns: 5,
      maxBudgetUsd: 1.5,
      fallbackModel: "claude-haiku",
      forkSession: true,
      persistSession: false,
    });
  });

  it("rejects start with invalid maxTurns", () => {
    expect(
      parseClientMessage('{"type":"start","projectPath":"/p","maxTurns":0}'),
    ).toBeNull();
  });

  it("accepts Antigravity as a provider", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","provider":"antigravity","model":"gemini-3.8-flash-high"}',
      ),
    ).toMatchObject({ provider: "antigravity" });
    expect(
      parseClientMessage(
        '{"type":"resume_session","sessionId":"s","projectPath":"/p","provider":"antigravity"}',
      ),
    ).toMatchObject({ provider: "antigravity" });
    expect(
      parseClientMessage(
        '{"type":"list_recent_sessions","provider":"antigravity","includeAntigravity":true}',
      ),
    ).toMatchObject({ provider: "antigravity", includeAntigravity: true });
  });

  it("accepts archiving an Antigravity session", () => {
    expect(
      parseClientMessage(
        '{"type":"archive_session","sessionId":"s","provider":"antigravity","projectPath":"/p"}',
      ),
    ).toMatchObject({ provider: "antigravity" });
    expect(
      parseClientMessage('{"type":"archive_session","sessionId":"s","projectPath":"/p"}'),
    ).toBeNull();
  });

  it("validates the pin messages", () => {
    const parse = (msg: unknown) => parseClientMessage(JSON.stringify(msg));
    const pin = { provider: "codex", sessionId: "s", projectPath: "/p" };

    expect(parse({ type: "get_pins" })).toMatchObject({ type: "get_pins" });
    expect(
      parse({ type: "get_pins", seed: { sessions: [pin], projects: ["/p"] } }),
    ).toMatchObject({ seed: { sessions: [pin] } });
    expect(parse({ type: "get_pins", seed: {} })).not.toBeNull();
    expect(parse({ type: "get_pins", seed: [] })).toBeNull();
    expect(
      parse({ type: "get_pins", seed: { sessions: [{ ...pin, provider: "x" }] } }),
    ).toBeNull();
    expect(
      parse({ type: "get_pins", seed: { sessions: [{ ...pin, projectPath: 1 }] } }),
    ).toBeNull();
    expect(parse({ type: "get_pins", seed: { projects: [""] } })).toBeNull();

    expect(
      parse({ type: "set_session_pin", ...pin, pinned: true }),
    ).toMatchObject({ pinned: true });
    expect(
      parse({ type: "set_session_pin", ...pin, projectPath: "", pinned: false }),
    ).not.toBeNull();
    expect(parse({ type: "set_session_pin", ...pin })).toBeNull();
    expect(
      parse({ type: "set_session_pin", ...pin, sessionId: "", pinned: true }),
    ).toBeNull();
    expect(
      parse({ type: "set_session_pin", ...pin, provider: "x", pinned: true }),
    ).toBeNull();

    expect(
      parse({ type: "set_project_pin", projectPath: "/p", pinned: false }),
    ).toMatchObject({ pinned: false });
    expect(parse({ type: "set_project_pin", projectPath: "", pinned: true })).toBeNull();
    expect(parse({ type: "set_project_pin", projectPath: "/p" })).toBeNull();
  });

  it("validates the shared state messages", () => {
    const parse = (msg: unknown) => parseClientMessage(JSON.stringify(msg));

    expect(parse({ type: "get_shared_state" })).not.toBeNull();
    expect(
      parse({ type: "set_shared_state", key: "a/b", value: { x: 1 }, mutationId: "m", mode: "max" }),
    ).toMatchObject({ key: "a/b", mode: "max" });
    expect(parse({ type: "set_shared_state", key: "a", value: null })).not.toBeNull();
    expect(parse({ type: "set_shared_state", key: "a" })).not.toBeNull();
    expect(parse({ type: "set_shared_state", key: "", value: 1 })).toBeNull();
    expect(parse({ type: "set_shared_state", key: "k".repeat(513), value: 1 })).toBeNull();
    expect(parse({ type: "set_shared_state", key: "a", value: 1, mode: "min" })).toBeNull();
    expect(parse({ type: "set_shared_state", key: "a", value: 1, mutationId: "" })).toBeNull();
    expect(
      parse({ type: "set_shared_state", key: "a", value: "x".repeat(40 * 1024) }),
    ).toBeNull();

    expect(parse({ type: "seed_shared_state", entries: { a: 1 } })).not.toBeNull();
    expect(parse({ type: "seed_shared_state", entries: [] })).toBeNull();
    expect(parse({ type: "seed_shared_state" })).toBeNull();
  });

  it("validates set_antigravity_model", () => {
    expect(
      parseClientMessage(
        '{"type":"set_antigravity_model","sessionId":"s","model":"gemini-3.8-flash-low"}',
      ),
    ).toEqual({
      type: "set_antigravity_model",
      sessionId: "s",
      model: "gemini-3.8-flash-low",
    });
    expect(
      parseClientMessage('{"type":"set_antigravity_model","sessionId":"s","model":" "}'),
    ).toBeNull();
    expect(
      parseClientMessage('{"type":"set_antigravity_model","model":"m"}'),
    ).toBeNull();
  });

  it("rejects start without projectPath", () => {
    expect(parseClientMessage('{"type":"start"}')).toBeNull();
  });

  it.each([
    ["provider", "other"],
    ["sandboxMode", 1],
    ["model", 1],
    ["effort", "turbo"],
    ["maxTurns", 0],
    ["maxBudgetUsd", -1],
    ["fallbackModel", false],
    ["forkSession", "true"],
    ["persistSession", 1],
    ["profile", false],
    ["modelReasoningEffort", ""],
    ["serviceTier", ""],
    ["networkAccessEnabled", "true"],
    ["permissionMode", "unrestricted"],
    ["executionMode", "unrestricted"],
    ["approvalPolicy", "always"],
    ["approvalsReviewer", "bot"],
    ["codexPermissionsMode", "reviewEverything"],
    ["planMode", "true"],
    ["webSearchMode", "auto"],
    ["additionalWritableRoots", [42]],
  ])("rejects invalid shared session option %s", (field, value) => {
    const start = { type: "start", projectPath: "/p", [field]: value };
    const resume = {
      type: "resume_session",
      sessionId: "s1",
      projectPath: "/p",
      [field]: value,
    };

    expect(parseClientMessage(JSON.stringify(start))).toBeNull();
    expect(parseClientMessage(JSON.stringify(resume))).toBeNull();
  });

  it.each([
    ["sessionId", 1],
    ["continue", "true"],
    ["useWorktree", "true"],
    ["worktreeBranch", false],
    ["existingWorktreePath", false],
    ["autoRename", "true"],
  ])("rejects invalid start option %s", (field, value) => {
    expect(
      parseClientMessage(
        JSON.stringify({ type: "start", projectPath: "/p", [field]: value }),
      ),
    ).toBeNull();
  });

  it("parses input message", () => {
    const msg = parseClientMessage('{"type":"input","text":"hello"}');
    expect(msg).toEqual({ type: "input", text: "hello" });
  });

  it("accepts input carrying local outbox Bridge identity metadata", () => {
    const msg = parseClientMessage(
      '{"type":"input","text":"hello","_ccpocketOriginBridgeInstanceId":"bridge-a"}',
    );
    expect(msg).toEqual({
      type: "input",
      text: "hello",
      _ccpocketOriginBridgeInstanceId: "bridge-a",
    });
  });

  it("parses input strict ack metadata", () => {
    const msg = parseClientMessage(
      '{"type":"input","sessionId":"s1","text":"hello","clientMessageId":"cm-1","baseSeq":42}',
    );
    expect(msg).toEqual({
      type: "input",
      sessionId: "s1",
      text: "hello",
      clientMessageId: "cm-1",
      baseSeq: 42,
    });
  });

  it("rejects input without text", () => {
    expect(parseClientMessage('{"type":"input"}')).toBeNull();
  });

  it("rejects input with invalid strict ack metadata", () => {
    expect(
      parseClientMessage(
        '{"type":"input","text":"hello","clientMessageId":1}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage('{"type":"input","text":"hello","baseSeq":-1}'),
    ).toBeNull();
  });

  it("parses push_register message", () => {
    const msg = parseClientMessage(
      '{"type":"push_register","token":"t1","platform":"ios","requestId":"req-1"}',
    );
    expect(msg).toEqual({
      type: "push_register",
      token: "t1",
      platform: "ios",
      requestId: "req-1",
    });
  });

  it("rejects push_register with invalid platform", () => {
    expect(
      parseClientMessage(
        '{"type":"push_register","token":"t1","platform":"desktop"}',
      ),
    ).toBeNull();
  });

  it("rejects push_register with invalid requestId", () => {
    expect(
      parseClientMessage(
        '{"type":"push_register","token":"t1","platform":"ios","requestId":1}',
      ),
    ).toBeNull();
  });

  it("parses push_unregister message", () => {
    const msg = parseClientMessage('{"type":"push_unregister","token":"t1"}');
    expect(msg).toEqual({ type: "push_unregister", token: "t1" });
  });

  it("rejects push_unregister without token", () => {
    expect(parseClientMessage('{"type":"push_unregister"}')).toBeNull();
  });

  it("parses set_permission_mode message", () => {
    const msg = parseClientMessage(
      '{"type":"set_permission_mode","mode":"plan","sessionId":"s1","approvalsReviewer":"guardian_subagent","codexPermissionsMode":"custom"}',
    );
    expect(msg).toEqual({
      type: "set_permission_mode",
      mode: "plan",
      sessionId: "s1",
      approvalsReviewer: "guardian_subagent",
      codexPermissionsMode: "custom",
    });
  });

  it("rejects set_permission_mode with invalid mode", () => {
    expect(
      parseClientMessage('{"type":"set_permission_mode","mode":"unsupported"}'),
    ).toBeNull();
  });

  it("parses set_codex_model message", () => {
    const msg = parseClientMessage(
      '{"type":"set_codex_model","model":"gpt-5.4-mini","modelReasoningEffort":"low","sessionId":"s1"}',
    );
    expect(msg).toEqual({
      type: "set_codex_model",
      model: "gpt-5.4-mini",
      modelReasoningEffort: "low",
      sessionId: "s1",
    });
  });

  it("parses GPT-5.6 max and ultra reasoning efforts", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","provider":"codex","model":"gpt-5.6-sol","modelReasoningEffort":"ultra"}',
      ),
    ).toMatchObject({ modelReasoningEffort: "ultra" });
    expect(
      parseClientMessage(
        '{"type":"set_codex_model","model":"gpt-5.6-luna","modelReasoningEffort":"max"}',
      ),
    ).toMatchObject({ modelReasoningEffort: "max" });
  });

  it("accepts model-advertised reasoning effort strings", () => {
    expect(
      parseClientMessage(
        '{"type":"set_codex_model","model":"future-model","modelReasoningEffort":"future-tier"}',
      ),
    ).toMatchObject({ modelReasoningEffort: "future-tier" });
  });

  it("rejects set_codex_model with invalid fields", () => {
    expect(parseClientMessage('{"type":"set_codex_model"}')).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_codex_model","model":"gpt-5.4-mini","modelReasoningEffort":""}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_codex_model","model":"gpt-5.4-mini","modelReasoningEffort":1}',
      ),
    ).toBeNull();
  });

  it("parses set_codex_speed messages", () => {
    expect(
      parseClientMessage(
        '{"type":"set_codex_speed","serviceTier":"fast","sessionId":"s1"}',
      ),
    ).toEqual({
      type: "set_codex_speed",
      serviceTier: "fast",
      sessionId: "s1",
    });
    expect(
      parseClientMessage('{"type":"set_codex_speed","serviceTier":""}'),
    ).toBeNull();
  });

  it("parses set_claude_settings messages", () => {
    expect(
      parseClientMessage(
        '{"type":"set_claude_settings","sessionId":"s1","model":"opus","effort":"xhigh","fastMode":true}',
      ),
    ).toEqual({
      type: "set_claude_settings",
      sessionId: "s1",
      model: "opus",
      effort: "xhigh",
      fastMode: true,
    });
    expect(
      parseClientMessage('{"type":"set_claude_settings","sessionId":"s1"}'),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_claude_settings","sessionId":"s1","effort":"ultra"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_claude_settings","sessionId":"s1","fastMode":"yes"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_claude_settings","sessionId":"s1","ultracode":true}',
      ),
    ).toEqual({ type: "set_claude_settings", sessionId: "s1", ultracode: true });
    expect(
      parseClientMessage(
        '{"type":"set_claude_settings","sessionId":"s1","ultracode":"on"}',
      ),
    ).toBeNull();
  });

  it("parses input delivery and rejects unknown values", () => {
    expect(
      parseClientMessage(
        '{"type":"input","text":"hi","sessionId":"s1","delivery":"steer"}',
      ),
    ).toMatchObject({ delivery: "steer" });
    expect(
      parseClientMessage(
        '{"type":"input","text":"hi","sessionId":"s1","delivery":"now"}',
      ),
    ).toBeNull();
  });

  it("parses Codex goal messages", () => {
    expect(parseClientMessage('{"type":"get_goal","sessionId":"s1","background":true}'))
      .toEqual({ type: "get_goal", sessionId: "s1", background: true });
    expect(parseClientMessage('{"type":"get_goal","sessionId":"s1","background":"true"}')).toBeNull();
    expect(
      parseClientMessage('{"type":"get_goal","sessionId":"s1"}'),
    ).toEqual({ type: "get_goal", sessionId: "s1" });
    expect(
      parseClientMessage(
        '{"type":"set_goal","sessionId":"s1","objective":"Ship Goal UI","status":"active"}',
      ),
    ).toEqual({
      type: "set_goal",
      sessionId: "s1",
      objective: "Ship Goal UI",
      status: "active",
    });
    expect(
      parseClientMessage(
        '{"type":"set_goal","sessionId":"s1","status":"paused"}',
      ),
    ).toEqual({ type: "set_goal", sessionId: "s1", status: "paused" });
    expect(
      parseClientMessage('{"type":"clear_goal","sessionId":"s1"}'),
    ).toEqual({ type: "clear_goal", sessionId: "s1" });
  });

  it("rejects invalid Codex goal messages", () => {
    expect(parseClientMessage('{"type":"get_goal"}')).toBeNull();
    expect(
      parseClientMessage('{"type":"set_goal","sessionId":"s1"}'),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_goal","sessionId":"s1","objective":"   "}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_goal","sessionId":"s1","status":"unknown"}',
      ),
    ).toBeNull();
    expect(parseClientMessage('{"type":"clear_goal"}')).toBeNull();
  });

  it("rejects invalid approvalsReviewer", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","approvalsReviewer":"bot"}',
      ),
    ).toBeNull();
  });

  it("rejects invalid codexPermissionsMode", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","codexPermissionsMode":"reviewEverything"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_permission_mode","mode":"default","codexPermissionsMode":"reviewEverything"}',
      ),
    ).toBeNull();
  });

  it("rejects invalid additionalWritableRoots", () => {
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/p","additionalWritableRoots":"/tmp"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"resume_session","sessionId":"s3","projectPath":"/p","additionalWritableRoots":[42]}',
      ),
    ).toBeNull();
  });

  it("parses approve message", () => {
    const msg = parseClientMessage('{"type":"approve","id":"tu1"}');
    expect(msg).toEqual({ type: "approve", id: "tu1" });
  });

  it("rejects approve without id", () => {
    expect(parseClientMessage('{"type":"approve"}')).toBeNull();
  });

  it("parses approve_always message", () => {
    const msg = parseClientMessage('{"type":"approve_always","id":"tu2"}');
    expect(msg).toEqual({ type: "approve_always", id: "tu2" });
  });

  it("rejects approve_always without id", () => {
    expect(parseClientMessage('{"type":"approve_always"}')).toBeNull();
  });

  it("parses reject message", () => {
    const msg = parseClientMessage(
      '{"type":"reject","id":"tu3","message":"no"}',
    );
    expect(msg).toEqual({ type: "reject", id: "tu3", message: "no" });
  });

  it("rejects reject without id", () => {
    expect(parseClientMessage('{"type":"reject"}')).toBeNull();
  });

  it("parses answer message", () => {
    const msg = parseClientMessage(
      '{"type":"answer","toolUseId":"tu4","result":"yes"}',
    );
    expect(msg).toEqual({ type: "answer", toolUseId: "tu4", result: "yes" });
  });

  it("rejects answer without toolUseId", () => {
    expect(parseClientMessage('{"type":"answer","result":"yes"}')).toBeNull();
  });

  it("rejects answer without result", () => {
    expect(
      parseClientMessage('{"type":"answer","toolUseId":"tu4"}'),
    ).toBeNull();
  });

  it("parses install_tool_suggestion message", () => {
    const msg = parseClientMessage(
      '{"type":"install_tool_suggestion","toolUseId":"approval-0","sessionId":"session-1"}',
    );
    expect(msg).toEqual({
      type: "install_tool_suggestion",
      toolUseId: "approval-0",
      sessionId: "session-1",
    });
  });

  it("rejects install_tool_suggestion without toolUseId", () => {
    expect(
      parseClientMessage('{"type":"install_tool_suggestion"}'),
    ).toBeNull();
  });

  it("parses list_sessions message", () => {
    const msg = parseClientMessage('{"type":"list_sessions"}');
    expect(msg).toEqual({ type: "list_sessions" });
  });

  it("parses stop_session message", () => {
    const msg = parseClientMessage('{"type":"stop_session","sessionId":"s1"}');
    expect(msg).toEqual({ type: "stop_session", sessionId: "s1" });
  });

  it("rejects stop_session without sessionId", () => {
    expect(parseClientMessage('{"type":"stop_session"}')).toBeNull();
  });

  it("parses get_history message", () => {
    const msg = parseClientMessage('{"type":"get_history","sessionId":"s2"}');
    expect(msg).toEqual({ type: "get_history", sessionId: "s2" });
  });

  it("parses get_session_context message", () => {
    const msg = parseClientMessage(
      '{"type":"get_session_context","sessionId":"s2"}',
    );
    expect(msg).toEqual({ type: "get_session_context", sessionId: "s2" });
  });

  it("rejects get_session_context without sessionId", () => {
    expect(parseClientMessage('{"type":"get_session_context"}')).toBeNull();
  });

  it("parses resolve_session_link message", () => {
    const msg = parseClientMessage(
      '{"type":"resolve_session_link","requestId":"req-1","sessionId":"session-1","provider":"claude"}',
    );
    expect(msg).toEqual({
      type: "resolve_session_link",
      requestId: "req-1",
      sessionId: "session-1",
      provider: "claude",
    });
  });

  it("rejects resolve_session_link without requestId", () => {
    expect(
      parseClientMessage(
        '{"type":"resolve_session_link","sessionId":"session-1"}',
      ),
    ).toBeNull();
  });

  it("rejects get_history without sessionId", () => {
    expect(parseClientMessage('{"type":"get_history"}')).toBeNull();
  });

  it("parses get_history_delta message", () => {
    const msg = parseClientMessage(
      '{"type":"get_history_delta","sessionId":"s2","sinceSeq":12}',
    );
    expect(msg).toEqual({
      type: "get_history_delta",
      sessionId: "s2",
      sinceSeq: 12,
    });
  });

  it("rejects get_history_delta without valid sinceSeq", () => {
    expect(
      parseClientMessage('{"type":"get_history_delta","sessionId":"s2"}'),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"get_history_delta","sessionId":"s2","sinceSeq":-1}',
      ),
    ).toBeNull();
  });

  it("parses list_recent_sessions message", () => {
    const msg = parseClientMessage('{"type":"list_recent_sessions"}');
    expect(msg).toEqual({ type: "list_recent_sessions" });
  });

  it("parses list_recent_sessions with workspace filters", () => {
    const msg = parseClientMessage(
      '{"type":"list_recent_sessions","limit":10,"offset":20,"projectPath":"/tmp/project","projectId":"project-1","workspaceKind":"project","requestScope":"project","requestId":"recent-1","provider":"codex","namedOnly":true,"searchQuery":"needle"}',
    );
    expect(msg).toEqual({
      type: "list_recent_sessions",
      limit: 10,
      offset: 20,
      projectPath: "/tmp/project",
      projectId: "project-1",
      workspaceKind: "project",
      requestScope: "project",
      requestId: "recent-1",
      provider: "codex",
      namedOnly: true,
      searchQuery: "needle",
    });
  });

  it("parses list_recent_sessions with pinned sessions", () => {
    const msg = parseClientMessage(
      JSON.stringify({
        type: "list_recent_sessions",
        limit: 20,
        offset: 0,
        pinnedSessions: [
          { provider: "claude", sessionId: "c1" },
          { provider: "codex", sessionId: "x1" },
          { provider: "antigravity", sessionId: "a1" },
        ],
      }),
    );
    expect(msg).toEqual({
      type: "list_recent_sessions",
      limit: 20,
      offset: 0,
      pinnedSessions: [
        { provider: "claude", sessionId: "c1" },
        { provider: "codex", sessionId: "x1" },
        { provider: "antigravity", sessionId: "a1" },
      ],
    });
  });

  it("rejects malformed list_recent_sessions pinned sessions", () => {
    for (const pinnedSessions of [
      "c1",
      [{ provider: "gemini", sessionId: "c1" }],
      [{ provider: "claude", sessionId: "" }],
      [{ provider: "claude" }],
      [null],
      Array.from({ length: 1001 }, (_, i) => ({
        provider: "claude",
        sessionId: `s${i}`,
      })),
    ]) {
      expect(
        parseClientMessage(
          JSON.stringify({ type: "list_recent_sessions", pinnedSessions }),
        ),
      ).toBeNull();
    }
  });

  it("parses list_recent_sessions filter fields", () => {
    const fields = {
      projectFilters: [
        { projectPath: "/tmp/a" },
        { projectId: "p1", workspaceKind: "project" },
        { projectPath: "/tmp/b", workspaceKind: "unassigned" },
      ],
      modifiedAfter: "2026-11-01T00:00:00.000Z",
      modifiedBefore: "2026-11-02T00:00:00+09:00",
      dateField: "created",
      pinnedOnly: true,
      pinnedProjects: [{ projectPath: "/tmp/fav" }],
      searchContent: false,
    };
    expect(
      parseClientMessage(
        JSON.stringify({ type: "list_recent_sessions", ...fields }),
      ),
    ).toEqual({ type: "list_recent_sessions", ...fields });
  });

  it("accepts both dateField values and 100 project filters", () => {
    for (const dateField of ["modified", "created"]) {
      expect(
        parseClientMessage(
          JSON.stringify({ type: "list_recent_sessions", dateField }),
        ),
      ).toMatchObject({ dateField });
    }
    const hundred = Array.from({ length: 100 }, (_, i) => ({
      projectPath: `/tmp/p${i}`,
    }));
    expect(
      parseClientMessage(
        JSON.stringify({
          type: "list_recent_sessions",
          projectFilters: hundred,
          pinnedProjects: hundred,
        }),
      ),
    ).not.toBeNull();
  });

  it("rejects malformed list_recent_sessions project filters", () => {
    const malformed: unknown[] = [
      "/tmp/a",
      { projectPath: "/tmp/a" },
      [null],
      ["/tmp/a"],
      [[{ projectPath: "/tmp/a" }]],
      [{}],
      [{ workspaceKind: "project" }],
      [{ projectPath: "" }],
      [{ projectId: "" }],
      [{ projectPath: "", projectId: "" }],
      [{ projectPath: 1 }],
      [{ projectPath: "/tmp/a", projectId: 2 }],
      [{ projectPath: "/tmp/a", workspaceKind: "other" }],
      Array.from({ length: 101 }, (_, i) => ({ projectPath: `/tmp/p${i}` })),
    ];
    for (const value of malformed) {
      for (const field of ["projectFilters", "pinnedProjects"]) {
        expect(
          parseClientMessage(
            JSON.stringify({ type: "list_recent_sessions", [field]: value }),
          ),
        ).toBeNull();
      }
    }
  });

  it("rejects malformed list_recent_sessions dates", () => {
    for (const value of [123, "", "   ", "not a date", "2026-13-45", true, {}]) {
      for (const field of ["modifiedAfter", "modifiedBefore"]) {
        expect(
          parseClientMessage(
            JSON.stringify({ type: "list_recent_sessions", [field]: value }),
          ),
        ).toBeNull();
      }
    }
  });

  it("rejects malformed list_recent_sessions dateField and flags", () => {
    for (const dateField of ["updated", "", 1, true]) {
      expect(
        parseClientMessage(
          JSON.stringify({ type: "list_recent_sessions", dateField }),
        ),
      ).toBeNull();
    }
    for (const value of ["true", 1, null, {}]) {
      for (const field of ["pinnedOnly", "searchContent"]) {
        expect(
          parseClientMessage(
            JSON.stringify({ type: "list_recent_sessions", [field]: value }),
          ),
        ).toBeNull();
      }
    }
  });

  it("ignores unknown list_recent_sessions fields", () => {
    // Older Bridges must not reject newer optional fields from the app.
    expect(
      parseClientMessage(
        '{"type":"list_recent_sessions","futureField":[1,2,3]}',
      ),
    ).toMatchObject({ type: "list_recent_sessions" });
  });

  it("parses Project CRUD messages", () => {
    expect(parseClientMessage('{"type":"list_projects"}')).toEqual({
      type: "list_projects",
    });
    expect(
      parseClientMessage(
        '{"type":"create_project","name":"App","rootPaths":["/app","/api"]}',
      ),
    ).toMatchObject({ name: "App", rootPaths: ["/app", "/api"] });
    expect(
      parseClientMessage(
        '{"type":"update_project","projectId":"p1","name":"App 2","rootPaths":["/app"]}',
      ),
    ).toMatchObject({ projectId: "p1", name: "App 2" });
    expect(
      parseClientMessage('{"type":"remove_project","projectId":"p1"}'),
    ).toMatchObject({ projectId: "p1" });
  });

  it("rejects invalid Project mutations", () => {
    expect(
      parseClientMessage(
        '{"type":"create_project","name":"App","rootPaths":[]}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"update_project","projectId":"p1","name":" ","rootPaths":["/app"]}',
      ),
    ).toBeNull();
    expect(parseClientMessage('{"type":"remove_project"}')).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"start","projectPath":"/tasks","workspaceKind":"projectless"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"set_projectless_root","projectlessRoot":"/tasks"}',
      ),
    ).toBeNull();
  });

  it("rejects invalid list_recent_sessions options", () => {
    const invalidMessages = [
      '{"type":"list_recent_sessions","limit":0}',
      '{"type":"list_recent_sessions","limit":501}',
      '{"type":"list_recent_sessions","limit":1.5}',
      '{"type":"list_recent_sessions","offset":-1}',
      '{"type":"list_recent_sessions","offset":100001}',
      '{"type":"list_recent_sessions","offset":1.5}',
      '{"type":"list_recent_sessions","projectPath":42}',
      '{"type":"list_recent_sessions","requestScope":"global"}',
      '{"type":"list_recent_sessions","requestId":42}',
      '{"type":"list_recent_sessions","requestId":""}',
      '{"type":"list_recent_sessions","requestId":"   "}',
      JSON.stringify({
        type: "list_recent_sessions",
        requestId: "r".repeat(129),
      }),
      '{"type":"list_recent_sessions","provider":"other"}',
      '{"type":"list_recent_sessions","namedOnly":"true"}',
      '{"type":"list_recent_sessions","searchQuery":42}',
    ];

    for (const raw of invalidMessages) {
      expect(parseClientMessage(raw), raw).toBeNull();
    }
  });

  it("parses resume_session message", () => {
    const msg = parseClientMessage(
      '{"type":"resume_session","sessionId":"s3","projectPath":"/p"}',
    );
    expect(msg).toEqual({
      type: "resume_session",
      sessionId: "s3",
      projectPath: "/p",
    });
  });

  it("parses resume_session with provider", () => {
    const msg = parseClientMessage(
      '{"type":"resume_session","sessionId":"s3","projectPath":"/p","provider":"codex","profile":"ccpocket","approvalsReviewer":"auto_review","additionalWritableRoots":["/tmp/extra"],"resumeRequestId":"link-request-1"}',
    );
    expect(msg).toEqual({
      type: "resume_session",
      sessionId: "s3",
      projectPath: "/p",
      provider: "codex",
      profile: "ccpocket",
      approvalsReviewer: "auto_review",
      additionalWritableRoots: ["/tmp/extra"],
      resumeRequestId: "link-request-1",
    });
  });

  it("rejects resume_session with a non-string resumeRequestId", () => {
    expect(
      parseClientMessage(
        '{"type":"resume_session","sessionId":"s3","projectPath":"/p","resumeRequestId":42}',
      ),
    ).toBeNull();
  });

  it("parses resume_session with advanced Claude options", () => {
    const msg = parseClientMessage(
      '{"type":"resume_session","sessionId":"s3","projectPath":"/p","model":"claude-sonnet","effort":"medium","maxTurns":3,"maxBudgetUsd":0.8,"fallbackModel":"claude-haiku","forkSession":true,"persistSession":false}',
    );
    expect(msg).toEqual({
      type: "resume_session",
      sessionId: "s3",
      projectPath: "/p",
      model: "claude-sonnet",
      effort: "medium",
      maxTurns: 3,
      maxBudgetUsd: 0.8,
      fallbackModel: "claude-haiku",
      forkSession: true,
      persistSession: false,
    });
  });

  it("parses resume_session with xhigh effort", () => {
    expect(
      parseClientMessage(
        '{"type":"resume_session","sessionId":"s3","projectPath":"/p","effort":"xhigh"}',
      ),
    ).toEqual({
      type: "resume_session",
      sessionId: "s3",
      projectPath: "/p",
      effort: "xhigh",
    });
  });

  it("rejects resume_session without sessionId", () => {
    expect(
      parseClientMessage('{"type":"resume_session","projectPath":"/p"}'),
    ).toBeNull();
  });

  it("rejects resume_session without projectPath", () => {
    expect(
      parseClientMessage('{"type":"resume_session","sessionId":"s3"}'),
    ).toBeNull();
  });

  it("rejects resume_session with invalid provider", () => {
    expect(
      parseClientMessage(
        '{"type":"resume_session","sessionId":"s3","projectPath":"/p","provider":"foo"}',
      ),
    ).toBeNull();
  });

  it("parses correlated list_gallery metadata", () => {
    const msg = parseClientMessage(
      '{"type":"list_gallery","projectPath":"/p","project":"/p","sessionId":"session-1","requestId":"gallery-1"}',
    );
    expect(msg).toEqual({
      type: "list_gallery",
      projectPath: "/p",
      project: "/p",
      sessionId: "session-1",
      requestId: "gallery-1",
    });
  });

  it("rejects invalid list_gallery correlation metadata", () => {
    const invalidMessages = [
      '{"type":"list_gallery","projectPath":42}',
      '{"type":"list_gallery","projectPath":""}',
      '{"type":"list_gallery","project":"/legacy","projectPath":"/canonical"}',
      '{"type":"list_gallery","sessionId":42}',
      '{"type":"list_gallery","sessionId":""}',
      '{"type":"list_gallery","requestId":42}',
      '{"type":"list_gallery","requestId":""}',
      JSON.stringify({ type: "list_gallery", projectPath: "p".repeat(4097) }),
      JSON.stringify({ type: "list_gallery", sessionId: "s".repeat(513) }),
      JSON.stringify({ type: "list_gallery", requestId: "r".repeat(129) }),
      '{"type":"list_gallery","unexpected":true}',
    ];

    for (const raw of invalidMessages) {
      expect(parseClientMessage(raw), raw).toBeNull();
    }
  });

  it("parses list_files message", () => {
    const msg = parseClientMessage('{"type":"list_files","projectPath":"/p"}');
    expect(msg).toEqual({ type: "list_files", projectPath: "/p" });
  });

  it("parses scoped list_files request metadata", () => {
    const msg = parseClientMessage(
      '{"type":"list_files","projectPath":"/p","requestId":"files-1"}',
    );
    expect(msg).toEqual({
      type: "list_files",
      projectPath: "/p",
      requestId: "files-1",
    });
  });

  it("parses read_model_file and rejects missing paths", () => {
    expect(parseClientMessage(JSON.stringify({ type: "read_model_file", projectPath: "/p", filePath: "model.glb", requestId: "preview-1" })))
      .toEqual({ type: "read_model_file", projectPath: "/p", filePath: "model.glb", requestId: "preview-1" });
    expect(parseClientMessage('{"type":"read_model_file","projectPath":"/p"}')).toBeNull();
  });

  it("parses read_media_file message", () => {
    const msg = parseClientMessage(
      '{"type":"read_media_file","projectPath":"/p","filePath":"output.mp4"}',
    );
    expect(msg).toEqual({
      type: "read_media_file",
      projectPath: "/p",
      filePath: "output.mp4",
    });
  });

  it("parses prepare_file_download message", () => {
    const msg = parseClientMessage(
      '{"type":"prepare_file_download","projectPath":"/p","filePath":"build/report.pdf","requestId":"download-1"}',
    );
    expect(msg).toEqual({
      type: "prepare_file_download",
      projectPath: "/p",
      filePath: "build/report.pdf",
      requestId: "download-1",
    });
  });

  it("rejects invalid prepare_file_download messages", () => {
    expect(
      parseClientMessage(
        '{"type":"prepare_file_download","projectPath":"/p","filePath":"report.pdf"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"prepare_file_download","projectPath":"/p","filePath":" ","requestId":"download-1"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"prepare_file_download","projectPath":"/p","filePath":"report.pdf","requestId":"download-1","extra":true}',
      ),
    ).toBeNull();
  });

  it("rejects list_files without projectPath", () => {
    expect(parseClientMessage('{"type":"list_files"}')).toBeNull();
  });

  it("parses list_directory message", () => {
    const msg = parseClientMessage(
      '{"type":"list_directory","path":"/workspace","requestId":"dir-1","includeHidden":true}',
    );
    expect(msg).toEqual({
      type: "list_directory",
      path: "/workspace",
      requestId: "dir-1",
      includeHidden: true,
    });
  });

  it("rejects list_directory without a non-empty path", () => {
    expect(parseClientMessage('{"type":"list_directory"}')).toBeNull();
    expect(
      parseClientMessage('{"type":"list_directory","path":"   "}'),
    ).toBeNull();
    expect(
      parseClientMessage('{"type":"list_directory","path":123}'),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"list_directory","path":"/workspace","requestId":123}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"list_directory","path":"/workspace","includeHidden":"yes"}',
      ),
    ).toBeNull();
  });

  it("parses includeFiles and rejects non-boolean values", () => {
    expect(parseClientMessage('{"type":"list_directory","path":"/workspace","includeFiles":true}'))
      .toEqual({ type: "list_directory", path: "/workspace", includeFiles: true });
    expect(parseClientMessage('{"type":"list_directory","path":"/workspace","includeFiles":"yes"}')).toBeNull();
  });

  it("rejects list_directory with unknown fields", () => {
    expect(
      parseClientMessage(
        '{"type":"list_directory","path":"/workspace","unknownOption":true}',
      ),
    ).toBeNull();
  });

  it("parses interrupt message", () => {
    const msg = parseClientMessage('{"type":"interrupt"}');
    expect(msg).toEqual({ type: "interrupt" });
  });

  it("parses steer_queued_input message", () => {
    const msg = parseClientMessage(
      '{"type":"steer_queued_input","sessionId":"s1","itemId":"q1"}',
    );
    expect(msg).toEqual({
      type: "steer_queued_input",
      sessionId: "s1",
      itemId: "q1",
    });
  });

  it("returns null for unknown type", () => {
    expect(parseClientMessage('{"type":"unknown_type"}')).toBeNull();
  });

  it("returns null for missing type", () => {
    expect(parseClientMessage('{"foo":"bar"}')).toBeNull();
  });

  it("returns null for non-string type", () => {
    expect(parseClientMessage('{"type":123}')).toBeNull();
  });

  it("returns null for invalid JSON", () => {
    expect(parseClientMessage("not json")).toBeNull();
  });

  it("parses list_project_history message", () => {
    const msg = parseClientMessage('{"type":"list_project_history"}');
    expect(msg).toEqual({ type: "list_project_history" });
  });

  it("parses get_debug_bundle message", () => {
    const msg = parseClientMessage(
      '{"type":"get_debug_bundle","sessionId":"s1","traceLimit":120,"includeDiff":false}',
    );
    expect(msg).toEqual({
      type: "get_debug_bundle",
      sessionId: "s1",
      traceLimit: 120,
      includeDiff: false,
    });
  });

  it("rejects get_debug_bundle without sessionId", () => {
    expect(parseClientMessage('{"type":"get_debug_bundle"}')).toBeNull();
  });

  it("parses remove_project_history message", () => {
    const msg = parseClientMessage(
      '{"type":"remove_project_history","projectPath":"/p"}',
    );
    expect(msg).toEqual({ type: "remove_project_history", projectPath: "/p" });
  });

  it("rejects remove_project_history without projectPath", () => {
    expect(parseClientMessage('{"type":"remove_project_history"}')).toBeNull();
  });

  it("parses approve with clearContext: true", () => {
    const msg = parseClientMessage(
      '{"type":"approve","id":"tu1","clearContext":true}',
    );
    expect(msg).toEqual({
      type: "approve",
      id: "tu1",
      clearContext: true,
    });
  });

  it("parses approve without clearContext (backward compat)", () => {
    const msg = parseClientMessage('{"type":"approve","id":"tu1"}');
    expect(msg).not.toBeNull();
    expect((msg as Record<string, unknown>).clearContext).toBeUndefined();
  });

  // ---- rewind ----

  it("parses rewind with mode=both", () => {
    const msg = parseClientMessage(
      '{"type":"rewind","sessionId":"s1","targetUuid":"uuid-abc","mode":"both"}',
    );
    expect(msg).toEqual({
      type: "rewind",
      sessionId: "s1",
      targetUuid: "uuid-abc",
      mode: "both",
    });
  });

  it("parses rewind with mode=conversation", () => {
    const msg = parseClientMessage(
      '{"type":"rewind","sessionId":"s1","targetUuid":"uuid-abc","mode":"conversation"}',
    );
    expect(msg).toEqual({
      type: "rewind",
      sessionId: "s1",
      targetUuid: "uuid-abc",
      mode: "conversation",
    });
  });

  it("parses rewind with mode=code", () => {
    const msg = parseClientMessage(
      '{"type":"rewind","sessionId":"s1","targetUuid":"uuid-abc","mode":"code"}',
    );
    expect(msg).toEqual({
      type: "rewind",
      sessionId: "s1",
      targetUuid: "uuid-abc",
      mode: "code",
    });
  });

  it("rejects rewind with invalid mode", () => {
    expect(
      parseClientMessage(
        '{"type":"rewind","sessionId":"s1","targetUuid":"uuid-abc","mode":"invalid"}',
      ),
    ).toBeNull();
  });

  it("rejects rewind without sessionId", () => {
    expect(
      parseClientMessage(
        '{"type":"rewind","targetUuid":"uuid-abc","mode":"both"}',
      ),
    ).toBeNull();
  });

  it("rejects rewind without targetUuid", () => {
    expect(
      parseClientMessage('{"type":"rewind","sessionId":"s1","mode":"both"}'),
    ).toBeNull();
  });

  // ---- rewind_dry_run ----

  it("parses rewind_dry_run message", () => {
    const msg = parseClientMessage(
      '{"type":"rewind_dry_run","sessionId":"s1","targetUuid":"uuid-abc"}',
    );
    expect(msg).toEqual({
      type: "rewind_dry_run",
      sessionId: "s1",
      targetUuid: "uuid-abc",
    });
  });

  it("rejects rewind_dry_run without sessionId", () => {
    expect(
      parseClientMessage('{"type":"rewind_dry_run","targetUuid":"uuid-abc"}'),
    ).toBeNull();
  });

  it("rejects rewind_dry_run without targetUuid", () => {
    expect(
      parseClientMessage('{"type":"rewind_dry_run","sessionId":"s1"}'),
    ).toBeNull();
  });

  it("parses fork message", () => {
    expect(
      parseClientMessage(
        '{"type":"fork","sessionId":"s1","targetUuid":"codex:user-turn:1"}',
      ),
    ).toEqual({
      type: "fork",
      sessionId: "s1",
      targetUuid: "codex:user-turn:1",
    });
  });

  it("parses handoff_session and rejects unknown targets", () => {
    expect(
      parseClientMessage(
        '{"type":"handoff_session","sessionId":"s1","targetProvider":"codex","instruction":"finish it"}',
      ),
    ).toEqual({
      type: "handoff_session",
      sessionId: "s1",
      targetProvider: "codex",
      instruction: "finish it",
    });
    expect(
      parseClientMessage(
        '{"type":"handoff_session","sessionId":"s1","targetProvider":"antigravity"}',
      ),
    ).not.toBeNull();
    expect(
      parseClientMessage(
        '{"type":"handoff_session","sessionId":"s1","targetProvider":"gemini"}',
      ),
    ).toBeNull();
    expect(
      parseClientMessage('{"type":"handoff_session","targetProvider":"codex"}'),
    ).toBeNull();
    expect(
      parseClientMessage(
        '{"type":"handoff_session","sessionId":"s1","targetProvider":"codex","instruction":5}',
      ),
    ).toBeNull();
  });

  // ---- Git Operations (Phase 1-3) ----

  // git_stage
  it("parses git_stage with files", () => {
    const msg = parseClientMessage(
      '{"type":"git_stage","projectPath":"/p","files":["a.txt","b.txt"]}',
    );
    expect(msg).toEqual({
      type: "git_stage",
      projectPath: "/p",
      files: ["a.txt", "b.txt"],
    });
  });

  it("parses git_stage with hunks", () => {
    const msg = parseClientMessage(
      '{"type":"git_stage","projectPath":"/p","hunks":[{"file":"a.txt","hunkIndex":0}]}',
    );
    expect(msg).toEqual({
      type: "git_stage",
      projectPath: "/p",
      hunks: [{ file: "a.txt", hunkIndex: 0 }],
    });
  });

  it("parses git_stage with both files and hunks", () => {
    const msg = parseClientMessage(
      '{"type":"git_stage","projectPath":"/p","files":["a.txt"],"hunks":[{"file":"b.txt","hunkIndex":1}]}',
    );
    expect(msg).not.toBeNull();
  });

  it("rejects git_stage without projectPath", () => {
    expect(
      parseClientMessage('{"type":"git_stage","files":["a.txt"]}'),
    ).toBeNull();
  });

  it("rejects git_stage without files or hunks", () => {
    expect(
      parseClientMessage('{"type":"git_stage","projectPath":"/p"}'),
    ).toBeNull();
  });

  it("rejects git_stage with invalid hunk shape", () => {
    expect(
      parseClientMessage(
        '{"type":"git_stage","projectPath":"/p","hunks":[{"file":123}]}',
      ),
    ).toBeNull();
  });

  // git_unstage
  it("parses git_unstage", () => {
    const msg = parseClientMessage(
      '{"type":"git_unstage","projectPath":"/p","files":["a.txt"]}',
    );
    expect(msg).toEqual({
      type: "git_unstage",
      projectPath: "/p",
      files: ["a.txt"],
    });
  });

  it("rejects git_unstage without projectPath", () => {
    expect(
      parseClientMessage('{"type":"git_unstage","files":["a.txt"]}'),
    ).toBeNull();
  });

  it("parses git_unstage_hunks", () => {
    const msg = parseClientMessage(
      '{"type":"git_unstage_hunks","projectPath":"/p","hunks":[{"file":"a.txt","hunkIndex":0}]}',
    );
    expect(msg).toEqual({
      type: "git_unstage_hunks",
      projectPath: "/p",
      hunks: [{ file: "a.txt", hunkIndex: 0 }],
    });
  });

  it("rejects git_unstage_hunks without hunks", () => {
    expect(
      parseClientMessage('{"type":"git_unstage_hunks","projectPath":"/p"}'),
    ).toBeNull();
  });

  // git_commit
  it("parses git_commit with message", () => {
    const msg = parseClientMessage(
      '{"type":"git_commit","projectPath":"/p","message":"feat: add feature"}',
    );
    expect(msg).toEqual({
      type: "git_commit",
      projectPath: "/p",
      message: "feat: add feature",
    });
  });

  it("parses git_commit with autoGenerate", () => {
    const msg = parseClientMessage(
      '{"type":"git_commit","projectPath":"/p","autoGenerate":true}',
    );
    expect(msg).toEqual({
      type: "git_commit",
      projectPath: "/p",
      autoGenerate: true,
    });
  });

  it("parses git_commit with sessionId", () => {
    const msg = parseClientMessage(
      '{"type":"git_commit","projectPath":"/p","sessionId":"s-1","autoGenerate":true}',
    );
    expect(msg).toEqual({
      type: "git_commit",
      projectPath: "/p",
      sessionId: "s-1",
      autoGenerate: true,
    });
  });

  it("parses git_commit with request correlation metadata", () => {
    const msg = parseClientMessage(
      '{"type":"git_commit","projectPath":"/p","message":"fix: scope result","requestId":"commit-1"}',
    );
    expect(msg).toEqual({
      type: "git_commit",
      projectPath: "/p",
      message: "fix: scope result",
      requestId: "commit-1",
    });
  });

  it("rejects git_commit with unknown fields", () => {
    expect(
      parseClientMessage(
        '{"type":"git_commit","projectPath":"/p","message":"feat: add feature","forceLease":true}',
      ),
    ).toBeNull();
  });

  it("rejects git_commit without projectPath", () => {
    expect(
      parseClientMessage('{"type":"git_commit","message":"x"}'),
    ).toBeNull();
  });

  // git_push
  it("parses git_push", () => {
    const msg = parseClientMessage('{"type":"git_push","projectPath":"/p"}');
    expect(msg).toEqual({ type: "git_push", projectPath: "/p" });
  });

  it("rejects git_push with removed forceLease field", () => {
    expect(
      parseClientMessage(
        '{"type":"git_push","projectPath":"/p","forceLease":true}',
      ),
    ).toBeNull();
  });

  it("rejects git_push without projectPath", () => {
    expect(parseClientMessage('{"type":"git_push"}')).toBeNull();
  });

  // git_branches
  it("parses git_branches", () => {
    const msg = parseClientMessage(
      '{"type":"git_branches","projectPath":"/p"}',
    );
    expect(msg).toEqual({ type: "git_branches", projectPath: "/p" });
  });

  it("rejects git_branches with removed query field", () => {
    expect(
      parseClientMessage(
        '{"type":"git_branches","projectPath":"/p","query":"feat"}',
      ),
    ).toBeNull();
  });

  it("rejects git_branches without projectPath", () => {
    expect(parseClientMessage('{"type":"git_branches"}')).toBeNull();
  });

  // github_list / github_item
  it("parses github_list", () => {
    const msg = parseClientMessage(
      '{"type":"github_list","projectPath":"/p","kind":"pr","requestId":"gh-1"}',
    );
    expect(msg).toEqual({
      type: "github_list",
      projectPath: "/p",
      kind: "pr",
      requestId: "gh-1",
    });
  });

  it("parses github_item", () => {
    const msg = parseClientMessage(
      '{"type":"github_item","projectPath":"/p","kind":"issue","number":327,"requestId":"gh-2"}',
    );
    expect(msg).toEqual({
      type: "github_item",
      projectPath: "/p",
      kind: "issue",
      number: 327,
      requestId: "gh-2",
    });
  });

  it.each([
    ["missing requestId", { projectPath: "/p", kind: "pr" }],
    ["empty requestId", { projectPath: "/p", kind: "pr", requestId: " " }],
    ["missing projectPath", { kind: "pr", requestId: "gh-1" }],
    ["non-string projectPath", { projectPath: 1, kind: "pr", requestId: "gh-1" }],
    ["missing kind", { projectPath: "/p", requestId: "gh-1" }],
    ["unknown kind", { projectPath: "/p", kind: "discussion", requestId: "gh-1" }],
  ])("rejects github_list with %s", (_name, fields) => {
    expect(
      parseClientMessage(JSON.stringify({ type: "github_list", ...fields })),
    ).toBeNull();
    expect(
      parseClientMessage(
        JSON.stringify({ type: "github_item", number: 1, ...fields }),
      ),
    ).toBeNull();
  });

  it.each([undefined, 0, -3, 1.5, "327", null])(
    "rejects github_item with number %s",
    (number) => {
      expect(
        parseClientMessage(
          JSON.stringify({
            type: "github_item",
            projectPath: "/p",
            kind: "pr",
            requestId: "gh-1",
            number,
          }),
        ),
      ).toBeNull();
    },
  );

  // git_create_branch
  it("parses git_create_branch", () => {
    const msg = parseClientMessage(
      '{"type":"git_create_branch","projectPath":"/p","name":"feat/x","checkout":true}',
    );
    expect(msg).toEqual({
      type: "git_create_branch",
      projectPath: "/p",
      name: "feat/x",
      checkout: true,
    });
  });

  it("rejects git_create_branch without name", () => {
    expect(
      parseClientMessage('{"type":"git_create_branch","projectPath":"/p"}'),
    ).toBeNull();
  });

  it("rejects git_create_branch without projectPath", () => {
    expect(
      parseClientMessage('{"type":"git_create_branch","name":"feat/x"}'),
    ).toBeNull();
  });

  // git_checkout_branch
  it("parses git_checkout_branch", () => {
    const msg = parseClientMessage(
      '{"type":"git_checkout_branch","projectPath":"/p","branch":"main"}',
    );
    expect(msg).toEqual({
      type: "git_checkout_branch",
      projectPath: "/p",
      branch: "main",
    });
  });

  it("rejects git_checkout_branch without branch", () => {
    expect(
      parseClientMessage('{"type":"git_checkout_branch","projectPath":"/p"}'),
    ).toBeNull();
  });

  it("rejects git_checkout_branch without projectPath", () => {
    expect(
      parseClientMessage('{"type":"git_checkout_branch","branch":"main"}'),
    ).toBeNull();
  });

  // git_revert_file
  it("parses git_revert_file", () => {
    const msg = parseClientMessage(
      '{"type":"git_revert_file","projectPath":"/p","files":["a.txt"]}',
    );
    expect(msg).toEqual({
      type: "git_revert_file",
      projectPath: "/p",
      files: ["a.txt"],
    });
  });

  it("rejects git_revert_file without files", () => {
    expect(
      parseClientMessage('{"type":"git_revert_file","projectPath":"/p"}'),
    ).toBeNull();
  });

  it("parses git_revert_hunks", () => {
    const msg = parseClientMessage(
      '{"type":"git_revert_hunks","projectPath":"/p","hunks":[{"file":"a.txt","hunkIndex":1}]}',
    );
    expect(msg).toEqual({
      type: "git_revert_hunks",
      projectPath: "/p",
      hunks: [{ file: "a.txt", hunkIndex: 1 }],
    });
  });

  it("rejects git_revert_hunks with invalid hunk shape", () => {
    expect(
      parseClientMessage(
        '{"type":"git_revert_hunks","projectPath":"/p","hunks":[{"file":"a.txt"}]}',
      ),
    ).toBeNull();
  });
});


describe("recovery commands", () => {
  it("requires an explicit boolean and nonempty session id", () => {
    expect(parseClientMessage(JSON.stringify({ type: "set_codex_recovery", sessionId: "s1", enabled: false }))).toMatchObject({ enabled: false });
    for (const enabled of ["true", null, undefined, 1]) expect(parseClientMessage(JSON.stringify({ type: "set_codex_recovery", sessionId: "s1", enabled }))).toBeNull();
    expect(parseClientMessage(JSON.stringify({ type: "cancel_codex_recovery", sessionId: "" }))).toBeNull();
  });
});


describe("new project protocol", () => {
  it("validates bootstrap and trust requests", () => {
    expect(parseClientMessage(JSON.stringify({ type: "bootstrap_project", parentPath: "/work", name: "app", initializeGit: true, requestId: "r" }))).not.toBeNull();
    expect(parseClientMessage(JSON.stringify({ type: "bootstrap_project", parentPath: "/work", name: "app", initializeGit: "yes", requestId: "r" }))).toBeNull();
    expect(parseClientMessage(JSON.stringify({ type: "trust_project", projectPath: "/work/app", requestId: "r", sessionId: 42 }))).toBeNull();
    expect(parseClientMessage(JSON.stringify({ type: "start", projectPath: "/work/app", initialPrompt: 42 }))).toBeNull();
  });
});


// ---- isAgentBackgroundTask ----

describe("isAgentBackgroundTask", () => {
  it.each([
    "local_agent",
    "remote_agent",
    "local_workflow",
    "codex_agent",
    "antigravity_agent",
  ])("treats %s as an agent task", (taskType) => {
    expect(isAgentBackgroundTask({ taskId: "t1", taskType })).toBe(true);
  });

  it.each(["local_bash", "monitor", ""])(
    "treats %j as a non-agent task",
    (taskType) => {
      expect(isAgentBackgroundTask({ taskId: "t1", taskType })).toBe(false);
    },
  );
});

// ---- parseClientMessage field contracts ----

type Patch = Record<string, unknown>;

/** Serialises like a real client would; `undefined` values drop the key. */
function parse(message: Patch) {
  return parseClientMessage(JSON.stringify(message));
}

function label(patch: Patch): string {
  const text = JSON.stringify(patch, (_key, value) =>
    value === undefined ? "<missing>" : value,
  );
  return text.length > 120 ? `${text.slice(0, 120)}... (${text.length} chars)` : text;
}

/**
 * Checks one message type: the base message and every `accept` variant parse
 * to the same object that was sent, and every `reject` variant is refused.
 */
function expectContract(
  base: Patch,
  variants: { accept?: Patch[]; reject?: Patch[] },
) {
  for (const patch of [{}, ...(variants.accept ?? [])]) {
    const message = { ...base, ...patch };
    expect(parse(message), `should accept ${label(patch)}`).toEqual(
      JSON.parse(JSON.stringify(message)),
    );
  }
  for (const patch of variants.reject ?? []) {
    expect(
      parse({ ...base, ...patch }),
      `should reject ${label(patch)}`,
    ).toBeNull();
  }
}

const ITEM_REFS_REJECTED = (field: string): Patch[] => [
  { [field]: "not-an-array" },
  { [field]: [{ name: "a" }] },
  { [field]: [{ path: "/a" }] },
  { [field]: [{ name: "a", path: "/a" }, { name: 1, path: "/b" }] },
  { [field]: [{ name: "a", path: "/a" }, null] },
];

const HUNKS_REJECTED: Patch[] = [
  { hunks: [{ file: "a.ts" }] },
  { hunks: [{ hunkIndex: 0 }] },
  { hunks: [{ file: "a.ts", hunkIndex: "0" }] },
  { hunks: [{ file: "a.ts", hunkIndex: 0 }, { file: 1, hunkIndex: 1 }] },
  { hunks: [null] },
];

const VALID_HISTORY_ENTRY = {
  text: "run tests",
  projectPath: "/p",
  projectId: "proj-1",
  projectName: "App",
  id: "e1",
  useCount: 0,
  totalUseCount: 0,
  isFavorite: false,
};

const INVALID_HISTORY_ENTRIES: unknown[] = [
  null,
  "run tests",
  { ...VALID_HISTORY_ENTRY, text: 5 },
  { ...VALID_HISTORY_ENTRY, projectPath: 5 },
  { ...VALID_HISTORY_ENTRY, projectId: 5 },
  { ...VALID_HISTORY_ENTRY, projectName: 5 },
  { ...VALID_HISTORY_ENTRY, id: 5 },
  { ...VALID_HISTORY_ENTRY, useCount: -1 },
  { ...VALID_HISTORY_ENTRY, useCount: 1.5 },
  { ...VALID_HISTORY_ENTRY, totalUseCount: -1 },
  { ...VALID_HISTORY_ENTRY, totalUseCount: 1.5 },
  { ...VALID_HISTORY_ENTRY, isFavorite: "yes" },
];

describe("parseClientMessage envelope", () => {
  it.each(["null", "5", '"start"', "[]", "{}"])(
    "rejects JSON that is not a typed message: %s",
    (raw) => {
      expect(parseClientMessage(raw)).toBeNull();
    },
  );

  it("limits requestId on every message type to a non-blank string of at most 128 chars", () => {
    expectContract(
      { type: "list_sessions" },
      {
        accept: [{ requestId: "r1" }, { requestId: "r".repeat(128) }],
        reject: [
          { requestId: 5 },
          { requestId: null },
          { requestId: "" },
          { requestId: "   " },
          { requestId: "r".repeat(129) },
        ],
      },
    );
  });
});

describe("parseClientMessage field contracts", () => {
  it("client_capabilities", () => {
    expectContract(
      { type: "client_capabilities" },
      {
        accept: [
          { deliveryRevision: 0 },
          { performanceMode: false },
          { sessionPerformanceModes: {} },
          { sessionPerformanceModes: { s1: true, s2: false } },
          { appVersion: "1.2.3" },
          { protocolVersion: 1 },
          { protocolVersion: 2, minimumProtocolVersion: 2 },
          { supportedServerMessages: [] },
          { supportedServerMessages: ["agent_activity"] },
        ],
        reject: [
          { deliveryRevision: -1 },
          { deliveryRevision: 1.5 },
          { deliveryRevision: "1" },
          { performanceMode: "true" },
          { sessionPerformanceModes: null },
          { sessionPerformanceModes: 5 },
          { sessionPerformanceModes: [true] },
          { sessionPerformanceModes: { s1: true, s2: "false" } },
          { appVersion: 5 },
          { protocolVersion: 0 },
          { protocolVersion: 1.5 },
          { protocolVersion: "1" },
          { protocolVersion: 2, minimumProtocolVersion: 0 },
          { protocolVersion: 2, minimumProtocolVersion: 1.5 },
          { protocolVersion: 2, minimumProtocolVersion: 3 },
          { minimumProtocolVersion: 1 },
          { supportedServerMessages: "agent_activity" },
          { supportedServerMessages: ["agent_activity", 1] },
        ],
      },
    );
  });

  it("start and resume_session shared options at their boundaries", () => {
    const variants = {
      accept: [
        { maxTurns: 1 },
        { maxBudgetUsd: 0 },
        { maxBudgetUsd: 0.5 },
        { additionalWritableRoots: ["/a", "/b"] },
        { workspaceKind: "project", projectId: "proj-1", projectName: "App" },
      ],
      reject: [
        { projectPath: 5 },
        { maxTurns: 1.5 },
        { maxTurns: "3" },
        { maxBudgetUsd: "5" },
        { additionalWritableRoots: "/a" },
        { additionalWritableRoots: ["/a", 1] },
        { modelReasoningEffort: "   " },
        { serviceTier: "   " },
        { serviceTier: 1 },
        { projectId: "   " },
        { projectName: "" },
        { workspaceKind: "unassigned" },
      ],
    };
    expectContract({ type: "start", projectPath: "/p" }, variants);
    expectContract(
      { type: "resume_session", sessionId: "s1", projectPath: "/p" },
      variants,
    );
  });

  it("rejects a non-finite budget", () => {
    // JSON.parse turns an overflowing literal into Infinity.
    expect(
      parseClientMessage('{"type":"start","projectPath":"/p","maxBudgetUsd":1e999}'),
    ).toBeNull();
  });

  it("start initialPrompt is limited to 16000 characters", () => {
    expectContract(
      { type: "start", projectPath: "/p" },
      {
        accept: [{ initialPrompt: "" }, { initialPrompt: "a".repeat(16000) }],
        reject: [{ initialPrompt: "a".repeat(16001) }, { initialPrompt: 5 }],
      },
    );
  });

  it("input", () => {
    expectContract(
      { type: "input", text: "hello" },
      {
        accept: [
          { text: "" },
          { delivery: "steer" },
          { delivery: "queue" },
          { clientMessageId: "c1", baseSeq: 0 },
          { images: [] },
          { images: [{ base64: "AAAA", mimeType: "image/png" }] },
          { skills: [{ name: "review", path: "/skills/review" }] },
          { mentions: [{ name: "app", path: "/apps/app" }] },
          { imageBase64: "AAAA", mimeType: "image/png" },
        ],
        reject: [
          { text: 5 },
          { text: undefined },
          { delivery: "later" },
          { clientMessageId: 5 },
          { baseSeq: -1 },
          { baseSeq: 1.5 },
          { baseSeq: "1" },
          { images: "AAAA" },
          { images: [{ base64: "AAAA" }] },
          { images: [{ mimeType: "image/png" }] },
          { images: [{ base64: "AAAA", mimeType: "image/png" }, null] },
          ...ITEM_REFS_REJECTED("skills"),
          ...ITEM_REFS_REJECTED("mentions"),
          { imageBase64: "AAAA" },
          { imageBase64: "AAAA", mimeType: 5 },
        ],
      },
    );
  });

  it("update_queued_input", () => {
    expectContract(
      { type: "update_queued_input", sessionId: "s1", itemId: "q1", text: "new" },
      {
        accept: [
          { text: "" },
          { skills: [{ name: "review", path: "/skills/review" }] },
          { mentions: [{ name: "app", path: "/apps/app" }] },
        ],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { itemId: undefined },
          { itemId: 5 },
          { text: undefined },
          { text: 5 },
          ...ITEM_REFS_REJECTED("skills"),
          ...ITEM_REFS_REJECTED("mentions"),
        ],
      },
    );
  });

  it.each(["steer_queued_input", "cancel_queued_input"])(
    "%s needs a session and an item",
    (type) => {
      expectContract(
        { type, sessionId: "s1", itemId: "q1" },
        {
          reject: [
            { sessionId: undefined },
            { sessionId: 5 },
            { itemId: undefined },
            { itemId: 5 },
          ],
        },
      );
    },
  );

  it("push_register", () => {
    expectContract(
      { type: "push_register", token: "tok", platform: "ios" },
      {
        accept: [{ platform: "android" }, { platform: "web" }],
        reject: [
          { token: 5 },
          { token: undefined },
          { platform: "windows" },
          { platform: undefined },
        ],
      },
    );
  });

  it("set_permission_mode", () => {
    expectContract(
      { type: "set_permission_mode", mode: "default" },
      {
        accept: [
          {
            mode: "plan",
            executionMode: "fullAccess",
            approvalPolicy: "on-request",
            approvalsReviewer: "auto_review",
            codexPermissionsMode: "autoReview",
            planMode: true,
          },
        ],
        reject: [
          { mode: undefined },
          { mode: 5 },
          { executionMode: "unrestricted" },
          { approvalPolicy: "always" },
          { approvalsReviewer: "bot" },
          { codexPermissionsMode: "reviewEverything" },
          { planMode: "true" },
        ],
      },
    );
  });

  it("set_codex_model", () => {
    expectContract(
      { type: "set_codex_model", model: "gpt-5" },
      {
        accept: [{ modelReasoningEffort: "high" }, { sessionId: "s1" }],
        reject: [
          { model: undefined },
          { model: 5 },
          { model: "" },
          { model: "   " },
          { modelReasoningEffort: 5 },
          { modelReasoningEffort: "   " },
          { sessionId: 5 },
        ],
      },
    );
  });

  it("set_codex_speed", () => {
    expectContract(
      { type: "set_codex_speed", serviceTier: "fast" },
      {
        accept: [{ sessionId: "s1" }],
        reject: [
          { serviceTier: undefined },
          { serviceTier: 5 },
          { serviceTier: "" },
          { serviceTier: "   " },
          { sessionId: 5 },
        ],
      },
    );
  });

  it("set_antigravity_model", () => {
    expectContract(
      { type: "set_antigravity_model", sessionId: "s1", model: "gemini" },
      {
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { sessionId: "" },
          { model: undefined },
          { model: 5 },
          { model: "   " },
        ],
      },
    );
  });

  it("set_antigravity_settings needs a session and at least one setting", () => {
    expectContract(
      { type: "set_antigravity_settings", sessionId: "s1", model: "gemini" },
      {
        accept: [
          { thoughtLevel: "high" },
          { model: undefined, thoughtLevel: "high" },
        ],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { sessionId: "" },
          { model: "" },
          { model: 5 },
          { thoughtLevel: "   " },
          { thoughtLevel: 5 },
          { model: undefined },
        ],
      },
    );
  });

  it("set_claude_settings needs a session and at least one setting", () => {
    expectContract(
      { type: "set_claude_settings", sessionId: "s1", model: "opus" },
      {
        accept: [
          { model: undefined, effort: "max" },
          { model: undefined, fastMode: false },
          { model: undefined, ultracode: false },
        ],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { sessionId: "" },
          { model: "" },
          { model: 5 },
          { effort: "turbo" },
          { fastMode: "yes" },
          { ultracode: 1 },
          { model: undefined },
        ],
      },
    );
  });

  it("codex recovery commands need a real session id", () => {
    expectContract(
      { type: "set_codex_recovery", sessionId: "s1", enabled: true },
      { reject: [{ sessionId: undefined }, { sessionId: 5 }, { sessionId: "" }] },
    );
    expectContract(
      { type: "cancel_codex_recovery", sessionId: "s1" },
      { reject: [{ sessionId: undefined }, { sessionId: 5 }] },
    );
  });

  it("goal messages", () => {
    expectContract(
      { type: "get_goal", sessionId: "s1" },
      {
        accept: [{ background: true }],
        reject: [{ sessionId: undefined }, { background: "yes" }],
      },
    );
    expectContract(
      { type: "clear_goal", sessionId: "s1" },
      { reject: [{ sessionId: undefined }, { sessionId: 5 }] },
    );
    expectContract(
      { type: "set_goal", sessionId: "s1", objective: "ship it" },
      {
        accept: [
          { objective: "a".repeat(4000) },
          { status: "paused" },
          ...[
            "active",
            "paused",
            "blocked",
            "usageLimited",
            "budgetLimited",
            "complete",
          ].map((status) => ({ objective: undefined, status })),
        ],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { objective: undefined },
          { objective: 5 },
          { objective: "   " },
          { objective: "a".repeat(4001) },
          { status: "done" },
          { objective: undefined, status: "done" },
          { objective: "", status: "active" },
        ],
      },
    );
  });

  it.each([
    ["set_sandbox_mode", { sandboxMode: "workspace-write" }, "sandboxMode"],
    ["rename_session", { sessionId: "s1", name: "New name" }, "sessionId"],
    ["refresh_branch", { sessionId: "s1" }, "sessionId"],
    ["get_recording", { sessionId: "s1" }, "sessionId"],
    ["get_diff", { projectPath: "/p" }, "projectPath"],
    ["list_worktrees", { projectPath: "/p" }, "projectPath"],
    ["git_fetch", { projectPath: "/p" }, "projectPath"],
    ["git_pull", { projectPath: "/p" }, "projectPath"],
    ["git_remote_status", { projectPath: "/p" }, "projectPath"],
    ["git_unstage", { projectPath: "/p", files: ["a.ts"] }, "projectPath"],
    ["git_revert_file", { projectPath: "/p", files: ["a.ts"] }, "projectPath"],
  ])("%s requires a string %s", (type, fields, required) => {
    expectContract(
      { type, ...fields },
      { reject: [{ [required]: undefined }, { [required]: 5 }] },
    );
  });

  it.each([
    "list_windows",
    "list_recordings",
    "restore_prompt_history",
    "get_prompt_history_backup_info",
    "list_projects",
    "get_antigravity_catalog",
  ])("%s needs no fields", (type) => {
    expectContract({ type }, { accept: [{ requestId: "r1" }] });
  });

  it("get_history_delta", () => {
    expectContract(
      { type: "get_history_delta", sessionId: "s1", sinceSeq: 0 },
      {
        accept: [{ sinceSeq: 12 }],
        reject: [
          { sessionId: 5 },
          { sinceSeq: -1 },
          { sinceSeq: 1.5 },
          { sinceSeq: "0" },
        ],
      },
    );
  });

  it("resolve_session_link", () => {
    expectContract(
      { type: "resolve_session_link", requestId: "r1", sessionId: "s1" },
      {
        accept: [
          { provider: "claude" },
          { provider: "codex" },
          { provider: "antigravity" },
        ],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { provider: "other" },
          { provider: 5 },
        ],
      },
    );
  });

  it("list_recent_sessions paging, scope and filter boundaries", () => {
    const pin = { provider: "claude", sessionId: "s1" };
    expectContract(
      { type: "list_recent_sessions" },
      {
        accept: [
          { limit: 1 },
          { limit: 500 },
          { offset: 0 },
          { offset: 100_000 },
          { projectPath: "/p", projectId: "proj-1" },
          { workspaceKind: "project" },
          { workspaceKind: "unassigned" },
          { requestScope: "list" },
          { requestScope: "project" },
          { provider: "claude" },
          { provider: "codex" },
          { provider: "antigravity" },
          { pinnedSessions: Array.from({ length: 1000 }, () => pin) },
          { projectFilters: [{ projectId: "proj-1", workspaceKind: "project" }] },
          { pinnedProjects: [{ projectPath: "/p", workspaceKind: "unassigned" }] },
        ],
        reject: [
          { limit: 0 },
          { limit: 501 },
          { limit: 1.5 },
          { limit: "5" },
          { offset: -1 },
          { offset: 100_001 },
          { offset: 1.5 },
          { offset: "0" },
          { projectPath: 5 },
          { projectId: 5 },
          { projectId: "   " },
          { workspaceKind: "other" },
          { requestScope: "other" },
          { provider: "other" },
          { namedOnly: "yes" },
          { searchQuery: 5 },
          { pinnedSessions: Array.from({ length: 1001 }, () => pin) },
          { pinnedSessions: [pin, null] },
          { pinnedSessions: [pin, { provider: "other", sessionId: "s2" }] },
          { pinnedSessions: [pin, { provider: "codex", sessionId: " " }] },
          { projectFilters: [{ projectPath: "/p" }, {}] },
          { projectFilters: [{ projectPath: "/p" }, null] },
          { projectFilters: [{ projectPath: 5, projectId: "proj-1" }] },
          { projectFilters: [{ projectPath: "/p", projectId: 5 }] },
          { projectFilters: [{ projectPath: "/p", workspaceKind: "other" }] },
          { pinnedProjects: [{ projectPath: "/p" }, { projectPath: " " }] },
          { modifiedAfter: "   " },
          { modifiedBefore: "not a date" },
        ],
      },
    );
  });

  it("list_gallery scope limits", () => {
    expectContract(
      { type: "list_gallery" },
      {
        accept: [
          { project: "/p" },
          { projectPath: "/p" },
          { project: "/p", projectPath: "/p" },
          { project: "p".repeat(4096) },
          { projectPath: "p".repeat(4096) },
          { sessionId: "s".repeat(512) },
        ],
        reject: [
          { project: 5 },
          { project: "   " },
          { project: "p".repeat(4097) },
          { projectPath: 5 },
          { projectPath: "   " },
          { projectPath: "p".repeat(4097) },
          { project: "/p", projectPath: "/other" },
          { sessionId: 5 },
          { sessionId: "   " },
          { sessionId: "s".repeat(513) },
          { limit: 10 },
        ],
      },
    );
  });

  it("reveal_file_local path, port and token limits", () => {
    expectContract(
      {
        type: "reveal_file_local",
        projectPath: "/p",
        filePath: "movie.mp4",
        requestId: "r1",
        proofPort: 54321,
        proofToken: "a".repeat(64),
      },
      {
        accept: [
          { proofPort: 1024 },
          { proofPort: 65535 },
          { filePath: "f".repeat(4096) },
          { proofToken: "0123456789abcdef".repeat(4) },
        ],
        reject: [
          { proofPort: 1023 },
          { proofPort: 65536 },
          { projectPath: undefined },
          { projectPath: 5 },
          { projectPath: "   " },
          { projectPath: "/p\0" },
          { filePath: undefined },
          { filePath: "f".repeat(4097) },
          { requestId: undefined },
          { proofToken: undefined },
          { proofToken: "a".repeat(63) },
          { proofToken: "a".repeat(65) },
          { proofToken: `x${"a".repeat(64)}` },
          { proofToken: `${"a".repeat(64)}x` },
          { proofToken: "A".repeat(64) },
        ],
      },
    );
  });

  it("reveal_file path and token limits", () => {
    expectContract(
      {
        type: "reveal_file",
        projectPath: "/p",
        filePath: "video.mp4",
        requestId: "r1",
        proofPath: "/tmp/proof",
        proofToken: "a".repeat(64),
      },
      {
        accept: [
          { filePath: "f".repeat(4096) },
          { proofPath: "p".repeat(4096) },
        ],
        reject: [
          { projectPath: undefined },
          { projectPath: "   " },
          { filePath: 5 },
          { filePath: "f".repeat(4097) },
          { requestId: undefined },
          { proofPath: undefined },
          { proofPath: "   " },
          { proofPath: "p".repeat(4097) },
          { proofPath: "/tmp/\0proof" },
          { proofToken: undefined },
          { proofToken: "a".repeat(65) },
          { proofToken: `x${"a".repeat(64)}` },
          { proofToken: `${"a".repeat(64)}x` },
          { proofToken: "A".repeat(64) },
          { proofPort: 54321 },
        ],
      },
    );
  });

  it.each(["read_file", "read_media_file", "read_model_file"])(
    "%s needs a project and a file path",
    (type) => {
      expectContract(
        { type, projectPath: "/p", filePath: "a.txt" },
        {
          reject: [
            { projectPath: undefined },
            { projectPath: 5 },
            { filePath: undefined },
            { filePath: 5 },
          ],
        },
      );
    },
  );

  it("prepare_file_download", () => {
    expectContract(
      {
        type: "prepare_file_download",
        projectPath: "/p",
        filePath: "a.txt",
        requestId: "r1",
      },
      {
        reject: [
          { projectPath: undefined },
          { projectPath: 5 },
          { projectPath: "   " },
          { filePath: undefined },
          { filePath: 5 },
          { filePath: "   " },
          { requestId: undefined },
          { inline: true },
        ],
      },
    );
  });

  it("prepare_file_upload", () => {
    expectContract(
      {
        type: "prepare_file_upload",
        projectPath: "/p",
        directoryPath: "docs",
        fileName: "report.pdf",
        sizeBytes: 10,
        conflictPolicy: "rename",
        requestId: "r1",
      },
      {
        accept: [
          { directoryPath: "" },
          { fileName: "f".repeat(255) },
          { sizeBytes: 0 },
          { conflictPolicy: "overwrite" },
          { conflictPolicy: "skip" },
        ],
        reject: [
          { projectPath: undefined },
          { projectPath: 5 },
          { projectPath: "   " },
          { directoryPath: undefined },
          { directoryPath: 5 },
          { fileName: undefined },
          { fileName: 5 },
          { fileName: "" },
          { fileName: "f".repeat(256) },
          { sizeBytes: undefined },
          { sizeBytes: "10" },
          { sizeBytes: 1.5 },
          { sizeBytes: -1 },
          { sizeBytes: 2 ** 53 },
          { conflictPolicy: undefined },
          { conflictPolicy: "" },
          { requestId: undefined },
          { mimeType: "application/pdf" },
        ],
      },
    );
  });

  it("finalize_file_upload", () => {
    expectContract(
      {
        type: "finalize_file_upload",
        uploadToken: "a".repeat(48),
        sha256: "b".repeat(64),
        requestId: "r1",
      },
      {
        accept: [{ sha256: "ABCDEF0123456789".repeat(4) }],
        reject: [
          { uploadToken: undefined },
          { uploadToken: 5 },
          { uploadToken: "a".repeat(47) },
          { uploadToken: `x${"a".repeat(48)}` },
          { uploadToken: `${"a".repeat(48)}x` },
          { uploadToken: "A".repeat(48) },
          { sha256: undefined },
          { sha256: 5 },
          { sha256: "b".repeat(63) },
          { sha256: `x${"b".repeat(64)}` },
          { sha256: `${"b".repeat(64)}x` },
          { sha256: "g".repeat(64) },
          { requestId: undefined },
          { projectPath: "/p" },
        ],
      },
    );
  });

  it("cancel_file_upload", () => {
    expectContract(
      { type: "cancel_file_upload", uploadToken: "a".repeat(48) },
      {
        reject: [
          { uploadToken: undefined },
          { uploadToken: 5 },
          { uploadToken: "a".repeat(47) },
          { uploadToken: `x${"a".repeat(48)}` },
          { uploadToken: `${"a".repeat(48)}x` },
          { requestId: "r1" },
        ],
      },
    );
  });

  it("list_directory", () => {
    expectContract(
      { type: "list_directory", path: "/p" },
      {
        accept: [{ includeHidden: true, includeFiles: false, requestId: "r1" }],
        reject: [{ path: 5 }, { path: "   " }, { includeHidden: "yes" }],
      },
    );
  });

  it("get_diff_image", () => {
    expectContract(
      { type: "get_diff_image", projectPath: "/p", filePath: "a.png", version: "old" },
      {
        accept: [{ version: "new" }, { version: "both" }],
        reject: [
          { projectPath: undefined },
          { projectPath: 5 },
          { filePath: undefined },
          { filePath: 5 },
          { version: undefined },
          { version: "latest" },
        ],
      },
    );
  });

  it("interrupt", () => {
    expectContract(
      { type: "interrupt" },
      {
        accept: [{ retract: true }, { sessionId: "s1" }],
        reject: [{ retract: "yes" }],
      },
    );
  });

  it("edit_message", () => {
    expectContract(
      { type: "edit_message", sessionId: "s1", targetUuid: "u1", text: "fixed" },
      {
        accept: [{ clientMessageId: "c1" }],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { targetUuid: undefined },
          { targetUuid: 5 },
          { targetUuid: "" },
          { text: undefined },
          { text: 5 },
          { text: "   " },
          { clientMessageId: 5 },
        ],
      },
    );
  });

  it("bootstrap_project", () => {
    expectContract(
      {
        type: "bootstrap_project",
        parentPath: "/work",
        name: "app",
        initializeGit: false,
        requestId: "r1",
      },
      {
        accept: [{ sourcePath: "/templates/app" }],
        reject: [
          { parentPath: undefined },
          { parentPath: 5 },
          { name: undefined },
          { name: "   " },
          { initializeGit: undefined },
          { requestId: undefined },
          { sourcePath: "   " },
          { sourcePath: 5 },
        ],
      },
    );
  });

  it("trust_project and initialize_git need a project path and a request id", () => {
    expectContract(
      { type: "trust_project", projectPath: "/p", requestId: "r1" },
      {
        accept: [{ sessionId: "s1" }],
        reject: [
          { sessionId: "   " },
          { projectPath: undefined },
          { projectPath: "   " },
          { requestId: undefined },
        ],
      },
    );
    expectContract(
      { type: "initialize_git", projectPath: "/p", requestId: "r1" },
      {
        reject: [
          { projectPath: undefined },
          { projectPath: "   " },
          { projectPath: 5 },
          { requestId: undefined },
        ],
      },
    );
  });

  it("create_project, update_project and remove_project", () => {
    const rootPathsRejected: Patch[] = [
      { rootPaths: undefined },
      { rootPaths: "/a" },
      { rootPaths: [] },
      { rootPaths: ["/a", "   "] },
      { rootPaths: ["/a", 5] },
    ];
    expectContract(
      { type: "create_project", name: "App", rootPaths: ["/a"] },
      {
        accept: [{ rootPaths: ["/a", "/b"], requestId: "r1" }],
        reject: [
          { name: undefined },
          { name: "   " },
          { name: 5 },
          ...rootPathsRejected,
        ],
      },
    );
    expectContract(
      { type: "update_project", projectId: "proj-1", name: "App", rootPaths: ["/a"] },
      {
        accept: [{ rootPaths: ["/a", "/b"], requestId: "r1" }],
        reject: [
          { projectId: undefined },
          { projectId: "   " },
          { projectId: 5 },
          { name: undefined },
          { name: "   " },
          ...rootPathsRejected,
        ],
      },
    );
    expectContract(
      { type: "remove_project", projectId: "proj-1" },
      {
        accept: [{ requestId: "r1" }],
        reject: [{ projectId: undefined }, { projectId: "   " }, { projectId: 5 }],
      },
    );
  });

  it("remove_worktree", () => {
    expectContract(
      { type: "remove_worktree", projectPath: "/p", worktreePath: "/p-wt" },
      {
        reject: [
          { projectPath: undefined },
          { projectPath: 5 },
          { worktreePath: undefined },
          { worktreePath: 5 },
        ],
      },
    );
  });

  it.each(["fork", "rewind_dry_run"])(
    "%s needs a session and a target message",
    (type) => {
      expectContract(
        { type, sessionId: "s1", targetUuid: "u1" },
        {
          reject: [
            { sessionId: undefined },
            { sessionId: 5 },
            { targetUuid: undefined },
            { targetUuid: 5 },
          ],
        },
      );
    },
  );

  it("take_screenshot", () => {
    expectContract(
      { type: "take_screenshot", mode: "fullscreen", projectPath: "/p" },
      {
        accept: [{ mode: "window", windowId: 42 }],
        reject: [
          { mode: undefined },
          { mode: "region" },
          { mode: "window" },
          { mode: "window", windowId: "42" },
          { projectPath: undefined },
          { projectPath: 5 },
        ],
      },
    );
  });

  it("get_debug_bundle and get_usage options", () => {
    expectContract(
      { type: "get_debug_bundle", sessionId: "s1" },
      {
        accept: [{ traceLimit: 50 }, { includeDiff: false }],
        reject: [{ sessionId: 5 }, { traceLimit: "50" }, { includeDiff: "yes" }],
      },
    );
    expectContract(
      { type: "get_usage" },
      {
        accept: [{ refreshAntigravity: true }],
        reject: [{ refreshAntigravity: "yes" }],
      },
    );
  });

  it("get_session_transcript paging", () => {
    expectContract(
      { type: "get_session_transcript", sessionId: "s1", requestId: "r1" },
      {
        accept: [
          { beforeIndex: 0 },
          { limit: 1 },
          { beforeIndex: 40, limit: 20, untilLatestCompaction: true },
        ],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { requestId: undefined },
          { beforeIndex: -1 },
          { beforeIndex: 1.5 },
          { beforeIndex: "0" },
          { limit: 0 },
          { limit: 1.5 },
          { limit: "1" },
          { untilLatestCompaction: "yes" },
        ],
      },
    );
  });

  it("get_message_images", () => {
    expectContract(
      { type: "get_message_images", claudeSessionId: "c1", messageUuid: "u1" },
      {
        reject: [
          { claudeSessionId: undefined },
          { claudeSessionId: 5 },
          { messageUuid: undefined },
          { messageUuid: 5 },
        ],
      },
    );
  });

  it("backup_prompt_history", () => {
    expectContract(
      { type: "backup_prompt_history", data: "AAAA", appVersion: "1.0.0", dbVersion: 3 },
      {
        reject: [
          { data: undefined },
          { data: 5 },
          { appVersion: undefined },
          { appVersion: 5 },
          { dbVersion: undefined },
          { dbVersion: "3" },
          { dbVersion: 1.5 },
        ],
      },
    );
  });

  it("record_prompt_history", () => {
    const optional = [
      "projectPath",
      "projectId",
      "projectName",
      "clientName",
      "sessionId",
      "usedAt",
    ];
    expectContract(
      { type: "record_prompt_history", text: "run tests", clientId: "phone" },
      {
        accept: [Object.fromEntries(optional.map((field) => [field, "x"]))],
        reject: [
          { text: undefined },
          { text: 5 },
          { clientId: undefined },
          { clientId: 5 },
          ...optional.map((field) => ({ [field]: 5 })),
        ],
      },
    );
  });

  it("sync_prompt_history", () => {
    expectContract(
      { type: "sync_prompt_history", clientId: "phone" },
      {
        accept: [
          { clientName: "Phone" },
          { sinceRevision: 0 },
          { entries: [] },
          { entries: [VALID_HISTORY_ENTRY, { text: "minimal" }] },
          { includeDeleted: true },
        ],
        reject: [
          { clientId: undefined },
          { clientId: 5 },
          { clientName: 5 },
          { sinceRevision: -1 },
          { sinceRevision: 1.5 },
          { sinceRevision: "0" },
          { entries: "run tests" },
          { includeDeleted: "yes" },
          ...INVALID_HISTORY_ENTRIES.map((entry) => ({
            entries: [VALID_HISTORY_ENTRY, entry],
          })),
        ],
      },
    );
  });

  it("mutate_prompt_history", () => {
    expectContract(
      { type: "mutate_prompt_history", action: "favorite" },
      {
        accept: [
          { action: "delete" },
          { action: "restore" },
          {
            id: "e1",
            text: "run tests",
            projectPath: "/p",
            projectId: "proj-1",
            isFavorite: true,
            updatedAt: "2026-01-01T00:00:00Z",
          },
        ],
        reject: [
          { action: undefined },
          { action: "archive" },
          { id: 5 },
          { text: 5 },
          { projectPath: 5 },
          { projectId: 5 },
          { isFavorite: "yes" },
          { updatedAt: 5 },
        ],
      },
    );
  });

  it("import_prompt_history_v1", () => {
    expectContract(
      { type: "import_prompt_history_v1", clientId: "phone", entries: [] },
      {
        accept: [
          { clientName: "Phone" },
          { entries: [VALID_HISTORY_ENTRY, { text: "minimal" }] },
        ],
        reject: [
          { clientId: undefined },
          { clientId: 5 },
          { clientName: 5 },
          { entries: undefined },
          { mode: "replace" },
          ...INVALID_HISTORY_ENTRIES.map((entry) => ({
            entries: [VALID_HISTORY_ENTRY, entry],
          })),
        ],
      },
    );
  });

  it("git_stage", () => {
    expectContract(
      { type: "git_stage", projectPath: "/p", files: ["a.ts"] },
      {
        accept: [
          { hunks: [] },
          { files: undefined, hunks: [{ file: "a.ts", hunkIndex: 0 }] },
        ],
        reject: [{ projectPath: 5 }, { hunks: "a.ts" }, ...HUNKS_REJECTED],
      },
    );
  });

  it.each(["git_unstage_hunks", "git_revert_hunks"])(
    "%s needs at least one well-formed hunk",
    (type) => {
      expectContract(
        { type, projectPath: "/p", hunks: [{ file: "a.ts", hunkIndex: 0 }] },
        {
          reject: [
            { projectPath: undefined },
            { projectPath: 5 },
            { hunks: undefined },
            { hunks: "a.ts" },
            { hunks: [] },
            ...HUNKS_REJECTED,
          ],
        },
      );
    },
  );

  it("git_commit, git_create_branch and git_status options", () => {
    expectContract(
      { type: "git_commit", projectPath: "/p" },
      {
        reject: [
          { projectPath: 5 },
          { sessionId: 5 },
          { message: 5 },
          { autoGenerate: "yes" },
        ],
      },
    );
    expectContract(
      { type: "git_create_branch", projectPath: "/p", name: "feature" },
      { accept: [{ checkout: true }], reject: [{ checkout: "yes" }] },
    );
    expectContract(
      { type: "git_status", projectPath: "/p" },
      {
        accept: [{ sessionId: "s1", includeRemote: true }],
        reject: [
          { projectPath: undefined },
          { projectPath: 5 },
          { sessionId: 5 },
          { includeRemote: "yes" },
        ],
      },
    );
  });

  it.each(["git_push", "git_branches"])(
    "%s accepts request correlation but no other extra field",
    (type) => {
      expectContract(
        { type, projectPath: "/p" },
        { accept: [{ requestId: "r1" }], reject: [{ sessionId: "s1" }] },
      );
    },
  );

  it("archive_session", () => {
    expectContract(
      { type: "archive_session", sessionId: "s1", provider: "claude", projectPath: "/p" },
      {
        accept: [{ provider: "codex" }],
        reject: [
          { sessionId: undefined },
          { sessionId: 5 },
          { provider: undefined },
          { provider: "other" },
          { projectPath: undefined },
          { projectPath: 5 },
        ],
      },
    );
  });
});
