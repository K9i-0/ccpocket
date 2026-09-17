# GLB file previews

The file peek UI requests `.glb` files using `read_model_file` with the same
projectPath, filePath, and optional requestId scoping as read_file. The Bridge
reuses the existing canonical path authorization and MediaStore capability URL
transport. Responses use file_content with kind `model`, MIME
`model/gltf-binary`, sizeBytes, and mediaUrl. GLB files larger than 20 MiB return
`model_too_large`; the client also enforces this limit while streaming downloads.

A dedicated request prevents older Bridges from reading binary GLB as text.
Their unsupported_message response is handled in file peek with the existing
Bridge update guidance. Existing read_file/read_media_file behavior is unchanged.

flutter_scene 0.23.0 loads downloaded GLB bytes at runtime. Native runners enable
Flutter GPU; Flutter is pinned to 3.47.2. No model build-time conversion or
Blender installation is required. External resource URIs are rejected; export
self-contained GLB files with embedded textures. Redirects are disabled.

The first version shows a static model with orbit, pinch/wheel zoom, bounds-based
framing (including portrait aspect ratios), and reset. Imported material warnings
are surfaced. Arbitrary Blender shaders, every glTF extension, and animation
playback are not guaranteed. `.blend` conversion and `.gltf` sidecar resolution
are outside this feature. A file size limit is not a GPU memory budget: complex
models and large decoded textures can still be expensive.

## Validation

- Bridge: 1,165 existing/parser tests pass (six socket-dependent tests rerun
  outside the sandbox), plus four new handler cases for GLB success, size limit,
  unsupported format, and symlink escape.
- Flutter: 1,835 tests passed on the full run; the new wire-message assertion
  was corrected and all four GLB tests then passed. Four existing skips.
- Static analysis: no errors or warnings; existing informational lints remain.
- iOS simulator debug build succeeded. Through a separate test Bridge, opened
  GLB from Explorer and visually verified rendering, orbit, pinch zoom and reset.
- Android, desktop and web runtime rendering have not been exercised here.
