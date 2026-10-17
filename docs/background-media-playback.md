# Background media playback

File Peek continues playback when the app loses focus or enters the background.
On phones, this means continuing video audio or music while another app is open
or the screen is locked. PiP is not included. Closing the preview stops playback;
this is not a persistent library or playlist service.

## Implementation

- Disable both the preview's lifecycle pause and media_kit Video's automatic
  background pause. Desktop playback remains managed by media_kit.
- iOS enables the audio background mode. Android uses audio_service's foreground
  media playback service, media button receiver, and shared Flutter engine.
- A single audio_service handler exposes the current preview player to OS
  controls. Capability URLs are never placed in lock-screen metadata.
- SessionMediaPlayer acquires audio focus before playback. It serializes shared
  audio-session operations and tracks ownership so an old player's teardown
  cannot deactivate a newer player. Pause, stop, completion and disposal release
  owned focus. Calls and unplugged headphones pause playback; resuming is explicit.
- Voice input pauses playback before starting microphone capture. Each new play
  configures the playback session again because speech recognition can change it.
- OS Stop pauses the loaded media and dismisses its active service state, allowing
  the preview's play button to restart. Closing the preview unloads the player.

No Bridge protocol changes are needed. Android and iOS require a new native build;
these dependency and manifest changes cannot be delivered solely as an OTA patch.

## Validation boundaries

Dart tests cover OS command forwarding, stopping and preview replacement. Native
builds check plugin integration. Real-device background/lock-screen playback,
interruptions, Bluetooth disconnects, and Android service lifecycle still require
runtime testing; simulator/build success alone does not establish these behaviors.
