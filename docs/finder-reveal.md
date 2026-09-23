# Show a project file in Finder

The native macOS file preview has a folder button with the tooltip **Show in
Finder / Finderで表示**. It is available while preview content is loading and
when an in-app preview is unavailable, including large videos and other files.
Finder selects the original file; the action does not download the file or launch
its associated application. The user can then use Finder / Quick Look / Open With.

## Locality and permissions

The app must connect to a Bridge on the same Mac. The button is macOS-only.
The UI does not guess locality from the Bridge URL, so a non-loopback address
can also work for a local Bridge.

For each operation the app binds a one-use TCP listener to `127.0.0.1` on an
OS-assigned port and creates a cryptographically random 32-byte token encoded
as 64 hex characters. The new request carries the port and token. The Bridge
connects only to its own `127.0.0.1`, sends no data, and checks that the peer
returns exactly those 64 bytes and closes the connection within 1.5 seconds.
Extra data, invalid tokens, connection errors and timeouts fail closed.
The app closes its listener on the first connection and disposes all sockets
on completion, timeout or preview closure.

This guards against accidental actions on another machine, including ordinary
SSH-forwarded Bridge connections. It is not authentication or a guarantee
against deliberately configured reverse forwarding. Existing authenticated
Bridge access and file permissions remain necessary.

The original temporary-file proof failed for the released sandboxed app:
macOS app-container protection can deny an external process access to its
`Data/tmp`, even under the same user. The new proof avoids that access.
Release builds need `com.apple.security.network.server` for the listener;
Debug/Profile already had it. The listener is bound only to loopback.
See Apple's [app-container protection](https://developer.apple.com/documentation/xcode/protecting-local-app-data-using-containers)
and [server entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.server).

The Bridge then validates the target against its existing lexical and canonical
path allowlist. It invokes `/usr/bin/open` with the separate arguments
`['-R', canonicalPath]` and a five-second timeout. No shell is involved. The proof
is not a replacement for Bridge authentication or its file allowlist; it prevents
accidental actions on a different machine through an otherwise valid connection.

Finder commands are never added to the offline queue or replayed on reconnect.
The app has a ten-second response timeout. A successful reply means the operating
system accepted the reveal command, not that Finder window visibility was observed.

## Protocol and compatibility

New client message:

```text
reveal_file_local { projectPath, filePath, requestId, proofPort, proofToken }
```

Existing response:

```text
reveal_file_result { requestId, errorCode? }
```

`errorCode` is `not_local_mac`, `path_not_allowed`, or `reveal_failed`. An absent
error means success. Responses are correlated by request ID and routed to the
global action stream, not the chat transcript. Old Bridges' `unsupported_message`
response is handled by the Finder UI itself, which asks the user to update Bridge.
The Bridge retains the legacy `reveal_file` temporary-file handler for old clients.
New clients use the new message type so older Bridges explicitly request an update.
No protocol version bump is needed for this optional request/response extension.

## Validation

- Bridge: socket proof, parser, Finder argument handling, allowlist/symlink
  rejection and WebSocket tests: 400 passed; TypeScript check passed.
- Flutter: Finder lifecycle, socket cleanup, timeout, unsupported-message and
  error UI tests: 5 passed. Targeted analysis has no errors or warnings
  (three existing info-level findings).
- Independent protocol/security review: no material findings.
- `node --import tsx scripts/verify-finder-sandbox.mts` compiles the production
  Dart proof into an ad-hoc signed macOS app. It uses the release sandbox and
  network entitlements, omitting the unrelated restricted Keychain entitlement
  and expanding the bundle ID. It checks failure without the server entitlement,
  success with it against the production Bridge verifier, and one-use behavior.
- Full installed app → Bridge → visible Finder selection remains outside this
  automated check. Do not interpret socket verification as a visual Finder test.
