# Pins shared through the Bridge

Pinned sessions and pinned (favorite) projects used to live only in each
app's SharedPreferences, so every device had its own set. The Bridge now owns
them and every client of that Bridge sees the same pins.

## Storage

`~/.ccpocket/pins.json` (`PinStore`, `packages/bridge/src/pin-store.ts`):

```json
{
  "version": 1,
  "sessions": [{ "provider": "codex", "sessionId": "…", "projectPath": "/repo" }],
  "projects": ["/repo"]
}
```

- A session pin is identified by `provider:sessionId`. `projectPath` is the
  path the pinning client listed the session under; it only lets the app
  rebuild its own key and is not used for matching.
- `projects` holds the app's project keys as opaque strings.
- At most 1000 sessions and 1000 projects.
- `CCPOCKET_PINS_FILE` overrides the path. `scripts/e2e-env.sh bridge` sets it
  to a temp file per port so that a test Bridge never touches the real pins.

## Protocol (additive, protocol 1)

Client:

```ts
{ type: "get_pins"; seed?: { sessions?: PinnedSession[]; projects?: string[] } }
{ type: "set_session_pin"; provider; sessionId; projectPath; pinned: boolean }
{ type: "set_project_pin"; projectPath: string; pinned: boolean }
```

Server (opt-in through `supportedServerMessages: ["pins"]`):

```ts
{ type: "pins"; sessions: PinnedSession[]; projects: string[] }
```

- `pins` always carries the complete state. It answers `get_pins` and is
  broadcast to every opted-in client after each `set_*_pin`, including the
  sender and including a change that altered nothing.
- Changes are single-item deltas, not whole-set replacements, so a client with
  stale state cannot overwrite what another client did.
- `list_recent_sessions` is unchanged: the app still sends `pinnedSessions` /
  `pinnedProjects` from its state ([recent-sessions-pinned.md](recent-sessions-pinned.md)).
  Only the source of that state moved.

## Migration: the first client with pins wins

The store is *seeded* once `pins.json` exists. The app offers its local pins
as `get_pins.seed` on every connect:

- Unseeded Bridge and a non-empty seed: the seed becomes the Bridge's pins and
  is broadcast to all clients.
- Unseeded Bridge and an empty or missing seed: the answer is empty and the
  store stays unseeded, so a later client can still bring its pins.
- Seeded Bridge: the seed is ignored. That client's local pins are replaced by
  the Bridge's. Pins that only existed on the second and later devices are
  lost; this was accepted for simplicity.
- Any `set_*_pin` seeds the store, so unpinning everything is not undone by
  the next client's seed.

## App behavior

- `SessionListCubit` sends `get_pins` on every `connected` state (changes by
  other clients are missed while disconnected) and replaces its pins when
  `pins` differs from its state. Session pins are compared by
  `provider:sessionId`, so the echo of its own toggle changes nothing.
- A toggle updates the state at once, sends the `set_*_pin` delta, and writes
  SharedPreferences as before. A delta sent while disconnected waits in the
  offline queue and is replayed after reconnecting.
- SharedPreferences (`session_list_pinned_session_keys_v1`,
  `session_list_pinned_project_paths_v1`) is now a copy of what the device
  last saw: shown before the Bridge answers, used with a Bridge that has no
  shared pins, and offered as the seed.
- When `pins` adds a pin for a session that is not among the loaded ones, the
  first page is requested again so the Bridge returns it. A pin on a loaded
  session needs no request, and with the pinned-only filter every change
  re-requests.
- Each Bridge has its own pins. After switching to another Bridge the app
  shows that Bridge's pins once it answers; a Bridge that is still unseeded
  adopts the pins the app last saw.

Known limit: two quick toggles can briefly show the first one's confirmed
state before the second confirmation arrives. The list is not reloaded for it.

## Compatibility

- New app + Bridge without shared pins: the three client messages return
  `unsupported_message`, which `BridgeService` drops silently. Pins stay on
  the device exactly as before. Delete this path when the minimum supported
  Bridge includes `get_pins`.
- Old app + new Bridge: the app never sends the messages and does not opt in
  to `pins`, so it keeps its own local pins and does not see shared ones.
