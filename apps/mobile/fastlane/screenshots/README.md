# Store screenshots

The store set follows the Mint palette of `docs/install/`: `#101212` background,
`#9BDDC5` headlines, and large screenshots of the real app UI. The app itself
keeps its shipping colors. No app controls are drawn in the marketing artwork.

## Generate

On macOS with ImageMagick and the system fonts:

```sh
bash apps/mobile/fastlane/screenshots/compose.sh
bash scripts/feature-graphic/generate.sh
python3 scripts/store-preview/validate.py
python3 scripts/store-preview/generate.py
```

The final command creates a local review page in `/private/tmp/ccpocket-mint-review`.
Serve it with `python3 -m http.server 8900 --bind 127.0.0.1 --directory /private/tmp/ccpocket-mint-review`.

## Phone sequence

All raw phone captures live in `en-US/`, at 1206×2622, using the English dark
UI on iPhone 17 Pro. They are captured, with the Duo and iPad sets, from
[`apps/mobile_preview`](../../../mobile_preview/README.md) by
`scripts/store-preview/capture.mjs` (multi_device_preview on macOS). The frame and headline are localized into English,
Japanese, Simplified Chinese, and Korean. Final phone cards are 1320×2868.

| File | Actual preview scenario | Source |
| --- | --- | --- |
| 01_conversation | LP Conversation | LP capture |
| 02_recent_sessions | Recent Sessions | Fresh store capture |
| 03_approval_list | Approval List | LP capture |
| 04_git_review | Git Actions | Fresh store capture |
| 05_network_resilience | LP Network | LP capture |
| 06_imagegen | LP Imagegen | LP capture |
| 07_video | LP Video | LP capture |
| 08_audio | LP Audio | LP capture |

The same eight scenarios are also captured on the iPhone Duo cover display as
`en-US/duo_<key>.png` (1398×2034, portrait, dark, English). They show the Duo
control strip and are composed with the same Mint headlines at the
`APP_IPHONE_DUO` cover size.
Their frame is the closed iPhone Duo preset of multi_device_preview
(`MultiDevicePresets.iPhoneDuo`), kept as `assets/iphone-duo-closed-frame.svg`
and `assets/iphone-duo-closed-screen.svg` (screen outline with the camera
cutout): square on the hinge (left) side, rounded on the right. Update both
SVGs from the package's `presets.dart` if the preset changes.

LP capture instructions and media fixture limitations are in
[`scripts/landing-preview/README.md`](../../../../scripts/landing-preview/README.md).
The five iPad workspace captures (iPad Pro 13" M5 in landscape, light theme)
are composed with Mint headlines; their final size is 2752×2064. They represent iPad, not macOS.

## Outputs

- `store/{en-US,ja,zh-Hans,ko}/`: 8 phone and 5 iPad cards per locale; the
  canonical App Store upload path used by `fastlane ios metadata`.
- `store_duo/{en-US,ja,zh-Hans,ko}/`: 8 iPhone Duo cards per locale
  (1398×2034). Kept out of `store/` because fastlane deliver does not know the
  Duo sizes; `upload-metadata.yml` uploads them with asc as `APP_IPHONE_DUO`
  when `upload_duo_screenshots` is set (`scripts/store-review/upload-duo-screenshots.py`
  skips an identical remote set and replaces anything else).
- `../metadata/android/{en-US,ja-JP,zh-CN,ko-KR}/images/phoneScreenshots/`:
  the same 8 phone cards, shared with iOS by the maintainer's explicit choice.
- `docs/images/screenshots*.png`: four-card README banners.
- Android `featureGraphic.png`: 1024×500 Mint graphics in all four locales.

Phone bezels sit outside the screenshot with matched corner radii, preserving
the full UI. Store outputs have no alpha channel. The composer checks for required raw
captures before replacing generated files and removes obsolete phone cards.
The old `PPO_OUTPUT_DIR` illustration experiment is retired; the script rejects
that option so it cannot silently upload duplicate treatments.
`Framefile.json`, legacy `*.strings`, and `metadata/*/screenshots/` are not used
by this pipeline.
