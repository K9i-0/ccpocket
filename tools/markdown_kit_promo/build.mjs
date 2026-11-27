#!/usr/bin/env node
/**
 * Builds manifest.json for the markdown_kit X promo video (1920x1080, 30fps, 60.0s, silent).
 * Probes raw footage with kasaneru/media to ensure every trim/duration fits safely.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {probeMedia} from '/Users/kotahayashi/Workspace/kasaneru/src/media.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FPS = 30;
const WIDTH = 1920;
const HEIGHT = 1080;
const DURATION = 1800; // 60.0s @ 30fps

const rawFiles = {
  mobile: path.join(__dirname, 'raw/mobile_chat.mp4'),
  editor: path.join(__dirname, 'raw/desktop_editor.mp4'),
  showcase: path.join(__dirname, 'raw/desktop_showcase.mp4'),
};

const info = {};
for (const [k, file] of Object.entries(rawFiles)) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing raw footage: ${file}. Run "node record.mjs all" first.`);
  }
  info[k] = probeMedia(file, FPS);
  console.log(`[probe] ${k}: ${info[k].width}x${info[k].height}, ${info[k].durationInFrames} frames`);
}

function assertClip(name, mediaInfo, trimBefore, durationInFrames) {
  if (trimBefore + durationInFrames > mediaInfo.durationInFrames) {
    throw new Error(
      `Clip ${name} exceeds asset length: trimBefore(${trimBefore}) + duration(${durationInFrames}) > ${mediaInfo.durationInFrames}`
    );
  }
}

// Section boundaries (integer frames @ 30fps — single source of truth passed via props)
const timeline = {
  fps: FPS,
  durationInFrames: DURATION,
  heroEnd: 120,            // 0.0s - 4.0s
  mobileStart: 120,        // 4.0s - 15.0s (Streaming)
  selectionStart: 450,     // 15.0s - 29.5s (Selection, Scroll survival, Copy, Dark)
  mobileDarkFrame: 806,    // 26.87s (app toggles to dark mode)
  editorStart: 885,        // 29.5s - 49.0s (Live typing, sub-ms parse, sync scroll, click jump, Dark)
  editorDarkFrame: 1388,   // 46.27s (editor toggles to dark mode)
  showcaseStart: 1470,     // 49.0s - 54.2s (SliverMarkdownView in Dark mode: 5 alerts, LaTeX math, details, RTL)
  outroStart: 1626,        // 54.2s - 60.0s (Outro CTA card)
};

// Verify every clip range against actual probed asset length
assertClip('hero_desktop', info.editor, 30, 126);
assertClip('hero_mobile', info.mobile, 45, 126);
assertClip('mobile_main', info.mobile, 0, 773);
assertClip('desktop_editor', info.editor, 10, 592);
assertClip('desktop_showcase', info.showcase, 288, 156);

const manifest = {
  composition: {
    width: WIDTH,
    height: HEIGHT,
    fps: FPS,
    durationInFrames: DURATION,
  },
  background: '#f4f7fb',
  scenes: {
    browser: 'scene.tsx',
  },
  layers: [
    // 1. Dynamic studio background + device frames/shadows behind video
    {
      type: 'scene',
      id: 'bg',
      scene: 'bg',
      opaque: true,
    },
    // 2. S0 Hero: Desktop editor live preview (back-right)
    {
      type: 'video',
      x: 910,
      y: 178,
      width: 904,
      height: 536,
      fit: 'cover',
      radius: 10,
      clips: [
        {
          src: 'raw/desktop_editor.mp4',
          from: 0,
          trimBefore: 30,
          durationInFrames: 124,
          fadeOut: 8,
        },
      ],
    },
    // 3. S0 Hero: Mobile chat streaming (front-center-right)
    {
      type: 'video',
      x: 822,
      y: 334,
      width: 304,
      height: 660,
      fit: 'cover',
      radius: 26,
      clips: [
        {
          src: 'raw/mobile_chat.mp4',
          from: 0,
          trimBefore: 45,
          durationInFrames: 124,
          fadeOut: 8,
        },
      ],
    },
    // 4. S1 + S2: Mobile chat continuous take (Streaming -> Touch Selection -> Scroll -> Copy -> Dark)
    {
      type: 'video',
      x: 150,
      y: 80,
      width: 414,
      height: 900,
      fit: 'cover',
      radius: 34,
      clips: [
        {
          src: 'raw/mobile_chat.mp4',
          from: 116,
          trimBefore: 0,
          durationInFrames: 773,
          fadeIn: 8,
          fadeOut: 8,
        },
      ],
    },
    // 5. S3: Desktop live-preview editor (Typing -> Sub-ms parse -> Sync scroll -> Jump -> Dark)
    {
      type: 'video',
      x: 96,
      y: 184,
      width: 1312,
      height: 778,
      fit: 'cover',
      radius: 8,
      clips: [
        {
          src: 'raw/desktop_editor.mp4',
          from: 882,
          trimBefore: 10,
          durationInFrames: 592,
          fadeIn: 8,
          fadeOut: 8,
        },
      ],
    },
    // 6. S4: Desktop showcase in dark mode (5 alerts, LaTeX math, details, custom inline, RTL)
    {
      type: 'video',
      x: 96,
      y: 184,
      width: 1278,
      height: 758,
      fit: 'cover',
      radius: 8,
      clips: [
        {
          src: 'raw/desktop_showcase.mp4',
          from: 1468,
          trimBefore: 288,
          durationInFrames: 156,
          fadeIn: 8,
          fadeOut: 10,
        },
      ],
    },
    // 7. Foreground typography, callouts, progress bar, device bezel polish, and outro card
    {
      type: 'scene',
      id: 'overlay',
      scene: 'overlay',
    },
  ],
  props: {
    timeline,
  },
};

const outPath = path.join(__dirname, 'manifest.json');
fs.writeFileSync(outPath, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Wrote ${outPath} (${DURATION} frames = ${(DURATION / FPS).toFixed(1)}s @ ${FPS}fps)`);
