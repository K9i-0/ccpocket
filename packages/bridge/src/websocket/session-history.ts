import { WebSocket } from "ws";
import {
  MAX_HISTORY_PER_SESSION,
  type HistoryEntry,
  type SessionInfo,
} from "../session.js";
import { CodexProcess } from "../codex-process.js";
import { readAntigravityTranscriptFile } from "../antigravity-sessions.js";
import type { AssistantContent, ServerMessage } from "../parser.js";
import {
  getCodexSessionHistory,
  getSessionHistory,
  codexThreadToSessionHistory,
  type SessionHistoryMessage,
  extractMessageImages,
} from "../sessions-index.js";
import type { ImageRef } from "../image-store.js";
import {
  assistantTextBlocks,
  hasMarkdownImages,
  type AssistantImageRef,
} from "../markdown-images.js";
import { countCodexHistoryUserTurns } from "./shared.js";
import type { BridgeWebSocketServer } from "../websocket.js";
import {
  sendCodexCurrentSettings,
  sendBackgroundTasksState,
  sendCodexGoalState,
} from "./session-state.js";

export async function splitPastHistoryMessages(
  server: BridgeWebSocketServer,
  session: SessionInfo,
): Promise<{ pastMessages: unknown[]; historyMessages: ServerMessage[] }> {
  return server.preparePastHistoryMessages(session, session.pastMessages ?? []);
}

/**
 * Full provider transcript for the read-only transcript screen. Unlike the
 * live history window it is not trimmed, and it keeps compaction markers.
 */
export async function sessionTranscriptMessages(
  server: BridgeWebSocketServer,
  session: SessionInfo,
): Promise<SessionHistoryMessage[]> {
  if (session.provider === "codex") {
    const threadId = codexThreadIdForSession(session);
    if (!threadId) return [];
    if (session.codexInitialHistoryPending) {
      return (session.pastMessages ?? []) as SessionHistoryMessage[];
    }
    return getCodexThreadHistoryFromRpc(
        server,
      threadId,
      session.projectPath,
      session.process instanceof CodexProcess ? session.process : undefined,
    );
  }
  if (session.provider === "antigravity") {
    if (session.antigravityTranscript && session.antigravityTranscript.length > 0) {
      return session.antigravityTranscript;
    }
    if (!session.claudeSessionId) return [];
    return readAntigravityTranscriptFile(session.claudeSessionId);
  }
  if (!session.claudeSessionId) return [];
  return getSessionHistory(session.claudeSessionId);
}

export function codexThreadIdForSession(session: SessionInfo): string | undefined {
  if (session.provider !== "codex") return undefined;
  if (session.claudeSessionId) return session.claudeSessionId;
  if (session.process instanceof CodexProcess) {
    return session.process.sessionId ?? undefined;
  }
  return undefined;
}

export function applyCodexCanonicalHistoryBaseline(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  history: SessionHistoryMessage[],
  canonicalEntries: HistoryEntry[],
): void {
  const orderedRevision = session.codexOrderedHistoryRevision ?? 0;
  const liveEntries: HistoryEntry[] = [
    ...(session.codexOrderedHistoryEntries ?? []),
    ...session.historyEntries.filter((entry) => entry.seq > orderedRevision),
  ].map((entry) => ({
    seq: entry.seq,
    message: entry.message,
  }));
  const latestUserInput = session.codexLatestUserInput;
  const latestUserKeys = latestUserInput
    ? server.codexHistoryMessageIdentityKeys(latestUserInput)
    : [];
  if (
    latestUserInput &&
    !liveEntries.some(
      (entry) =>
        entry.message === latestUserInput ||
        (entry.message.type === "user_input" &&
          server.codexHistoryMessageIdentityKeys(entry.message).some((key) =>
            latestUserKeys.includes(key),
          )),
    )
  ) {
    const historySeq = (latestUserInput as Record<string, unknown>)
      .historySeq;
    liveEntries.unshift({
      seq: typeof historySeq === "number" ? historySeq : 0,
      message: latestUserInput,
    });
  }
  const canonicalUserUuids = new Set<string>();
  for (const entry of canonicalEntries) {
    const message = entry.message;
    if (message.type === "user_input" && message.userMessageUuid) {
      canonicalUserUuids.add(message.userMessageUuid);
    }
  }

  seedCodexCanonicalUserTurnUuidMap(session, history);

  const merged: Array<{ message: ServerMessage; retained: boolean }> = [];
  let canonicalCursor = 0;
  let hasCanonicalAnchor = false;
  let canMatchAssistantContent = false;
  const appendCanonicalUntil = (endExclusive: number): void => {
    while (canonicalCursor < endExclusive) {
      const message = canonicalEntries[canonicalCursor].message;
      merged.push({ message, retained: false });
      canonicalCursor += 1;
      hasCanonicalAnchor = true;
      if (message.type === "user_input") {
        canMatchAssistantContent = true;
      }
    }
  };

  for (let liveIndex = 0; liveIndex < liveEntries.length; liveIndex++) {
    const liveEntry = liveEntries[liveIndex];
    const matchIndex = findCodexCanonicalMatchIndex(
        server,
      canonicalEntries,
      liveEntry.message,
      canonicalCursor,
      canMatchAssistantContent,
    );
    if (matchIndex === -1) {
      let nextMatchIndex = -1;
      for (
        let nextLiveIndex = liveIndex + 1;
        nextLiveIndex < liveEntries.length;
        nextLiveIndex++
      ) {
        nextMatchIndex = findCodexCanonicalMatchIndex(
            server,
          canonicalEntries,
          liveEntries[nextLiveIndex].message,
          canonicalCursor,
          canMatchAssistantContent,
        );
        if (nextMatchIndex !== -1) break;
      }
      if (nextMatchIndex !== -1) {
        appendCanonicalUntil(nextMatchIndex);
      } else if (!hasCanonicalAnchor) {
        appendCanonicalUntil(canonicalEntries.length);
      }
      if (shouldRetainCodexLiveHistoryMessage(liveEntry.message)) {
        merged.push({ message: liveEntry.message, retained: true });
      }
      continue;
    }

    appendCanonicalUntil(matchIndex + 1);
  }
  appendCanonicalUntil(canonicalEntries.length);

  const retainedMessages: ServerMessage[] = [];
  const retainedEntries: HistoryEntry[] = [];
  let canonicalRevision = 0;
  const previousRevision = session.historyRevision;
  const requiresNewBaselineRevision = previousRevision > 0;
  const targetRevision = requiresNewBaselineRevision
    ? Math.max(merged.length, previousRevision + 1)
    : merged.length;
  const sequenceOffset = targetRevision - merged.length;
  const mergedEntries = merged.map(({ message, retained }, index) => {
    const seq = sequenceOffset + index + 1;
    if (retained) {
      (message as Record<string, unknown>).historySeq = seq;
      retainedMessages.push(message);
      retainedEntries.push({ seq, message });
    } else {
      canonicalRevision = seq;
    }
    return { seq, message };
  });
  canonicalEntries.splice(0, canonicalEntries.length, ...mergedEntries);

  session.codexOrderedHistoryEntries =
    buildCodexOrderedHistoryWindow(mergedEntries);
  session.codexOrderedHistoryRevision = targetRevision;

  session.pastMessages = history;
  session.history = retainedMessages;
  session.historyEntries = retainedEntries;
  session.historyRevision = targetRevision;
  session.codexCanonicalHistoryRevision = canonicalRevision;
  session.codexHistoryResetRevision = targetRevision;
  session.historyLowWatermark =
    retainedEntries[0]?.seq ?? session.historyRevision + 1;

  if (session.pendingCodexUserEchoUuids) {
    for (const uuid of canonicalUserUuids) {
      session.pendingCodexUserEchoUuids.delete(uuid);
    }
    for (const uuid of [...session.pendingCodexUserEchoUuids]) {
      const stillLive = retainedMessages.some(
        (message) =>
          message.type === "user_input" && message.userMessageUuid === uuid,
      );
      if (!stillLive) session.pendingCodexUserEchoUuids.delete(uuid);
    }
  }
}

export function buildCodexOrderedHistoryWindow(
  entries: HistoryEntry[],
): HistoryEntry[] {
  if (entries.length <= MAX_HISTORY_PER_SESSION) {
    return entries.map((entry) => ({
      seq: entry.seq,
      message: entry.message,
    }));
  }

  const tail = entries.slice(-MAX_HISTORY_PER_SESSION);
  if (tail.some((entry) => entry.message.type === "user_input")) {
    return tail;
  }

  let latestUser: HistoryEntry | undefined;
  for (let index = entries.length - 1; index >= 0; index--) {
    if (entries[index].message.type === "user_input") {
      latestUser = entries[index];
      break;
    }
  }
  return latestUser
    ? [latestUser, ...entries.slice(-(MAX_HISTORY_PER_SESSION - 1))]
    : tail;
}

export function findCodexCanonicalMatchIndex(
  server: BridgeWebSocketServer,
  canonicalEntries: HistoryEntry[],
  liveMessage: ServerMessage,
  start: number,
  allowAssistantContentMatch: boolean,
): number {
  const liveKeys = server.codexHistoryMessageIdentityKeys(liveMessage);
  if (liveKeys.length > 0) {
    for (let index = start; index < canonicalEntries.length; index++) {
      const canonicalKeys = server.codexHistoryMessageIdentityKeys(
        canonicalEntries[index].message,
      );
      if (liveKeys.some((key) => canonicalKeys.includes(key))) return index;
    }
  }

  if (!allowAssistantContentMatch || liveMessage.type !== "assistant") {
    return -1;
  }
  const liveContent = historyValueKey(liveMessage.message.content);
  for (let index = start; index < canonicalEntries.length; index++) {
    const canonicalMessage = canonicalEntries[index].message;
    if (canonicalMessage.type === "user_input") break;
    if (
      canonicalMessage.type === "assistant" &&
      historyValueKey(canonicalMessage.message.content) === liveContent
    ) {
      return index;
    }
  }
  return -1;
}

export function seedCodexCanonicalUserTurnUuidMap(
  session: SessionInfo,
  history: SessionHistoryMessage[],
): void {
  if (session.provider !== "codex") return;
  for (const message of history) {
    if (
      message.role !== "user" ||
      !message.rawItemId ||
      !message.uuid
    ) {
      continue;
    }
    session.codexUserTurnUuidByRawId ??= new Map<string, string>();
    session.codexUserTurnUuidByRawId.set(message.rawItemId, message.uuid);
  }
}

export function shouldRetainCodexLiveHistoryMessage(message: ServerMessage): boolean {
  return !(
    message.type === "system" &&
    (message as Record<string, unknown>).subtype === "tip"
  );
}

export function historyValueKey(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

export async function sendCodexCanonicalHistorySnapshot(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): Promise<boolean> {
  try {
    const entries = await server.codexCanonicalHistoryEntries(session);
    if (!entries) return false;
    server.send(ws, {
      type: "history_snapshot",
      sessionId,
      fromSeq: entries[0]?.seq ?? session.historyRevision + 1,
      toSeq: session.historyRevision,
      messages: entries,
      status: session.status,
      reason: "reset",
    } satisfies Extract<ServerMessage, { type: "history_snapshot" }>);
    sendCodexCurrentSettings(server, ws, sessionId, session);
    server.sendQueueState(ws, sessionId, session);
    sendBackgroundTasksState(server, ws, sessionId, session);
    sendCodexGoalState(server, ws, sessionId, session);
    server.sendCachedCommands(ws, sessionId, session);
    return true;
  } catch (err) {
    server.send(ws, {
      type: "error",
      message: `Failed to read Codex thread history: ${
        err instanceof Error ? err.message : String(err)
      }`,
    });
    return true;
  }
}

export async function sendCodexCanonicalLegacyHistory(
  server: BridgeWebSocketServer,
  ws: WebSocket,
  sessionId: string,
  session: SessionInfo,
): Promise<boolean> {
  try {
    const entries = await server.codexCanonicalHistoryEntries(session);
    if (!entries) return false;
    server.send(ws, {
      type: "history",
      messages: entries.map((entry) => entry.message),
      sessionId,
    } as Record<string, unknown>);
    sendCodexCurrentSettings(server, ws, sessionId, session);
    server.send(ws, {
      type: "status",
      status: session.status,
      sessionId,
    } as Record<string, unknown>);
    server.sendQueueState(ws, sessionId, session);
    sendBackgroundTasksState(server, ws, sessionId, session);
    sendCodexGoalState(server, ws, sessionId, session);
    server.sendCachedCommands(ws, sessionId, session);
    return true;
  } catch (err) {
    server.send(ws, {
      type: "error",
      message: `Failed to read Codex thread history: ${
        err instanceof Error ? err.message : String(err)
      }`,
    });
    return true;
  }
}

export function shouldResetCodexHistoryDelta(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  sinceSeq: number,
  resultKind: "delta" | "snapshot",
): boolean {
  if (!codexThreadIdForSession(session)) return false;
  const resetRevision = session.codexHistoryResetRevision ??
    session.codexCanonicalHistoryRevision;
  if (typeof resetRevision !== "number") return true;
  if (sinceSeq < resetRevision) return true;
  return resultKind === "snapshot";
}

export async function codexHistoryToServerMessages(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  history: SessionHistoryMessage[],
): Promise<ServerMessage[]> {
  const messages: ServerMessage[] = [];
  for (const item of history) {
    const converted = await server.codexHistoryMessageToServerMessage(
      session,
      item,
    );
    if (converted) messages.push(converted);
  }
  return messages;
}

export function sessionHistoryText(content: SessionHistoryMessage["content"]): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((item) => {
      if (item.type === "text" && typeof item.text === "string") {
        return item.text;
      }
      if (item.type === "thinking" && typeof item.thinking === "string") {
        return item.thinking;
      }
      return "";
    })
    .filter((text) => text.length > 0)
    .join("\n");
}

export function sessionHistoryAssistantContent(
  content: SessionHistoryMessage["content"],
): AssistantContent[] {
  if (typeof content === "string") {
    return content.trim().length > 0
      ? [{ type: "text", text: content }]
      : [];
  }
  if (!Array.isArray(content)) return [];
  const items: AssistantContent[] = [];
  for (const item of content) {
    if (item.type === "text" && typeof item.text === "string") {
      items.push({ type: "text", text: item.text });
    } else if (
      item.type === "thinking" &&
      typeof item.thinking === "string"
    ) {
      items.push({ type: "thinking", thinking: item.thinking });
    } else if (
      item.type === "tool_use" &&
      typeof item.id === "string" &&
      typeof item.name === "string"
    ) {
      items.push({
        type: "tool_use",
        id: item.id,
        name: item.name,
        input: item.input ?? {},
      });
    }
  }
  return items;
}

export function sessionHistorySingleToolUseId(
  content: SessionHistoryMessage["content"],
): string | undefined {
  if (!Array.isArray(content) || content.length !== 1) return undefined;
  const item = content[0];
  return item.type === "tool_use" && typeof item.id === "string"
    ? item.id
    : undefined;
}

export async function registerPastUserMessageImages(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  msg: Record<string, unknown>,
): Promise<ImageRef[]> {
  if (!server.imageStore) return [];

  const existingImages = Array.isArray(msg.images)
    ? (msg.images as ImageRef[])
    : [];
  const refs: ImageRef[] = [...existingImages];

  if (Array.isArray(msg.imagePaths)) {
    const paths = msg.imagePaths.filter(
      (path): path is string => typeof path === "string" && path.length > 0,
    );
    if (paths.length > 0) {
      refs.push(
        ...(await server.imageStore.registerImages(paths, session.projectPath)),
      );
    }
  }

  if (Array.isArray(msg.imageBase64)) {
    for (const image of msg.imageBase64) {
      const rawImage = image as Record<string, unknown>;
      if (
        typeof rawImage.data !== "string" ||
        typeof rawImage.mimeType !== "string"
      ) {
        continue;
      }
      const ref = server.imageStore.registerFromBase64(
        rawImage.data,
        rawImage.mimeType,
      );
      if (ref) refs.push(ref);
    }
  }

  const messageUuid = typeof msg.uuid === "string" ? msg.uuid : undefined;
  const providerSessionId = session.claudeSessionId;
  if (
    refs.length === existingImages.length &&
    messageUuid &&
    providerSessionId
  ) {
    try {
      const extracted = await extractMessageImages(
        providerSessionId,
        messageUuid,
      );
      for (const image of extracted) {
        const ref = server.imageStore.registerFromBase64(
          image.base64,
          image.mimeType,
        );
        if (ref) refs.push(ref);
      }
    } catch (err) {
      console.warn(
        `[ws] Failed to restore user message images for ${messageUuid}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  }

  return refs;
}

/** Re-registers markdown-embedded images when history is restored. */
export async function resolveAssistantImages(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  content: unknown,
): Promise<AssistantImageRef[]> {
  if (!server.assistantImageResolver) return [];
  const texts = assistantTextBlocks(content);
  if (!hasMarkdownImages(texts)) return [];
  return server.assistantImageResolver(texts, session.projectPath);
}

export async function registerPastToolResultImages(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  msg: Record<string, unknown>,
): Promise<ImageRef[]> {
  const existingImages = Array.isArray(msg.images)
    ? (msg.images as ImageRef[])
    : [];
  if (!server.imageStore) return [...existingImages];

  const paths = new Set<string>();
  if (Array.isArray(msg.imagePaths)) {
    for (const path of msg.imagePaths) {
      if (typeof path === "string" && path.length > 0) paths.add(path);
    }
  }

  const content = typeof msg.content === "string" ? msg.content : "";
  if (content) {
    for (const path of server.imageStore.extractImagePaths(content)) {
      paths.add(path);
    }
  }

  const refs: ImageRef[] = [...existingImages];
  if (paths.size > 0) {
    refs.push(
      ...(await server.imageStore.registerImages([...paths], session.projectPath)),
    );
  }

  if (Array.isArray(msg.imageBase64)) {
    for (const image of msg.imageBase64) {
      const rawImage = image as Record<string, unknown>;
      if (
        typeof rawImage.data !== "string" ||
        typeof rawImage.mimeType !== "string"
      ) {
        continue;
      }
      const ref = server.imageStore.registerFromBase64(
        rawImage.data,
        rawImage.mimeType,
      );
      if (ref) refs.push(ref);
    }
  }

  return refs;
}

export async function getCodexThreadHistoryFromRpc(
  server: BridgeWebSocketServer,
  threadId: string,
  projectPath?: string,
  preferredProcess?: CodexProcess,
): Promise<SessionHistoryMessage[]> {
  const activeProcess = preferredProcess ?? server.getActiveCodexProcess();
  const process =
    activeProcess ?? (await server.createStandaloneCodexProcess(projectPath));
  const isStandalone = process !== activeProcess;
  try {
    const thread = await process.readThread(threadId, true);
    return codexThreadToSessionHistory(thread);
  } catch (err) {
    if (isCodexThreadNotMaterializedError(err)) return [];
    throw err;
  } finally {
    if (isStandalone) {
      process.stop();
    }
  }
}

export function isCodexThreadNotMaterializedError(err: unknown): boolean {
  const message = err instanceof Error ? err.message : String(err);
  return (
    message.includes("is not materialized yet") &&
    message.includes("includeTurns is unavailable before first user message")
  );
}

export async function getCodexThreadHistory(
  server: BridgeWebSocketServer,
  threadId: string,
  projectPath?: string,
): Promise<SessionHistoryMessage[]> {
  if (!server.getActiveCodexProcess() && process.env.NODE_ENV === "test") {
    return getCodexSessionHistory(threadId);
  }
  return getCodexThreadHistoryFromRpc(server, threadId, projectPath);
}

export function codexHistoryFromThreadOrFallback(params: {
  thread: unknown;
  expectedUserTurns: number;
  fallback: SessionHistoryMessage[];
}): SessionHistoryMessage[] {
  const messages = codexThreadToSessionHistory(params.thread);
  if (countCodexHistoryUserTurns(messages) >= params.expectedUserTurns) {
    return messages;
  }
  return params.fallback;
}
