# Release Card

Generate X announcement images from App Store release notes.

```bash
npm run release-card
```

Inputs:

- English: `apps/mobile/fastlane/metadata/en-US/release_notes.txt`
- Japanese: `apps/mobile/fastlane/metadata/ja/release_notes.txt`
- Version: `apps/mobile/pubspec.yaml`

Outputs:

- `tmp/release-card/release-card-v<version>-en.png`
- `tmp/release-card/release-card-v<version>-ja.png`

Options:

```bash
node scripts/release-card/generate.mjs --locales ja --version 1.87.0
node scripts/release-card/generate.mjs --out-dir /tmp/release-card
```

The generator uses Playwright via `npx playwright screenshot`, matching the other image-generation scripts in this repository.
