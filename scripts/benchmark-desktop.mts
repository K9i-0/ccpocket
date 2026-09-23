/** Run: node --import tsx scripts/benchmark-desktop.mts [output.json]
 * Synthetic, warm-cache microbenchmarks; never touches a user's repository or Bridge.
 * FFmpeg first-frame timing is a decoder proxy, not Flutter/media_kit UI latency.
 */
import assert from 'node:assert/strict';
import { execFile as execFileCallback } from 'node:child_process';
import { createReadStream } from 'node:fs';
import { mkdtemp, readFile, realpath, rm, stat, writeFile } from 'node:fs/promises';
import { createServer, get } from 'node:http';
import { tmpdir, platform, release, cpus } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';
import { WebSocket, WebSocketServer } from 'ws';
import { MediaStore } from '../packages/bridge/src/media-store.js';
import { textPreview } from '../packages/bridge/src/text-preview.js';

const execFile = promisify(execFileCallback);
const repetitions = 11;
const root = await realpath(await mkdtemp(join(tmpdir(), 'ccpocket-bench-')));
const results: Record<string, unknown> = {};
const servers: ReturnType<typeof createServer>[] = [];
const sockets: WebSocket[] = [];
const mib = 1024 * 1024;

async function compare(name: string, cases: Record<string, () => Promise<unknown>>) {
  const entries = Object.entries(cases);
  const samples = Object.fromEntries(entries.map(([key]) => [key, [] as number[]]));
  for (const [, run] of entries) await run();
  for (let round = 0; round < repetitions; round++) {
    // Rotate order to reduce systematic warmup/order bias.
    for (let offset = 0; offset < entries.length; offset++) {
      const [key, run] = entries[(round + offset) % entries.length];
      const start = performance.now();
      await run();
      samples[key].push(performance.now() - start);
    }
  }
  results[name] = Object.fromEntries(Object.entries(samples).map(([key, values]) => {
    const sorted = [...values].sort((a, b) => a - b);
    return [key, { medianMs: sorted[Math.floor(sorted.length / 2)],
      p95Ms: sorted[Math.ceil(sorted.length * .95) - 1], samplesMs: values }];
  }));
  console.log(name, JSON.stringify(results[name], (key, value) => key === 'samplesMs' ? undefined : value));
}

async function listen(server: ReturnType<typeof createServer>) {
  servers.push(server);
  await new Promise<void>((ok, fail) => {
    server.once('error', fail);
    server.listen(0, '127.0.0.1', ok);
  });
  const address = server.address();
  assert(address && typeof address !== 'string');
  return `http://127.0.0.1:${address.port}`;
}

function consumeHttp(url: string, bytes: number) {
  return new Promise<void>((ok, fail) => {
    const request = get(url, { headers: { Range: `bytes=0-${bytes - 1}` } }, response => {
      assert.equal(response.statusCode, 206);
      let count = 0;
      response.on('data', chunk => { count += chunk.length; });
      response.on('error', fail);
      response.on('end', () => { try { assert.equal(count, bytes); ok(); } catch (e) { fail(e); } });
    });
    request.on('error', fail);
  });
}

async function consumeFile(file: string, bytes: number) {
  let count = 0;
  for await (const chunk of createReadStream(file, { start: 0, end: bytes - 1 })) count += chunk.length;
  assert.equal(count, bytes);
}

const splitPreview = (raw: string) => {
  const lines = raw.split('\n');
  return { content: lines.length > 5000 ? lines.slice(0, 5000).join('\n') : raw,
    totalLines: lines.length, truncated: lines.length > 5000 };
};
const scanPreview = (raw: string) => textPreview(raw, 5000);

try {
  const media = join(root, 'large.bin');
  await writeFile(media, Buffer.alloc(128 * mib, 0x61));
  const source = await readFile(new URL('../packages/bridge/src/media-store.ts', import.meta.url), 'utf8');
  const constructors: Record<string, typeof MediaStore> = { production256KiB: MediaStore };
  for (const size of [64, 1024]) {
    const file = join(root, `media-${size}.mts`);
    const needle = 'highWaterMark: 256 * 1024';
    assert(source.includes(needle), 'Update benchmark to match the production stream creation');
    await writeFile(file, source.replace(needle, `highWaterMark: ${size * 1024}`));
    constructors[size === 64 ? 'baseline64KiB' : '1024KiB'] = (await import(pathToFileURL(file).href)).MediaStore;
  }
  const stores: Record<string, { store: MediaStore; base: string; url: string }> = {};
  for (const [key, Constructor] of Object.entries(constructors)) {
    const store = new Constructor();
    const ref = await store.register(media, 'application/octet-stream', 128 * mib);
    const base = await listen(createServer((req, res) => {
      if (!store.handleRequest(req, res)) { res.writeHead(404); res.end(); }
    }));
    stores[key] = { store, base, url: base + ref.url };
  }
  for (const bytes of [64 * 1024, mib, 128 * mib]) {
    await compare(`media-${bytes}-bytes`, {
      direct: () => consumeFile(media, bytes),
      ...Object.fromEntries(Object.entries(stores).map(([key, { url }]) => [key, () => consumeHttp(url, bytes)])),
    });
  }
  for (const bytes of [64 * 1024, 16 * mib]) {
    const raw = ('short source line with 日本語\n').repeat(Math.ceil(bytes / 33));
    assert.deepEqual(scanPreview(raw), splitPreview(raw));
    await compare(`text-preview-${bytes}-target-bytes`, {
      split: async () => splitPreview(raw), scan: async () => scanPreview(raw),
    });
  }

  const gitRoot = join(root, 'repo');
  await execFile('git', ['init', '-q', gitRoot]);
  const git = (...args: string[]) => execFile('git', ['-c', 'core.hooksPath=/dev/null', ...args],
    { cwd: gitRoot, maxBuffer: 10 * mib, timeout: 30_000 });
  const original = Array.from({ length: 700 }, (_, i) => `line ${i}: original content\n`).join('');
  for (let i = 0; i < 200; i++) await writeFile(join(gitRoot, `${i}.txt`), original);
  await git('add', '.');
  await git('-c', 'user.name=Benchmark', '-c', 'user.email=benchmark@example.invalid',
    '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture');
  const changed = original.replaceAll('original', 'modified');
  for (let i = 0; i < 200; i++) await writeFile(join(gitRoot, `${i}.txt`), changed);
  const wsServer = createServer();
  const wss = new WebSocketServer({ server: wsServer });
  const imageFile = join(root, 'image.bin');
  await writeFile(imageFile, Buffer.alloc(4 * mib, 0x62));
  wss.on('connection', socket => {
    socket.on('message', data => {
      if (data.toString() === 'image') {
        void readFile(imageFile).then(bytes => socket.send(JSON.stringify({ base64: bytes.toString('base64') })));
      } else {
        void git('diff', '--no-color').then(({ stdout }) => socket.send(JSON.stringify({ diff: stdout })));
      }
    });
  });
  const ws = new WebSocket((await listen(wsServer)).replace('http:', 'ws:'));
  sockets.push(ws);
  await new Promise<void>((ok, fail) => { ws.once('open', ok); ws.once('error', fail); });
  const imageStore = stores.production256KiB;
  const imageRef = await imageStore.store.register(imageFile, 'application/octet-stream', 4 * mib);
  await compare('image-4MiB-transport-only', {
    direct: () => readFile(imageFile),
    websocketBase64: () => new Promise<void>((ok, fail) => {
      ws.once('message', data => {
        try {
          assert.equal(Buffer.from(JSON.parse(data.toString()).base64, 'base64').length, 4 * mib);
          ok();
        } catch (error) { fail(error); }
      });
      ws.send('image');
    }),
    httpBinary: () => consumeHttp(imageStore.base + imageRef.url, 4 * mib),
  });
  await compare('git-200-changed-files', {
    directAll: () => git('diff', '--no-color'),
    websocketAll: () => new Promise<void>((ok, fail) => {
      ws.once('message', data => { try { assert(JSON.parse(data.toString()).diff.length > 0); ok(); } catch (e) { fail(e); } });
      ws.send('{}');
    }),
    oneFile: () => git('diff', '--no-color', '--', '0.txt'),
    namesOnly: () => git('diff', '--name-status'),
  });
  results.gitFixture = { files: 200, linesPerFile: 700,
    allDiffBytes: Buffer.byteLength((await git('diff', '--no-color')).stdout) };
  // Also measure the common case; huge synthetic diffs alone overstate WS cost.
  for (let i = 3; i < 200; i++) await writeFile(join(gitRoot, `${i}.txt`), original);
  for (let i = 0; i < 3; i++) await writeFile(join(gitRoot, `${i}.txt`), original.replace('line 500:', 'changed 500:'));
  await compare('git-3-small-changes', {
    directAll: () => git('diff', '--no-color'),
    websocketAll: () => new Promise<void>((ok, fail) => {
      ws.once('message', data => { try { assert(JSON.parse(data.toString()).diff.length > 0); ok(); } catch (e) { fail(e); } });
      ws.send('{}');
    }),
    oneFile: () => git('diff', '--no-color', '--', '0.txt'),
    namesOnly: () => git('diff', '--name-status'),
  });

  // Generate a real seekable MP4 with metadata at the end and a faststart copy.
  const video = join(root, 'video.mp4');
  const fastVideo = join(root, 'faststart.mp4');
  try {
    const version = await execFile('ffmpeg', ['-version']);
    results.ffmpeg = version.stdout.split('\n')[0];
    await execFile('ffmpeg', ['-v', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=1280x720:rate=30',
      '-t', '15', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '18', video]);
    await execFile('ffmpeg', ['-v', 'error', '-i', video, '-c', 'copy', '-movflags', '+faststart', fastVideo]);
    results.videoBytes = (await stat(video)).size;
    for (const [layout, file] of [['tail-metadata', video], ['faststart', fastVideo]]) {
      const cases: Record<string, () => Promise<unknown>> = {};
      const decode = (input: string) => () => execFile('ffmpeg', ['-v', 'error', '-i', input,
        '-frames:v', '1', '-an', '-f', 'null', '-']);
      cases.direct = decode(file);
      for (const [key, { store, base }] of Object.entries(stores)) {
        const ref = await store.register(file, 'video/mp4', (await stat(file)).size);
        cases[key] = decode(base + ref.url);
      }
      await compare(`first-decoded-frame-${layout}`, cases);
      if (layout === 'tail-metadata') {
        const seekCases: Record<string, () => Promise<unknown>> = {};
        const seek = (input: string) => () => execFile('ffmpeg', ['-v', 'error', '-ss', '10', '-i', input,
          '-frames:v', '1', '-an', '-f', 'null', '-']);
        seekCases.direct = seek(file);
        for (const [key, { store, base }] of Object.entries(stores)) {
          const ref = await store.register(file, 'video/mp4', (await stat(file)).size);
          seekCases[key] = seek(base + ref.url);
        }
        await compare('seek-10s-first-decoded-frame', seekCases);
      }
    }
  } catch (error) {
    // Keep transport/Git measurements useful when FFmpeg is unavailable.
    results.videoError = String(error);
    console.error(error);
  }
  const report = { timestamp: new Date().toISOString(), node: process.version,
    platform: `${platform()} ${release()}`, cpu: cpus()[0]?.model, repetitions,
    scope: 'Warm-cache loopback component benchmarks; not Flutter UI timings. Git WS is a transport proxy, not the full Bridge handler.', results };
  if (process.argv[2]) await writeFile(resolve(process.argv[2]), JSON.stringify(report, null, 2) + '\n');
} finally {
  for (const socket of sockets) socket.terminate();
  for (const server of servers) {
    server.closeAllConnections();
    await new Promise<void>(ok => server.close(() => ok()));
  }
  await rm(root, { recursive: true, force: true });
}
