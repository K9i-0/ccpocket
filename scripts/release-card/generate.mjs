#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, "../..");
const width = 1600;
const height = 900;

const localeConfig = {
  "en-US": {
    notePath: "apps/mobile/fastlane/metadata/en-US/release_notes.txt",
    lang: "en",
    outputLocale: "en",
    eyebrow: "New Release",
    titlePrefix: "CC Pocket",
    sectionTitle: "What's new",
    tagline: "Codex and Claude from your phone",
  },
  ja: {
    notePath: "apps/mobile/fastlane/metadata/ja/release_notes.txt",
    lang: "ja",
    outputLocale: "ja",
    eyebrow: "新バージョン",
    titlePrefix: "CC Pocket",
    sectionTitle: "今回の変更点",
    tagline: "スマホから Codex と Claude を操作",
  },
};

function usage() {
  console.log(`Usage: node scripts/release-card/generate.mjs [options]

Options:
  --locales en-US,ja      Locales to render. Default: en-US,ja
  --version 1.86.1        Override version. Default: apps/mobile/pubspec.yaml
  --out-dir tmp/release-card  Output directory. Default: tmp/release-card

Examples:
  node scripts/release-card/generate.mjs
  node scripts/release-card/generate.mjs --locales ja --version 1.87.0
`);
}

function readArg(name) {
  const index = process.argv.indexOf(name);
  if (index === -1) return undefined;
  return process.argv[index + 1];
}

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  usage();
  process.exit(0);
}

const requestedLocales = (readArg("--locales") ?? "en-US,ja")
  .split(",")
  .map((locale) => locale.trim())
  .filter(Boolean);
const version = readArg("--version") ?? readVersion();
const outputDir = path.resolve(root, readArg("--out-dir") ?? "tmp/release-card");
const iconPath = path.resolve(root, "docs/images/cc-pocket-icon.png");
const tempDir = path.resolve(scriptDir, ".tmp");

mkdirSync(outputDir, { recursive: true });
mkdirSync(tempDir, { recursive: true });

for (const locale of requestedLocales) {
  const config = localeConfig[locale];
  if (!config) {
    const supported = Object.keys(localeConfig).join(", ");
    throw new Error(`Unsupported locale "${locale}". Supported locales: ${supported}`);
  }

  const noteFile = path.resolve(root, config.notePath);
  const notes = parseNotes(readFileSync(noteFile, "utf8"));
  if (notes.length === 0) {
    throw new Error(`No release notes found in ${noteFile}`);
  }

  const htmlPath = path.resolve(tempDir, `${locale}.html`);
  const outputPath = path.resolve(outputDir, `release-card-v${version}-${config.outputLocale}.png`);
  writeFileSync(htmlPath, renderHtml({ config, notes, version, iconPath }), "utf8");

  console.log(`Rendering ${locale}: ${path.relative(root, outputPath)}`);
  const result = spawnSync(
    "npx",
    [
      "playwright",
      "screenshot",
      "--viewport-size",
      `${width},${height}`,
      pathToFileURL(htmlPath).href,
      outputPath,
    ],
    { cwd: root, stdio: "inherit" },
  );

  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    throw new Error(`Playwright screenshot failed for ${locale}`);
  }
}

rmSync(tempDir, { recursive: true, force: true });
console.log("Done.");

function readVersion() {
  const pubspec = readFileSync(path.resolve(root, "apps/mobile/pubspec.yaml"), "utf8");
  const match = pubspec.match(/^version:\s*([^\s+]+)(?:\+\d+)?\s*$/m);
  if (!match) {
    throw new Error("Could not read version from apps/mobile/pubspec.yaml");
  }
  return match[1];
}

function parseNotes(raw) {
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.replace(/^(?:[•・*\-–—]|\d+[\.)])\s*/, "").trim())
    .filter(Boolean)
    .slice(0, 6);
}

function escapeHtml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderHtml({ config, notes, version, iconPath }) {
  const longestNote = Math.max(...notes.map((note) => [...note].length));
  const noteClass = longestNote > 72 || notes.length > 5 ? "notes compact" : "notes";
  const escapedNotes = notes
    .map(
      (note, index) => `
        <li>
          <span class="note-num">${String(index + 1).padStart(2, "0")}</span>
          <span>${escapeHtml(note)}</span>
        </li>`,
    )
    .join("");

  return `<!DOCTYPE html>
<html lang="${escapeHtml(config.lang)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=${width}, initial-scale=1">
<style>
  :root {
    --accent: #5fe0cf;
    --accent-muted: rgba(95, 224, 207, 0.18);
    --bg: #050506;
    --panel: #0d0f12;
    --panel-strong: #111419;
    --border: #242830;
    --border-strong: #363c46;
    --text: #f5f7fb;
    --muted: #a7afbd;
    --muted-strong: #d3d8e2;
    --warm: #f4a261;
  }

  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    width: ${width}px;
    height: ${height}px;
    overflow: hidden;
    font-family: Inter, "Noto Sans JP", "Hiragino Sans", "Yu Gothic", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    color: var(--text);
    background-color: var(--bg);
    background-image:
      linear-gradient(rgba(255, 255, 255, 0.035) 1px, transparent 1px),
      linear-gradient(90deg, rgba(255, 255, 255, 0.035) 1px, transparent 1px);
    background-size: 72px 72px;
  }

  .stage {
    position: relative;
    width: 100%;
    height: 100%;
    padding: 64px 76px 70px;
    display: flex;
    flex-direction: column;
  }

  .stage::before {
    content: "";
    position: absolute;
    inset: 0;
    background:
      radial-gradient(circle at 12% 18%, rgba(95, 224, 207, 0.13), transparent 34%),
      radial-gradient(circle at 92% 82%, rgba(244, 162, 97, 0.11), transparent 32%);
    pointer-events: none;
  }

  .content {
    position: relative;
    z-index: 1;
  }

  .content {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }

  .brand-row {
    display: flex;
    align-items: center;
    gap: 18px;
    margin-bottom: 44px;
  }

  .icon {
    width: 68px;
    height: 68px;
    border-radius: 16px;
    box-shadow: 0 18px 40px rgba(0, 0, 0, 0.38);
  }

  .brand-name {
    font-size: 28px;
    font-weight: 800;
    letter-spacing: 0;
  }

  .tagline {
    color: var(--muted);
    font-size: 20px;
    line-height: 1.4;
    font-weight: 650;
    margin-left: 8px;
  }

  .eyebrow {
    display: inline-flex;
    align-items: center;
    width: fit-content;
    gap: 10px;
    padding: 9px 14px;
    border-radius: 8px;
    background: #0c1414;
    border: 1px solid var(--accent-muted);
    color: var(--accent);
    font-size: 18px;
    font-weight: 700;
    margin-bottom: 28px;
  }

  .dot {
    width: 9px;
    height: 9px;
    border-radius: 999px;
    background: var(--accent);
    box-shadow: 0 0 18px rgba(95, 224, 207, 0.75);
  }

  h1 {
    max-width: 100%;
    font-size: 94px;
    line-height: 1;
    letter-spacing: 0;
    font-weight: 800;
    color: #fff;
    white-space: nowrap;
  }

  .version {
    color: var(--accent);
  }

  .section-title {
    margin-top: 38px;
    color: var(--muted-strong);
    font-size: 24px;
    line-height: 1.2;
    font-weight: 700;
  }

  .notes {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 16px;
    margin-top: 22px;
    list-style: none;
  }

  .notes li {
    display: grid;
    grid-template-columns: 56px minmax(0, 1fr);
    align-items: start;
    gap: 16px;
    padding: 24px;
    min-height: 132px;
    background: rgba(13, 15, 18, 0.86);
    border: 1px solid var(--border);
    border-radius: 8px;
    box-shadow: 0 18px 44px rgba(0, 0, 0, 0.18);
    color: #fff;
    font-size: 31px;
    line-height: 1.22;
    font-weight: 650;
  }

  .notes.compact li {
    padding: 22px;
    min-height: 124px;
    font-size: 27px;
    line-height: 1.22;
  }

  .notes li:last-child:nth-child(odd) {
    grid-column: 1 / -1;
    min-height: 104px;
  }

  .note-num {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 48px;
    height: 48px;
    border-radius: 8px;
    background: var(--accent);
    color: #031111;
    font-size: 20px;
    font-weight: 900;
    font-variant-numeric: tabular-nums;
  }

</style>
</head>
<body>
  <main class="stage">
    <section class="content">
      <div class="brand-row">
        <img class="icon" src="${pathToFileURL(iconPath).href}" alt="">
        <div class="brand-name">CC Pocket</div>
        <div class="tagline">${escapeHtml(config.tagline)}</div>
      </div>

      <div class="eyebrow"><span class="dot"></span>${escapeHtml(config.eyebrow)}</div>
      <h1>${escapeHtml(config.titlePrefix)} <span class="version">v${escapeHtml(version)}</span></h1>
      <div class="section-title">${escapeHtml(config.sectionTitle)}</div>
      <ol class="${noteClass}">
        ${escapedNotes}
      </ol>
    </section>
  </main>
</body>
</html>`;
}
