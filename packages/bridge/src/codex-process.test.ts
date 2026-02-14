import { beforeEach, describe, expect, it, vi } from "vitest";

const { startThreadMock, resumeThreadMock } = vi.hoisted(() => ({
  startThreadMock: vi.fn(),
  resumeThreadMock: vi.fn(),
}));

vi.mock("@openai/codex-sdk", () => {
  const fakeThread = {
    runStreamed: vi.fn(async () => ({
      events: (async function* () {
        // no events
      })(),
    })),
  };

  class MockCodex {
    startThread = startThreadMock.mockReturnValue(fakeThread);
    resumeThread = resumeThreadMock.mockReturnValue(fakeThread);
  }

  return {
    Codex: MockCodex,
  };
});

import { CodexProcess } from "./codex-process.js";

describe("CodexProcess.start", () => {
  beforeEach(() => {
    startThreadMock.mockReset();
    resumeThreadMock.mockReset();
  });

  it("uses startThread when threadId is not provided", () => {
    const proc = new CodexProcess();
    proc.start("/tmp/project-a", {
      sandboxMode: "workspace-write",
      approvalPolicy: "on-request",
      model: "gpt-5.3-codex",
      modelReasoningEffort: "medium",
      networkAccessEnabled: true,
      webSearchMode: "cached",
    });

    expect(startThreadMock).toHaveBeenCalledTimes(1);
    expect(resumeThreadMock).not.toHaveBeenCalled();
    expect(startThreadMock).toHaveBeenCalledWith(
      expect.objectContaining({
        workingDirectory: "/tmp/project-a",
        sandboxMode: "workspace-write",
        approvalPolicy: "on-request",
        model: "gpt-5.3-codex",
        modelReasoningEffort: "medium",
        networkAccessEnabled: true,
        webSearchMode: "cached",
      }),
    );

    proc.stop();
  });

  it("uses resumeThread when threadId is provided", () => {
    const proc = new CodexProcess();
    proc.start("/tmp/project-b", {
      threadId: "thread-123",
      sandboxMode: "danger-full-access",
      approvalPolicy: "never",
    });

    expect(resumeThreadMock).toHaveBeenCalledTimes(1);
    expect(startThreadMock).not.toHaveBeenCalled();
    expect(resumeThreadMock).toHaveBeenCalledWith(
      "thread-123",
      expect.objectContaining({
        workingDirectory: "/tmp/project-b",
        sandboxMode: "danger-full-access",
        approvalPolicy: "never",
      }),
    );

    proc.stop();
  });
});
