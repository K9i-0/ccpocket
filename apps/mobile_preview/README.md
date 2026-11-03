# ccpocket_preview

Runs ccpocket on several devices side by side in one macOS window with
[multi_device_preview](https://pub.dev/packages/multi_device_preview), for
layout checks and store screenshots. It is a separate host app so that the
shipping macOS app keeps its entitlements and signing.

```sh
cd apps/mobile_preview
flutter run -d macos
```

The store screenshot workflow is described in
`.claude/skills/update-store/references/screenshots.md`.
