import { describe, expect, it } from "vitest";
import {
  deriveCodexPermissionsMode,
  withDerivedCodexPermissionsMode,
} from "./codex-permissions.js";

describe("deriveCodexPermissionsMode", () => {
  it.each([
    ["default", "on-request", "user", "workspace-write"],
    ["default", "on-request", undefined, "workspace-write"],
    ["autoReview", "on-request", "auto_review", "workspace-write"],
    ["autoReview", "on-request", "guardian_subagent", "workspace-write"],
    ["fullAccess", "never", "user", "danger-full-access"],
  ] as const)(
    "derives %s from a complete preset tuple",
    (expected, approvalPolicy, approvalsReviewer, sandboxMode) => {
      expect(deriveCodexPermissionsMode({
        approvalPolicy,
        approvalsReviewer,
        sandboxMode,
      })).toBe(expected);
    },
  );

  it.each([
    ["on-request", "user", "read-only"],
    ["never", "user", "workspace-write"],
    ["on-request", "future-reviewer", "workspace-write"],
    ["future-policy", "user", "workspace-write"],
    ["on-request", "user", "future-sandbox"],
  ] as const)(
    "classifies a complete non-preset tuple as custom",
    (approvalPolicy, approvalsReviewer, sandboxMode) => {
      expect(deriveCodexPermissionsMode({
        approvalPolicy,
        approvalsReviewer,
        sandboxMode,
      })).toBe("custom");
    },
  );

  it.each([
    { approvalPolicy: "on-request" },
    { sandboxMode: "workspace-write" },
    { approvalsReviewer: "auto_review" },
    { model: "gpt" },
  ])("does not invent a mode from partial or unrelated metadata", (settings) => {
    expect(deriveCodexPermissionsMode(settings)).toBeUndefined();
  });

  it("prioritizes recognized explicit modes and contains unknown modes", () => {
    expect(deriveCodexPermissionsMode({
      codexPermissionsMode: "fullAccess",
      approvalPolicy: "on-request",
      sandboxMode: "read-only",
    })).toBe("fullAccess");
    expect(deriveCodexPermissionsMode({
      codexPermissionsMode: "future-mode",
      approvalPolicy: "never",
      sandboxMode: "danger-full-access",
    })).toBe("custom");
  });

  it("adds derived output without mutating raw settings", () => {
    const raw = {
      approvalPolicy: "on-request",
      sandboxMode: "read-only",
    };
    expect(withDerivedCodexPermissionsMode(raw)).toEqual({
      ...raw,
      codexPermissionsMode: "custom",
    });
    expect(raw).not.toHaveProperty("codexPermissionsMode");
  });
});
