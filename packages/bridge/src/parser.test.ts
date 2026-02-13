import { describe, it, expect } from "vitest";
import {
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
  it("parses start message", () => {
    const msg = parseClientMessage('{"type":"start","projectPath":"/tmp/foo"}');
    expect(msg).toEqual({ type: "start", projectPath: "/tmp/foo" });
  });

  it("parses start with optional fields", () => {
    const msg = parseClientMessage('{"type":"start","projectPath":"/p","sessionId":"s1","continue":true,"permissionMode":"acceptEdits"}');
    expect(msg).toEqual({
      type: "start",
      projectPath: "/p",
      sessionId: "s1",
      continue: true,
      permissionMode: "acceptEdits",
    });
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
      parseClientMessage(
        '{"type":"set_permission_mode","mode":"unsupported"}',
      ),
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
    const msg = parseClientMessage('{"type":"reject","id":"tu3","message":"no"}');
    expect(msg).toEqual({ type: "reject", id: "tu3", message: "no" });
  });

  it("rejects reject without id", () => {
    expect(parseClientMessage('{"type":"reject"}')).toBeNull();
  });

  it("parses answer message", () => {
    const msg = parseClientMessage('{"type":"answer","toolUseId":"tu4","result":"yes"}');
    expect(msg).toEqual({ type: "answer", toolUseId: "tu4", result: "yes" });
  });

  it("rejects answer without toolUseId", () => {
    expect(parseClientMessage('{"type":"answer","result":"yes"}')).toBeNull();
  });

  it("rejects answer without result", () => {
    expect(parseClientMessage('{"type":"answer","toolUseId":"tu4"}')).toBeNull();
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
    const msg = parseClientMessage('{"type":"list_recent_sessions","limit":10,"offset":20,"projectPath":"/tmp/project"}');
    expect(msg).toEqual({
      type: "list_recent_sessions",
      limit: 10,
      offset: 20,
      projectPath: "/tmp/project",
    });
  });

  it("parses resume_session message", () => {
    const msg = parseClientMessage('{"type":"resume_session","sessionId":"s3","projectPath":"/p"}');
    expect(msg).toEqual({ type: "resume_session", sessionId: "s3", projectPath: "/p" });
  });

  it("parses resume_session with provider", () => {
    const msg = parseClientMessage('{"type":"resume_session","sessionId":"s3","projectPath":"/p","provider":"codex"}');
    expect(msg).toEqual({ type: "resume_session", sessionId: "s3", projectPath: "/p", provider: "codex" });
  });

  it("rejects resume_session without sessionId", () => {
    expect(parseClientMessage('{"type":"resume_session","projectPath":"/p"}')).toBeNull();
  });

  it("rejects resume_session without projectPath", () => {
    expect(parseClientMessage('{"type":"resume_session","sessionId":"s3"}')).toBeNull();
  });

  it("rejects resume_session with invalid provider", () => {
    expect(parseClientMessage('{"type":"resume_session","sessionId":"s3","projectPath":"/p","provider":"foo"}')).toBeNull();
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

  it("parses remove_project_history message", () => {
    const msg = parseClientMessage('{"type":"remove_project_history","projectPath":"/p"}');
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
      parseClientMessage(
        '{"type":"rewind","sessionId":"s1","mode":"both"}',
      ),
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
});
