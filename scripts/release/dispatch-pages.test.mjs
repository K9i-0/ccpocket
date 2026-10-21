import test from 'node:test';
import assert from 'node:assert/strict';
import publish from './dispatch-pages.cjs';

function fixture(conclusion = 'success', discover = true) {
  let time = 0;
  let input;
  const calls = [];
  const run = { id: 42, status: 'in_progress', html_url: 'https://example.test/run' };
  return {
    calls,
    options: {
      context: { repo: { owner: 'owner', repo: 'repo' }, runId: 123 },
      core: { info() {} },
      sleep: async (ms) => { time += ms; }, now: () => time, timeoutMs: 35_000,
      github: { rest: { actions: {
        createWorkflowDispatch: async (args) => { input = args.inputs; calls.push(args); },
        listWorkflowRuns: async () => ({ data: { workflow_runs: discover ? [
          { ...run, id: 999, display_title: 'Pages unrelated', status: 'completed', conclusion: 'success' },
          { ...run, display_title: `Pages ${input.request_id}` },
        ] : [] } }),
        getWorkflowRun: async (args) => {
          calls.push(args);
          return { data: { ...run, status: 'completed', conclusion } };
        },
      } } },
    },
  };
}

test('dispatches main and waits for the exact requesting run, not another success', async () => {
  const { options, calls } = fixture();
  await publish(options);
  assert.equal(calls[0].ref, 'main');
  assert.equal(calls[0].workflow_id, 'pages.yml');
  assert.match(calls[0].inputs.request_id, /^123-/);
  assert.equal(calls[1].run_id, 42);
});

for (const result of ['failure', 'cancelled', 'skipped']) {
  test(`propagates Pages ${result} to the release`, async () => {
    const { options } = fixture(result);
    await assert.rejects(publish(options), new RegExp(result));
  });
}

test('fails if the dispatched workflow never appears', async () => {
  const { options } = fixture('success', false);
  await assert.rejects(publish(options), /timed out/);
});
