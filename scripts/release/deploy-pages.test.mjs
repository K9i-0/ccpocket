import test from 'node:test';
import assert from 'node:assert/strict';
import deploy from './deploy-pages.cjs';

function fixture(statuses = ['succeed']) {
  const calls = [];
  const outputs = {};
  let time = 0;
  return {
    calls, outputs,
    options: {
      artifactId: '123',
      context: { repo: { owner: 'owner', repo: 'repo' }, sha: 'same-sha' },
      core: {
        getIDToken: async () => 'secret', setSecret() {}, info() {}, warning() {},
        setOutput: (key, value) => { outputs[key] = value; },
      },
      github: { request: async (route, args) => {
        calls.push({ route, args });
        if (route.startsWith('GET')) {
          const status = statuses.length > 1 ? statuses.shift() : statuses[0];
          if (status instanceof Error) throw status;
          return { data: { status } };
        }
        return { data: { id: 'deployment-123', page_url: 'https://example.test/' } };
      } },
      now: () => time,
      sleep: async (ms) => { time += ms; },
      timeoutMs: 15_000,
    },
  };
}

test('deploys the exact artifact with unique IDs even on the same commit', async () => {
  const first = fixture(['deployment_in_progress', 'succeed']);
  const second = fixture();
  second.options.artifactId = '456';
  await deploy(first.options);
  await deploy(second.options);
  assert.equal(first.calls[0].args.artifact_id, 123);
  assert.equal(first.calls[0].args.pages_build_version, 'artifact-123');
  assert.equal(second.calls[0].args.pages_build_version, 'artifact-456');
  assert.equal(first.calls[1].args.deployment_id, 'deployment-123');
  assert.equal(first.outputs.page_url, 'https://example.test/');
});

for (const status of ['deployment_failed', 'deployment_content_failed', 'deployment_cancelled', 'deployment_lost']) {
  test(`does not report success for ${status}`, async () => {
    const { options, calls, outputs } = fixture([status]);
    await assert.rejects(deploy(options), /Pages deployment failed/);
    assert.match(calls.at(-1).route, /\/cancel$/);
    assert.deepEqual(outputs, {});
  });
}

test('times out and cancels a deployment that never finishes', async () => {
  const { options, calls } = fixture(['deployment_in_progress']);
  await assert.rejects(deploy(options), /timed out/);
  assert.match(calls.at(-1).route, /\/cancel$/);
});

test('API failures cancel the deployment and remain failures', async () => {
  const { options, calls } = fixture([new Error('API unavailable')]);
  await assert.rejects(deploy(options), /API unavailable/);
  assert.match(calls.at(-1).route, /\/cancel$/);
});

test('missing artifact ID fails before authentication or deployment', async () => {
  const { options, calls } = fixture();
  options.artifactId = '';
  await assert.rejects(deploy(options), /artifact ID/);
  assert.equal(calls.length, 0);
});
