#!/usr/bin/env node
/**
 * Builds manifest.json for the markdown_kit X promo video (1920x1080, 30fps, 60.0s).
 * Probes raw video and generated audio with kasaneru/media so every frame boundary is exact.
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
  mobileDarkFrame: 816,    // 27.20s (app toggles to dark mode at clip frame ~700)
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

// Audio placement (aligned to on-screen events; verified against probed WAV durations)
const narrationPlan = [
  {id: '01_hero', from: 8},         // 0.27s (Hero opener)
  {id: '02_streaming', from: 132},  // 4.40s (Mobile streaming)
  {id: '03_selection', from: 472},  // 15.73s (Drag selection -> scroll survival -> Copy)
  {id: '04_dark_mobile', from: 814},// 27.13s (Mobile dark theme switch)
  {id: '05_editor_type', from: 904},// 30.13s (Desktop live typing + <0.5ms parse)
  {id: '06_editor_sync', from: 1200},// 40.00s (Synced scroll -> tap jump -> 46.3s dark toggle)
  {id: '07_showcase', from: 1476},  // 49.20s (Dark Showcase: alerts, math, custom rules, RTL)
  {id: '08_outro', from: 1640},     // 54.67s (Outro CTA + 0.8s BGM tail)
];

const bgmFile = path.join(__dirname, 'audio/bgm_60s.wav');
const audioTracks = [];
let hasAudio = false;

if (fs.existsSync(bgmFile)) {
  const bgmInfo = probeMedia(bgmFile, FPS);
  console.log(`[probe] bgm: ${bgmInfo.durationSeconds}s (${bgmInfo.durationInFrames} frames, ${bgmInfo.channels}ch)`);
  audioTracks.push({
    src: 'audio/bgm_60s.wav',
    from: 0,
    durationInFrames: DURATION,
    volume: 0.24,
    fadeIn: 18,
    fadeOut: 45,
    duck: {
      by: 'narration',
      to: 0.38,
      attack: 6,
      release: 14,
      lead: 4,
      tail: 8,
      threshold: -35,
    },
  });
  hasAudio = true;
}

let prevEnd = 0;
for (const item of narrationPlan) {
  const rel = `audio/narration/${item.id}.wav`;
  const abs = path.join(__dirname, rel);
  if (!fs.existsSync(abs)) continue;
  const aInfo = probeMedia(abs, FPS);
  const durFrames = aInfo.durationInFrames;
  const endFrame = item.from + durFrames;
  if (item.from < prevEnd) {
    throw new Error(`Narration overlap: ${item.id} starts at ${item.from} before previous ends at ${prevEnd}`);
  }
  if (endFrame > DURATION) {
    throw new Error(`Narration ${item.id} exceeds video duration: ends at ${endFrame} > ${DURATION}`);
  }
  prevEnd = endFrame;
  console.log(
    `[audio] ${item.id}: frame ${item.from}..${endFrame} (${(item.from / FPS).toFixed(2)}s..${(endFrame / FPS).toFixed(2)}s, ${aInfo.durationSeconds}s)`
  );
  audioTracks.push({
    src: rel,
    from: item.from,
    durationInFrames: durFrames,
    group: 'narration',
    volume: 1.0,
    fadeIn: 2,
    fadeOut: 3,
  });
  hasAudio = true;
}

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
    // 3. S0 Hero: iPhone chassis & shadow ABOVE the desktop window!
    {
      type: 'scene',
      id: 'heroPhone',
      scene: 'heroPhone',
    },
    // 4. S0 Hero: Mobile chat streaming inside the iPhone screen (between status bar & home bar)
    {
      type: 'video',
      x: 816,
      y: 258,
      width: 294,
      height: 640,
      fit: 'cover',
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
    // 5. S1 + S2: Mobile chat continuous take inside main iPhone screen (leaves room for 38px mobile-readable subtitle)
    {
      type: 'video',
      x: 204,
      y: 92,
      width: 374,
      height: 814,
      fit: 'cover',
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
    // 6. S3: Desktop live-preview editor centered large (1376x818 exact 1.682 aspect)
    {
      type: 'video',
      x: 272,
      y: 138,
      width: 1376,
      height: 818,
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
    // 7. S4: Desktop showcase in dark mode centered large (1376x818 exact 1.682 aspect)
    {
      type: 'video',
      x: 272,
      y: 138,
      width: 1376,
      height: 818,
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
  ...(hasAudio
    ? {
        audio: audioTracks,
        master: {
          loudnorm: {i: -16, tp: -1.5, lra: 11},
          limiter: 0.95,
        },
      }
    : {}),
  props: {
    timeline,
    pubUrl: 'pub.dev/packages/markdown_kit',
    githubRepo: 'github.com/K9i-0/markdown_kit',
    demoUrl: 'k9i-0.github.io/markdown_kit',
  },
};

const outPath = path.join(__dirname, 'manifest.json');
fs.writeFileSync(outPath, JSON.stringify(manifest, null, 2) + '\n');
console.log(`Wrote ${outPath} (${DURATION} frames = ${(DURATION / FPS).toFixed(1)}s @ ${FPS}fps, audio tracks: ${audioTracks.length})`);
