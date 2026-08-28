# Request correlation for scoped Bridge operations

## Problem

The mobile app can keep multiple session screens and state objects alive at the
same time. A Bridge response published on a broadcast stream must therefore
identify the request and scope that produced it. Message type alone is not a
safe correlation key.

Without correlation, a response for project B can update a screen for project
A, and an older response can overwrite a newer request for the same project.

## Protocol contract

Every request/response operation scoped to a project, session, or UI action
uses the following metadata where applicable:

- `requestId`: unique per client request. The Bridge echoes it unchanged.
- `projectPath`: the normalized request scope. The Bridge echoes the requested
  project path on both success and operation-specific failure responses.
- `sessionId`: required on errors caused by a session-scoped request.
- `protocolCapabilities`: `session_list` advertises
  `project_request_correlation_v1` when these fields are supported.

Until that capability is observed on the current transport, the client omits
the new `requestId` field. Capabilities are cleared on every disconnect so an
offline request can be replayed safely even if an older Bridge later appears at
the same address.

The initial migration covers:

- file lists and file content
- Git diff, diff images, and all Git commands
- worktree list/removal
- screenshot capture

## Mobile acceptance rules

1. A response with `requestId` is accepted only by the matching pending
   request.
2. Its returned scope must also match the pending scope.
3. Only the latest request for a replaceable view scope may update that view.
4. A legacy response without `requestId` is accepted only when exactly one
   compatible request is pending. Ambiguous legacy responses are discarded.
   Legacy requests are serialized across the entire response family, not just
   within one project. A refresh requested for an in-flight scope discards that
   response and sends one fresh request, because response generations cannot
   otherwise be distinguished.
5. Session screens never consume unscoped errors as session transcript events.
   Global workflows subscribe to the global error stream explicitly.
6. Project-scoped failures use the same operation-specific response type as a
   success, carrying the original correlation metadata and an `error`. The
   mobile adapter also maps correlated generic errors from transitional Bridge
   versions back to their operation stream so pending UI state always clears.

These rules preserve compatibility with an older Bridge for the common
single-request case without reintroducing cross-session data corruption.

## Testing requirements

The shared routers and state owners collectively cover:

- two projects with responses delivered in reverse order
- stale response after a newer request for the same scope
- mismatched `projectPath` with a matching message type
- legacy unscoped response with one pending request
- ambiguous legacy response with multiple pending requests
- legacy requests for different projects serialized by response family
- transport disconnect followed by a retry
- correlated operation errors clearing pending state
- session error delivery to only the addressed session
