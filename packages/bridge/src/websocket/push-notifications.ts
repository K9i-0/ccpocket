import { createHash } from "node:crypto";
import { AntigravityProcess } from "../antigravity-process.js";
import { isAgentBackgroundTask, type ServerMessage } from "../parser.js";
import { type PushLocale, t } from "../push-i18n.js";
import type { ResultServerMessage } from "./shared.js";
import { workspaceForRuntimeSession } from "./workspaces.js";
import type { BridgeWebSocketServer } from "../websocket.js";

/** Resolve a user-facing Project label, falling back to the cwd basename. */
export function projectLabel(
  server: BridgeWebSocketServer,
  sessionId: string,
): string {
  const session = server.sessionManager.get(sessionId);
  if (!session?.projectPath) return "";
  const workspace = workspaceForRuntimeSession(server, session);
  if (workspace?.projectName) return workspace.projectName;
  const parts = session.projectPath.replace(/\/+$/, "").split("/");
  return parts[parts.length - 1] || "";
}

export function beginPushTokenOperation(
  server: BridgeWebSocketServer,
  token: string,
): number {
  const generation = ++server.nextPushTokenGeneration;
  server.pushTokenGeneration.set(token, generation);
  // Local delivery is disabled synchronously while the relay operation is
  // pending. The app stays on local fallback until a successful ACK.
  server.tokenLocales.delete(token);
  server.tokenPrivacyMode.delete(token);
  return generation;
}

export function enqueuePushTokenOperation(
  server: BridgeWebSocketServer,
  token: string,
  operation: () => Promise<void>,
): Promise<void> {
  const previous = server.pushTokenOperations.get(token);
  const pending = (previous?.catch(() => {}) ?? Promise.resolve()).then(
    operation,
  );
  server.pushTokenOperations.set(token, pending);
  const cleanup = () => {
    if (server.pushTokenOperations.get(token) === pending) {
      server.pushTokenOperations.delete(token);
    }
  };
  void pending.then(cleanup, cleanup);
  return pending;
}

export function isCurrentPushTokenOperation(
  server: BridgeWebSocketServer,
  token: string,
  generation: number,
): boolean {
  return server.pushTokenGeneration.get(token) === generation;
}

/** Get unique locales from tokens acknowledged by the push relay. */
export function getRegisteredLocales(server: BridgeWebSocketServer): PushLocale[] {
  const locales = new Set(server.tokenLocales.values());
  return [...locales];
}

/** Hashes of relay tokens that are currently safe for remote delivery. */
export function getActivePushTokenHashes(
  server: BridgeWebSocketServer,
  locale: PushLocale,
): string[] {
  return [...server.tokenLocales]
    .filter(([, tokenLocale]) => tokenLocale === locale)
    .map(([token]) => createHash("sha256").update(token).digest("hex"));
}

/** Whether any registered token has privacy mode enabled (conservative: privacy wins). */
export function isPrivacyMode(server: BridgeWebSocketServer): boolean {
  for (const privacy of server.tokenPrivacyMode.values()) {
    if (privacy) return true;
  }
  return false;
}

/** Get a display label for push notification title: "name (project)" or just project. */
export function sessionLabel(
  server: BridgeWebSocketServer,
  sessionId: string,
): string {
  const session = server.sessionManager.get(sessionId);
  const project = projectLabel(server, sessionId);
  if (session?.name) {
    return project ? `${session.name} (${project})` : session.name;
  }
  return project;
}

export function maybeSendPushNotification(
  server: BridgeWebSocketServer,
  sessionId: string,
  msg: ServerMessage,
): void {
  if (!server.pushRelay.isConfigured) return;
  if (server.tokenLocales.size === 0) return;

  const privacy = isPrivacyMode(server);
  const label = privacy ? "" : sessionLabel(server, sessionId);

  if (msg.type === "permission_request") {
    const seen =
      server.notifiedPermissionToolUses.get(sessionId) ?? new Set<string>();
    if (seen.has(msg.toolUseId)) return;
    seen.add(msg.toolUseId);
    server.notifiedPermissionToolUses.set(sessionId, seen);

    const isAskUserQuestion = msg.toolName === "AskUserQuestion";
    const isExitPlanMode = msg.toolName === "ExitPlanMode";
    const eventType = isAskUserQuestion
      ? "ask_user_question"
      : "approval_required";

    // Extract question text for AskUserQuestion (standard mode only)
    let questionText: string | undefined;
    if (!privacy && isAskUserQuestion) {
      const questions = msg.input?.questions;
      const firstQuestion =
        Array.isArray(questions) && questions.length > 0
          ? (questions[0] as Record<string, unknown>)?.question
          : undefined;
      if (typeof firstQuestion === "string" && firstQuestion.length > 0) {
        questionText = firstQuestion.slice(0, 120);
      }
    }

    const data: Record<string, string> = {
      sessionId,
      provider: server.sessionManager.get(sessionId)?.provider ?? "claude",
      toolUseId: msg.toolUseId,
      toolName: msg.toolName,
    };

    for (const locale of getRegisteredLocales(server)) {
      let title: string;
      let body: string;

      if (isExitPlanMode) {
        const titleKey = "plan_ready_title";
        title = label
          ? `${t(locale, titleKey)} - ${label}`
          : t(locale, titleKey);
        body = t(locale, "plan_ready_body");
      } else if (isAskUserQuestion) {
        const titleKey = "ask_title";
        title = label
          ? `${t(locale, titleKey)} - ${label}`
          : t(locale, titleKey);
        body = privacy
          ? t(locale, "ask_body_private")
          : (questionText ?? t(locale, "ask_default_body"));
      } else {
        const titleKey = "approval_title";
        title = label
          ? `${t(locale, titleKey)} - ${label}`
          : t(locale, titleKey);
        body = privacy
          ? t(locale, "approval_body_private")
          : t(locale, "approval_body", { toolName: msg.toolName });
      }

      void server.pushRelay
        .notify({
          eventType,
          title,
          body,
          locale,
          tokenHashes: getActivePushTokenHashes(server, locale),
          data,
        })
        .catch((err) => {
          const detail = err instanceof Error ? err.message : String(err);
          console.warn(
            `[ws] Failed to send push notification (${eventType}, ${locale}): ${detail}`,
          );
        });
    }
    return;
  }

  if ((msg.type === "result" || msg.type === "goal_state") && msg.notification) {
    if (msg.notification === "none") return;
    const kind = msg.notification;
    const icon = kind === "goal_complete" ? "✅"
      : kind === "goal_progress" ? "💬"
      : kind === "goal_blocked" ? "⚠️" : "⏸";
    for (const locale of getRegisteredLocales(server)) {
      const copy = t(locale, kind);
      void server.pushRelay.notify({
        eventType: kind,
        title: `${icon} ${copy}${label ? ` - ${label}` : ""}`,
        body: copy,
        locale,
        tokenHashes: getActivePushTokenHashes(server, locale),
        data: { sessionId, provider: "codex" },
      }).catch((err) => {
        console.warn(`[ws] Failed to send ${kind}: ${String(err)}`);
      });
    }
    return;
  }

  if (msg.type === "status" || msg.type === "background_tasks") {
    server.completionGate.update(sessionId);
    return;
  }

  if (msg.type !== "result") return;
  if (msg.subtype === "stopped") {
    server.completionGate.discard(sessionId);
    return;
  }
  if (msg.subtype !== "success" && msg.subtype !== "error") return;
  if (msg.subtype === "error") {
    server.completionGate.discard(sessionId);
  } else if (
    server.completionGate.hold(
      sessionId,
      msg,
      keepsWorkingInBackground(server, sessionId),
    )
  ) {
    return;
  }
  sendCompletionPush(server, sessionId, msg);
}

/**
 * Claude keeps working after a result while background agents are live: it
 * starts a follow-up turn when they report back. Shells and monitors may
 * run indefinitely (dev servers), so they do not delay completion. Codex
 * never starts a follow-up turn, so its background work is ignored too.
 * Antigravity carries on by itself when a timer fires or a background
 * command ends; the process says for how long that is still expected.
 */
export function keepsWorkingInBackground(
  server: BridgeWebSocketServer,
  sessionId: string,
): boolean {
  const session = server.sessionManager.get(sessionId);
  if (session?.process instanceof AntigravityProcess) {
    return session.process.expectsFollowUp;
  }
  return (
    session?.provider === "claude" &&
    !!session.backgroundTasks?.some(isAgentBackgroundTask)
  );
}

export function sendCompletionPush(
  server: BridgeWebSocketServer,
  sessionId: string,
  msg: ResultServerMessage,
): void {
  if (!server.pushRelay.isConfigured) return;
  if (server.tokenLocales.size === 0) return;
  const privacy = isPrivacyMode(server);
  const label = privacy ? "" : sessionLabel(server, sessionId);
  const isSuccess = msg.subtype === "success";
  const eventType = isSuccess ? "session_completed" : "session_failed";

  const pieces: string[] = [];
  if (isSuccess) {
    if (msg.duration != null) pieces.push(`${msg.duration.toFixed(1)}s`);
    if (msg.cost != null) pieces.push(`$${msg.cost.toFixed(4)}`);
  }
  const stats = pieces.length > 0 ? ` (${pieces.join(", ")})` : "";

  const data: Record<string, string> = {
    sessionId,
    provider: server.sessionManager.get(sessionId)?.provider ?? "claude",
    subtype: msg.subtype,
  };
  if (msg.stopReason) data.stopReason = msg.stopReason;
  if (msg.sessionId) data.providerSessionId = msg.sessionId;

  for (const locale of getRegisteredLocales(server)) {
    let title: string;
    if (privacy) {
      title = isSuccess
        ? t(locale, "task_completed")
        : t(locale, "error_occurred");
    } else {
      title = label
        ? isSuccess
          ? `✅ ${label}`
          : `❌ ${label}`
        : isSuccess
          ? t(locale, "task_completed")
          : t(locale, "error_occurred");
    }

    let body: string;
    if (privacy) {
      const privateBody = isSuccess
        ? t(locale, "result_success_body_private")
        : t(locale, "result_error_body_private");
      body = isSuccess ? `${privateBody}${stats}` : privateBody;
    } else if (isSuccess) {
      body = msg.result
        ? `${msg.result.slice(0, 120)}${stats}`
        : `${t(locale, "session_completed")}${stats}`;
    } else {
      body = msg.error
        ? msg.error.slice(0, 120)
        : t(locale, "session_failed");
    }

    void server.pushRelay
      .notify({
        eventType,
        title,
        body,
        locale,
        tokenHashes: getActivePushTokenHashes(server, locale),
        data,
      })
      .catch((err) => {
        const detail = err instanceof Error ? err.message : String(err);
        console.warn(
          `[ws] Failed to send push notification (${eventType}, ${locale}): ${detail}`,
        );
      });
  }
}
