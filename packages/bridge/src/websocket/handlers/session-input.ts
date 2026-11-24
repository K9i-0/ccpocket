import { randomUUID } from "node:crypto";
import { WebSocket } from "ws";
import type { QueuedSessionInput } from "../../session.js";
import { SdkProcess } from "../../sdk-process.js";
import { CodexProcess } from "../../codex-process.js";
import { AntigravityProcess } from "../../antigravity-process.js";
import type { ClientMessage, ServerMessage } from "../../parser.js";
import { nextCodexUserTurnUuid } from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { interruptAndRetract, editUserMessage } from "../rewind-fork.js";
import { hasInputConflictSince } from "../session-state.js";

export async function handleInput(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "input" }>,
  ws: WebSocket,
  echoInput: boolean,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    const pendingInputs = msg.sessionId
      ? server.pendingClaudeResumeInputs.get(ws)?.get(msg.sessionId)
      : undefined;
    if (pendingInputs) {
      pendingInputs.push(msg);
      return;
    }
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session. Send 'start' first.",
    });
    return;
  }
  const text = msg.text;
  const clientMessageId = msg.clientMessageId;
  const baseSeq = msg.baseSeq;
  const codexSkills = msg.skills ?? (msg.skill ? [msg.skill] : []);
  const codexMentions = msg.mentions ?? [];

  // Snapshot busy state before dispatch. We prefer the actual enqueue
  // result returned by SdkProcess sendInput* below, but keep this as a
  // fallback for test doubles and async paths.
  const isAgentBusySnapshot =
    session.provider === "claude" && !session.process.isWaitingForInput;

  // Normalize images: support new `images` array and legacy single-image fields
  let images: Array<{ base64: string; mimeType: string }> = [];
  if (msg.images && msg.images.length > 0) {
    images = msg.images;
  } else if (msg.imageBase64 && msg.mimeType) {
    // Legacy single-image fallback
    images = [{ base64: msg.imageBase64, mimeType: msg.mimeType }];
  }

  // Add user_input to in-memory history.
  // The SDK stream does NOT emit user messages, so session.history would
  // otherwise lack them.  This ensures get_history responses include user
  // messages and replaceEntries on the client side preserves them.
  // Flutter already shows the user bubble optimistically. For Codex we
  // echo the accepted user_input back with its synthetic UUID so the live
  // bubble becomes rewindable/forkable without requiring a stop+resume.
  //
  // Register images in the image store so they can be served via HTTP
  // when the client re-enters the session and loads history.
  let imageRefs:
    | Array<{ id: string; url: string; mimeType: string }>
    | undefined;
  if (images.length > 0 && server.imageStore) {
    imageRefs = [];
    for (const img of images) {
      const ref = server.imageStore.registerFromBase64(
        img.base64,
        img.mimeType,
      );
      if (ref) imageRefs.push(ref);
    }
    if (imageRefs.length === 0) imageRefs = undefined;
  }

  if (
    clientMessageId &&
    baseSeq !== undefined &&
    hasInputConflictSince(server, session, baseSeq)
  ) {
    server.send(ws, {
      type: "input_rejected",
      sessionId: session.id,
      clientMessageId,
      reason: "conflict",
    });
    return;
  }

  const delivery = msg.delivery;
  const sdkTurnActive =
    session.provider === "claude"
      ? (session.process as Partial<Pick<SdkProcess, "isTurnActive">>)
          .isTurnActive
      : undefined;
  // Antigravity steers the running turn when it gets a prompt, so a
  // message is held back only when the client asks for a delivery.
  const turnActive =
    session.process instanceof AntigravityProcess
      ? session.process.isTurnActive
      : session.provider === "codex"
      ? !session.process.isWaitingForInput
      : typeof sdkTurnActive === "boolean"
        ? sdkTurnActive
        : isAgentBusySnapshot;
  // Older clients omit `delivery`: Codex queues and Claude keeps the
  // legacy interrupt-and-send path below.
  const usageLimited = server.sessionManager.isUsageLimited(session.id);
  const holdForDelivery =
    usageLimited || (turnActive &&
    (delivery !== undefined || session.provider === "codex"));

  if (holdForDelivery) {
    const pendingInput: QueuedSessionInput = {
      itemId: randomUUID(),
      ...(clientMessageId ? { clientMessageId } : {}),
      text,
      createdAt: new Date().toISOString(),
      ...(session.provider === "codex"
        ? { userMessageUuid: nextCodexUserTurnUuid(session) }
        : {}),
      ...(images.length > 0 ? { imageCount: images.length, images } : {}),
      ...(imageRefs ? { imageRefs } : {}),
      ...(codexSkills.length > 0 ? { skills: codexSkills } : {}),
      ...(codexMentions.length > 0 ? { mentions: codexMentions } : {}),
    };

    let outcome: "steered" | "queued" | "rejected";
    if (delivery === "steer" && !usageLimited) {
      outcome = await server.sessionManager.steerInput(
        session.id,
        pendingInput,
      );
    } else if (session.queuedInput) {
      outcome = "rejected";
    } else {
      outcome = server.sessionManager.queueInput(session.id, pendingInput)
        ? "queued"
        : "rejected";
    }

    if (outcome === "rejected") {
      server.send(ws, {
        type: "input_rejected",
        sessionId: session.id,
        ...(clientMessageId ? { clientMessageId } : {}),
        reason: "Queue is full",
      });
      return;
    }
    if (images.length > 0 && server.galleryStore && session.projectPath) {
      for (const img of images) {
        server.galleryStore
          .addImageFromBase64(
            img.base64,
            img.mimeType,
            session.projectPath,
            msg.sessionId,
          )
          .catch((err) => {
            console.warn(
              `[ws] Failed to persist queued image to gallery: ${err}`,
            );
          });
      }
    }
    server.send(ws, {
      type: "input_ack",
      sessionId: session.id,
      ...(clientMessageId ? { clientMessageId } : {}),
      acceptedSeq: session.historyRevision,
      queued: outcome === "queued",
    });
    server.broadcastSessionList();
    return;
  }

  if (session.provider === "claude" && session.process.isRunning === false) {
    // The query ended (for example after an SDK error) but the session is
    // still listed. Nothing would read this input, so say so instead of
    // acknowledging it. Rejected before it reaches history.
    const message = "Claude session is not running. Start it again.";
    server.send(ws, {
      type: "input_rejected",
      sessionId: session.id,
      ...(clientMessageId ? { clientMessageId } : {}),
      reason: message,
    });
    server.send(ws, { type: "error", sessionId: session.id, message });
    return;
  }

  if (session.process instanceof AntigravityProcess) {
    if (!session.process.isRunning) {
      // Rejected before it reaches history, so no ghost turn is left.
      server.send(ws, {
        type: "error",
        sessionId: session.id,
        message: "Antigravity session is not running. Start it again.",
      });
      return;
    }
    if (session.process.isReplaying) {
      await session.process.waitUntilReady().catch(() => {});
      if (!session.process.isRunning) {
        server.send(ws, {
          type: "error",
          sessionId: session.id,
          message: "Antigravity session is not running. Start it again.",
        });
        return;
      }
    }
    // Commit any buffered assistant text/thinking before recording the new
    // user message so prior agent output never lands below it.
    session.process.flushPendingOutput();
  }
  if (server.sessionManager.hasPendingMessages(session.id)) {
    await server.sessionManager.waitForPendingMessages(session.id);
  }

  const userEntry = server.sessionManager.appendHistory(session.id, {
    type: "user_input",
    text,
    ...(session.provider === "codex"
      ? { userMessageUuid: nextCodexUserTurnUuid(session) }
      : {}),
    ...(clientMessageId ? { clientMessageId } : {}),
    timestamp: new Date().toISOString(),
    ...(images.length > 0 ? { imageCount: images.length } : {}),
    ...(imageRefs ? { images: imageRefs } : {}),
  } as ServerMessage);
  const acceptedSeq = userEntry?.seq ?? session.historyRevision;

  if ((session.provider === "codex" || echoInput) && userEntry) {
    server.send(ws, {
      ...userEntry.message,
      sessionId: session.id,
      historySeq: acceptedSeq,
    } as ServerMessage & { sessionId: string; historySeq: number });
  }
  if (userEntry) {
    server.broadcastSessionMessage(
      session.id,
      {
        ...userEntry.message,
        historySeq: acceptedSeq,
      } as ServerMessage & { historySeq: number },
      ws,
    );
  }

  // Persist images to Gallery Store asynchronously (fire-and-forget)
  if (images.length > 0 && server.galleryStore && session.projectPath) {
    for (const img of images) {
      server.galleryStore
        .addImageFromBase64(
          img.base64,
          img.mimeType,
          session.projectPath,
          msg.sessionId,
        )
        .catch((err) => {
          console.warn(`[ws] Failed to persist image to gallery: ${err}`);
        });
    }
  }

  if (session.process instanceof AntigravityProcess) {
    // Legacy clients name a gallery image instead of sending its bytes.
    const galleryImage =
      images.length === 0 && msg.imageId && server.galleryStore
        ? await server.galleryStore
            .getImageAsBase64(msg.imageId)
            .catch(() => null)
        : null;
    const inputImages = galleryImage ? [galleryImage] : images;
    const accepted = session.process.sendInput(
      text,
      inputImages.length > 0 ? inputImages : undefined,
    );
    if (!accepted) {
      server.send(ws, {
        type: "error",
        sessionId: session.id,
        message: "Antigravity session is not running. Start it again.",
      });
      return;
    }
    server.send(ws, {
      type: "input_ack",
      sessionId: session.id,
      ...(clientMessageId ? { clientMessageId } : {}),
      acceptedSeq,
      queued: false,
    });
    return;
  }

  // Codex input path
  if (session.provider === "codex") {
    server.send(ws, {
      type: "input_ack",
      sessionId: session.id,
      ...(clientMessageId ? { clientMessageId } : {}),
      acceptedSeq,
      queued: false,
    });
    const codexProc = session.process as CodexProcess;
    if (images.length > 0) {
      codexProc.sendInputStructured(text, {
        images,
        skills: codexSkills,
        mentions: codexMentions,
      });
    } else if (msg.imageId && server.galleryStore) {
      server.galleryStore
        .getImageAsBase64(msg.imageId)
        .then((imageData) => {
          if (imageData) {
            codexProc.sendInputStructured(text, {
              images: [imageData],
              skills: codexSkills,
              mentions: codexMentions,
            });
          } else {
            console.warn(`[ws] Image not found: ${msg.imageId}`);
            codexProc.sendInputStructured(text, {
              skills: codexSkills,
              mentions: codexMentions,
            });
          }
        })
        .catch((err) => {
          console.error(`[ws] Failed to load image: ${err}`);
          codexProc.sendInputStructured(text, {
            skills: codexSkills,
            mentions: codexMentions,
          });
        });
    } else if (codexSkills.length > 0 || codexMentions.length > 0) {
      codexProc.sendInputStructured(text, {
        skills: codexSkills,
        mentions: codexMentions,
      });
    } else {
      codexProc.sendInput(text);
    }
    return;
  }

  // Claude Code input path — enqueue first, then interrupt if busy
  const claudeProc = session.process as SdkProcess;
  let wasQueued = false;
  let shouldInterrupt = false;
  if (images.length > 0) {
    console.log(
      `[ws] Sending message with ${images.length} inline Base64 image(s)`,
    );
    if (typeof claudeProc.dispatchInputWithImages === "function") {
      const result = claudeProc.dispatchInputWithImages(text, images);
      wasQueued = result.queued;
      shouldInterrupt = result.shouldInterrupt;
    } else {
      const result = claudeProc.sendInputWithImages(text, images);
      wasQueued =
        typeof result === "boolean" ? result : isAgentBusySnapshot;
      shouldInterrupt = wasQueued;
    }
  }
  // Legacy imageId mode (backward compatibility)
  else if (msg.imageId && server.galleryStore) {
    server.send(ws, {
      type: "input_ack",
      sessionId: session.id,
      ...(clientMessageId ? { clientMessageId } : {}),
      acceptedSeq,
      queued: isAgentBusySnapshot,
    });
    server.galleryStore
      .getImageAsBase64(msg.imageId)
      .then((imageData) => {
        let queuedAfterResolve = false;
        if (imageData) {
          if (typeof claudeProc.dispatchInputWithImages === "function") {
            const result = claudeProc.dispatchInputWithImages(text, [
              imageData,
            ]);
            queuedAfterResolve = result.queued;
            if (result.shouldInterrupt) claudeProc.interrupt();
          } else {
            const result = claudeProc.sendInputWithImages(text, [
              imageData,
            ]);
            queuedAfterResolve =
              typeof result === "boolean"
                ? result
                : isAgentBusySnapshot;
            if (queuedAfterResolve) claudeProc.interrupt();
          }
        } else {
          console.warn(`[ws] Image not found: ${msg.imageId}`);
          if (typeof claudeProc.dispatchInput === "function") {
            const result = claudeProc.dispatchInput(text);
            queuedAfterResolve = result.queued;
            if (result.shouldInterrupt) claudeProc.interrupt();
          } else {
            const result = session.process.sendInput(text);
            queuedAfterResolve =
              typeof result === "boolean"
                ? result
                : isAgentBusySnapshot;
            if (queuedAfterResolve) claudeProc.interrupt();
          }
        }
      })
      .catch((err) => {
        console.error(`[ws] Failed to load image: ${err}`);
        if (typeof claudeProc.dispatchInput === "function") {
          const result = claudeProc.dispatchInput(text);
          if (result.shouldInterrupt) claudeProc.interrupt();
        } else {
          const result = session.process.sendInput(text);
          const queuedAfterResolve =
            typeof result === "boolean" ? result : isAgentBusySnapshot;
          if (queuedAfterResolve) claudeProc.interrupt();
        }
      });
    return;
  }
  // Text-only message
  else {
    if (typeof claudeProc.dispatchInput === "function") {
      const result = claudeProc.dispatchInput(text);
      wasQueued = result.queued;
      shouldInterrupt = result.shouldInterrupt;
    } else {
      const result = session.process.sendInput(text);
      wasQueued =
        typeof result === "boolean" ? result : isAgentBusySnapshot;
      shouldInterrupt = wasQueued;
    }
  }

  // Acknowledge receipt so the client can mark the message state.
  // queued=true means the input was enqueued instead of being consumed
  // immediately by the SDK stream.
  server.send(ws, {
    type: "input_ack",
    sessionId: session.id,
    ...(clientMessageId ? { clientMessageId } : {}),
    acceptedSeq,
    queued: wasQueued,
  });

  if (shouldInterrupt) {
    console.log(
      `[ws] Agent is busy — will queue input and interrupt current turn`,
    );
    claudeProc.interrupt();
  }
}

export async function handleUpdateQueuedInput(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "update_queued_input" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  if (!msg.text.trim()) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Queued message cannot be empty.",
    });
    return;
  }
  const success = server.sessionManager.updateQueuedInput(
    session.id,
    msg.itemId,
    msg.text,
    { skills: msg.skills ?? [], mentions: msg.mentions ?? [] },
  );
  if (!success) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Queued message not found.",
      errorCode: "queued_input_not_found",
    });
    return;
  }
  server.broadcastSessionList();
}

export async function handleCancelQueuedInput(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "cancel_queued_input" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  const success = server.sessionManager.cancelQueuedInput(
    session.id,
    msg.itemId,
  );
  if (!success) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "Queued message not found.",
      errorCode: "queued_input_not_found",
    });
    return;
  }
  server.broadcastSessionList();
}

export async function handleSteerQueuedInput(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "steer_queued_input" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  const result = await server.sessionManager.steerQueuedInput(
    session.id,
    msg.itemId,
  );
  if (!result.ok) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: result.error,
      errorCode:
        result.error === "Queued message not found."
          ? "queued_input_not_found"
          : "queued_input_steer_failed",
    });
    return;
  }
  server.broadcastSessionList();
}

export async function handleInterrupt(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "interrupt" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.resolveSession(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: "No active session.",
    });
    return;
  }
  if (msg.retract === true) {
    interruptAndRetract(server, ws, session).catch((err) => {
      console.warn(
        `[ws] Failed to retract interrupted prompt: ${err instanceof Error ? err.message : String(err)}`,
      );
    });
    return;
  }
  session.process.interrupt();
}

export async function handleEditMessage(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "edit_message" }>,
  ws: WebSocket,
): Promise<void> {
  await editUserMessage(server, ws, msg);
}
