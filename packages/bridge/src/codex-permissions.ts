import type { CodexPermissionsMode } from "./parser.js";

export interface CodexPermissionSettings {
  codexPermissionsMode?: string;
  approvalPolicy?: string;
  approvalsReviewer?: string;
  sandboxMode?: string;
}

export function normalizeCodexPermissionsMode(
  value?: string,
): CodexPermissionsMode | undefined {
  switch (value) {
    case "default":
    case "autoReview":
    case "fullAccess":
    case "custom":
      return value;
    default:
      return undefined;
  }
}

export function deriveCodexPermissionsMode(
  settings?: CodexPermissionSettings,
): CodexPermissionsMode | undefined {
  if (!settings) return undefined;
  const explicit = normalizeCodexPermissionsMode(
    settings.codexPermissionsMode,
  );
  if (explicit) return explicit;
  if (settings.codexPermissionsMode !== undefined) return "custom";

  if (
    settings.approvalPolicy === undefined ||
    settings.sandboxMode === undefined
  ) {
    return undefined;
  }

  const sandboxMode = switchCodexSandboxMode(settings.sandboxMode);
  if (
    settings.approvalPolicy === "never" &&
    sandboxMode === "danger-full-access"
  ) {
    return "fullAccess";
  }
  if (
    settings.approvalPolicy === "on-request" &&
    sandboxMode === "workspace-write"
  ) {
    if (
      settings.approvalsReviewer === "auto_review" ||
      settings.approvalsReviewer === "guardian_subagent"
    ) {
      return "autoReview";
    }
    if (
      settings.approvalsReviewer === undefined ||
      settings.approvalsReviewer === "user"
    ) {
      return "default";
    }
  }
  return "custom";
}

function switchCodexSandboxMode(
  value?: string,
): "danger-full-access" | "workspace-write" | "read-only" | undefined {
  switch (value) {
    case "danger-full-access":
    case "off":
      return "danger-full-access";
    case "workspace-write":
    case "on":
      return "workspace-write";
    case "read-only":
      return "read-only";
    default:
      return undefined;
  }
}

export function withDerivedCodexPermissionsMode<T extends CodexPermissionSettings>(
  settings: T | undefined,
): T | undefined {
  if (!settings) return undefined;
  const mode = deriveCodexPermissionsMode(settings);
  return mode ? { ...settings, codexPermissionsMode: mode } : settings;
}
