# Flutter 3.50 / Dart 3.14 upgrade notes

Decisions made when moving from Flutter 3.47.9 to 3.50.0 (2026-11).

## Material / Cupertino

Flutter 3.50 deprecates `package:flutter/material.dart` and
`package:flutter/cupertino.dart`. The app now imports `package:material_ui`
and `package:cupertino_ui` (`dart fix --apply --code=migrate_design_widgets`).

Both libraries define classes with the same names, and the analyzer treats
them as different types. Three consequences:

- **Dependencies that still use the SDK libraries** (`flutter_painter` —
  `flutter_markdown`, `skeletonizer`, `talker_flutter`, and `extended_image`
  have been removed) read the legacy `Theme` and `MaterialLocalizations`.
  `MaterialApp.builder` in `lib/main.dart` wraps the app in
  `LegacyMaterialBridge` (`MaterialUiCompatibilityBridge`), which maps the
  colour scheme and text theme for them. Remove it once `flutter_painter`
  migrates or is replaced.
- **Widgets built by those packages are legacy types.**
  *(Note: `flutter_markdown` was later replaced by the in-repo
  `packages/markdown_kit` package built solely on `package:flutter/widgets.dart`;
  see [markdown-kit-architecture.md](markdown-kit-architecture.md).)*
- **Localization delegates.** gen-l10n still emits the `flutter_localizations`
  delegates in `AppLocalizations.localizationsDelegates`; they do not localize
  `material_ui` widgets. Use `appLocalizationsDelegates`
  (`lib/l10n/app_localizations_delegates.dart`) everywhere instead.

google_fonts 9 and flutter_slidable 5 were adopted because they are the first
versions built on `material_ui`.

## Direct native interop (FFIgen)

FFIgen for Objective-C is stable. `PlatformEnvironmentService` now reads
`NSProcessInfo.isiOSAppOnMac` and `UIDevice.userInterfaceIdiom` through
generated bindings instead of the `ccpocket/platform_environment` method
channel, and the Swift handler is gone.

- Config: `apps/mobile/tool/ffigen.dart`. Regenerate with
  `dart run tool/ffigen.dart` from `apps/mobile` (needs Xcode).
- Output: `lib/services/native/ios_environment_bindings.g.dart` (committed).
- Bindings are only called behind `Platform.isIOS`; web gets a stub through a
  conditional export.
- Tests replace the service with `PlatformEnvironmentService.debugOverride`.

Good next candidates are other request/response channels with plain values
(`ccpocket/clipboard`, `ccpocket/photo_library`). Channels that own native
views or push events are not.

## Native clipboard & desktop image drop

`super_clipboard`, `super_drag_and_drop`, and the `irondash_engine_context`
`dependency_overrides` have been replaced with direct platform implementations:

- `ccpocket/clipboard` (`ClipboardImageService`): `hasImage` and `readImage`
  implemented natively on iOS (Swift, alongside the existing iOS 16+
  `UIPasteControl` / `UIEditMenuInteraction` paths), Android (Kotlin), macOS
  (Swift), Windows (Win32 C++ + WIC), and Linux (GTK C++).
- `ccpocket/image_drop` (`DesktopImageDropService` / `DesktopImageDropTarget`):
  OS drag-and-drop image delivery on macOS (`NSDraggingDestination`), Windows
  (`WM_DROPFILES`), and Linux (`gtk_drag_dest_set`).

## Android toolchain

Flutter 3.50 refuses Gradle below 9.3.1, so the project moved to Gradle 9.5.0,
AGP 9.3.1, Kotlin 2.4.20 and google-services 4.6.0.

With `super_clipboard`, `super_drag_and_drop`, and `irondash_engine_context`
removed, both Gradle 9 workarounds in `apps/mobile/android/build.gradle.kts`
(the cargokit `Project.exec` shim and the `minPluginCompileSdk` override) are
no longer needed and have been removed.

`android.builtInKotlin=false` and `android.newDsl=false` stay, because
in_app_review, package_info_plus, share_plus and wakelock_plus still apply the
Kotlin Gradle Plugin themselves. Flutter warns that this will fail in a future
release.

## Not done

- **Swift Package Manager** stays disabled. `media_kit_video`,
  `media_kit_libs_ios_video`, and `speech_to_text` still block SwiftPM
  (`irondash_engine_context` and `super_native_extensions` have been removed),
  and Flutter 3.50 warns about it on every command. CocoaPods trunk becomes
  read-only in December 2026, so this needs revisiting.
- **firebase 5 / purchases_flutter 11 / flutter_local_notifications 23** major
  upgrades are left for separate changes.
