# Flutter 3.50 / Dart 3.14 upgrade notes

Decisions made when moving from Flutter 3.47.9 to 3.50.0 (2026-11).

## Material / Cupertino

Flutter 3.50 deprecates `package:flutter/material.dart` and
`package:flutter/cupertino.dart`. The app now imports `package:material_ui`
and `package:cupertino_ui` (`dart fix --apply --code=migrate_design_widgets`).

Both libraries define classes with the same names, and the analyzer treats
them as different types. Three consequences:

- **Dependencies that still use the SDK libraries** (flutter_markdown,
  skeletonizer, talker_flutter, extended_image, flutter_painter and others)
  read the legacy `Theme` and `MaterialLocalizations`. `MaterialApp.builder` in
  `lib/main.dart` wraps the app in `MaterialUiCompatibilityBridge`, which maps
  the colour scheme and text theme for them. Remove it once those packages
  migrate.
- **Widgets built by those packages are legacy types.** A test that looks for
  the `SelectableText` created by flutter_markdown must import it from
  `package:flutter/material.dart` (see `test/markdown_style_test.dart`).
  `MarkdownStyleSheet.fromTheme` takes the legacy `ThemeData`, so
  `lib/theme/markdown_style.dart` builds the same defaults itself.
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

## Android toolchain

Flutter 3.50 refuses Gradle below 9.3.1, so the project moved to Gradle 9.5.0,
AGP 9.3.1, Kotlin 2.4.20 and google-services 4.6.0. Two workarounds live in
`apps/mobile/android/build.gradle.kts`:

- **`Project.exec` shim.** cargokit (irondash_engine_context,
  super_native_extensions) calls `project.exec`, which Gradle 9 removed. The
  root build script re-adds it as an extra-property closure backed by
  `ExecOperations`. Remove it when cargokit migrates.
- **Plugin `compileSdk` floor.** AGP 9 checks AAR metadata for library modules;
  super_native_extensions still compiles against API 31, so plugins below 36
  are raised to 36.

`android.builtInKotlin=false` and `android.newDsl=false` stay, because
bonsoir_android, device_info_plus, firebase_core, in_app_review,
package_info_plus, share_plus and wakelock_plus still apply the Kotlin Gradle
Plugin themselves. Flutter warns that this will fail in a future release.

## Not done

- **Swift Package Manager** stays disabled. irondash_engine_context,
  super_native_extensions, media_kit_video and media_kit_libs_ios_video have no
  SwiftPM support, and Flutter 3.50 warns about it on every command. CocoaPods
  trunk becomes read-only in December 2026, so this needs revisiting.
- **firebase 5 / purchases_flutter 11 / flutter_local_notifications 23** major
  upgrades are left for separate changes.
