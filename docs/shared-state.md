# Shared state: settings and data kept on the Bridge

Some of what the app used to keep only in its own SharedPreferences belongs
to the Bridge's machine (its projects, its sessions) rather than to a device.
That data now lives on the Bridge and every device connected to it sees the
same values. Pins use their own messages ([pin-sync.md](pin-sync.md)) because
they are sets changed one member at a time.

## What is shared

| Shared key | Value | Local copy (SharedPreferences) |
| --- | --- | --- |
| `claude_session_settings/<sessionId>` | object | `claude_session_settings_<sessionId>` |
| `seen_at/<sessionId>` | ISO timestamp | `unseen_sessions_seen_at` (one map) |
| `codex_profile/<projectKey>` | profile name, `""` = cleared | `codex_profile_by_project_v1` (one map) |
| `writable_root_history` | string list | `new_session_additional_writable_root_history` |
| `new_project_parent` | path | `new_project_parent_<bridgeUrl>` |
| `session_start_defaults.<provider>` | object | `session_start_defaults_<provider>_v1` |
| `session_start_defaults.last_provider` | provider | `session_start_defaults_last_provider_v1` |
| `auto_rename.claude` / `auto_rename.codex` | bool | `autoRenameClaudeSessions` / `autoRenameCodexSessions` |

New-session defaults and the auto-rename switches are fully shared: there is
no per-device override. Everything else in the app's settings stays on the
device (appearance, list display, connection data, notifications).

The app still reads from the local copies. They are what it shows before the
Bridge answers and what it uses with a Bridge that has no shared state.

## Storage

`~/.ccpocket/shared-state.json` (`SharedStateStore`,
`packages/bridge/src/shared-state-store.ts`):

```json
{ "version": 1, "storeId": "<uuid>", "entries": { "<key>": { "value": …, "updatedAt": 0 } } }
```

- The Bridge does not interpret values. A key is at most 512 characters, a
  value at most 32 KB of JSON and never `null`.
- `name/id` keys are per session or project: at most 500 per `name`, and the
  least recently written one is evicted for a new one. Keys without `/` are
  never evicted; beyond 200 of them a new key is refused.
- `storeId` identifies the content's lineage. It is created with the file and
  changes when the file is lost or unreadable.
- Changes are written once per burst (200 ms), atomically.
- `CCPOCKET_SHARED_STATE_FILE` overrides the path. `scripts/e2e-env.sh bridge`
  sets it to a temp file per port.

## Protocol (additive, protocol 1)

The Bridge announces `shared_state_v1` in `protocolCapabilities`. The app
sends nothing below without it.

Client:

```ts
{ type: "get_shared_state" }
{ type: "set_shared_state"; key: string; value?: unknown; mode?: "max"; mutationId?: string }
{ type: "seed_shared_state"; entries: Record<string, unknown> }
```

Server (each opt-in through `supportedServerMessages`):

```ts
{ type: "shared_state"; storeId: string; entries: Record<string, unknown> }
{ type: "shared_state_changed"; key: string; value: unknown; mutationId?: string }
{ type: "shared_state_seeded"; storeId: string; adopted: string[] }
```

- `get_shared_state` is answered with the complete `shared_state`.
- `set_shared_state` stores the value (`null` or missing deletes the key) and
  is answered by a `shared_state_changed` broadcast to every client, the
  sender included, repeating `mutationId`. `value` is what the Bridge now
  stores, which may differ from what was sent: with `mode: "max"` a stored
  string that is not smaller is kept, and a refused key reports `null`.
- `seed_shared_state` adopts the entries whose keys the Bridge does not have.
  It never evicts; entries beyond a limit are skipped. When something was
  adopted, `shared_state` is broadcast to every client; then the sender gets
  `shared_state_seeded`.

## App behavior (`SharedStateSync`)

`apps/mobile/lib/services/shared_state_sync.dart` owns the exchange; each
kind of data is an adapter (`shared_state_adapters.dart`, plus one in
`SettingsCubit` and one in `UnseenSessionsCubit`) that reads the local copy
and takes over a remote value. Writers call `SharedStateSync.instance?.set`
after writing the local copy.

- **Connect.** Once per connection, when `session_list` arrives with the
  capability, the app sends `get_shared_state`. The snapshot replaces the
  local copies.
- **Pending writes.** A local write is pending until its echo (same
  `mutationId`) arrives. While a key is pending, values for it from the
  Bridge are ignored, in changes and in snapshots, so the echo of an earlier
  write or another device's older value cannot revert it. Pending writes are
  not put in the offline queue; they are sent again after every snapshot,
  which covers writes made offline and writes lost with a broken connection.
  They do not survive an app restart.
- **Migration, once per store.** The app remembers the `storeId`s it has
  seeded (`shared_state_seeded_store_ids_v1`). For a store it has not seeded,
  local entries the snapshot lacks are offered with `seed_shared_state`, and
  nothing local is removed. The store is marked only when
  `shared_state_seeded` arrives, so a connection lost in between offers them
  again. So for each key the first device to bring a value wins; a value that
  only a later device had, for a key the Bridge already has, is replaced by
  the Bridge's.
  A Bridge store the device has not met adopts the copies the device last
  saw, including ones that came from another Bridge.
- **After that the Bridge is the truth.** For a seeded store, a local entry
  the snapshot lacks was removed elsewhere and is removed locally.
- **Read marks (`seen_at`).** Session IDs do not outlive a Bridge run, so
  these are not offered as a seed. Writes use `mode: "max"` and remote values
  are applied only when later than the local one, so a replayed older mark
  cannot make a session unseen. Dropping records of ended sessions stays
  local (the Bridge's per-name limit bounds the store).
- **Session settings.** `ClaudeSessionSettingsStore.save` writes and shares
  only when the merged settings differ from the stored ones, because every
  device saves what a running session reports.
- **Auto-rename.** Only a switch the user has changed is offered as a seed,
  so a device on the default does not override another device's choice.
- **Codex profile.** Clearing a profile stores `""` instead of deleting the
  key, so an older copy on another device is not offered again.

Known limit: a device with more than 500 stored
`claude_session_settings_*` entries offers them all, the Bridge adopts 500,
and the rest are removed locally at the next snapshot. Only the saved resume
settings of those sessions are lost.

## Compatibility

- New app + Bridge without `shared_state_v1`: nothing is sent and the data
  stays on the device as before. An `unsupported_message` for the three
  client messages is also dropped silently. Delete this path when the minimum
  supported Bridge has the capability.
- Old app + new Bridge: the app neither sends the messages nor opts in, and
  keeps its own local data.
