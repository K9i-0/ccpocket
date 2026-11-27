#!/usr/bin/env node
/**
 * Records real screen footage of the markdown_kit example app using
 * Playwright + CDP Page.startScreencast (lossless PNG frames -> 30fps MP4).
 *
 * Outputs:
 *   raw/mobile_chat.mp4       (804x1748, 30fps — mobile streaming, touch selection, scroll survival, copy, dark mode)
 *   raw/desktop_editor.mp4    (2560x1520, 30fps — live typing, sub-ms parse, synced scroll, tap-to-jump, dark mode)
 *   raw/desktop_showcase.mp4  (2560x1520, 30fps — SliverMarkdownView, alerts, LaTeX math, custom inline, dark mode)
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {chromium} from '/Users/kotahayashi/Workspace/kasaneru/node_modules/playwright-core/index.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WEB_DIR = path.resolve(__dirname, '../../packages/markdown_kit/example/build/web');
const RAW_DIR = path.join(__dirname, 'raw');
const TMP_FRAMES_ROOT = '/tmp/markdown_kit_promo_frames';

fs.mkdirSync(RAW_DIR, {recursive: true});

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
};

function startStaticServer(rootDir) {
  const server = http.createServer((req, res) => {
    const urlPath = (req.url || '/').split('?')[0];
    const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
    const full = path.join(rootDir, rel);
    if (fs.existsSync(full) && fs.statSync(full).isFile()) {
      const ext = path.extname(full);
      res.writeHead(200, {'Content-Type': MIME[ext] || 'application/octet-stream'});
      fs.createReadStream(full).pipe(res);
    } else {
      res.writeHead(404);
      res.end('Not found');
    }
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const {port} = server.address();
      resolve({server, url: `http://127.0.0.1:${port}`});
    });
  });
}

class ScreencastRecorder {
  constructor(page, name, {fps = 30} = {}) {
    this.page = page;
    this.name = name;
    this.fps = fps;
    this.framesDir = path.join(TMP_FRAMES_ROOT, name);
    this.frames = [];
    this.running = false;
    this.loopPromise = null;
    this.stoppedAt = null;
  }

  async start() {
    fs.rmSync(this.framesDir, {recursive: true, force: true});
    fs.mkdirSync(this.framesDir, {recursive: true});
    this.frames = [];
    this.running = true;
    const intervalMs = 1000 / this.fps;

    this.loopPromise = (async () => {
      while (this.running) {
        const t0 = performance.now();
        try {
          const buf = await this.page.screenshot({type: 'png', animations: 'allow'});
          if (!this.running) break;
          const now = performance.now() / 1000;
          const idx = this.frames.length;
          const filePath = path.join(this.framesDir, `f_${String(idx).padStart(5, '0')}.png`);
          fs.writeFileSync(filePath, buf);
          if (idx === 0 && buf.length > 24) {
            const w = buf.readUInt32BE(16);
            const h = buf.readUInt32BE(20);
            console.log(`[${this.name}] exact viewport PNG size: ${w}x${h}`);
          }
          this.frames.push({filePath, wall: now});
        } catch {
          if (!this.running) break;
        }
        const elapsed = performance.now() - t0;
        const wait = Math.max(1, intervalMs - elapsed);
        await new Promise((r) => setTimeout(r, wait));
      }
    })();

    // Wait for first frame so start timing aligns cleanly
    while (this.frames.length === 0) {
      await new Promise((r) => setTimeout(r, 10));
    }
  }

  async stopAndEncode(outMp4, fps = 30) {
    this.running = false;
    this.stoppedAt = performance.now() / 1000;
    if (this.loopPromise) await this.loopPromise;

    if (this.frames.length < 2) {
      throw new Error(`Too few frames captured for ${this.name}: ${this.frames.length}`);
    }

    // Build ffmpeg concat list using exact wall-clock deltas
    const listPath = path.join(this.framesDir, 'concat.txt');
    const lines = [];
    for (let i = 0; i < this.frames.length; i++) {
      const curr = this.frames[i];
      const nextWall = i + 1 < this.frames.length ? this.frames[i + 1].wall : this.stoppedAt;
      const dur = Math.max(0.008, nextWall - curr.wall);
      lines.push(`file '${curr.filePath.replace(/'/g, "'\\''")}'`);
      lines.push(`duration ${dur.toFixed(6)}`);
    }
    lines.push(`file '${this.frames[this.frames.length - 1].filePath.replace(/'/g, "'\\''")}'`);
    fs.writeFileSync(listPath, lines.join('\n') + '\n');

    const res = spawnSync(
      'ffmpeg',
      [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', listPath,
        '-vf', `fps=${fps},scale=trunc(iw/2)*2:trunc(ih/2)*2:flags=accurate_rnd+full_chroma_int`,
        '-c:v', 'libx264',
        '-pix_fmt', 'yuv420p',
        '-crf', '14',
        '-preset', 'medium',
        '-movflags', '+faststart',
        outMp4,
      ],
      {stdio: 'pipe', encoding: 'utf8'}
    );
    if (res.status !== 0) {
      throw new Error(`ffmpeg failed for ${this.name}:\n${res.stderr}`);
    }
    const totalWall = (this.stoppedAt - this.frames[0].wall).toFixed(2);
    const effFps = (this.frames.length / Number(totalWall)).toFixed(1);
    console.log(`[${this.name}] encoded ${this.frames.length} frames (~${totalWall}s, capture ~${effFps}fps) -> ${outMp4}`);
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function touchTap(cdp, x, y, holdMs = 45) {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{x, y, id: 1}],
  });
  await sleep(holdMs);
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
}

async function touchLongPress(cdp, x, y, holdMs = 650) {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{x, y, id: 1}],
  });
  await sleep(holdMs);
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
}

async function touchDrag(cdp, x1, y1, x2, y2, steps = 45, durationMs = 1800) {
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [{x: x1, y: y1, id: 1}],
  });
  const stepMs = durationMs / steps;
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    // smooth ease-in-out
    const e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    const x = x1 + (x2 - x1) * e;
    const y = y1 + (y2 - y1) * e;
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [{x, y, id: 1}],
    });
    await sleep(stepMs);
  }
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
}

async function smoothWheel(page, x, y, totalDeltaY, steps = 40, durationMs = 1600) {
  await page.mouse.move(x, y);
  const perStep = totalDeltaY / steps;
  const stepMs = durationMs / steps;
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, perStep);
    await sleep(stepMs);
  }
}

async function recordMobileChat(browser, baseUrl) {
  console.log('\n=== Recording mobile_chat.mp4 ===');
  const ctx = await browser.newContext({
    viewport: {width: 402, height: 874},
    deviceScaleFactor: 2,
    hasTouch: true,
    isMobile: true,
    userAgent:
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
  });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);

  await page.goto(baseUrl, {waitUntil: 'networkidle'});
  await sleep(2500);

  const rec = new ScreencastRecorder(page, 'mobile_chat', {fps: 30});
  await rec.start();

  // Hold initial frame briefly
  await sleep(600);

  // 1. Tap "JSON & Math" preset to stream a full rich reply token by token
  await touchTap(cdp, 72, 792);
  // Wait for Normal speed streaming of sampleReply (~790 chars @ 2 chars/16ms ≈ 6.3s + margin)
  await sleep(7600);

  // Pause briefly to admire finished message (math, table, code, tip)
  await sleep(700);

  // Scroll up slightly so list + code block + table are nicely framed in upper-middle
  await touchDrag(cdp, 200, 350, 200, 560, 28, 850);
  await sleep(500);

  // 2. Long-press "Read" / "file" in item 1 ("1. Read the file as a string")
  await touchLongPress(cdp, 110, 290, 680);
  await sleep(600);

  // 3. Drag the end handle down across the Dart code block and into the table
  await touchDrag(cdp, 130, 314, 260, 625, 55, 2400);
  await sleep(900);

  // 4. Scroll the list up and back down WHILE SELECTION IS ACTIVE to prove scroll survival!
  await touchDrag(cdp, 340, 660, 340, 270, 32, 1100);
  await sleep(600);
  await touchDrag(cdp, 340, 270, 340, 660, 32, 1100);
  await sleep(800);

  // 5. Tap "Copy as Markdown" in the bottom selection pill (x=280, y=792)
  await touchTap(cdp, 280, 792);
  await sleep(1100);
  // Dismiss selection by tapping neutral margin so presets return
  await touchTap(cdp, 385, 160);
  await sleep(450);

  // 6. Toggle Dark theme (top-right chip x=358, y=22)
  await touchTap(cdp, 358, 22);
  await sleep(850);

  // 7. Tap "Streaming edge cases" preset in Dark mode (x=191, y=792)
  await touchTap(cdp, 191, 792);
  await sleep(6800);

  await rec.stopAndEncode(path.join(RAW_DIR, 'mobile_chat.mp4'), 30);
  await ctx.close();
}

async function recordDesktopEditor(browser, baseUrl) {
  console.log('\n=== Recording desktop_editor.mp4 ===');
  const ctx = await browser.newContext({
    viewport: {width: 1280, height: 760},
    deviceScaleFactor: 1.5,
  });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);

  await page.goto(`${baseUrl}/#/editor`, {waitUntil: 'networkidle'});
  await sleep(2500);

  const rec = new ScreencastRecorder(page, 'desktop_editor', {fps: 30});
  await rec.start();

  // Hold clean opening frame briefly
  await sleep(700);

  // 1. Click end of line 1 ("# Markdown editor") in left source pane and type a live callout
  await page.mouse.click(220, 116);
  await sleep(250);
  await page.keyboard.press('End');
  await sleep(150);
  await page.keyboard.press('Enter');
  await page.keyboard.press('Enter');

  // Note: the editor auto-continues `> ` after Enter on a blockquote line!
  const linesToType = [
    '> [!IMPORTANT]',
    'Only the **edited block** re-parses on every keystroke — under `1 ms`.',
  ];
  for (let li = 0; li < linesToType.length; li++) {
    const line = linesToType[li];
    for (const ch of line) {
      await page.keyboard.type(ch, {delay: 0});
      await sleep(40);
    }
    if (li === 0) {
      await page.keyboard.press('Enter');
      await sleep(120);
    }
  }
  await sleep(1000);

  // 2. Smoothly scroll left source pane downward to demonstrate block-by-block synced scrolling
  await smoothWheel(page, 320, 420, 560, 48, 2200);
  await sleep(700);
  await smoothWheel(page, 320, 420, 420, 36, 1700);
  await sleep(800);

  // 3. Click blocks in the right preview pane (code block & table/math) to jump caret in source!
  await page.mouse.click(860, 300);
  await sleep(900);
  await page.mouse.click(860, 520);
  await sleep(900);

  // 4. Toggle Dark mode (top-right chip x=1236, y=22)
  await page.mouse.click(1236, 22);
  await sleep(1100);

  // 5. Scroll smoothly back up in Dark mode showing code, table, alerts, math
  await smoothWheel(page, 940, 400, -480, 42, 2000);
  await sleep(1100);

  await rec.stopAndEncode(path.join(RAW_DIR, 'desktop_editor.mp4'), 30);
  await ctx.close();
}

async function recordDesktopShowcase(browser, baseUrl) {
  console.log('\n=== Recording desktop_showcase.mp4 ===');
  const ctx = await browser.newContext({
    viewport: {width: 1280, height: 760},
    deviceScaleFactor: 1.5,
  });
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);

  await page.goto(`${baseUrl}/#/showcase`, {waitUntil: 'networkidle'});
  await sleep(2500);

  const rec = new ScreencastRecorder(page, 'desktop_showcase', {fps: 30});
  await rec.start();

  await sleep(800);
  // Smooth scroll through lists, code, table, 5 GitHub alerts, LaTeX math, details, RTL
  await smoothWheel(page, 640, 420, 750, 50, 2200);
  await sleep(600);
  await smoothWheel(page, 640, 420, 880, 55, 2400);
  await sleep(700);

  // Toggle Dark theme while viewing Alerts & Math
  await page.mouse.click(1236, 22);
  await sleep(900);
  await smoothWheel(page, 640, 420, 620, 42, 2000);
  await sleep(1000);

  await rec.stopAndEncode(path.join(RAW_DIR, 'desktop_showcase.mp4'), 30);
  await ctx.close();
}

const only = process.argv[2] || 'all';
const {server, url} = await startStaticServer(WEB_DIR);
console.log('Static server listening at', url);

const browser = await chromium.launch({
  channel: 'chrome',
  headless: true,
});
try {
  if (only === 'all' || only === 'mobile') await recordMobileChat(browser, url);
  if (only === 'all' || only === 'editor') await recordDesktopEditor(browser, url);
  if (only === 'all' || only === 'showcase') await recordDesktopShowcase(browser, url);
} finally {
  await browser.close();
  server.close();
}
console.log('Done.');
