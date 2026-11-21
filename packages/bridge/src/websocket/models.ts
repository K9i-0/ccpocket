import {
  SdkProcess,
  listAvailableClaudeModels,
  type ClaudeModelMetadata,
} from "../sdk-process.js";
import {
  CodexProcess,
  type CodexModelMetadata,
  type CodexStartOptions,
} from "../codex-process.js";
import {
  normalizeCodexServiceTierForClient,
  isCodexServiceTierSupported,
} from "../codex-service-tier.js";
import { saveCodexSessionProfile } from "../sessions-index.js";
import {
  FALLBACK_CLAUDE_MODEL_OPTIONS,
  FALLBACK_CLAUDE_MODELS,
  FALLBACK_CLAUDE_MODEL_EFFORTS,
  FALLBACK_CODEX_MODELS,
  fallbackCodexReasoningEfforts,
  fallbackCodexServiceTiers,
} from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";

export async function loadClaudeModels(
  server: BridgeWebSocketServer,
  projectPath?: string,
): Promise<ClaudeModelMetadata[]> {
  const activeProcess = getActiveClaudeProcess(server);
  if (activeProcess) {
    const models = await activeProcess.listAvailableModels();
    if (models.length > 0) return models;
  }
  if (process.env.NODE_ENV === "test") return [];
  return listAvailableClaudeModels(projectPath);
}

export function applyFallbackClaudeModels(server: BridgeWebSocketServer): void {
  server.claudeModels = FALLBACK_CLAUDE_MODELS;
  server.claudeModelOptions = FALLBACK_CLAUDE_MODEL_OPTIONS;
  server.claudeModelEfforts = { ...FALLBACK_CLAUDE_MODEL_EFFORTS };
}

export async function readCodexModels(
  codexProcess: CodexProcess,
): Promise<CodexModelMetadata[]> {
  const modelSource = codexProcess as CodexProcess & {
    listAvailableModelMetadata?: () => Promise<CodexModelMetadata[]>;
    listAvailableModels?: () => Promise<string[]>;
  };
  if (typeof modelSource.listAvailableModelMetadata === "function") {
    return modelSource.listAvailableModelMetadata();
  }
  const models = typeof modelSource.listAvailableModels === "function"
    ? await modelSource.listAvailableModels()
    : [];
  return models.map((model) => ({
    model,
    supportedReasoningEfforts: fallbackCodexReasoningEfforts(model),
    supportedServiceTiers: fallbackCodexServiceTiers(model),
  }));
}

export async function readCodexAutoReviewDisabled(
  codexProcess: CodexProcess,
): Promise<boolean> {
  const requirementsSource = codexProcess as CodexProcess & {
    readConfigRequirements?: () => Promise<{
      autoReviewDisabled: boolean;
    }>;
  };
  if (typeof requirementsSource.readConfigRequirements !== "function") {
    return false;
  }
  return (await requirementsSource.readConfigRequirements())
    .autoReviewDisabled;
}

/** Validate candidates only. Codex still enforces account entitlement. */
export function codexServiceTierError(
  server: BridgeWebSocketServer,
  model: string | undefined,
  value: string | undefined,
): string | undefined {
  if (value === undefined) return undefined;
  // A profile or a resumed thread may supply the model. CodexProcess validates
  // its resolved model/tier before emitting init or accepting the first turn.
  if (model === undefined) return undefined;
  const tier = normalizeCodexServiceTierForClient(value);
  // Standard/Fast are legacy settings; older clients normalize Fast after
  // changing models. Strict catalog validation applies to extended tiers.
  if (tier === "standard" || tier === "fast") return undefined;
  const supported = server.codexModelServiceTiers[model ?? ""];
  if (isCodexServiceTierSupported(tier, supported ?? [])) return undefined;
  return `Codex speed "${value}" is not available for model "${model ?? "unknown"}". Choose a supported speed.`;
}

export function applyFallbackCodexModels(server: BridgeWebSocketServer): void {
  server.codexModelServiceTierMetadata = {};
  server.codexModels = FALLBACK_CODEX_MODELS;
  server.codexModelReasoningEfforts = Object.fromEntries(
    FALLBACK_CODEX_MODELS.map((model) => [
      model,
      fallbackCodexReasoningEfforts(model),
    ]),
  );
  server.codexModelServiceTiers = Object.fromEntries(
    FALLBACK_CODEX_MODELS.map((model) => [
      model,
      fallbackCodexServiceTiers(model),
    ]),
  );
}

export async function resolveCodexResumeProfile(
  server: BridgeWebSocketServer,
  requestedProfile: string,
  threadId: string,
  projectPath?: string,
): Promise<string | undefined> {
  const snapshot = await server.loadCodexProfiles(projectPath);
  server.codexProfiles = snapshot.profiles;
  server.defaultCodexProfile = snapshot.defaultProfile;
  if (snapshot.profiles.includes(requestedProfile)) {
    return requestedProfile;
  }

  const fallbackProfile =
    snapshot.defaultProfile &&
    snapshot.profiles.includes(snapshot.defaultProfile)
      ? snapshot.defaultProfile
      : undefined;
  console.warn(
    `[ws] Codex profile not found on resume: ${requestedProfile}; ` +
      (fallbackProfile
        ? `falling back to default profile: ${fallbackProfile}`
        : "falling back to Codex config default"),
  );
  saveCodexSessionProfile(threadId, fallbackProfile ?? null).catch((err) => {
    console.warn(`[ws] Failed to update Codex session profile cache: ${err}`);
  });
  return fallbackProfile;
}

export function withCodexAutoReviewPolicy(
  server: BridgeWebSocketServer,
  options: CodexStartOptions,
): CodexStartOptions {
  const disableAutoReview = server.codexAutoReviewDisabled;
  return {
    ...options,
    ...(disableAutoReview ? { approvalsReviewer: "user" as const } : {}),
    ...(disableAutoReview && options.codexPermissionsMode === "autoReview"
      ? { codexPermissionsMode: "default" as const }
      : {}),
    autoReviewDisabledByPolicy: server.codexAutoReviewPolicyLoaded
      ? disableAutoReview
      : null,
  };
}

export function getActiveClaudeProcess(server: BridgeWebSocketServer): SdkProcess | null {
  const summary = server.sessionManager
    .list()
    .find((session) => session.provider === "claude");
  if (!summary) return null;
  const session = server.sessionManager.get(summary.id);
  return session?.provider === "claude"
    ? (session.process as SdkProcess)
    : null;
}
