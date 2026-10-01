# Performance mode / パフォーマンスモード

Performance mode reduces Bridge → mobile delivery, as well as transcript rendering.
The default and each session's override are device preferences. Existing `settings_lite_mode`
and `settings_session_lite_mode:*` keys remain valid; no preference migration is needed.

## Delivery policy

Filtering runs per WebSocket **before JSON serialization** for live messages, legacy history,
past history, and sequenced snapshots/deltas. Thinking delta batches are skipped for these
clients; already queued batches pass through the same filter on flush.

- Keep assistant prose, user input/attachments, generated `ImageGeneration` results,
  approvals, questions, plans, errors, status and completion.
- Keep Explorer/file and explicitly requested image endpoints unchanged.
- Remove tool inputs, tool output bodies, incidental tool images (including simulator
  screenshots), thinking and tool summaries. Preserve a payload-free `tool_result` marker
  with its completion ID so questions answered on another client stay resolved.
- Preserve plan-file `Write` inputs because the approval UI derives plan text from them.
- Replace omitted live events with a small `session_activity` at most once per second per
  session/client. This reports observed activity, not proof that a stalled agent is healthy.
  Elapsed time in the UI is time observed by the client, not server execution duration.

Canonical agent/Bridge histories remain complete. Other clients and standard mode retain
full delivery. This does not reduce agent computation or all Bridge ingestion/image
registration work. Network savings depend on the share of tool payloads; these are not
claims about measured wall-clock speed or token cost.

## Protocol and switching

Existing `client_capabilities` accepts optional `performanceMode: boolean`,
`sessionPerformanceModes: Record<string, boolean>`, and `deliveryRevision: integer`.
Explicit `false` overrides a true default. New Bridges advertise `performance_mode_v1`.
When a revision is supplied, the Bridge responds with `performance_mode_state` carrying
that revision after applying preferences. Initial capabilities precede queued history
requests and are resent on reconnect.

The app waits for the latest acknowledgement, then invalidates affected transcript caches
and requests full history for open sessions. Invalidation includes sessions touched during
rapid toggles even when the final preference equals the starting preference. Older
acknowledgements cannot reset current history. Past-history deduplication resets at this
ordered boundary; local user entries are retained for pending input and attachment recovery.
Explorer/context metadata survives invalidation. Closed sessions fetch fresh history when
opened. Switching to standard therefore restores the complete transcript.

Filtered snapshots/deltas preserve canonical `fromSeq`/`toSeq` and entry sequence numbers
and set `filtered: true`. Clients accept intentional gaps only when the response begins at
or before the next expected sequence. Live activity can report the latest observed
`historySeq`; it is excluded from the transcript cache. Missing live sequence ranges are
recovered through the next filtered delta rather than falsely claiming to cache them.

Older Bridges ignore the added capability fields, retaining full delivery. The app applies
its local UI projection and shows an update notice; it does not claim network savings.
No new client message type is sent, so there is no new `unsupported_message` flow.
Older apps omit preferences and retain standard delivery.

## Verification

Tests cover non-mutating projections, large payload reduction, image/approval/plan retention,
completion markers, sparse cursors, independent client preferences, session overrides,
batch filtering, acknowledgement ordering and restoration after switching back. The local
WebSocket app test injects an already-sent old history frame before the ACK and verifies
that it cannot contaminate the new transcript.
