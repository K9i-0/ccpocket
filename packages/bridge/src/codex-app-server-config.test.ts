import { describe, expect, it } from "vitest";
import {
  codexCliJoinTarget,
  resolveCodexSharedAppServerUrl,
} from "./codex-app-server-config.js";

describe("codex app-server config", () => {
  it("builds a session-specific Codex CLI join command in managed mode", () => {
    const env = {
      BRIDGE_CODEX_APP_SERVER_MODE: "managed",
      BRIDGE_CODEX_SHARED_APP_SERVER_URL: "ws://127.0.0.1:8767",
    };

    expect(codexCliJoinTarget("thr_123", env)).toEqual({
      url: "ws://127.0.0.1:8767",
      command: "codex resume thr_123 --remote ws://127.0.0.1:8767",
    });
  });

  it("does not expose a join target for private mode", () => {
    expect(codexCliJoinTarget("thr_123", {})).toBeUndefined();
  });

  it("uses the managed default URL when no explicit URL is set", () => {
    expect(
      resolveCodexSharedAppServerUrl("managed", { BRIDGE_PORT: "8767" }),
    ).toBe("ws://127.0.0.1:8768");
  });
});
