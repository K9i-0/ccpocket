import { test } from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFile } from 'node:fs/promises';

const code = await readFile(new URL('app.js', import.meta.url), 'utf8');
function setup() {
  const elements = new Map();
  const element = id => {
    if (!elements.has(id)) elements.set(id, { value: '', textContent: '', disabled: false, prepend() {} });
    return elements.get(id);
  };
  const sockets = [];
  class Socket {
    readyState = 1; bufferedAmount = 0; messages = [];
    constructor() { sockets.push(this); }
    send(s) { this.messages.push(JSON.parse(s)); }
    close() { this.readyState = 3; this.onclose?.(); }
    emit(msg) { this.onmessage({ data: JSON.stringify(msg) }); }
  }
  let resolveMicrophone;
  let microphoneRequests = 0;
  vm.runInNewContext(code, {
    document: { getElementById: element, createElement: () => ({}) },
    window: { addEventListener() {} }, WebSocket: Socket, location: { host: '127.0.0.1:8790' },
    navigator: { mediaDevices: { getUserMedia() { microphoneRequests++; return new Promise(r => resolveMicrophone = r); } } },
    performance, setTimeout, clearTimeout, URL, Blob, console,
  });
  return { element, sockets, requests: () => microphoneRequests, resolveMicrophone: value => resolveMicrophone(value) };
}
test('uses the connection configuration and only adds user transcripts to the editable draft', () => {
  const { element: el, sockets } = setup();
  el('model').value = 'gpt-live-1'; el('version').value = 'v3'; el('connect').onclick();
  const ws = sockets[0]; ws.emit({ type: 'ready', allowed: true });
  assert.equal(ws.messages[0].model, 'gpt-live-1');
  assert.equal(el('model').disabled, true);
  ws.emit({ type: 'started' }); el('draft').value = 'Existing draft';
  ws.emit({ method: 'thread/realtime/transcript/done', params: { role: 'assistant', text: 'Not input' } });
  ws.emit({ method: 'thread/realtime/transcript/delta', params: { role: 'user', delta: 'Flut' } });
  assert.equal(el('partial').textContent, 'Flut');
  ws.emit({ method: 'thread/realtime/transcript/done', params: { role: 'user', text: 'Flutter' } });
  assert.equal(el('draft').value, 'Existing draft\nFlutter');
  assert.equal(el('partial').textContent, '');
});
test('surfaces the subscription auth error and allows reconnecting', () => {
  const { element: el, sockets } = setup(); el('connect').onclick();
  sockets[0].emit({ method: 'thread/realtime/error', params: { message: 'realtime conversation requires API key auth' } });
  assert.match(el('error').textContent, /requires API key auth/);
  assert.equal(el('connect').disabled, false);
  assert.equal(el('record').disabled, true);
});
test('prevents duplicate microphone requests and releases permission results after disconnect', async () => {
  const s = setup(), el = s.element; el('connect').onclick(); s.sockets[0].emit({ type: 'started' });
  const first = el('record').onclick(); await el('record').onclick(); assert.equal(s.requests(), 1);
  el('disconnect').onclick(); let stopped = false;
  s.resolveMicrophone({ getTracks: () => [{ stop() { stopped = true; } }] });
  await first; assert.equal(stopped, true); assert.equal(el('record').disabled, true);
});
