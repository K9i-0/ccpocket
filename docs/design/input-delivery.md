# Input delivery while a turn is running (steer / queue)

Claude and Codex now share one model for messages sent while the agent is
working. Each message chooses a delivery:

| Delivery | Codex | Claude |
| --- | --- | --- |
| `steer` | `turn/steer` into the running turn | SDK user message with `priority: "next"`; Claude Code injects it at the next safe point without interrupting the turn |
| `queue` | Held in the Bridge queue slot and sent after the turn | Same slot; sent when the Claude process becomes idle |

The app sends the delivery from **Settings → Messages during a turn** (default:
`queue`). Long-pressing the send button while the agent is working opens a sheet
with both choices. The queued message panel (steer / edit / cancel) is the same
for both providers.

## Wire protocol

- `input.delivery?: "steer" | "queue"` is optional. When it is omitted the Bridge
  keeps the previous behavior: Codex queues, Claude queues inside the SDK and
  interrupts the running turn.
- `update_queued_input`, `cancel_queued_input`, `steer_queued_input`,
  `conversation_queue` and the session summary `queuedInput` are no longer
  limited to Codex.
- The Bridge advertises `input_delivery_v1` in `protocolCapabilities`. The app
  only uses the queue panel and sends `delivery` for Claude when the capability
  is present. With an older Bridge, Claude keeps the immediate transcript entry
  and the interrupt behavior; Codex is unaffected because older Bridges ignore
  the field. Remove the fallback when protocol v2 makes the capability required.

## Bridge behavior

- The queue has one slot per session (`SessionInfo.queuedInput`). A `queue`
  delivery is rejected with `input_rejected` (`Queue is full`) when the slot is
  occupied. A `steer` delivery is attempted even when the slot is occupied.
- A queued or steered message is added to the in-memory history only when it is
  delivered to the provider, and is broadcast as `user_input` with the client
  message ID. `input_ack.queued` reports whether the message ended up in the slot.
- If steering fails (for example the Codex turn ended first), the message is held
  in the slot instead of being dropped.
- Claude: `SdkProcess.steerInput` resolves the waiting prompt generator with a
  `priority: "next"` message without changing the status. If the generator is not
  waiting, the message is buffered and yielded on the next pull; if the turn has
  ended by then it is sent as a normal prompt. The queue slot drains when the
  Claude process reports `idle`.
- Queued input protects the session from idle reclamation for both providers.
