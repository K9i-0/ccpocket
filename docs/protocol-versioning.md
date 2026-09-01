# App / Bridge protocol versioning

## Purpose

App and Bridge package versions are released independently. Compatibility is
therefore negotiated with an integer protocol range instead of inferred from
the package versions.

The version fields have distinct responsibilities:

- `appVersion` / `bridgeVersion`: diagnostics and update guidance
- `minimumProtocolVersion` / `protocolVersion`: breaking wire compatibility
- `protocolCapabilities`: additive behavior within a compatible protocol
- persisted schema versions: local data migration only
- Claude/Codex adapters: upstream CLI and history compatibility

## Protocol range

`protocolVersion` is the highest protocol understood by a peer.
`minimumProtocolVersion` is the oldest protocol it still supports. Peers select
the highest version in the overlap of their ranges.

Clients released before range negotiation are treated as supporting protocol 1
only. A Bridge that omits both fields from `session_list` is also treated as a
protocol 1 Bridge. This preserves the final v1 transition path without using
package-version comparisons as a wire contract.

Current range:

| Peer | Minimum | Maximum |
| --- | ---: | ---: |
| App | 1 | 1 |
| Bridge | 1 | 1 |

The App advertises its range in `client_capabilities`. The Bridge advertises its
range in `session_list` and `/version`.

## Incompatibility behavior

When ranges do not overlap:

1. Bridge sends `errorCode: "incompatible_protocol"` and closes the WebSocket
   with application close code `4406` after receiving client capabilities.
2. App rejects an incompatible `session_list`, publishes the same structured
   error locally, closes with `4406`, and does not reconnect automatically.
3. No project or session state from the incompatible response is accepted.
4. Malformed or partial protocol declarations fail closed with the same error.
5. Replay-safe operations already sent during negotiation return to the
   offline queue so a manual reconnect after updating the Bridge can retry them.

The current v1 Bridge still sends initial metadata before receiving client
capabilities for compatibility with older clients. The current App sends only
`client_capabilities` until it has accepted the Bridge range; queued commands
are flushed after negotiation. Protocol v2 must also make the Bridge wait and
must not send session or project data until negotiation succeeds.

## Change policy

The following require a new protocol version:

- removing or renaming a field
- changing the meaning or type of a field
- making an optional field required
- changing request/response correlation semantics
- changing error or retry semantics in a way that older peers cannot handle

The following can remain in the same protocol when older peers can safely
ignore them:

- adding an optional field
- adding an opt-in server message guarded by `protocolCapabilities`
- adding a client command that returns `unsupported_message` on older Bridges

Every compatibility fallback must name the protocol or persisted schema it
supports and the release condition for deleting it.

## Bridge distribution requirement

Generated launchd/systemd services run `@ccpocket/bridge@1`, so restarts remain
within the current major. `doctor` warns about legacy services that still track
the unbounded npm `latest` tag, and running `ccpocket-bridge setup` rewrites the
service. Interactive one-shot install commands may continue to use `latest`.

Before publishing v2, update the generated service major deliberately and
stage the package under a separate tag such as `next` until the App rollout is
ready.

## Protocol v2 readiness checklist

- [x] pin v1 auto-start installations to the v1 npm major
- [x] expose protocol compatibility in the connection/update UI
- [x] hold App commands until Bridge compatibility is accepted
- [x] freeze legacy/current v1 contract fixtures in both test suites
- make negotiation complete before normal WebSocket messages
- require request IDs and scope metadata for correlated operations
- add App v2/Bridge v2 contract fixtures
- verify both cross-major combinations fail with an update instruction
- retain persisted-data migrations independently from wire compatibility
