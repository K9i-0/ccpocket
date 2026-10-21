// Dispatch on main instead of deploying Pages from a release tag. GitHub can
// report success for tag/release deployments while still serving the prior site.
module.exports = async function dispatchPages({
  github, context, core,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  now = Date.now,
  timeoutMs = 1_800_000,
}) {
  const requestId = `${context.runId}-${process.env.GITHUB_RUN_ATTEMPT || '1'}`;
  const title = `Pages ${requestId}`;
  const repo = context.repo;
  await github.rest.actions.createWorkflowDispatch({
    ...repo, workflow_id: 'pages.yml', ref: 'main', inputs: { request_id: requestId },
    request: { timeout: 30_000 },
  });
  const start = now();
  let runId;
  while (now() - start < timeoutMs) {
    await sleep(10_000);
    let run;
    if (runId) {
      ({ data: run } = await github.rest.actions.getWorkflowRun({
        ...repo, run_id: runId, request: { timeout: 30_000 },
      }));
    } else {
      const { data } = await github.rest.actions.listWorkflowRuns({
        ...repo, workflow_id: 'pages.yml', event: 'workflow_dispatch', branch: 'main', per_page: 100,
        request: { timeout: 30_000 },
      });
      run = data.workflow_runs.find((item) => item.display_title === title);
      if (!run) continue;
      runId = run.id;
      core.info(`Waiting for Pages publication: ${run.html_url}`);
    }
    if (run.status !== 'completed') continue;
    if (run.conclusion !== 'success') {
      throw new Error(`Pages publication ${run.conclusion}: ${run.html_url}`);
    }
    core.info(`Pages publication verified: ${run.html_url}`);
    return;
  }
  throw new Error(`Pages publication timed out (request ${requestId})`);
};
