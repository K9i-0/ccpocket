# macOS Self-Update Local Validation

This flow is for fast local validation of the Sparkle wiring without waiting
for the GitHub Release workflow.

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

This generates an unsigned `appcast.xml` for local verification. Production
publishing should still use a signed Sparkle appcast in CI.

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
