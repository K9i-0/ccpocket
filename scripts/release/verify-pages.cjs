const { createHash } = require('node:crypto');

const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

module.exports = async function verifyPages({
  pageUrl, expected, core,
  fetchImpl = fetch,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  now = Date.now,
  timeoutMs = 600_000,
}) {
  const expectedHash = digest(expected);
  const url = new URL('sparkle/appcast.xml', pageUrl.endsWith('/') ? pageUrl : `${pageUrl}/`);
  const started = now();
  let lastResult = 'No response';
  while (now() - started < timeoutMs) {
    // Avoid a cached response from before this deployment. The digest itself
    // does not reveal secrets: this is the public, signed update feed.
    url.searchParams.set('verify', `${expectedHash}-${now()}`);
    try {
      const response = await fetchImpl(url, {
        headers: { 'Cache-Control': 'no-cache' },
        signal: AbortSignal.timeout(30_000),
      });
      const bytes = Buffer.from(await response.arrayBuffer());
      if (response.ok && digest(bytes) === expectedHash) {
        core.info('Published Sparkle appcast matches the uploaded artifact');
        return;
      }
      lastResult = `HTTP ${response.status}; published content does not match`;
    } catch {
      lastResult = 'Public Pages request failed';
    }
    core.info(`${lastResult}; waiting for Pages propagation`);
    await sleep(15_000);
  }
  throw new Error(`Pages content verification timed out: ${lastResult}`);
};
