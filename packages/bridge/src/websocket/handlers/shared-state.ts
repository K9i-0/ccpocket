import type { WebSocket } from "ws";
import type { ClientMessage } from "../../parser.js";
import type { SharedStateValue } from "../../shared-state-store.js";
import type { BridgeWebSocketServer } from "../../websocket.js";

function snapshotMessage(server: BridgeWebSocketServer): Record<string, unknown> {
  return {
    type: "shared_state",
    storeId: server.sharedStateStore.storeId,
    entries: server.sharedStateStore.snapshot(),
  };
}

export async function handleGetSharedState(
  server: BridgeWebSocketServer,
  ws: WebSocket,
): Promise<void> {
  await server.sharedStateStore.init();
  server.send(ws, snapshotMessage(server));
}

/**
 * The stored value is broadcast to every client, the sender included: that
 * echo (with its `mutationId`) is how the sender learns the write landed,
 * and what it must show when the Bridge kept another value.
 */
export async function handleSetSharedState(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "set_shared_state" }>,
): Promise<void> {
  const stored = await server.sharedStateStore.set(
    msg.key,
    (msg.value ?? null) as SharedStateValue | null,
    { max: msg.mode === "max" },
  );
  server.broadcast({
    type: "shared_state_changed",
    key: msg.key,
    value: stored,
    ...(msg.mutationId ? { mutationId: msg.mutationId } : {}),
  });
}

export async function handleSeedSharedState(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "seed_shared_state" }>,
  ws: WebSocket,
): Promise<void> {
  const adopted = await server.sharedStateStore.seed(msg.entries);
  if (adopted.length > 0) {
    console.log(`[ws] Adopted ${adopted.length} shared state entr(ies) from a client`);
    server.broadcast(snapshotMessage(server));
  }
  server.send(ws, {
    type: "shared_state_seeded",
    storeId: server.sharedStateStore.storeId,
    adopted,
  });
}
