import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  codexCliJoinTarget,
  readCodexAppServerMode,
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
      command:
        "codex resume thr_123 --remote ws://127.0.0.1:8767 --remote-auth-token-env CODEX_REMOTE_TOKEN",
      remoteAuthTokenEnv: "CODEX_REMOTE_TOKEN",
    });
  });

  it("uses a validated managed CLI token environment name without a token value", () => {
    const token = randomUUID();
    const tokenFilePath = "/tmp/not-a-join-token-file";
    const target = codexCliJoinTarget("thr_123", {
      BRIDGE_CODEX_APP_SERVER_MODE: "managed",
      BRIDGE_CODEX_SHARED_APP_SERVER_URL: "ws://127.0.0.1:8767",
      BRIDGE_CODEX_CLI_AUTH_TOKEN_ENV: "BRIDGE_JOIN_TOKEN",
      BRIDGE_JOIN_TOKEN: token,
    });

    expect(target).toEqual({
      url: "ws://127.0.0.1:8767",
      command:
        "codex resume thr_123 --remote ws://127.0.0.1:8767 --remote-auth-token-env BRIDGE_JOIN_TOKEN",
      remoteAuthTokenEnv: "BRIDGE_JOIN_TOKEN",
    });
    expect(target?.command).not.toContain(token);
    expect(target?.command).not.toContain(tokenFilePath);
  });

  it("requires validated nonempty external token indirection", () => {
    const token = randomUUID();
    const base = {
      BRIDGE_CODEX_APP_SERVER_MODE: "external",
      BRIDGE_CODEX_SHARED_APP_SERVER_URL: "ws://127.0.0.1:8767",
    };

    expect(() => codexCliJoinTarget("thr_123", base)).toThrow(
      "BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV",
    );
    let invalidNameError: Error | undefined;
    try {
      codexCliJoinTarget("thr_123", {
        ...base,
        BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV: "invalid-name",
        "invalid-name": token,
      });
    } catch (error) {
      invalidNameError = error as Error;
    }
    expect(invalidNameError?.message).toContain("environment-variable name");
    expect(invalidNameError?.message).not.toContain(token);
  });

  it("uses only the external token environment name in a join command", () => {
    const token = randomUUID();
    const tokenFilePath = "/tmp/not-a-join-token-file";
    const target = codexCliJoinTarget("thr_123", {
      BRIDGE_CODEX_APP_SERVER_MODE: "external",
      BRIDGE_CODEX_SHARED_APP_SERVER_URL: "ws://127.0.0.1:8767",
      BRIDGE_CODEX_EXTERNAL_AUTH_TOKEN_ENV: "BRIDGE_EXTERNAL_TOKEN",
      BRIDGE_EXTERNAL_TOKEN: token,
    });

    expect(target).toEqual({
      url: "ws://127.0.0.1:8767",
      command:
        "codex resume thr_123 --remote ws://127.0.0.1:8767 --remote-auth-token-env BRIDGE_EXTERNAL_TOKEN",
      remoteAuthTokenEnv: "BRIDGE_EXTERNAL_TOKEN",
    });
    expect(target?.command).not.toContain(token);
    expect(target?.command).not.toContain(tokenFilePath);
  });

  it("does not expose a join target for private mode", () => {
    expect(codexCliJoinTarget("thr_123", {})).toBeUndefined();
  });

  it("uses the managed default URL when no explicit URL is set", () => {
    expect(
      resolveCodexSharedAppServerUrl("managed", { BRIDGE_PORT: "8767" }),
    ).toBe("ws://127.0.0.1:8768");
  });

  it("keeps isolated mode private even when shared URL variables are set", () => {
    const env = {
      BRIDGE_CODEX_APP_SERVER_MODE: "isolated",
      BRIDGE_CODEX_SHARED_APP_SERVER_URL: "ws://shared.example:18700",
    };

    expect(readCodexAppServerMode(env)).toBe("isolated");
    expect(resolveCodexSharedAppServerUrl("isolated", env)).toBeUndefined();
    expect(codexCliJoinTarget("thr_123", env)).toBeUndefined();
  });
});
