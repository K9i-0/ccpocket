# Landing page captures

The LP uses screenshots of CC Pocket's real widgets, with curated fixture
conversations. No chat bubbles, network indicators, or playback controls are
redrawn in HTML. Crops on the LP open the original full screenshot.

## Capture

1. Run `bash scripts/landing-preview/prepare.sh` (requires ffmpeg).
2. Run `node scripts/landing-preview/serve.mjs`. This serves only two media
   fixtures on `127.0.0.1:8898`, with HTTP range support. The generated files
   stay in `/private/tmp/ccpocket-lp-media`; they are not bundled with the app.
3. Launch `apps/mobile/lib/main.dart` in debug mode on an iPhone simulator.
   Use Dart MCP when available, otherwise `flutter run -d <simulator-id>`.
4. Connect Marionette to the VM Service URI. Set `ccpocket.setLocale` to `en`
   and `ccpocket.setTheme` to `dark`.
5. Open `ccpocket.mock.openScenario` with one of the names below (or use the
   **Landing Page** section in Mock Preview). Between captures, call
   `ccpocket.popToRoot`.
6. Capture with `xcrun simctl io <simulator-id> screenshot <output.png>`.
   For Video, tap `file_peek_video_viewport` to reveal the controls before
   capturing. The sample clip and audio should both report a 12s duration.
7. Convert with `cwebp -q 88 -resize 804 0 <output.png> -o <asset.webp>`.
8. Restore the locale/theme, clear any `simctl status_bar` override, and stop
   the app and fixture server after capture.

| Scenario | Actual UI | LP asset |
| --- | --- | --- |
| LP Conversation | CodexSessionScreen | conversation.webp |
| LP Network | Network Resilience store scenario + real pending-delivery panel | network.webp |
| LP Imagegen | CodexSessionScreen + generated-image chat group | imagegen.webp |
| LP Video | CodexSessionScreen + File Peek video player | video.webp |
| LP Audio | CodexSessionScreen + File Peek audio player | audio.webp |
| Approval List (store scenario) | Session list with inline approvals | sessions.webp |

LP scenarios are registered only in debug mode. The app's actual theme and
controls remain unchanged. Imagegen uses the existing generated-landscape
fixture from `mock_image_data.dart`; the short MP4 and WAV are local playback
fixtures. Preview fixtures do not invoke an AI provider.

The large-screen image `workspace-en.webp` comes from the existing raw iPad
`fastlane/screenshots/en-US/ipad_05_dark_workspace.png` capture. Its visible
caption identifies it as iPad. New phone captures use iPhone 17 Pro (1206×2622).

To use another fixture host, set `--dart-define=LP_MEDIA_BASE_URL=<origin>`.
For Android emulators, the host loopback is typically `http://10.0.2.2:8898`.
The default host is for an iOS simulator on the same Mac.

## Playback verification

The iPhone 17 Pro simulator loaded both 12s fixtures. Video playback advanced
and paused successfully. Audio loaded its duration and responded to mute and
play/pause controls, but its playback position stayed at zero in this simulator.
Audio playback therefore remains unverified on a physical device; the LP image
captures the real loaded audio player, not a simulated playback state.
