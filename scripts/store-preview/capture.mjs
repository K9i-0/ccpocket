#!/usr/bin/env node
// Captures the raw store screenshots from apps/mobile_preview, which runs
// ccpocket on iPhone 17 Pro, iPhone Duo (closed) and iPad Pro 13" (M5,
// landscape) side by side with multi_device_preview.
//
//   cd apps/mobile_preview && flutter run -d macos   # keep the window visible
//   node scripts/landing-preview/serve.mjs &           # media for LP Video/Audio
//   node scripts/store-preview/capture.mjs <vm-service-ws-uri> [--only iphone|ipad]
//
// Each scenario is opened on every device at once; the iPhone and Duo
// captures are taken in the dark theme, the iPad ones in the light theme.
// Files go to apps/mobile/fastlane/screenshots/en-US (override with --out).
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const args = process.argv.slice(2);
const uri = args.find((a) => a.startsWith('ws://'));
const option = (name) => {
  const i = args.indexOf(name);
  return i < 0 ? undefined : args[i + 1];
};
const only = option('--only');
const outDir = path.resolve(
  option('--out') ?? path.join(root, 'apps/mobile/fastlane/screenshots/en-US'),
);
if (!uri) {
  console.error('usage: capture.mjs <ws://127.0.0.1:PORT/TOKEN=/ws> [--only iphone|ipad] [--out dir]');
  process.exit(64);
}

// [key, extension, scenario, extra wait in ms, tap key before capture]
const phoneShots = [
  ['01_conversation', 'ccpocket.mock.openScenario', 'LP Conversation'],
  ['02_recent_sessions', 'ccpocket.navigateToStoreScenario', 'Recent Sessions'],
  ['03_approval_list', 'ccpocket.navigateToStoreScenario', 'Approval List'],
  ['04_git_review', 'ccpocket.navigateToStoreScenario', 'Git Actions'],
  ['05_network_resilience', 'ccpocket.mock.openScenario', 'LP Network'],
  ['06_imagegen', 'ccpocket.mock.openScenario', 'LP Imagegen', 1000],
  ['07_video', 'ccpocket.mock.openScenario', 'LP Video', 2000, 'file_peek_video_viewport'],
  ['08_audio', 'ccpocket.mock.openScenario', 'LP Audio', 2000],
];
const ipadShots = [
  ['01_workspace_overview', 'Workspace Overview'],
  ['02_workspace_explorer', 'Workspace Explorer'],
  ['03_approval_context', 'Approval In Context'],
  ['04_approval_queue', 'Approval Queue'],
  ['05_dark_workspace', 'Dark Workspace'],
];

const ws = new WebSocket(uri);
let nextId = 0;
const pending = new Map();
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  const request = pending.get(message.id);
  if (!request) return;
  pending.delete(message.id);
  if (message.error) request.reject(new Error(JSON.stringify(message.error)));
  else request.resolve(message.result);
};
const rpc = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = String(++nextId);
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
  });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let isolateId;
const ext = (name, params = {}) =>
  rpc(`ext.flutter.${name}`, { isolateId, ...params });

async function capture(device, file) {
  const target = path.join(outDir, file);
  await ext('multiDevicePreview.saveScreenshot', {
    path: target,
    device: String(device),
    frame: 'false',
  });
  console.log(`saved ${path.relative(root, target)}`);
}

async function open(extension, scenario, wait = 0, tapKey) {
  await ext('ccpocket.popToRoot');
  await sleep(500);
  await ext(extension, { scenario });
  await sleep(3000 + wait);
  if (tapKey) {
    await ext('marionette.tap', { key: tapKey });
    await sleep(800);
  }
}

ws.onopen = async () => {
  try {
    const vm = await rpc('getVM');
    isolateId = vm.isolates.find((i) => i.name === 'main')?.id ?? vm.isolates[0].id;
    const state = await ext('multiDevicePreview.getState');
    const index = (preset) => state.devices.find((d) => d.preset === preset)?.index;
    const iphone = index('apple-iphone-17-pro');
    const duo = index('apple-iphone-duo');
    const ipad = index('apple-ipad-pro-13-m5');

    await ext('ccpocket.setLocale', { locale: 'en' });
    if (only !== 'ipad') {
      await ext('ccpocket.setTheme', { theme: 'dark' });
      for (const [key, extension, scenario, wait, tapKey] of phoneShots) {
        await open(extension, scenario, wait, tapKey);
        if (iphone !== undefined) await capture(iphone, `${key}.png`);
        if (duo !== undefined) await capture(duo, `duo_${key}.png`);
      }
    }
    if (only !== 'iphone' && ipad !== undefined) {
      await ext('ccpocket.setTheme', { theme: 'light' });
      for (const [key, scenario] of ipadShots) {
        await open('ccpocket.navigateToStoreScenario', scenario);
        await capture(ipad, `ipad_${key}.png`);
      }
    }
    await ext('ccpocket.popToRoot');
    await ext('ccpocket.setTheme', { theme: 'system' });
    await ext('ccpocket.setLocale', { locale: '' });
    ws.close();
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
};
