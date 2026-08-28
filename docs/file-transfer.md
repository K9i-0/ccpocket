# Project File Download and Sharing

## Scope

CC Pocket can download any regular file visible in Explorer from the active
project, show transfer progress, cancel an in-flight transfer, and pass the
completed file to the platform share sheet. On iOS and Android the share sheet
also provides Save to Files and Open In actions. The action is available on
iOS, Android, macOS, and Windows. It is hidden on Web and Linux, where the
current sharing backend cannot reliably hand off arbitrary files.

Uploading files is intentionally outside this protocol. Uploads require a
separate write-destination, overwrite, and agent-conflict design.

## Protocol

### Client to Bridge

```json
{
  "type": "prepare_file_download",
  "projectPath": "/workspace/project",
  "filePath": "build/report.pdf",
  "requestId": "download-request-id"
}
```

`filePath` is project-relative. Absolute paths and paths that resolve outside
`projectPath` are rejected even when another configured Bridge root would allow
them.

### Bridge to Client

```json
{
  "type": "file_download_ready",
  "requestId": "download-request-id",
  "filePath": "build/report.pdf",
  "fileName": "report.pdf",
  "mimeType": "application/pdf",
  "sizeBytes": 12345,
  "downloadUrl": "/api/media/<capability-token>"
}
```

Failures use the existing `error` message with the original `requestId` and
one of these error codes:

- `file_download_not_allowed`
- `file_download_not_found`
- `file_download_not_file`
- `file_download_too_large`
- `file_download_unavailable`
- `file_download_failed`

An older Bridge returns `unsupported_message` for
`prepare_file_download`; the app presents a Bridge update hint.

## Transfer

The returned URL is an unguessable, expiring capability created only after the
authenticated WebSocket request passes path validation. The existing HTTP
media store streams the file without Base64 encoding and provides
`Content-Length`, byte ranges, and cancellation when the client disconnects.

The app writes the response incrementally to its temporary directory. It never
holds the complete file in memory. A partial file is deleted after cancellation
or failure, and completed temporary files are removed after the platform share
sheet finishes.

## Security

The Bridge performs both lexical and canonical containment checks against the
requested project and `BRIDGE_ALLOWED_DIRS`. The media store pins the validated
file identity (device and inode), registered size, and canonical path. HTTP
serving opens with `O_NOFOLLOW` where available and rejects files whose path,
identity, or size changed after registration. The app independently rejects a
different `Content-Length` or any stream that exceeds the prepared size.

The default maximum downloadable file size is 512 MiB. It can be changed with
`BRIDGE_FILE_DOWNLOAD_MAX_SIZE_MB`; invalid or non-positive values use the
default.
