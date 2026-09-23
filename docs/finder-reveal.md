# Show a project file in Finder

The native macOS file preview has a folder button with the tooltip **Show in
Finder / Finderで表示**. It is available while preview content is loading and
when an in-app preview is unavailable, including large videos and other files.
Finder selects the original file; the action does not download the file or launch
its associated application. The user can then use Finder / Quick Look / Open With.

## Locality and permissions

The app must connect to a Bridge on the same Mac, running as the same user.
The button is macOS-only. Other Bridge hosts are rejected when the button is
pressed, with a localized explanation; the UI does not guess locality from a URL.
This also works when the same Mac is reached through a non-loopback address.

`localhost` alone is not sufficient because SSH forwarding can target another
machine. For each operation the app writes a new 32-byte cryptographically random
token, encoded as 64 hex characters, into a temporary directory named
`ccpocket-finder-<random>/proof`. The Bridge checks:

- absolute proof path, expected file/directory naming, regular file, exactly 64 bytes;
- no following the final symlink, nonblocking open, descriptor-based stat/read;
- same filesystem device as its local temporary directory, same user ID;
- modification age at most 30 seconds (one second tolerance for future timestamps);
- token equality, followed by unlink to consume the proof once.

The Bridge then validates the target against its existing lexical and canonical
path allowlist. It invokes `/usr/bin/open` with the separate arguments
`['-R', canonicalPath]` and a five-second timeout. No shell is involved. The proof
is not a replacement for Bridge authentication or its file allowlist; it prevents
accidental actions on a different machine through an otherwise valid connection.

The app removes its temporary directory after success, rejection, timeout, or
preview disposal. Proofs expire on the Bridge even if the client process crashes.
Finder commands are never added to the offline queue or replayed on reconnect.
The app has a ten-second response timeout. A successful reply means the operating
system accepted the reveal command, not that Finder window visibility was observed.

No macOS sandbox entitlement changes or new native method channels are required.
The Bridge performs the desktop action after checking the app's local proof.

## Protocol and compatibility

New client message:

```text
reveal_file { projectPath, filePath, requestId, proofPath, proofToken }
```

New response:

```text
reveal_file_result { requestId, errorCode? }
```

`errorCode` is `not_local_mac`, `path_not_allowed`, or `reveal_failed`. An absent
error means success. Responses are correlated by request ID and routed to the
global action stream, not the chat transcript. Old Bridges' `unsupported_message`
response is handled by the Finder UI itself, which asks the user to update Bridge.
No protocol version bump is needed for this optional request/response extension.

## Validation

- Bridge: parser, locality proof, Finder argument handling, allowlist/symlink
  rejection and existing WebSocket tests: 396 passed; TypeScript check passed.
- Flutter: Finder Cubit lifecycle, timeout/old-Bridge/remote-host handling,
  button/error UI, existing media preview and file-browser regression tests:
  27 passed. Analysis has no errors or warnings (46 existing info-level findings).
- Independent review: no material findings.
- A temporary local proof was consumed and the real Finder command exited with
  success on macOS. Temporary verification files were subsequently removed.
- Remaining runtime coverage: no full sandboxed macOS app → Bridge → Finder UI
  verification. This session did not expose the dart-mcp app-launch tool, and
  Finder UI inspection failed with `cgWindowNotFound`. Do not interpret the
  command's success as a visual verification of Finder selection.
