# iOS image paste

iOS 16+ prompts for permission when an app reads another app's clipboard
programmatically. An unclassified custom menu item that subsequently calls
`SystemClipboard.read()` still takes that path, even in a native context menu.

There are two native paste paths:

- The attachment menu retains its original icon-and-label row and opens a small
  sheet containing `UIPasteControl` (one additional tap).
- Long-press **Paste Image** uses a native `UIEditMenuInteraction` action with
  `UIAction.Identifier.paste`. Tapping that item attaches immediately, with no
  intermediate sheet. UIKit's suggested text actions remain in the menu.

Flutter's custom system-menu items currently use an unclassified `UIAction`
(`identifier: nil`), which does not identify the callback as a secure paste.
The dedicated image menu therefore attaches its own edit-menu interaction to the
active `UITextInput` responder using public UIKit APIs. It captures item providers
synchronously inside the `.paste` action, before returning to Dart. Request IDs
cancel obsolete menus/reads; closing the toolbar or leaving the route rejects
late results. No Flutter engine patch, swizzling, or hidden-button activation is
used. Text-only clipboards continue to use Flutter's `SystemContextMenu`.

Apple DTS confirms secure paste for taps on a `.paste` menu action, but notes that
sliding a held finger to the action or selecting it with a keyboard can still
show permission prompts. This is not a promise to suppress prompts for every
input gesture or OS version.

The native button declares GIF, WebP, PNG and JPEG in its paste configuration.
Both paths share an item-provider reader that loads the first supported item
from the `NSItemProvider` objects delivered to
`paste(itemProviders:)` (button) or the `.paste` action (menu), preserving the
preferred original representation. The button must not re-read `UIPasteboard`;
the menu must capture providers inside its native paste action. The
platform-view-specific
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
- [Apple DTS: secure paste menu actions and gesture limitations](https://developer.apple.com/forums/thread/823447)
- [Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views)

Verification should cover a clipboard image copied in another app with paste
permission still set to Ask, text-only/empty clipboard, cancellation during
loading, repeated taps, five-image limit, session changes, and old-runner fallback.
Mocked channel/widget tests cannot prove that iOS suppresses its permission alert.

## Device check

Install a new native build, with **Paste from Other Apps** left at **Ask** in
iOS Settings. Copy a screenshot in another app, then open the chat attachment
menu, choose **Paste from Clipboard**, then tap the system **Paste** button.
Expect one image attachment, a closed sheet, and no permission alert. Repeat
through long-press **Paste Image**: lift the finger after opening the menu, then
tap the item. Expect immediate attachment with no extra sheet. With only text
on the clipboard, the image paste
control should be disabled while normal text paste still works.

The Flutter tests cover method-channel delivery, duplicates, errors/retry,
old-runner/iOS fallback, cancellation during the sheet's reverse animation, and
direct context-menu delivery/cancellation without an intermediate sheet.
RunnerTests exercise native item-provider loading and format preservation without
reading the real clipboard. Simulator UI inspection covers native-control layout;
the cross-app permission behavior still needs the device check above.

On the iOS 27 simulator, the direct menu appeared without an intermediate sheet,
but displayed **Paste** rather than the requested **Paste Image** title. Native
tests confirm the action retains its supplied title and `.paste` identifier;
presentation-time title handling has not been established. Actual native item
selection, image delivery, and alert suppression still require the device check.
