import { randomUUID } from "node:crypto";
import { WebSocket } from "ws";
import type { ClientMessage, Provider } from "../../parser.js";
import type { SessionInfo } from "../../session.js";
import type { SessionHistoryMessage } from "../../sessions-index.js";
import { renameClaudeSession } from "../../sessions-index.js";
import { CodexProcess } from "../../codex-process.js";
import {
  buildHandoffNoteRequest,
  buildHandoffPrompt,
  handoffSessionTitle,
  handoffAgentName,
  writeHandoffTranscript,
} from "../../session-handoff.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { waitForSessionIdle, waitForSessionRunning } from "../rewind-fork.js";
import { sessionTranscriptMessages } from "../session-history.js";
import { workspaceForRuntimeSession } from "../workspaces.js";
import { handleStart } from "./session-start.js";
import { stopSessionAndNotify } from "./session-catalog.js";

/** How long a running turn may take to stop after the interrupt. */
const INTERRUPT_WAIT_MS = 15_000;
/** How long the note request may take to start a turn. */
const NOTE_START_WAIT_MS = 10_000;
/** How long the source agent may take to write the note. */
const NOTE_TURN_WAIT_MS = 180_000;
/** A reply shorter than this is not a usable note. */
const NOTE_MIN_LENGTH = 40;
/** How long the target may take to get its provider session id. */
const NAME_PERSIST_WAIT_MS = 120_000;
const NAME_PERSIST_POLL_MS = 1_000;

/** Timings, replaceable in tests. */
export const handoffTimings = {
  interruptWaitMs: INTERRUPT_WAIT_MS,
  noteStartWaitMs: NOTE_START_WAIT_MS,
  noteTurnWaitMs: NOTE_TURN_WAIT_MS,
  namePersistWaitMs: NAME_PERSIST_WAIT_MS,
  namePersistPollMs: NAME_PERSIST_POLL_MS,
};

/** Source sessions with a handoff under way. */
const handoffsInProgress = new Set<string>();

type NoteOutcome =
  | { kind: "note"; text: string }
  /** The source could not write one; the Bridge-built context is used. */
  | { kind: "unavailable"; reason: string }
  /** The user stopped the note turn: keep the source and do not hand off. */
  | { kind: "cancelled" };

/**
 * Stop a session and continue its task in a new session of another provider.
 *
 * The source agent writes a handoff note in one last turn. The Bridge adds
 * the recent conversation and the path of a saved transcript, starts the
 * target in the same directory with that as its first prompt, and stops the
 * source. When the source cannot write the note (usage limit, error, timeout)
 * the target starts from the Bridge-built context alone.
 */
export async function handleHandoffSession(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "handoff_session" }>,
  ws: WebSocket,
): Promise<void> {
  const sourceSessionId = msg.sessionId;
  const fail = (message: string) => {
    server.send(ws, {
      type: "error",
      sessionId: sourceSessionId,
      message,
      errorCode: "handoff_failed",
    });
  };
  const session = server.sessionManager.get(sourceSessionId);
  if (!session) {
    fail(`Session ${sourceSessionId} not found`);
    return;
  }
  const target = msg.targetProvider;
  if (session.provider === target) {
    fail(`This session already runs in ${handoffAgentName(target)}`);
    return;
  }
  if (handoffsInProgress.has(sourceSessionId)) {
    fail("A handoff of this session is already in progress");
    return;
  }

  handoffsInProgress.add(sourceSessionId);
  try {
    // A running turn is stopped first: the note has to be a turn of its own,
    // and Antigravity would steer the running turn with the request instead.
    if (!isSessionIdle(session)) {
      session.process.interrupt();
      await waitForSessionIdle(session, handoffTimings.interruptWaitMs);
    }
    if (server.sessionManager.get(sourceSessionId) !== session) {
      fail("The session stopped before it could be handed off");
      return;
    }

    // Read while the source is alive: Codex history comes from its
    // app-server. Reading before the note turn also keeps the note request
    // and its reply out of the conversation given to the target.
    let history: SessionHistoryMessage[] = [];
    try {
      history = await sessionTranscriptMessages(server, session);
    } catch (err) {
      console.warn(`[ws] handoff: could not read the transcript: ${err}`);
    }

    const note = await requestHandoffNote(server, session, target, ws);
    if (note.kind === "cancelled") {
      fail("Handoff cancelled: the handoff note was interrupted");
      return;
    }
    if (note.kind === "unavailable") {
      console.log(`[ws] handoff: no note from the source (${note.reason})`);
    }
    if (server.sessionManager.get(sourceSessionId) !== session) {
      fail("The session stopped before it could be handed off");
      return;
    }

    let transcriptPath: string | undefined;
    if (history.length > 0) {
      try {
        transcriptPath = await writeHandoffTranscript({
          source: session.provider,
          target,
          history,
        });
      } catch (err) {
        console.warn(`[ws] handoff: could not save the transcript: ${err}`);
      }
    }
    const prompt = buildHandoffPrompt({
      source: session.provider,
      target,
      history,
      ...(note.kind === "note" ? { note: note.text } : {}),
      ...(msg.instruction ? { instruction: msg.instruction } : {}),
      ...(transcriptPath ? { transcriptPath } : {}),
    });

    const summary = server.sessionManager
      .list()
      .find((item) => item.id === sourceSessionId);
    const workspace = workspaceForRuntimeSession(server, session);
    // Without a name the target would be titled after the handoff prompt.
    const name = session.name?.trim() || handoffSessionTitle(history);
    const newSessionId = await handleStart(
      server,
      {
        type: "start",
        projectPath: session.projectPath,
        provider: target,
        initialPrompt: prompt,
        // Plan mode is not carried over: the target is asked to continue.
        executionMode: executionModeForTarget(summary?.executionMode),
        ...(workspace?.kind === "project" && workspace.projectId
          ? { projectId: workspace.projectId }
          : workspace && workspace.rootPaths.length > 1
            ? { additionalWritableRoots: workspace.rootPaths.slice(1) }
            : {}),
        ...(session.worktreePath
          ? {
              existingWorktreePath: session.worktreePath,
              ...(session.worktreeBranch
                ? { worktreeBranch: session.worktreeBranch }
                : {}),
            }
          : {}),
        // The name is carried over, so none is generated.
        ...(name ? { autoRename: false } : {}),
      },
      ws,
      {
        handoffSourceSessionId: sourceSessionId,
        rawInitialPrompt: true,
        ...(name ? { name } : {}),
      },
    );
    // handleStart has reported the failure; the source keeps running.
    if (!newSessionId) return;

    if (name) void persistSessionName(server, newSessionId, name);
    stopSessionAndNotify(server, sourceSessionId);
  } catch (err) {
    console.error("[ws] handoff failed:", err);
    fail(`Handoff failed: ${err instanceof Error ? err.message : String(err)}`);
  } finally {
    handoffsInProgress.delete(sourceSessionId);
  }
}

function isSessionIdle(session: SessionInfo): boolean {
  return session.status === "idle" && (session.process.status ?? "idle") === "idle";
}

function executionModeForTarget(
  mode: string | undefined,
): "default" | "acceptEdits" | "fullAccess" {
  return mode === "fullAccess" || mode === "acceptEdits" ? mode : "default";
}

/** Ask the source agent for a handoff note and wait for its reply. */
async function requestHandoffNote(
  server: BridgeWebSocketServer,
  session: SessionInfo,
  target: Provider,
  ws: WebSocket,
): Promise<NoteOutcome> {
  if (!isSessionIdle(session)) {
    return { kind: "unavailable", reason: "the session is not idle" };
  }
  if (!session.process.isRunning) {
    return { kind: "unavailable", reason: "the agent process is not running" };
  }
  if (server.sessionManager.isUsageLimited(session.id)) {
    return { kind: "unavailable", reason: "the usage limit is reached" };
  }
  if (session.queuedInput) {
    return { kind: "unavailable", reason: "input is queued" };
  }

  const clientMessageId = randomUUID();
  await server.handleClientMessage(
    {
      type: "input",
      sessionId: session.id,
      text: buildHandoffNoteRequest(target),
      clientMessageId,
    },
    ws,
    true,
  );
  const requestSeq = session.historyEntries.find(
    (entry) =>
      entry.message.type === "user_input" &&
      entry.message.clientMessageId === clientMessageId,
  )?.seq;
  if (requestSeq === undefined) {
    return { kind: "unavailable", reason: "the note request was not accepted" };
  }

  if (!(await waitForSessionRunning(session, handoffTimings.noteStartWaitMs))) {
    // The reply may already be complete when the turn was very short.
    const early = noteFromHistory(session, requestSeq);
    if (early.kind !== "unavailable") return early;
    return { kind: "unavailable", reason: "the note turn did not start" };
  }
  if (!(await waitForSessionIdle(session, handoffTimings.noteTurnWaitMs))) {
    if (session.process.isRunning) session.process.interrupt();
    await waitForSessionIdle(session, handoffTimings.interruptWaitMs);
    return { kind: "unavailable", reason: "the note turn did not finish" };
  }
  return noteFromHistory(session, requestSeq);
}

/** The reply to the note request, read from the live history. */
function noteFromHistory(session: SessionInfo, requestSeq: number): NoteOutcome {
  let text = "";
  let failed = false;
  for (const entry of session.historyEntries) {
    if (entry.seq <= requestSeq) continue;
    const message = entry.message;
    if (message.type === "assistant") {
      const reply = message.message.content
        .filter((block) => block.type === "text")
        .map((block) => (block as { text: string }).text)
        .join("\n")
        .trim();
      // The last message with text is the note; earlier ones are preamble.
      if (reply) text = reply;
    } else if (message.type === "result") {
      if (message.subtype === "interrupted") return { kind: "cancelled" };
      if (message.subtype === "error") failed = true;
    } else if (message.type === "error") {
      failed = true;
    }
  }
  if (failed) return { kind: "unavailable", reason: "the note turn failed" };
  if (text.length < NOTE_MIN_LENGTH) {
    return { kind: "unavailable", reason: "the reply was empty" };
  }
  return { kind: "note", text };
}

/**
 * Write the carried-over name to the target's own storage once the provider
 * has given the session an id. Until then the name only lives in memory.
 */
async function persistSessionName(
  server: BridgeWebSocketServer,
  sessionId: string,
  name: string,
): Promise<void> {
  const deadline = Date.now() + handoffTimings.namePersistWaitMs;
  while (Date.now() < deadline) {
    const session = server.sessionManager.get(sessionId);
    if (!session || session.name !== name) return;
    const providerSessionId =
      session.claudeSessionId ??
      (session.process instanceof CodexProcess
        ? (session.process.sessionId ?? undefined)
        : undefined);
    if (providerSessionId) {
      try {
        if (session.provider === "claude") {
          await renameClaudeSession(
            session.worktreePath ?? session.projectPath,
            providerSessionId,
            name,
          );
        } else if (session.process instanceof CodexProcess) {
          await session.process.renameThread(name);
        } else if (session.provider === "antigravity") {
          // The recent-session list picks it up when its cache expires.
          await server.antigravityStore.setName(providerSessionId, name);
        }
      } catch (err) {
        console.warn(`[ws] handoff: could not save the session name: ${err}`);
      }
      return;
    }
    await new Promise((resolve) =>
      setTimeout(resolve, handoffTimings.namePersistPollMs),
    );
  }
}
