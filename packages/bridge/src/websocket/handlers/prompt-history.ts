import { WebSocket } from "ws";
import type { ClientMessage } from "../../parser.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { broadcastPromptHistoryStatus } from "../session-state.js";
import { workspaceForRuntimeSession } from "../workspaces.js";

export async function handleBackupPromptHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "backup_prompt_history" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryBackup) {
    server.send(ws, {
      type: "prompt_history_backup_result",
      success: false,
      error: "Backup store not available",
    });
    return;
  }
  const buf = Buffer.from(msg.data, "base64");
  server.promptHistoryBackup
    .save(buf, msg.appVersion, msg.dbVersion)
    .then((meta) => {
      server.send(ws, {
        type: "prompt_history_backup_result",
        success: true,
        backedUpAt: meta.backedUpAt,
      });
    })
    .catch((err) => {
      server.send(ws, {
        type: "prompt_history_backup_result",
        success: false,
        error: err instanceof Error ? err.message : String(err),
      });
    });
}

export async function handleRestorePromptHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "restore_prompt_history" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryBackup) {
    server.send(ws, {
      type: "prompt_history_restore_result",
      success: false,
      error: "Backup store not available",
    });
    return;
  }
  server.promptHistoryBackup
    .load()
    .then((result) => {
      if (result) {
        server.send(ws, {
          type: "prompt_history_restore_result",
          success: true,
          data: result.data.toString("base64"),
          appVersion: result.meta.appVersion,
          dbVersion: result.meta.dbVersion,
          backedUpAt: result.meta.backedUpAt,
        });
      } else {
        server.send(ws, {
          type: "prompt_history_restore_result",
          success: false,
          error: "No backup found",
        });
      }
    })
    .catch((err) => {
      server.send(ws, {
        type: "prompt_history_restore_result",
        success: false,
        error: err instanceof Error ? err.message : String(err),
      });
    });
}

export async function handleGetPromptHistoryBackupInfo(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_prompt_history_backup_info" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryBackup) {
    server.send(ws, { type: "prompt_history_backup_info", exists: false });
    return;
  }
  server.promptHistoryBackup
    .getMeta()
    .then((meta) => {
      if (meta) {
        server.send(ws, {
          type: "prompt_history_backup_info",
          exists: true,
          ...meta,
        });
      } else {
        server.send(ws, {
          type: "prompt_history_backup_info",
          exists: false,
        });
      }
    })
    .catch(() => {
      server.send(ws, {
        type: "prompt_history_backup_info",
        exists: false,
      });
    });
}

export async function handleRecordPromptHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "record_prompt_history" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryStore) {
    server.send(ws, {
      type: "prompt_history_mutation_result",
      success: false,
      error: "Prompt history store not available",
    });
    return;
  }
  try {
    const runtimeSession = msg.sessionId
      ? server.resolveSession(msg.sessionId)
      : undefined;
    const workspace = runtimeSession
      ? workspaceForRuntimeSession(server, runtimeSession)
      : undefined;
    const entry = await server.promptHistoryStore.record({
      text: msg.text,
      projectPath: msg.projectPath,
      projectId: workspace?.projectId ?? msg.projectId,
      projectName: workspace?.projectName ?? msg.projectName,
      clientId: msg.clientId,
      clientName: msg.clientName,
      sessionId: msg.sessionId,
      usedAt: msg.usedAt,
    });
    server.send(ws, {
      type: "prompt_history_mutation_result",
      success: true,
      bridgeInstanceId: server.promptHistoryStore.bridgeInstanceId,
      revision: server.promptHistoryStore.revision,
      entry,
    });
    broadcastPromptHistoryStatus(server);
  } catch (err) {
    server.send(ws, {
      type: "prompt_history_mutation_result",
      success: false,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function handleSyncPromptHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "sync_prompt_history" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryStore) {
    server.send(ws, {
      type: "prompt_history_sync_result",
      success: false,
      error: "Prompt history store not available",
    });
    return;
  }
  try {
    if (msg.entries?.length) {
      await server.promptHistoryStore.mergeClientEntries(msg.entries);
    }
    server.send(ws, {
      type: "prompt_history_sync_result",
      success: true,
      bridgeInstanceId: server.promptHistoryStore.bridgeInstanceId,
      revision: server.promptHistoryStore.revision,
      syncedAt: new Date().toISOString(),
      fullSnapshot: true,
      entries: server.promptHistoryStore.list(msg.includeDeleted ?? true),
    });
    broadcastPromptHistoryStatus(server);
  } catch (err) {
    server.send(ws, {
      type: "prompt_history_sync_result",
      success: false,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function handleMutatePromptHistory(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "mutate_prompt_history" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryStore) {
    server.send(ws, {
      type: "prompt_history_mutation_result",
      success: false,
      error: "Prompt history store not available",
    });
    return;
  }
  try {
    const entry = await server.promptHistoryStore.mutate({
      id: msg.id,
      text: msg.text,
      projectPath: msg.projectPath,
      projectId: msg.projectId,
      action: msg.action,
      isFavorite: msg.isFavorite,
      updatedAt: msg.updatedAt,
    });
    server.send(ws, {
      type: "prompt_history_mutation_result",
      success: entry != null,
      bridgeInstanceId: server.promptHistoryStore.bridgeInstanceId,
      revision: server.promptHistoryStore.revision,
      entry: entry ?? undefined,
      error: entry == null ? "Prompt not found" : undefined,
    });
    if (entry) broadcastPromptHistoryStatus(server);
  } catch (err) {
    server.send(ws, {
      type: "prompt_history_mutation_result",
      success: false,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function handleImportPromptHistoryV1(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "import_prompt_history_v1" }>,
  ws: WebSocket,
): Promise<void> {
  if (!server.promptHistoryStore) {
    server.send(ws, {
      type: "prompt_history_sync_result",
      success: false,
      error: "Prompt history store not available",
    });
    return;
  }
  try {
    const result = await server.promptHistoryStore.importEntries(
      msg.entries,
      msg.clientId,
      msg.clientName,
    );
    server.send(ws, {
      type: "prompt_history_sync_result",
      success: true,
      bridgeInstanceId: server.promptHistoryStore.bridgeInstanceId,
      revision: server.promptHistoryStore.revision,
      syncedAt: new Date().toISOString(),
      fullSnapshot: true,
      entries: result.entries,
    });
    broadcastPromptHistoryStatus(server);
  } catch (err) {
    server.send(ws, {
      type: "prompt_history_sync_result",
      success: false,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}
