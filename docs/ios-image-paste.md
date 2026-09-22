# iOS image paste

iOS 16+ prompts for permission when an app reads another app's clipboard
programmatically. A custom menu item that subsequently calls
`SystemClipboard.read()` still takes that path, even in a native context menu.

Image attachment now uses an actual `UIPasteControl`, embedded with `UiKitView`.
The attachment sheet displays it directly; the long-press **Paste Image** action
opens a small sheet containing the same control (one additional tap). The normal
text paste item continues to use Flutter's `SystemContextMenu`.

The native view declares GIF, WebP, PNG and JPEG in its paste configuration. It
loads the first supported item from the `NSItemProvider` objects delivered to
`paste(itemProviders:)`, preserving the preferred original representation. It
must not re-read `UIPasteboard` after the user taps. The platform-view-specific
method channel returns `{bytes, mimeType}` or an error event. Disposing the Dart
widget removes its handler, and native loading uses a weak reference. The widget
also rejects events as soon as its route is no longer current, including during
the dismiss animation, so closing the sheet cannot attach a late image or pop
the underlying chat route. Duplicate delivery is suppressed. The
composer additionally checks the captured session and the five-image limit, and
uses the existing draft persistence path.

`ccpocket/clipboard.supportsPasteControl` gates view creation. iOS 15 and old
native runners missing this method retain the previous explicit paste action.
Other capability/read errors do not fall back to a direct clipboard read. The
image-availability probe remains metadata-only. The OS control itself manages
enabled state when the clipboard changes. Android/desktop behavior is unchanged.

This requires a new iOS native build for the new behavior; a Dart-only OTA update
on an older runner retains the old behavior. Permission-dialog colors belong to
iOS. The new app-owned paste control uses the Flutter theme's primary colors.

References:
- [Apple UIPasteControl](https://developer.apple.com/documentation/uikit/uipastecontrol)
- [Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views)

Verification should cover a clipboard image copied in another app with paste
permission still set to Ask, text-only/empty clipboard, cancellation during
loading, repeated taps, five-image limit, session changes, and old-runner fallback.
Mocked channel/widget tests cannot prove that iOS suppresses its permission alert.

## Device check

Install a new native build, with **Paste from Other Apps** left at **Ask** in
iOS Settings. Copy a screenshot in another app, then open the chat attachment
menu and tap the system **Paste** button. Expect one image attachment, a closed
sheet, and no permission alert. Repeat through long-press **Paste Image** (which
opens the small paste sheet). With only text on the clipboard, the image paste
control should be disabled while normal text paste still works.

The Flutter tests cover method-channel delivery, duplicates, errors/retry,
old-runner/iOS fallback, and cancellation during the sheet's reverse animation.
RunnerTests exercise native item-provider loading and format preservation without
reading the real clipboard. Simulator UI inspection covers native-control layout;
the cross-app permission behavior still needs the device check above.
