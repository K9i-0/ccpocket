# Sketch attachments

An ordinary composer attachment opens the existing zoomable preview. Its
**Draw on image** action opens `SketchScreen` with the original image as a fixed
background. Existing sketch thumbnails open the editor directly.

Attaching replaces the same attachment slot with a flattened PNG. Cancellation
preserves the previous attachment. The composer resolves the source by byte
identity after previewing so pending removals cannot redirect an edit to another
image; results from an old session are ignored.

## Local draft format

`DraftService` keeps the flattened image and an optional sketch JSON document in
the existing per-session image draft. This change adds no Bridge messages.
Only the flattened PNG is sent to the agent.

- Version 1 remains the format for blank-canvas sketches and still loads.
- Version 2 adds `backgroundImage`, the base64-encoded original image bytes.
  Canvas dimensions and drawable coordinates are saved separately.
- Version 2 is deliberately rejected by older editors, rather than silently
  reopening the annotations on a white background.

The background never enters the editable drawable list. The painter keeps
annotations in a separate layer, so erase, delete, and undo cannot alter the
source image. Removing every annotation can still export the original background.

Images decode at at most 1536 pixels on their longest side; the editing canvas
preserves that aspect ratio and uses an 800-unit longest side. The output PNG
has a 1536-pixel longest side. Animated input uses its first decoded frame.
The original encoded image stays in the local draft for future edits, and the
editor disposes its decoded image when closed, including late load completion.
