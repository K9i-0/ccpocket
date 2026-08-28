# Explorer file upload

ccpocket can upload project files from the operating system file picker into
the folder currently open in Explorer. The first version intentionally uses a
project-file workflow instead of provider-specific message attachments.

## User flow

1. Open Explorer and navigate to the destination folder.
2. Select **Upload files** in the AppBar.
3. Select up to 20 files in the native file picker.
4. Choose how name conflicts are handled. **Keep both** is the default;
   **Replace** and **Skip** are also available.
5. Review progress, cancel the operation, or retry from the failed file.
6. Explorer refreshes the current folder and highlights the last uploaded file.

The app limits a selection to 512 MiB per file and 1 GiB in total. Bridge also
enforces its own per-file limit, configured with
`BRIDGE_FILE_UPLOAD_MAX_SIZE_MB` (default: `512`). Pending uploads are also
limited to 2 GiB of aggregate reservations and four concurrent HTTP transfers;
these can be configured with `BRIDGE_FILE_UPLOAD_MAX_RESERVED_MB` and
`BRIDGE_FILE_UPLOAD_MAX_CONCURRENT`. Web is not exposed in this initial
implementation.

## Protocol and integrity

`prepare_file_upload` is sent through the authenticated WebSocket connection.
Bridge validates the project-relative destination, canonical directory, file
name, allowlist, conflict policy, and declared size. It returns a short-lived,
unguessable same-origin `/api/uploads/<token>` capability.

The app streams the file with HTTP `PUT`; file bytes are never embedded in a
WebSocket or Base64 message. Bridge creates a hidden temporary file during
preparation and retains its file handle and filesystem identity while both
sides calculate SHA-256. The app compares Bridge's byte count and digest, then
sends `finalize_file_upload`. Bridge re-hashes the pinned file and checks the
temporary file and destination directory identities before publishing it.

Incomplete, cancelled, expired, or integrity-failed uploads are removed. The
default keep-both policy publishes `name (1).ext`, `name (2).ext`, and so on
using exclusive filesystem links to avoid overwriting a concurrently-created
file. Finalization is idempotent for the lifetime of the capability so a lost
WebSocket response can be retried without creating a duplicate.

## Security boundary

Upload capabilities are available only after the authenticated WebSocket
preparation step and are restricted to the same Bridge origin. The Bridge pins
temporary-file and directory identities and re-hashes immediately before
publish to detect normal filesystem changes and watcher interference. As with
the rest of the local Bridge filesystem API, a hostile process running as the
same operating-system user is outside the isolation boundary: such a process
can modify files that the Bridge user can modify, including in the narrow
interval between final verification and the atomic rename.
