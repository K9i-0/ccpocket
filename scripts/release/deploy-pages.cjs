// GitHub's Pages API requires a unique pages_build_version. A commit SHA is
// insufficient: docs and Sparkle can deploy different content from the same SHA.
module.exports = async function deployPages({
  github, context, core, artifactId,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  now = Date.now,
  timeoutMs = 600_000,
}) {
  if (!/^[1-9]\d*$/.test(String(artifactId ?? ''))) {
    throw new Error('A Pages artifact ID is required');
  }
  const repo = context.repo;
  const version = `artifact-${artifactId}`;
  const oidcToken = await core.getIDToken();
  core.setSecret(oidcToken);
  const { data } = await github.request('POST /repos/{owner}/{repo}/pages/deployments', {
    ...repo,
    artifact_id: Number(artifactId),
    pages_build_version: version,
    oidc_token: oidcToken,
    request: { timeout: 30_000 },
  });
  const deploymentId = data.id || data.status_url?.split('/').pop() || version;
  core.info(`Deploying Pages artifact ${artifactId} as ${deploymentId}`);
  const started = now();
  const terminal = new Set([
    'deployment_failed', 'deployment_content_failed',
    'deployment_cancelled', 'deployment_lost',
  ]);
  try {
    while (now() - started < timeoutMs) {
      await sleep(5000);
      const { data: status } = await github.request(
        'GET /repos/{owner}/{repo}/pages/deployments/{deployment_id}',
        { ...repo, deployment_id: deploymentId, request: { timeout: 30_000 } },
      );
      if (status.status === 'succeed') {
        core.setOutput('page_url', data.page_url);
        return;
      }
      if (terminal.has(status.status)) {
        throw new Error(`Pages deployment failed: ${status.status}`);
      }
      core.info(`Pages deployment: ${status.status}`);
    }
    throw new Error('Pages deployment timed out');
  } catch (error) {
    // Do not leave an unfinished deployment blocking the shared Pages queue.
    await github.request(
      'POST /repos/{owner}/{repo}/pages/deployments/{deployment_id}/cancel',
      { ...repo, deployment_id: deploymentId, request: { timeout: 30_000 } },
    ).catch(() => core.warning('Could not cancel the Pages deployment'));
    throw error;
  }
};
