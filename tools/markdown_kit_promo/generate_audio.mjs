#!/usr/bin/env node
/**
 * Generates English male narration (Vertex AI Gemini 2.5 Flash Preview TTS, voice "Charon")
 * and subtle ambient tech BGM (Vertex AI Lyria 2 "lyria-002") using gcloud credentials.
 *
 * Outputs (48 kHz stereo 16-bit PCM WAV):
 *   audio/narration/<id>.wav
 *   audio/bgm_raw.wav
 *   audio/bgm_60s.wav
 *   audio/manifest_audio.json (measured durations & script metadata)
 */
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync, spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const AUDIO_DIR = path.join(__dirname, 'audio');
const NARR_DIR = path.join(AUDIO_DIR, 'narration');
fs.mkdirSync(NARR_DIR, {recursive: true});

const PROJECT = process.env.GCP_PROJECT || 'precise-machine-464113-b9';
const LOCATION = process.env.GCP_LOCATION || 'us-central1';
const VOICE_NAME = process.env.TTS_VOICE || 'Charon';
const TTS_MODEL = process.env.TTS_MODEL || 'gemini-2.5-flash-preview-tts';
const BGM_MODEL = 'lyria-002';

const STYLE_PROMPT =
  'Speak briskly and crisply with minimal pauses in a calm, modern American male narrator voice:';

export const NARRATION_SEGMENTS = [
  {
    id: '01_hero',
    targetFromFrame: 6,
    maxDurationSec: 3.7,
    text: 'Meet markdown kit. AI chat Markdown for Flutter.',
  },
  {
    id: '02_streaming',
    targetFromFrame: 126,
    maxDurationSec: 10.4,
    text: 'When agents stream token by token, finished blocks build once, while unfinished bold, code, and tables stay held back with zero flicker.',
  },
  {
    id: '03_selection',
    targetFromFrame: 458,
    maxDurationSec: 10.9,
    text: 'Drag touch handles across lists, code, and tables. Scroll freely and your highlight stays anchored. Copy plain text or Markdown.',
  },
  {
    id: '04_dark_mobile',
    targetFromFrame: 804,
    maxDurationSec: 2.6,
    text: 'Built-in dark theme included.',
  },
  {
    id: '05_editor_type',
    targetFromFrame: 896,
    maxDurationSec: 8.6,
    text: 'On desktop, it drives a live-preview editor. Every keystroke re-parses only the active block in under half a millisecond.',
  },
  {
    id: '06_editor_sync',
    targetFromFrame: 1164,
    maxDurationSec: 9.8,
    text: 'Source and preview scroll in sync block by block. Tap any block to jump to its source, and switch to dark mode instantly.',
  },
  {
    id: '07_showcase',
    targetFromFrame: 1474,
    maxDurationSec: 5.0,
    text: 'Pure Flutter widgets only, with slivers, alerts, math, custom rules, and R T L.',
  },
  {
    id: '08_outro',
    targetFromFrame: 1636,
    maxDurationSec: 4.9,
    text: 'Available now on pub dev and GitHub. Try the live web demo today.',
  },
];

function getAccessToken() {
  return execFileSync('gcloud', ['auth', 'print-access-token'], {encoding: 'utf8'}).trim();
}

function probeDuration(filePath) {
  const out = execFileSync(
    'ffprobe',
    ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', filePath],
    {encoding: 'utf8'}
  ).trim();
  return Number(out);
}

async function synthesizeSegment(token, seg) {
  const url = `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT}/locations/${LOCATION}/publishers/google/models/${TTS_MODEL}:generateContent`;
  const body = {
    contents: [
      {
        role: 'user',
        parts: [{text: `${STYLE_PROMPT} "${seg.text}"`}],
      },
    ],
    generationConfig: {
      responseModalities: ['AUDIO'],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: {
            voiceName: VOICE_NAME,
          },
        },
      },
    },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`TTS failed for ${seg.id} (HTTP ${res.status}): ${errText.slice(0, 400)}`);
  }
  const json = await res.json();
  const inline = json?.candidates?.[0]?.content?.parts?.find((p) => p.inlineData)?.inlineData;
  if (!inline?.data) {
    throw new Error(`No audio data returned for ${seg.id}: ${JSON.stringify(json).slice(0, 400)}`);
  }

  const rawPcmPath = path.join(NARR_DIR, `${seg.id}.raw.pcm`);
  const outWavPath = path.join(NARR_DIR, `${seg.id}.wav`);
  fs.writeFileSync(rawPcmPath, Buffer.from(inline.data, 'base64'));

  // Convert 24kHz mono L16 PCM -> trimmed, gently loudnorm'd 48kHz stereo 16-bit WAV
  // Trim leading/trailing near-silence while keeping 40ms natural breath padding
  const ff = spawnSync(
    'ffmpeg',
    [
      '-y',
      '-f', 's16le',
      '-ar', '24000',
      '-ac', '1',
      '-i', rawPcmPath,
      '-af',
      'silenceremove=start_periods=1:start_silence=0.03:start_threshold=-46dB,areverse,silenceremove=start_periods=1:start_silence=0.05:start_threshold=-46dB,areverse,apad=pad_dur=0.06,loudnorm=I=-16:TP=-1.5:LRA=9,aresample=48000',
      '-ac', '2',
      '-c:a', 'pcm_s16le',
      outWavPath,
    ],
    {stdio: 'pipe', encoding: 'utf8'}
  );
  fs.rmSync(rawPcmPath, {force: true});
  if (ff.status !== 0) {
    throw new Error(`ffmpeg failed converting ${seg.id}:\n${ff.stderr}`);
  }

  const durationSec = probeDuration(outWavPath);
  const status = durationSec <= seg.maxDurationSec ? 'OK' : 'LONG';
  console.log(
    `[tts] ${seg.id}: ${durationSec.toFixed(2)}s (budget <= ${seg.maxDurationSec}s) [${status}]`
  );
  return {
    id: seg.id,
    file: `audio/narration/${seg.id}.wav`,
    targetFromFrame: seg.targetFromFrame,
    maxDurationSec: seg.maxDurationSec,
    durationSec: Number(durationSec.toFixed(4)),
    text: seg.text,
  };
}

async function generateBgm(token) {
  const url = `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT}/locations/${LOCATION}/publishers/google/models/${BGM_MODEL}:predict`;
  const body = {
    instances: [
      {
        prompt:
          'Minimalist warm ambient electronic background music for a clean modern software product demo. ' +
          'Soft muted electric piano and subtle airy synth pads, gentle steady pulse at 94 BPM, ' +
          'calm, sleek, unobtrusive tech atmosphere, clean stereo mix, gentle dynamics.',
        negative_prompt:
          'vocals, singing, speech, spoken word, aggressive drums, heavy bass drop, distortion, loud cymbals, dramatic orchestral, harsh lead synth',
        seed: 20261127,
      },
    ],
    parameters: {
      sample_count: 1,
    },
  };

  console.log('\n=== Generating BGM with Vertex AI lyria-002 ===');
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lyria failed (HTTP ${res.status}): ${errText.slice(0, 500)}`);
  }
  const json = await res.json();
  const b64 = json?.predictions?.[0]?.bytesBase64Encoded;
  if (!b64) {
    throw new Error(`No BGM audio returned: ${JSON.stringify(json).slice(0, 400)}`);
  }

  const rawWav = path.join(AUDIO_DIR, 'bgm_raw.wav');
  const out60s = path.join(AUDIO_DIR, 'bgm_60s.wav');
  fs.writeFileSync(rawWav, Buffer.from(b64, 'base64'));
  const rawDur = probeDuration(rawWav);
  console.log(`[bgm] raw lyria-002 clip: ${rawDur.toFixed(2)}s -> ${rawWav}`);

  // Build a seamless 61.5s stereo 48kHz bed by crossfading the clean interior (~2s..30s) three times
  // with a smooth 4-second triangular crossfade, plus gentle high-shelf softening so voice stays crystal clear.
  const segLen = Math.min(28.0, Math.max(20.0, rawDur - 3.5));
  const ff = spawnSync(
    'ffmpeg',
    [
      '-y',
      '-i', rawWav,
      '-filter_complex',
      `[0:a]atrim=start=1.0:duration=${segLen.toFixed(2)},asetpts=PTS-STARTPTS,asplit=3[a1][a2][a3];` +
        `[a1][a2]acrossfade=d=4.0:c1=tri:c2=tri[m12];` +
        `[m12][a3]acrossfade=d=4.0:c1=tri:c2=tri,atrim=0:61.0,asetpts=PTS-STARTPTS,` +
        `highpass=f=60,lowpass=f=12000,loudnorm=I=-18:TP=-2.0:LRA=11,aresample=48000[out]`,
      '-map', '[out]',
      '-ac', '2',
      '-c:a', 'pcm_s16le',
      out60s,
    ],
    {stdio: 'pipe', encoding: 'utf8'}
  );
  if (ff.status !== 0) {
    throw new Error(`ffmpeg failed building 60s BGM:\n${ff.stderr}`);
  }
  const dur60 = probeDuration(out60s);
  console.log(`[bgm] seamless 60s loop: ${dur60.toFixed(2)}s -> ${out60s}`);
  return {file: 'audio/bgm_60s.wav', rawDurationSec: Number(rawDur.toFixed(4)), durationSec: Number(dur60.toFixed(4))};
}

const mode = process.argv[2] || 'all';
const token = getAccessToken();

const metaPath = path.join(AUDIO_DIR, 'manifest_audio.json');
const existing = fs.existsSync(metaPath) ? JSON.parse(fs.readFileSync(metaPath, 'utf8')) : {narration: [], bgm: null};

if (mode === 'all' || mode === 'tts') {
  console.log(`=== Generating English male narration (${TTS_MODEL} / ${VOICE_NAME}) ===`);
  const results = [];
  for (const seg of NARRATION_SEGMENTS) {
    results.push(await synthesizeSegment(token, seg));
  }
  existing.narration = results;
} else if (mode.startsWith('seg:')) {
  const targetId = mode.slice(4);
  const seg = NARRATION_SEGMENTS.find((s) => s.id === targetId);
  if (!seg) throw new Error(`Unknown segment: ${targetId}`);
  const item = await synthesizeSegment(token, seg);
  existing.narration = existing.narration.filter((x) => x.id !== targetId);
  existing.narration.push(item);
  existing.narration.sort(
    (a, b) =>
      NARRATION_SEGMENTS.findIndex((s) => s.id === a.id) - NARRATION_SEGMENTS.findIndex((s) => s.id === b.id)
  );
}

if (mode === 'all' || mode === 'bgm') {
  existing.bgm = await generateBgm(token);
}

existing.project = PROJECT;
existing.voice = VOICE_NAME;
existing.ttsModel = TTS_MODEL;
existing.bgmModel = BGM_MODEL;

fs.writeFileSync(metaPath, JSON.stringify(existing, null, 2) + '\n');
console.log(`\nWrote ${metaPath}`);
