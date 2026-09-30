# Large Codex history loading

## Failure and scope

A long-running session with a 2.74 GB rollout crashed Bridge while reopening it.
The stdio JSONL reader accumulated a full RPC response, then called `join("")`
outside its exception boundary. A response larger than V8's string limit caused
an uncaught `RangeError: Invalid string length`. Turn pagination alone does not
bound response size: an autonomous turn can contain thousands of tool items.

This fix changes only Bridge's history loading and receive boundary. It does not
rewrite Codex rollouts, alter model context, or change the mobile protocol.

## Retrieval and display policy

- Read thread metadata without turns.
- Fetch turn metadata with `thread/turns/list`, `itemsView: "notLoaded"`, 50 turns
  per page. Preserve turn order, IDs, status, and timestamps for history/fork use.
- Fetch full items with `thread/items/list`, 10 items per page, ascending order.
  Associate each item with its turn before converting to existing history messages.
- Before retaining a tool item larger than 256 Ki UTF-16 code units (serialized
  JSON), shorten its long string fields to 16 Ki code units with a visible
  `[Truncated in Bridge history]` marker. Large inline images become text
  placeholders rather than invalid truncated base64. Nested tool details deeper
  than 20 levels are replaced with a visible omission note. Typed array structure
  is preserved. Normal-size tool items and user/assistant messages are unchanged.
- Bound retained history to 64 Mi UTF-16 code units. This is a display-data budget,
  not a byte or process-RSS guarantee; parsed objects, images, and transient copies
  also consume memory. Excessive history returns an explicit error.

Large tool outputs, arguments, diffs, and images may therefore be abbreviated in
the reopened history. The original full data remains in Codex. This policy does
not summarize or remove whole conversation turns. A concurrent new turn not
present in the metadata snapshot causes a retryable error instead of silent loss.

## Compatibility and failure isolation

If item pagination is unsupported (`-32601`), use full turn pagination with one
turn per page. If turn pagination is also unsupported, use legacy
`thread/read(includeTurns: true)`. A specific `-32602` unknown-variant rejection
of `notLoaded` also selects the full-turn path. Other RPC errors are not treated
as evidence of missing APIs.

All paths use a 64 Mi-code-unit per-record receive limit, checked before joining
both fragmented and single-chunk JSONL records. Allocation failures during join
are caught as well. A receive failure rejects pending RPCs/readiness, releases
partial buffers, and closes only that Codex transport; Bridge stays running.
There is no retry with a larger response after a size failure.

Consequently, a single huge item, a page over the receive limit, or an old server
that can only return an oversized full history fails safely instead of crashing
Bridge. Updating Codex is necessary if its older retrieval API cannot serve this
history within the limit. These limits do not guarantee arbitrary-size sessions
can be displayed.

API definitions were checked against local `codex-cli 0.157.0` generated bindings
and the [official App Server documentation](https://learn.chatgpt.com/docs/app-server).

## Discovery and delivery follow-up (2026-09-30)

Recent-session discovery uses a dedicated temporary app-server, including
workspace-filtered queries. A running turn or large history read on an active
session must not block the list. The temporary process is stopped on success
and failure. This costs an additional process initialization per query; it does
not interrupt the active session. Local session names override list metadata.

Continuation rollouts are matched by thread ID and the newest file modification
time. Metadata parsing also recognizes response-item user messages and expands
the tail window up to 4 MiB when the latest prompt is outside the initial 16 KiB.
The bounded window can still miss a prompt preceding more than 4 MiB of output.
History/image lookup preserves legacy filename matching without requiring cwd
or text metadata, but rejects an explicitly different thread ID in the header.

WebSocket clients can negotiate permessage-deflate, without context takeover,
with a 1 KiB threshold and compression level 3. This reduces transfer bytes at
the cost of compression CPU; clients that do not negotiate it remain supported.
It does not reduce the client's JSON parsing or rendering work.

PRs #247, #248, and #250 supplied these discovery, compression, and metadata
improvements. Their proposed 100-message/8 MiB-tail history shortcut is not used:
the existing mobile protocol treats the response as complete and has no older-page
cursor. Tail parsing also restarts ordinal user-message IDs, making rollback and
history merging unsafe. Full canonical history and the paginated RPC retrieval
above remain intact; the 100-entry in-memory window is only for live delta sync.

## Verification (2026-09-28)

- Unit coverage: item and turn pagination, compatibility fallbacks, cursor loops,
  unknown turn IDs, cumulative size limits, tool-detail compaction, and receive
  limits/allocation failures with pending requests and another working connection.
- Actual affected session: 280 turns / 20,534 source items became 30,238 history
  messages. A direct Bridge `CodexProcess` read completed in approximately 5.1 s;
  display JSON was approximately 49.5 MB, sampled peak RSS approximately 680 MiB.
- Full Bridge started on loopback port 8766. WebSocket `resume_session` succeeded
  in approximately 6.6 s including startup; `get_history` returned 30,248 messages
  including runtime state (49,198,290 bytes). `list_sessions` responded afterward,
  and `/health` returned 200 before and after. Total check: approximately 9.1 s.
- No model prompt was sent. The test session and test Bridge were stopped.
  Production port 8765 was not stopped or restarted.
