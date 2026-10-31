# Pending input lifetime and idle reclamation

Pending questions and permissions are presented in arrival order. The mobile
client maintains an actionable queue separately from the visible transcript:
resolving one request must never revive an expired historical approval. History
restoration and live events share this queue. Explicitly non-blocking questions
survive turn completion and idle status; blocking actions require a current
approval wait when restoring history. Live requests may arrive before that status.
Malformed questions retain the existing decline-only approval behavior.

There is no new protocol message. Existing request IDs, provider-specific answer
keys, and optional `isBlocking` metadata remain compatible with older peers.

Bridge checks idle sessions once per minute. `BRIDGE_IDLE_SESSION_TTL_MINUTES`
sets their retention period (default 15 minutes, minimum 1). The existing limit
of 30 idle sessions also applies. Both policies exempt sessions with queued
input (either provider; see `input-delivery.md`), pending questions or permissions, or automatic recovery waiting.
Protected sessions can therefore exceed the limit. Once protection ends, expiry
uses the last recorded activity time; it does not start a new grace period.
Active sessions are never reclaimed by this mechanism. Reclamation removes the
live process, not persisted provider conversation history. The interval is
unreferenced and is cleared when the manager is destroyed.

## Answered question transcripts

Answered questions retain their question context and submitted choices in the
mobile transcript. The Bridge preserves structured answer results in its in-memory
history, including Performance mode. Reconnection to that running Bridge restores
these panels. Provider disk history (past sessions or after a Bridge restart) does
not yet restore answered-question panels; this change does not add durable answer
storage. Codex secret answers are sent to the provider but redacted before replay.

Claude permission requests are registered before being announced. Both resolution
and answer-result events must follow delivery of the request to every listener,
including listeners that answer synchronously.

Queued prompts (Codex and Claude) retain their client message IDs through delivery. Matching
prefers client IDs over provider turn UUIDs. For echoes without client IDs, a unique
pending input may match by text and image count. Claude's acknowledged local input
may also match once while awaiting its provider UUID. Failed inputs, distinct
known sent turns, and ambiguous identical inputs must not be folded together.
