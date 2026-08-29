#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PLATFORM_CONFIG = {
  ios: { tagPrefix: 'ios', workflow: 'iOS Release (Shorebird)' },
  android: {
    tagPrefix: 'android',
    workflow: 'Android Release (Shorebird)',
  },
  macos: { tagPrefix: 'macos', workflow: 'macOS Release' },
  linux: { tagPrefix: 'linux', workflow: 'Linux Release' },
  windows: { tagPrefix: 'windows', workflow: 'Windows Release' },
};

const configuredCommandTimeout = Number(
  process.env.CCPOCKET_RELEASE_COMMAND_TIMEOUT_MS,
);
const COMMAND_TIMEOUT_MS =
  Number.isFinite(configuredCommandTimeout) && configuredCommandTimeout > 0
    ? configuredCommandTimeout
    : 60_000;

const DEFAULTS = {
  preflight: {
    discoveryPollMs: 10_000,
    discoveryTimeoutMs: 120_000,
    pollMs: 30_000,
    slowPollMs: 30_000,
    slowAfterMs: Number.POSITIVE_INFINITY,
    heartbeatMs: 180_000,
    timeoutMs: 15 * 60_000,
  },
  release: {
    discoveryPollMs: 10_000,
    discoveryTimeoutMs: 120_000,
    pollMs: 60_000,
    slowPollMs: 90_000,
    slowAfterMs: 10 * 60_000,
    heartbeatMs: 180_000,
    timeoutMs: 40 * 60_000,
  },
};

function fail(message) {
  throw new Error(message);
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    maxBuffer: 50 * 1024 * 1024,
    timeout: COMMAND_TIMEOUT_MS,
    ...options,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const detail = (result.stderr || result.stdout || '').trim().slice(-600);
    fail(`${command} ${args.join(' ')} failed${detail ? `: ${detail}` : ''}`);
  }
  return result.stdout;
}

function parsePositiveInteger(value, option) {
  if (!/^\d+$/.test(value) || Number(value) <= 0) {
    fail(`${option} must be a positive integer`);
  }
  return Number(value);
}

export function parseArgs(argv) {
  const [phase, ...rest] = argv;
  if (phase !== 'preflight' && phase !== 'release') {
    fail('usage: monitor.mjs <preflight|release> [options]');
  }

  const options = { phase };
  for (let index = 0; index < rest.length; index += 2) {
    const option = rest[index];
    const value = rest[index + 1];
    if (!option?.startsWith('--') || value === undefined) {
      fail(`invalid option: ${option ?? '<missing>'}`);
    }
    const key = option.slice(2).replace(/-([a-z])/g, (_, letter) =>
      letter.toUpperCase(),
    );
    if (
      ![
        'sha',
        'version',
        'platforms',
        'discoveryPollMs',
        'discoveryTimeoutMs',
        'pollMs',
        'slowPollMs',
        'slowAfterMs',
        'heartbeatMs',
        'timeoutMs',
      ].includes(key)
    ) {
      fail(`unknown option: ${option}`);
    }
    options[key] = value;
  }

  for (const key of [
    'discoveryPollMs',
    'discoveryTimeoutMs',
    'pollMs',
    'slowPollMs',
    'slowAfterMs',
    'heartbeatMs',
    'timeoutMs',
  ]) {
    if (options[key] !== undefined) {
      options[key] = parsePositiveInteger(options[key], `--${key}`);
    }
  }
  return options;
}

export function releaseTargets(version, platforms) {
  if (!/^\d+\.\d+\.\d+\+\d+$/.test(version ?? '')) {
    fail('--version must use X.Y.Z+N format');
  }
  const selected = (platforms ?? '')
    .split(',')
    .map((platform) => platform.trim().toLowerCase())
    .filter(Boolean);
  if (selected.length === 0) fail('--platforms must not be empty');
  if (new Set(selected).size !== selected.length) {
    fail('--platforms must not contain duplicates');
  }
  return selected.map((platform) => {
    const config = PLATFORM_CONFIG[platform];
    if (!config) fail(`unsupported platform: ${platform}`);
    return {
      key: platform,
      branch: `${config.tagPrefix}/v${version}`,
      workflow: config.workflow,
    };
  });
}

function preflightTargets() {
  return [{ key: 'test', branch: 'main', workflow: 'Test' }];
}

function resolveReleaseSha(targets) {
  const shas = targets.map(({ branch }) =>
    run('git', ['rev-parse', `refs/tags/${branch}^{commit}`]).trim(),
  );
  if (new Set(shas).size !== 1) {
    fail('all release tags must point to the same commit');
  }
  return shas[0];
}

function validateSha(sha) {
  if (!/^[0-9a-f]{7,40}$/i.test(sha ?? '')) {
    fail('--sha must be a Git commit SHA');
  }
}

function resolveCommitSha(sha) {
  validateSha(sha);
  return run('git', ['rev-parse', `${sha}^{commit}`]).trim();
}

function ghRuns(phase, sha) {
  const fields =
    'databaseId,workflowName,headBranch,headSha,status,conclusion,url,createdAt';
  const args = ['run', 'list'];
  if (phase === 'preflight') {
    args.push(
      '--workflow=test.yml',
      '--branch=main',
      `--commit=${sha}`,
      '--event=push',
      '--limit=1',
    );
  } else {
    args.push(`--commit=${sha}`, '--limit=100');
  }
  args.push(`--json=${fields}`);
  return JSON.parse(run('gh', args));
}

function latestRunFor(target, sha, runs) {
  return runs
    .filter(
      (candidate) =>
        candidate.workflowName === target.workflow &&
        candidate.headBranch === target.branch &&
        candidate.headSha === sha,
    )
    .sort((left, right) =>
      String(right.createdAt).localeCompare(String(left.createdAt)),
    )[0];
}

function stateFor(runInfo) {
  if (!runInfo) return 'waiting';
  if (runInfo.status !== 'completed') return 'running';
  return runInfo.conclusion === 'success' ? 'success' : 'failed';
}

export function summarizeRuns(targets, sha, runs) {
  const items = targets.map((target) => {
    const runInfo = latestRunFor(target, sha, runs);
    return { ...target, run: runInfo, state: stateFor(runInfo) };
  });
  const counts = Object.fromEntries(
    ['waiting', 'running', 'success', 'failed'].map((state) => [
      state,
      items.filter((item) => item.state === state).length,
    ]),
  );
  return { items, counts };
}

function elapsedLabel(milliseconds) {
  const seconds = Math.max(0, Math.round(milliseconds / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return `${minutes}m${String(remainder).padStart(2, '0')}s`;
}

function summarySignature(summary) {
  return summary.items.map(({ key, state, run: itemRun }) =>
    `${key}:${state}:${itemRun?.databaseId ?? ''}`,
  ).join('|');
}

function summaryLine(phase, kind, summary, elapsedMs) {
  const states = summary.items
    .map(({ key, state }) => `${key}:${state}`)
    .join(',');
  return `${phase.toUpperCase()} ${kind} states=${states} elapsed=${elapsedLabel(elapsedMs)}`;
}

function failureDetails(runId) {
  let jobs = [];
  try {
    const output = run('gh', ['run', 'view', String(runId), '--json=jobs']);
    jobs = JSON.parse(output).jobs ?? [];
  } catch {
    // The run URL and conclusion still provide a useful compact failure.
  }

  const failedJobs = jobs.filter(
    (job) => job.status === 'completed' && job.conclusion !== 'success',
  );
  const jobNames = failedJobs.map((job) => job.name);
  const stepNames = failedJobs.flatMap((job) =>
    (job.steps ?? [])
      .filter(
        (step) =>
          step.status === 'completed' &&
          !['success', 'skipped'].includes(step.conclusion),
      )
      .map((step) => step.name),
  );

  let logPath = '';
  try {
    const log = run('gh', ['run', 'view', String(runId), '--log-failed']);
    const logDirectory = fs.mkdtempSync(
      path.join(os.tmpdir(), 'ccpocket-release-'),
    );
    logPath = path.join(logDirectory, `${runId}.log`);
    fs.writeFileSync(logPath, log, { mode: 0o600 });
  } catch {
    // A missing log must not hide the structured job/step summary.
  }
  return { jobNames, stepNames, logPath };
}

function compactList(values) {
  return values.length > 0 ? values.join(',').replace(/\s+/g, ' ').slice(0, 400) : '-';
}

export async function monitorRuns({
  phase,
  targets,
  sha,
  fetchRuns,
  fetchFailure = failureDetails,
  sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
  now = () => Date.now(),
  write = (line) => console.log(line),
  discoveryPollMs,
  discoveryTimeoutMs = 120_000,
  pollMs,
  slowPollMs,
  slowAfterMs,
  heartbeatMs,
  timeoutMs,
  maxConsecutiveErrors = 3,
}) {
  const startedAt = now();
  let lastSignature = '';
  let lastHeartbeatAt = startedAt;
  let consecutiveErrors = 0;

  while (true) {
    const elapsedMs = now() - startedAt;
    if (elapsedMs > timeoutMs) {
      write(`${phase.toUpperCase()} timeout elapsed=${elapsedLabel(elapsedMs)}`);
      return { ok: false, reason: 'timeout' };
    }

    let runs;
    try {
      runs = await fetchRuns();
      consecutiveErrors = 0;
    } catch (error) {
      consecutiveErrors += 1;
      if (consecutiveErrors === 1 || consecutiveErrors === maxConsecutiveErrors) {
        write(
          `${phase.toUpperCase()} gh-error attempt=${consecutiveErrors}/${maxConsecutiveErrors} message=${String(error.message).replace(/\s+/g, ' ').slice(0, 300)}`,
        );
      }
      if (consecutiveErrors >= maxConsecutiveErrors) {
        return { ok: false, reason: 'gh-error' };
      }
      await sleep(discoveryPollMs);
      continue;
    }

    const summary = summarizeRuns(targets, sha, runs);
    const signature = summarySignature(summary);
    const failures = summary.items.filter((item) => item.state === 'failed');
    if (failures.length > 0) {
      for (const item of failures) {
        const details = await fetchFailure(item.run.databaseId);
        write(
          `${phase.toUpperCase()} failed target=${item.key} run=${item.run.databaseId} jobs=${compactList(details.jobNames)} steps=${compactList(details.stepNames)} url=${item.run.url}${details.logPath ? ` log=${details.logPath}` : ''}`,
        );
      }
      return { ok: false, reason: 'failed', summary };
    }

    if (summary.counts.success === targets.length) {
      const runIds = summary.items
        .map(({ key, run: itemRun }) => `${key}:${itemRun.databaseId}`)
        .join(',');
      write(
        `${phase.toUpperCase()} success elapsed=${elapsedLabel(elapsedMs)} runs=${runIds}`,
      );
      return { ok: true, summary };
    }

    if (summary.counts.waiting > 0 && elapsedMs > discoveryTimeoutMs) {
      write(
        `${phase.toUpperCase()} discovery-timeout states=${summary.items.map(({ key, state }) => `${key}:${state}`).join(',')} elapsed=${elapsedLabel(elapsedMs)}`,
      );
      return { ok: false, reason: 'discovery-timeout', summary };
    }

    if (signature !== lastSignature) {
      const kind = summary.counts.waiting > 0 ? 'waiting' : 'running';
      write(summaryLine(phase, kind, summary, elapsedMs));
      lastSignature = signature;
      lastHeartbeatAt = now();
    } else if (now() - lastHeartbeatAt >= heartbeatMs) {
      write(summaryLine(phase, 'heartbeat', summary, elapsedMs));
      lastHeartbeatAt = now();
    }

    const interval =
      summary.counts.waiting > 0
        ? discoveryPollMs
        : elapsedMs >= slowAfterMs
          ? slowPollMs
          : pollMs;
    await sleep(interval);
  }
}

async function main(argv) {
  const options = parseArgs(argv);
  const defaults = DEFAULTS[options.phase];
  let targets;
  let sha;
  if (options.phase === 'preflight') {
    targets = preflightTargets();
    sha = resolveCommitSha(options.sha);
  } else {
    targets = releaseTargets(options.version, options.platforms);
    sha = options.sha
      ? resolveCommitSha(options.sha)
      : resolveReleaseSha(targets);
  }

  const result = await monitorRuns({
    phase: options.phase,
    targets,
    sha,
    fetchRuns: () => ghRuns(options.phase, sha),
    discoveryPollMs: options.discoveryPollMs ?? defaults.discoveryPollMs,
    discoveryTimeoutMs:
      options.discoveryTimeoutMs ?? defaults.discoveryTimeoutMs,
    pollMs: options.pollMs ?? defaults.pollMs,
    slowPollMs: options.slowPollMs ?? defaults.slowPollMs,
    slowAfterMs: options.slowAfterMs ?? defaults.slowAfterMs,
    heartbeatMs: options.heartbeatMs ?? defaults.heartbeatMs,
    timeoutMs: options.timeoutMs ?? defaults.timeoutMs,
  });
  if (!result.ok) process.exitCode = 1;
}

const isMain =
  process.argv[1] &&
  path.resolve(fileURLToPath(import.meta.url)) === path.resolve(process.argv[1]);
if (isMain) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(`MONITOR error message=${error.message}`);
    process.exitCode = 1;
  });
}
