# PDF file preview

PDF files (case-insensitive `.pdf`) use the existing `read_file` request.
Bridge responds with `file_content`, `kind: "pdf"`, an empty `content`,
`mimeType: "application/pdf"`, `sizeBytes`, and a `mediaUrl`.
The URL uses the existing MediaStore capability, expiry, path authorization,
file identity checks and HTTP range support; PDF bytes are not sent over WebSocket.

Flutter renders the document using pdfrx, including scrolling and zooming.
Retry requests fresh file metadata and a fresh capability URL. The existing
file download action remains available. Missing URLs from older Bridges show
an update hint instead of presenting PDF bytes as source code; Bridge errors
continue through the normal file error UI. No new client message is required.
Older apps do not render the new PDF kind and should be updated along with Bridge.

This adds a native PDFium dependency, so mobile distribution requires a full
app build rather than only a Dart OTA patch. PDF rendering must also be checked
on target devices before release.
