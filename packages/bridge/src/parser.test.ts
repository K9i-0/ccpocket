import { describe, it, expect } from "vitest";
import { normalizeToolResultContent, parseClientMessage } from "./parser.js";

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
  it("parses start message", () => {
    const msg = parseClientMessage('{"type":"start","projectPath":"/tmp/foo"}');
    expect(msg).toEqual({ type: "start", projectPath: "/tmp/foo" });
  });

  it("parses start with optional fields", () => {
    const msg = parseClientMessage(
      '{"type":"start","projectPath":"/p","sessionId":"s1","continue":true,"permissionMode":"acceptEdits"}',
    );
    expect(msg).toEqual({
      type: "start",
      projectPath: "/p",
      sessionId: "s1",
      continue: true,
      permissionMode: "acceptEdits",
    });
  });

  it("parses start with advanced Claude options", () => {
    const msg = parseClientMessage(
      '{"type":"start","projectPath":"/p","model":"claude-sonnet","effort":"high","maxTurns":5,"maxBudgetUsd":1.5,"fallbackModel":"claude-haiku","forkSession":true,"persistSession":false}',
    );
    expect(msg).toEqual({
      type: "start",
      projectPath: "/p",
      model: "claude-sonnet",
      effort: "high",
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

  it("rejects start without projectPath", () => {
    expect(parseClientMessage('{"type":"start"}')).toBeNull();
  });

  it("parses input message", () => {
    const msg = parseClientMessage('{"type":"input","text":"hello"}');
    expect(msg).toEqual({ type: "input", text: "hello" });
  });

  it("rejects input without text", () => {
    expect(parseClientMessage('{"type":"input"}')).toBeNull();
  });

  it("parses push_register message", () => {
    const msg = parseClientMessage(
      '{"type":"push_register","token":"t1","platform":"ios"}',
    );
    expect(msg).toEqual({
      type: "push_register",
      token: "t1",
      platform: "ios",
    });
  });

  it("rejects push_register with invalid platform", () => {
    expect(
      parseClientMessage(
        '{"type":"push_register","token":"t1","platform":"desktop"}',
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
      '{"type":"set_permission_mode","mode":"plan","sessionId":"s1"}',
    );
    expect(msg).toEqual({
      type: "set_permission_mode",
      mode: "plan",
      sessionId: "s1",
    });
  });

  it("rejects set_permission_mode with invalid mode", () => {
    expect(
      parseClientMessage('{"type":"set_permission_mode","mode":"unsupported"}'),
    ).toBeNull();
  });

  it("parses approve message", () => {
    const msg = parseClientMessage('{"type":"approve","id":"tu1"}');
    expect(msg).toEqual({ type: "approve", id: "tu1" });
  });

  it("parses approve with updatedInput", () => {
    const msg = parseClientMessage(
      '{"type":"approve","id":"tu1","updatedInput":{"plan":"edited plan"}}',
    );
    expect(msg).toEqual({
      type: "approve",
      id: "tu1",
      updatedInput: { plan: "edited plan" },
    });
  });

  it("parses approve without updatedInput (backward compat)", () => {
    const msg = parseClientMessage('{"type":"approve","id":"tu1"}');
    expect(msg).not.toBeNull();
    expect((msg as Record<string, unknown>).updatedInput).toBeUndefined();
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

  it("rejects get_history without sessionId", () => {
    expect(parseClientMessage('{"type":"get_history"}')).toBeNull();
  });

  it("parses list_recent_sessions message", () => {
    const msg = parseClientMessage('{"type":"list_recent_sessions"}');
    expect(msg).toEqual({ type: "list_recent_sessions" });
  });

  it("parses list_recent_sessions with offset and projectPath", () => {
    const msg = parseClientMessage(
      '{"type":"list_recent_sessions","limit":10,"offset":20,"projectPath":"/tmp/project"}',
    );
    expect(msg).toEqual({
      type: "list_recent_sessions",
      limit: 10,
      offset: 20,
      projectPath: "/tmp/project",
    });
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
      '{"type":"resume_session","sessionId":"s3","projectPath":"/p","provider":"codex"}',
    );
    expect(msg).toEqual({
      type: "resume_session",
      sessionId: "s3",
      projectPath: "/p",
      provider: "codex",
    });
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

  it("rejects resume_session with invalid effort", () => {
    expect(
      parseClientMessage(
        '{"type":"resume_session","sessionId":"s3","projectPath":"/p","effort":"xhigh"}',
      ),
    ).toBeNull();
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

  it("parses list_gallery message", () => {
    const msg = parseClientMessage('{"type":"list_gallery"}');
    expect(msg).toEqual({ type: "list_gallery" });
  });

  it("parses list_files message", () => {
    const msg = parseClientMessage('{"type":"list_files","projectPath":"/p"}');
    expect(msg).toEqual({ type: "list_files", projectPath: "/p" });
  });

  it("rejects list_files without projectPath", () => {
    expect(parseClientMessage('{"type":"list_files"}')).toBeNull();
  });

  it("parses interrupt message", () => {
    const msg = parseClientMessage('{"type":"interrupt"}');
    expect(msg).toEqual({ type: "interrupt" });
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

  it("parses approve with updatedInput and clearContext", () => {
    const msg = parseClientMessage(
      '{"type":"approve","id":"tu1","updatedInput":{"plan":"my plan"},"clearContext":true}',
    );
    expect(msg).toEqual({
      type: "approve",
      id: "tu1",
      updatedInput: { plan: "my plan" },
      clearContext: true,
    });
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

  it("parses git_push with forceLease", () => {
    const msg = parseClientMessage(
      '{"type":"git_push","projectPath":"/p","forceLease":true}',
    );
    expect(msg).toEqual({
      type: "git_push",
      projectPath: "/p",
      forceLease: true,
    });
  });

  it("rejects git_push without projectPath", () => {
    expect(parseClientMessage('{"type":"git_push"}')).toBeNull();
  });

  // git_status
  it("parses git_status", () => {
    const msg = parseClientMessage('{"type":"git_status","projectPath":"/p"}');
    expect(msg).toEqual({ type: "git_status", projectPath: "/p" });
  });

  it("rejects git_status without projectPath", () => {
    expect(parseClientMessage('{"type":"git_status"}')).toBeNull();
  });

  // git_branches
  it("parses git_branches", () => {
    const msg = parseClientMessage(
      '{"type":"git_branches","projectPath":"/p"}',
    );
    expect(msg).toEqual({ type: "git_branches", projectPath: "/p" });
  });

  it("parses git_branches with query", () => {
    const msg = parseClientMessage(
      '{"type":"git_branches","projectPath":"/p","query":"feat"}',
    );
    expect(msg).toEqual({
      type: "git_branches",
      projectPath: "/p",
      query: "feat",
    });
  });

  it("rejects git_branches without projectPath", () => {
    expect(parseClientMessage('{"type":"git_branches"}')).toBeNull();
  });

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
