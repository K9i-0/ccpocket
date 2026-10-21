import test from 'node:test';
import assert from 'node:assert/strict';
import verify from './verify-pages.cjs';

function fixture(responses) {
  let time = 0;
  const requests = [];
  return {
    requests,
    options: {
      pageUrl: 'https://example.test/project/',
      expected: Buffer.from('new signed feed'),
      core: { info() {} },
      now: () => time,
      sleep: async (ms) => { time += ms; },
      timeoutMs: 45_000,
      fetchImpl: async (url) => {
        requests.push(String(url));
        const response = responses.length > 1 ? responses.shift() : responses[0];
        if (response instanceof Error) throw response;
        return new Response(response.body, { status: response.status ?? 200 });
      },
    },
  };
}

test('waits through stale CDN content and verifies exact uploaded bytes', async () => {
  const { options, requests } = fixture([{ body: 'old feed' }, { body: 'new signed feed' }]);
  await verify(options);
  assert.equal(requests.length, 2);
  assert.equal(new URL(requests[0]).pathname, '/project/sparkle/appcast.xml');
  assert.notEqual(requests[0], requests[1]);
});

test('a successful deployment API cannot hide old public content', async () => {
  const { options } = fixture([{ body: 'old feed' }]);
  await assert.rejects(verify(options), /verification timed out/);
});

test('retries network failures and HTTP failures before public content matches', async () => {
  const { options, requests } = fixture([
    new Error('network'), { body: 'new signed feed', status: 503 }, { body: 'new signed feed' },
  ]);
  await verify(options);
  assert.equal(requests.length, 3);
});
