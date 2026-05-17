# Linux Desktop Support

## Status: In progress / experimental

This document captures the implementation plan and risks for adding a Linux
desktop build of the Flutter app. The initial target should be an experimental
artifact, not a fully supported platform.

Tracking context:

- Issue #86 asks for a Linux version of CC Pocket.
- The Bridge Server already supports Linux hosts, including systemd user service
  setup.
- The Flutter app has `android`, `ios`, `macos`, `web`, and now `linux`
  platform directories.
- A Linux desktop app may improve the "mobile + desktop" CC Pocket workflow, but
  it does not solve the broader Codex Desktop / CLI session sync limitations
  tracked in Issue #25.
- PR #89 provided the first Linux bring-up and tester validation on Linux Mint
  22.3. The maintainer-side implementation keeps the contributor's validation
  and credit while reworking the patch into the MVP scope described here.

## Goals

- Produce a Linux desktop build that can launch and connect to a Bridge Server.
- Keep iOS, Android, macOS, and web behavior unchanged.
- Treat Linux-only features and failures as best-effort until maintainers have a
  reliable Linux GUI validation path.
- Add CI coverage for Linux build and basic launch smoke tests.
- Document unsupported or degraded features clearly in the app and release
  notes.

## Non-Goals

- Full official Linux support in the first release.
- Linux packaging for every distribution.
- Solving Codex Desktop / CLI upstream sync behavior.
- Replacing the existing macOS release and updater path.
- Supporting mobile-only services on Linux when the upstream plugins do not
  support Linux.

## MVP Scope

The MVP should prove that the Linux desktop app can support the core CC Pocket
workflow without taking on the full distribution and maintenance burden.

MVP requirements:

- The app has a generated Linux runner under `apps/mobile/linux/`.
- `flutter build linux --release` passes on a supported Ubuntu CI runner.
- The release bundle launches on at least one real Linux desktop environment.
- The app can connect to a Bridge Server.
- A Codex or Claude session can be started from the Linux app.
- Core chat input, streaming output, permission approval, and final result
  display work.
- Session list, settings, Git diff, Explorer, and prompt history do not crash in
  the normal disconnected/connected flows.
- Local prompt history storage works through `sqflite_common_ffi`.
- Unsupported mobile/macOS-only services are safely unavailable and do not block
  startup.
- Release notes clearly mark the build as experimental.

MVP exclusions:

- Automatic app updates.
- Polished Linux app icon and launcher metadata.
- Native package installation (`.deb`, AppImage, Flatpak).
- Push notifications.
- Purchases / RevenueCat support.
- Shorebird patches.
- QR scanning.
- Distro-specific support commitments.

The excluded items are still desirable before broader distribution. They should
not block a first experimental MVP artifact if the core Bridge/session workflow
is usable and the limitations are documented.

## Implementation Plan

### 1. Add the Linux Flutter platform

Generated the Linux runner from the existing Flutter project:

```bash
cd apps/mobile
flutter create --platforms=linux .
```

Review generated files before committing. Keep generated runner changes minimal
unless the app needs a custom window title, app id, icon, or plugin setup.

Expected path:

- `apps/mobile/linux/`

### 2. Make the local database work on Linux

The app currently imports `package:sqflite/sqflite.dart` directly in
`DatabaseService`. The mobile/macOS implementation works through sqflite's
registered platform backend, but Linux needs an FFI-backed SQLite factory.

Use `sqflite_common_ffi` for Linux desktop. The current implementation keeps the
existing sqflite backend for mobile/macOS and switches only Linux to the FFI
factory through a small platform adapter.

- Add `sqflite_common_ffi` as an app dependency.
- Import shared database types from `package:sqflite_common/sqlite_api.dart`
  where possible.
- Keep iOS, Android, and macOS on the existing sqflite backend.
- On Linux, initialize sqflite FFI before opening the database through
  `databaseFactoryFfi`.
- Avoid relying on `getDatabasesPath()` for Linux. Use `path_provider` and store
  the database below the application support directory.

Recommended storage shape:

```dart
final supportDir = await getApplicationSupportDirectory();
final dbDir = Directory(path.join(supportDir.path, 'databases'));
await dbDir.create(recursive: true);
final dbPath = path.join(dbDir.path, 'ccpocket.db');
```

Linux runtime package requirement:

```bash
sudo apt-get -y install libsqlite3-0 libsqlite3-dev
```

The CI workflow should install these packages before `flutter build linux`.

### 3. Guard mobile-only and macOS-only services

Linux should not execute services that are only available or meaningful on
mobile/macOS.

Review these areas:

- Firebase Messaging / push notification registration.
- Shorebird patch checks.
- RevenueCat purchases and supporter catalog.
- QR scanning and camera access.
- macOS native app update checks.
- macOS native app install banners.
- App icon switching.
- In-app review.

Preferred behavior:

- Unsupported services return an explicit unavailable state.
- Unsupported UI controls are hidden or disabled with existing copy patterns.
- Initialization failures are caught and logged without blocking app startup.
- Feature availability is determined by platform helpers or service-level
  capability checks, not scattered `Platform.isLinux` checks in widgets.

### 4. Reuse desktop layout behavior

The app already treats Linux as a desktop platform in some layout helpers. Keep
that direction:

- Use width-based adaptive layout, not OS-specific layout branches.
- Use pointer-sized resize handles on Linux.
- Keep macOS-specific window chrome and update UI scoped to macOS only.

Linux should generally behave like the existing wide desktop workspace, minus
macOS-only window integrations.

### 5. Add a Linux release path only after validation

Do not extend the macOS DMG workflow directly. Create a separate Linux workflow
after the build is stable.

Recommended first artifact:

- A `.tar.gz` of the Flutter Linux release bundle.

Later candidates:

- AppImage.
- `.deb`.
- Flatpak.

Release tags should be separate from macOS tags if the artifacts have different
build and validation requirements, for example `linux/v1.2.3+45`.

Before publishing a polished user-facing artifact, also prepare the Linux
desktop integration details. These are desirable but not required for the first
experimental MVP artifact:

- Configure the Linux app icon instead of relying on the generated Flutter
  default.
- Ensure the `.desktop` launcher metadata uses the CC Pocket name, icon, and app
  id consistently.
- Verify that the installed app appears correctly in common desktop launchers.
- Decide whether the first package is only a downloadable archive or whether it
  should install launcher metadata through a package format such as `.deb`,
  AppImage, or Flatpak.

### 6. Plan Linux app updates

The current app update implementation is macOS-specific and looks for macOS
release tags and DMG assets. Linux should have its own update strategy instead
of reusing the macOS updater path.

This is not required for the first experimental MVP artifact as long as release
notes clearly tell users how to download newer builds.

Options:

- GitHub Releases check for `linux/v*` tags and Linux artifact names.
- AppImage update support, if AppImage becomes the chosen package format.
- Distribution package updates through `.deb` repositories or Flatpak, if those
  become official distribution channels.

Recommended first step:

- Add a Linux-aware update check that can report a newer GitHub Release without
  trying to self-install it.
- Open the release page or downloaded artifact externally.
- Keep automatic self-update out of scope until the packaging format is stable.

The update UI should make the platform explicit. Linux builds should not show
macOS DMG update copy, macOS native updater state, or macOS release links.

## Verification Plan

### Static and unit checks

Run the existing Flutter checks:

```bash
dart analyze apps/mobile
cd apps/mobile && flutter test
```

Add Linux-specific unit tests around:

- database factory selection
- Linux database path construction
- unsupported service states
- app update service returning no update on non-macOS platforms

### CI build smoke

On `ubuntu-latest`:

```bash
sudo apt-get update
sudo apt-get -y install libsqlite3-0 libsqlite3-dev ninja-build libgtk-3-dev
cd apps/mobile
flutter pub get
flutter build linux --release
```

This catches runner, CMake, and native plugin breakage.

### Headless launch smoke

Use Xvfb to verify that the built Linux app starts without crashing:

```bash
xvfb-run -a apps/mobile/build/linux/x64/release/bundle/ccpocket
```

The smoke test should impose a timeout and treat early process exit as failure
unless the app exits with an expected diagnostic.

### UI automation

For repeatable checks, prefer Flutter integration tests first:

```bash
cd apps/mobile
flutter test integration_test -d linux
```

Suggested initial coverage:

- app launches to the session list or setup state
- settings can be opened
- a server URL can be entered
- offline / disconnected state renders
- wide workspace layout does not crash
- Git / Explorer entry points render in mocked or disconnected state

Marionette can be used for local and deeper E2E verification once the Linux debug
app exposes a VM service in a reliable way.

### Human validation

Because Linux desktop environments vary, experimental releases should require
human validation before being treated as usable.

Ask testers to report:

- distribution and version
- desktop environment and display server (`X11` or `Wayland`)
- Flutter version
- `flutter build linux --release` result
- launch result
- Bridge connection result
- Codex / Claude session start result
- Explorer, Git, Diff, prompt history, and settings checks
- unsupported feature behavior

## Risk Areas

### Native plugin coverage

Some dependencies have Linux implementations; others are mobile/macOS/web only.
The build may fail or the app may crash at runtime if a plugin registers
unexpectedly or is initialized on an unsupported platform.

Mitigation:

- Add service-level platform guards.
- Keep unsupported services lazy where possible.
- Add Linux CI build coverage before publishing artifacts.

### SQLite runtime dependency

Linux needs SQLite development/runtime packages available during build and
runtime. A binary tarball may not work on minimal distributions without
`libsqlite3`.

Mitigation:

- Document `libsqlite3` as a runtime requirement.
- Prefer a packaging format that can declare system dependencies when moving
  beyond a tarball.

### Desktop environment differences

Clipboard, drag-and-drop, notifications, file pickers, window behavior, and
system tray behavior can differ across distributions and display servers.

Mitigation:

- Keep the first release focused on core chat / Bridge workflows.
- Mark notifications and OS integrations as best-effort.
- Collect distro-specific reports before calling Linux supported.

### Release maintenance cost

Linux artifacts introduce a separate build, packaging, and support path.

Mitigation:

- Keep Linux experimental until CI and external testers consistently pass.
- Do not promise support for distribution-specific packaging until the tarball
  path is stable.

## Acceptance Criteria for Experimental Release

- `apps/mobile/linux/` exists and builds on CI.
- `flutter build linux --release` passes on `ubuntu-latest`.
- Headless launch smoke passes under Xvfb.
- Database reads/writes work through `sqflite_common_ffi`.
- Unsupported services do not block app startup.
- At least one tester has validated the release on a real Linux desktop.
- Release notes clearly mark the artifact as experimental.

## Acceptance Criteria for Supported Release

Do not promote Linux beyond experimental until all of the following are true:

- A maintainer or trusted contributor can regularly validate Linux GUI behavior.
- CI covers build, launch smoke, and core integration tests.
- The app has a documented packaging and update strategy.
- Unsupported feature behavior is intentional and covered by tests.
- At least two common Linux environments have been validated.
