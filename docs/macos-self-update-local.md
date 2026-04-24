# macOS Self-Update Validation

This runbook covers two Sparkle validation paths:

- Production update failure diagnosis without running CD again
- Fast local feed validation without waiting for the GitHub Release workflow

## Production update failure diagnosis

Use this when a published macOS release appears in the app, but pressing the
update button fails on the user's Mac. The useful failure detail is emitted by
Sparkle on the client machine, not by the GitHub Actions build log.

### 1. Install an older signed release

Install a previous GitHub Release DMG, such as `macos/v1.70.1+122` or
`macos/v1.70.0+121`, into `/Applications/CC Pocket.app`.

Do not run the app directly from the mounted DMG. Sparkle installation behavior
depends on the app being installed at a normal writable location.

### 2. Reset Sparkle check state

```bash
bash scripts/macos-reset-sparkle-state.sh
```

This clears the appcast override and `SULastCheckTime` so the installed app
checks the production feed immediately.

### 3. Stream Sparkle logs

In a separate terminal:

```bash
bash scripts/macos-stream-sparkle-logs.sh stream
```

Then launch `/Applications/CC Pocket.app` and press the app's update button.

If the update fails, capture the recent log window:

```bash
bash scripts/macos-stream-sparkle-logs.sh show 20m
```

Look for:

- `[CCPocket][Sparkle] manual update requested`
- `Sparkle requested feed URL`
- `will download update`
- `did download update`
- `will extract update`
- `did extract update`
- `will install update`
- `update cycle aborted`
- `update cycle finished`

### 4. Interpret the failure point

- Appcast fetch failure: feed URL, GitHub Pages, or network problem
- Signature failure: `sparkle:edSignature`, `SUPublicEDKey`, or replaced asset
- Extraction failure: DMG/archive format, notarization, or quarantine problem
- Installation failure: `/Applications` permissions or app/helper signing
- Relaunch failure: bundle path, Launch Services, or post-install relaunch

CI logs are still useful for confirming build, signing, notarization, release
upload, and appcast generation. They do not explain client-side installation
failures after a user presses the update button.

If Sparkle logs `bad URL` and the URL looks like `https:localhost/`, inspect the
installed app's `SUFeedURL`:

```bash
plutil -p "/Applications/CC Pocket.app/Contents/Info.plist" | grep SUFeedURL
```

An `SUFeedURL` value of just `https:` means the URL was truncated by `.xcconfig`
comment parsing. In `.xcconfig`, write `https:/$()/host/path` instead of
`https://host/path` so the `//` is not parsed as a comment.

If Sparkle logs the following around `will install update`, the sandboxed app
is missing Sparkle's installer launcher setup:

```text
Failed to make auth right set
Failed to submit installer job
Failed to gain authorization required to update target
```

For sandboxed apps, the app `Info.plist` must set
`SUEnableInstallerLauncherService` to `true`, and the app entitlements must
allow Sparkle's `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and
`$(PRODUCT_BUNDLE_IDENTIFIER)-spki` mach lookup names.

## 1. Build a newer local update archive

```bash
bash scripts/macos-build-local-update.sh 1.69.0 119
```

This writes a zipped app bundle and `update.json` to
`tmp/sparkle-local-feed/`.

## 2. Generate a local appcast

```bash
bash scripts/macos-generate-local-appcast.sh \
  tmp/sparkle-local-feed \
  http://127.0.0.1:8899
```

By default this generates an unsigned `appcast.xml`, which is only useful for
basic feed wiring checks.

To validate with the same EdDSA signature path used by production, provide the
private Sparkle key and `sign_update`:

```bash
SPARKLE_PRIVATE_KEY="$SPARKLE_PRIVATE_KEY" \
SIGN_UPDATE_PATH="/path/to/sign_update" \
bash scripts/macos-generate-local-appcast.sh \
  tmp/sparkle-local-feed \
  http://127.0.0.1:8899
```

Apps that contain `SUPublicEDKey` will reject unsigned appcasts or mismatched
signatures. Use the signed local appcast when validating download, verification,
extract, install, and relaunch behavior.

## 3. Serve the feed

```bash
bash scripts/macos-serve-local-feed.sh tmp/sparkle-local-feed 8899
```

## 4. Point the app at the local feed

```bash
bash scripts/macos-set-feed-override.sh http://127.0.0.1:8899/appcast.xml
```

This writes the override to the app's `UserDefaults` and resets the last
Sparkle check timestamp.

To clear the override later:

```bash
bash scripts/macos-set-feed-override.sh
```

## 5. Run the installed app and verify

- Install/run an older `CC Pocket.app` from `/Applications`
- Open the app
- Wait for the existing in-app update banner, or use the Settings update row
- Tap `Update`

## Notes

- Local validation uses a simple zip archive so you can iterate without DMG
  creation or notarization.
- Sparkle cannot install updates when the app is run directly from a mounted
  disk image or while app translocation is in effect. Use `/Applications`.
- Production releases use
  `https://k9i-0.github.io/ccpocket/sparkle/appcast.xml` as the appcast URL.
  The macOS release workflow signs the release DMG with the
  `SPARKLE_PRIVATE_KEY` GitHub Actions secret and deploys the generated
  `docs/sparkle/appcast.xml` artifact to GitHub Pages.
