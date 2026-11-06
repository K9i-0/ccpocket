# Floating keyboard composer and frosted input

The chat composer follows iPad floating (undocked / split) keyboards, and it is
drawn as frosted glass over the chat in every mode.

## Why a native channel

Flutter reports `viewInsets.bottom == 0` for iPad floating keyboards. The engine
(`FlutterKeyboardInsetManager`) only insets docked keyboards, and it ignores
the frame notifications sent while the keyboard is dragged. Dart cannot find a
floating keyboard on its own.

`AppDelegate.swift` registers `FloatingKeyboardTracker` on the event channel
`ccpocket/floating_keyboard`. On the first listen, it adds an invisible view to
the Flutter view and pins it to `keyboardLayoutGuide` with
`followsUndockedKeyboard = true` (iOS 15+, the app's minimum). UIKit updates the
guide on every frame while the keyboard is dragged (about 16 ms apart on an
iPad mini). Each event is `{x, y, w, h, viewW, viewH}` in the Flutter view's
logical points.

`FloatingKeyboardService` (Dart) publishes a frame only while it is floating:
it is taller than 40 pt and does not span the bottom edge of the view. If the
keyboard is hidden, only the bottom safe-area strip is left, and a docked
keyboard spans the full width at the bottom. Neither counts as floating.

### Compatibility

- Android, desktop and web never subscribe. They always use the docked layout.
- An older iOS binary that receives a Dart-only Shorebird patch has no native
  tracker. Its listen fails, the error is swallowed, and the layout stays
  docked. Following floating keyboards therefore needs a store build.

## Layout (`FloatingComposerLayout`)

The Claude and Codex session screens place three slots in one
`CustomMultiChildLayout`:

- the chat content
- the bottom bars: Lite activity, background tasks, Codex recovery and goal
- the composer: the queued input panel and `ChatInputWithOverlays`

The composer always stays in the same tree position, so the draft, the
attachments and the overlay state survive mode changes. Two things to keep in
mind when changing it:

- **Visual changes must not change the widget structure.** Any change of
  widget type or tree shape rebuilds the text field, which drops focus and
  closes the keyboard.
- **Changes to `initState` or fields need a hot restart.** A hot reload keeps
  stale closures.

| Mode | Content | Bars | Composer |
|---|---|---|---|
| Docked (default) | Full height, behind the bars and the composer | Above the composer | Bottom |
| Floating keyboard and composer focused | Down to the bars | Bottom | Just above the keyboard (vertical only, full pane width) |
| No composer (approval / AskUserQuestion) | Down to the bars | Bottom | — |

- The content receives `FloatingComposerStatus.obscuredBottom`. The message
  list adds it to its bottom padding, so the newest message stays reachable
  while older ones scroll behind the glass. The scroll-to-bottom button is
  offset by the same amount.
- While a slash, `$` or `@` completion is open, the floating composer stays at
  least 228 pt below the top, so the options (which grow upward) stay visible.
- While floating, the keyboard follows ChatGPT's behavior:
  - Scrolling the chat keeps it open.
  - Tapping the chat area closes it. Taps on inner buttons and links still win.
  - Swiping the composer down closes it.

## Frosted glass

`_FloatingComposerFrame` draws a `BackdropFilter` blur and a gradient tint. The
values live in `ComposerGlassStyle` (the "Clear" preset chosen on device:
light 0.30 / 0.40, dark 0.05 / 0.18, blur 20). Fields and buttons inside use
`FrostedComposer.fill`, which applies 72% opacity.

The blur is always clipped to the composer: an unclipped `BackdropFilter`
blurs the whole screen. The docked glass draws only a top edge.
