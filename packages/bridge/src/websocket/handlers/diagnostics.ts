import { unlink } from "node:fs/promises";
import { WebSocket } from "ws";
import type { ClientMessage } from "../../parser.js";
import { findSessionsByClaudeIds } from "../../sessions-index.js";
import { listWindows, takeScreenshot } from "../../screenshot.js";
import { fetchAllUsage, type UsageInfo } from "../../usage.js";
import { projectRequestMetadata, MAX_DEBUG_EVENTS } from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import {
  getDebugEvents,
  buildHistorySummary,
  buildReproRecipe,
} from "../debug-trace.js";
import { buildAgentPrompt } from "../session-state.js";

export async function handleGetDebugBundle(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_debug_bundle" }>,
  ws: WebSocket,
): Promise<void> {
  const session = server.sessionManager.get(msg.sessionId);
  if (!session) {
    server.send(ws, {
      type: "error",
      sessionId: msg.sessionId,
      message: `Session ${msg.sessionId} not found`,
    });
    return;
  }

  const emitBundle = (diff: string, diffError?: string): void => {
    const traceLimit =
      msg.traceLimit ?? MAX_DEBUG_EVENTS;
    const trace = getDebugEvents(server, msg.sessionId, traceLimit);
    const generatedAt = new Date().toISOString();
    const includeDiff = msg.includeDiff !== false;
    const bundlePayload: Record<string, unknown> = {
      type: "debug_bundle",
      sessionId: msg.sessionId,
      generatedAt,
      session: {
        id: session.id,
        provider: session.provider,
        status: session.status,
        projectPath: session.projectPath,
        worktreePath: session.worktreePath,
        worktreeBranch: session.worktreeBranch,
        claudeSessionId: session.claudeSessionId,
        createdAt: session.createdAt.toISOString(),
        lastActivityAt: session.lastActivityAt.toISOString(),
      },
      pastMessageCount: session.pastMessages?.length ?? 0,
      historySummary: buildHistorySummary(server, session.history),
      debugTrace: trace,
      traceFilePath: server.debugTraceStore.getTraceFilePath(msg.sessionId),
      reproRecipe: buildReproRecipe(
        server,
        session,
        traceLimit,
        includeDiff,
      ),
      agentPrompt: buildAgentPrompt(session),
      diff,
      diffError,
    };
    const savedBundlePath = server.debugTraceStore.getBundleFilePath(
      msg.sessionId,
      generatedAt,
    );
    bundlePayload.savedBundlePath = savedBundlePath;
    server.debugTraceStore.saveBundleAtPath(savedBundlePath, bundlePayload);
    server.send(ws, bundlePayload);
  };

  if (msg.includeDiff === false) {
    emitBundle("");
    return;
  }

  const cwd = session.worktreePath ?? session.projectPath;
  server.collectGitDiff(cwd, ({ diff, error }) => {
    emitBundle(diff, error);
  });
}

export async function handleGetUsage(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_usage" }>,
  ws: WebSocket,
): Promise<void> {
  // The Antigravity CLI takes seconds to answer, so the other agents
  // go out first with its last reading, and a second result follows
  // when the new one differs.
  const lastAntigravity = server.antigravityUsageCache?.usage ?? [];
  const antigravityRead = server.antigravityUsage(
    msg.refreshAntigravity === true,
  );
  fetchAllUsage({ readClaudeLive: () => server.readClaudePlanUsage() })
    .then(async (usage) => {
      const sendUsage = (antigravity: UsageInfo[]) =>
        server.send(ws, {
          type: "usage_result",
          providers: [...usage, ...antigravity],
        } as Record<string, unknown>);
      sendUsage(lastAntigravity);
      const antigravity = await antigravityRead;
      if (JSON.stringify(antigravity) !== JSON.stringify(lastAntigravity)) {
        sendUsage(antigravity);
      }
    })
    .catch((err) => {
      server.send(ws, {
        type: "error",
        message: `Failed to fetch usage: ${err}`,
      });
    });
}

export async function handleListRecordings(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_recordings" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.recordingStore) {
    server.send(ws, { type: "recording_list", recordings: [] } as Record<
      string,
      unknown
    >);
    return;
  }
  const store = server.recordingStore;
  void store.listRecordings().then(async (recordings) => {
    // First pass: extract info from JSONL for recordings missing firstPrompt
    // This covers both meta-less legacy recordings and new ones where sessions-index hasn't indexed yet
    await Promise.all(
      recordings.map(async (rec) => {
        const info = await store.extractInfoFromJsonl(rec.name);
        if (info.firstPrompt && !rec.firstPrompt)
          rec.firstPrompt = info.firstPrompt;
        if (info.lastPrompt && !rec.lastPrompt)
          rec.lastPrompt = info.lastPrompt;
        // Backfill meta for legacy recordings
        if (!rec.meta && (info.claudeSessionId || info.projectPath)) {
          rec.meta = {
            bridgeSessionId: rec.name,
            claudeSessionId: info.claudeSessionId,
            projectPath: info.projectPath ?? "",
            createdAt: rec.modified,
          };
        }
      }),
    );

    // Second pass: look up sessions-index for summaries (if claudeSessionIds available)
    const claudeIds = new Set<string>();
    const idToIdx = new Map<string, number[]>();
    for (let i = 0; i < recordings.length; i++) {
      const cid = recordings[i].meta?.claudeSessionId;
      if (cid) {
        claudeIds.add(cid);
        const arr = idToIdx.get(cid) ?? [];
        arr.push(i);
        idToIdx.set(cid, arr);
      }
    }

    if (claudeIds.size > 0) {
      const sessionInfo = await findSessionsByClaudeIds(claudeIds);
      for (const [cid, info] of sessionInfo) {
        const indices = idToIdx.get(cid) ?? [];
        for (const idx of indices) {
          if (info.summary) recordings[idx].summary = info.summary;
          if (info.firstPrompt)
            recordings[idx].firstPrompt = info.firstPrompt;
          if (info.lastPrompt)
            recordings[idx].lastPrompt = info.lastPrompt;
        }
      }
    }

    // A recording keeps its name snapshot after Project deletion, but a
    // live Project rename should be reflected when the list is read.
    for (const recording of recordings) {
      const projectId = recording.meta?.projectId;
      if (!projectId) continue;
      const project = server.workspaceStore?.getProject(projectId);
      if (project && recording.meta) {
        recording.meta = {
          ...recording.meta,
          projectName: project.name,
        };
      }
    }

    server.send(ws, { type: "recording_list", recordings } as Record<
      string,
      unknown
    >);
  });
}

export async function handleGetRecording(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_recording" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.recordingStore) {
    server.send(ws, {
      type: "error",
      message: "Recording is not enabled on this server",
    });
    return;
  }
  void server.recordingStore
    .getRecordingContent(msg.sessionId)
    .then((content) => {
      if (content !== null) {
        server.send(ws, {
          type: "recording_content",
          sessionId: msg.sessionId,
          content,
        } as Record<string, unknown>);
      } else {
        server.send(ws, {
          type: "error",
          message: `Recording ${msg.sessionId} not found`,
        });
      }
    });
}

export async function handleListWindows(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_windows" }>,
  ws: WebSocket,
): Promise<void> {
  listWindows()
    .then((windows) => {
      server.send(ws, { type: "window_list", windows });
    })
    .catch((err) => {
      server.send(ws, {
        type: "error",
        message: `Failed to list windows: ${err instanceof Error ? err.message : String(err)}`,
      });
    });
}

export async function handleTakeScreenshot(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "take_screenshot" }>,
  ws: WebSocket,
): Promise<void> {
  // For window mode, verify the window ID is still valid.
  // The user may have fetched the window list minutes ago and the
  // window could have been closed since then.
  const doCapture = async (): Promise<{
    mode: "fullscreen" | "window";
    windowId?: number;
  }> => {
    if (msg.mode !== "window" || msg.windowId == null) {
      return { mode: msg.mode };
    }
    const current = await listWindows();
    if (current.some((w) => w.windowId === msg.windowId)) {
      return { mode: "window", windowId: msg.windowId };
    }
    // Window ID is stale — fall back to fullscreen and notify
    console.warn(
      `[screenshot] Window ID ${msg.windowId} no longer exists, falling back to fullscreen`,
    );
    return { mode: "fullscreen" };
  };
  doCapture()
    .then((opts) => takeScreenshot(opts))
    .then(async (result) => {
      try {
        if (server.galleryStore) {
          const meta = await server.galleryStore.addImage(
            result.filePath,
            msg.projectPath,
            msg.sessionId,
          );
          if (meta) {
            const info = server.galleryStore.metaToInfo(meta);
            server.send(ws, {
              type: "screenshot_result",
              ...projectRequestMetadata(msg),
              sessionId: msg.sessionId,
              success: true,
              image: info,
            });
            server.broadcast({ type: "gallery_new_image", image: info });
            return;
          }
        }
        server.send(ws, {
          type: "screenshot_result",
          ...projectRequestMetadata(msg),
          sessionId: msg.sessionId,
          success: false,
          error: "Failed to save screenshot to gallery",
        });
      } finally {
        // Always clean up temp file
        unlink(result.filePath).catch(() => {});
      }
    })
    .catch((err) => {
      server.send(ws, {
        type: "screenshot_result",
        ...projectRequestMetadata(msg),
        sessionId: msg.sessionId,
        success: false,
        error: err instanceof Error ? err.message : String(err),
      });
    });
}
